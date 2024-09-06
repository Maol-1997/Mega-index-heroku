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

  # Obtener la URL de Mega desde la solicitud HTTP
  MEGA_URL=$(echo "$request" | grep "GET /" | sed -n 's/.*megaurl=\([^ ]*\).*/\1/p' | tr -d '\r')

  if [ -z "$MEGA_URL" ]; then
    echo -ne "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
    return
  fi

  # Crear el enlace directo usando rclone
  DIRECT_URL=$(/home/$RCR link "CLOUDNAME:${MEGA_URL}")

  if [ -z "$DIRECT_URL" ]; then
    echo -ne "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n"
    return
  fi

  # Enviar la respuesta HTTP con el enlace directo
  echo -ne "HTTP/1.1 200 OK\r\nContent-Length: $(echo -n "$DIRECT_URL" | wc -c)\r\n\r\n$DIRECT_URL"
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

while :
do
  # Usar socat para manejar conexiones HTTP
  request=$(socat - TCP-LISTEN:$PORT,crlf,reuseaddr,fork 2>/dev/null | head -n 1)
  response=$(handle_request "$request")
  echo "$response" | socat - TCP-LISTEN:$PORT,crlf,reuseaddr,fork 2>/dev/null
done
