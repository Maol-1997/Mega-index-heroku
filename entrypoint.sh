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
  local request_file=$1
  local response_file=$2

  # Obtener la URL de Mega desde la solicitud HTTP
  MEGA_URL=$(grep "megaurl=" "$request_file" | cut -d'=' -f2 | tr -d '\r')

  # Crear el enlace directo usando rclone
  DIRECT_URL=$(/home/$RCR link "CLOUDNAME:${MEGA_URL}")

  # Enviar la respuesta HTTP con el enlace directo
  echo -ne "HTTP/1.1 200 OK\r\nContent-Length: $(echo -n "$DIRECT_URL" | wc -c)\r\n\r\n$DIRECT_URL" > "$response_file"
}

# Iniciar el servicio de rclone con manejo de cuota automática si está habilitado
start_rclone_service() {
  /home/$RCR serve http CLOUDNAME: --addr :$PORT --buffer-size 256M --dir-cache-time 12h --vfs-read-chunk-size 256M --vfs-read-chunk-size-limit 2G --vfs-cache-mode writes > "$log" 2>&1 &
  
  if [ "$Auto_Quota_Bypass" = true ] ; then
    while sleep 10; do
      if fgrep --quiet "Bandwidth Limit Exceeded" "$log"; then
        cd /Mega-index-heroku/quota-bypass
        bash bypass.sh
      fi
    done
  fi
}

# Iniciar el servicio rclone con manejo de cuota automática en segundo plano
start_rclone_service &

# Esperar y manejar conexiones HTTP
while :
do
  # Crear archivos temporales para la solicitud y la respuesta
  request_file=$(mktemp)
  response_file=$(mktemp)

  # Esperar conexión HTTP
  { echo -ne "HTTP/1.1 200 OK\r\nContent-Length: $(wc -c <"$response_file")\r\n\r\n"; cat "$response_file"; } | nc -l -p "$PORT" -q 1 > "$request_file"

  # Manejar la solicitud
  handle_request "$request_file" "$response_file"

  # Limpiar archivos temporales
  rm "$request_file" "$response_file"
done
