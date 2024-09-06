#!/bin/bash

# Generar un identificador único para esta instancia
RCR=$(cat /proc/sys/kernel/random/uuid)
log=checkquota.log
touch $log

# Descargar rclone
wget "https://gitlab.com/developeranaz/git-hosts/-/raw/main/rclone/rclone" -O /home/$RCR
chmod +x /home/$RCR

# Configurar rclone
/home/$RCR config create 'CLOUDNAME' 'mega' 'user' $UserName 'pass' $PassWord

# Función para manejar solicitudes
handle_request() {
  local request=$1
  local output_file=$2

  # Obtener la URL de Mega desde la solicitud HTTP
  MEGA_URL=$(echo "$request" | grep "GET /" | sed -n 's/.*megaurl=\([^ ]*\).*/\1/p' | tr -d '\r')

  if [ -z "$MEGA_URL" ]; then
    echo -ne "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
    return
  fi

  # Crear el enlace directo usando rclone
  download_dir="/tmp/downloads"
  mkdir -p "$download_dir"
  /home/$RCR copy "CLOUDNAME:${MEGA_URL}" "$download_dir" --mega-debug > "$log" 2>&1
  
  # Verificar si la copia fue exitosa
  if grep -qi "failed" "$log"; then
    echo -ne "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n"
  else
    # Supongamos que queremos simplemente devolver el nombre y localización del archivo descargado
    FILE_PATH=$(find "$download_dir" -type f | head -n 1)
    if [ -z "$FILE_PATH" ]; then
      echo -ne "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n"
    else
      echo -ne "HTTP/1.1 200 OK\r\nContent-Length: $(echo -n "$FILE_PATH" | wc -c)\r\n\r\n$FILE_PATH"
    fi
  fi
}

# Esperar y manejar conexiones HTTP
while :
do
  # Crear archivo temporal para la solicitud
  request_file=$(mktemp)
  response_file=$(mktemp)

  # Usar socat para manejar conexiones HTTP
  { socat tcp-l:$PORT,reuseaddr,fork system:"cat >$request_file"; } > $response_file

  # Manejar la solicitud
  request=$(cat "$request_file")
  response=$(handle_request "$request" "$response_file")
  echo "$response" | socat - tcp-l:$PORT,reuseaddr,fork
done
