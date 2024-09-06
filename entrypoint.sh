#!/bin/bash

# Generar un identificador único para esta instancia
RCR=$(cat /proc/sys/kernel/random/uuid)
touch checkquota.log
log=checkquota.log

# Descargar rclone
wget "https://gitlab.com/developeranaz/git-hosts/-/raw/main/rclone/rclone" -O /home/$RCR
chmod +x /home/$RCR

# Dar permisos de ejecución a los scripts
chmod +x /Mega-index-heroku/quota-bypass/init.sh
chmod +x /Mega-index-heroku/quota-bypass/login.sh
chmod +x /Mega-index-heroku/quota-bypass/bypass.sh
touch /Mega-index-heroku/quota-bypass/checkquota.log

# Verificar la versión de rclone
/home/$RCR version

# Configurar rclone
/home/$RCR config create 'CLOUDNAME' 'mega' 'user' $UserName 'pass' $PassWord

while :
do
  # Esperar conexión HTTP
  { echo -ne "HTTP/1.1 200 OK\r\nContent-Length: $(wc -c <resp.txt)\r\n\r\n"; cat resp.txt; } | nc -l -p "$PORT" -q 1 >request.txt
  
  # Obtener la URL de Mega desde la solicitud HTTP
  MEGA_URL=$(cat request.txt | grep "megaurl=" | cut -d'=' -f2 | tr -d '\r')

  # Crear el enlace directo usando rclone
  DIRECT_URL=$(/home/$RCR link "CLOUDNAME:${MEGA_URL}")

  # Enviar la respuesta HTTP con el enlace directo
  echo -ne "HTTP/1.1 200 OK\r\nContent-Length: $(echo -n "$DIRECT_URL" | wc -c)\r\n\r\n$DIRECT_URL" > resp.txt
done

# Manejo de cuota automática (Auto_Quota_Bypass)
if [ "$Auto_Quota_Bypass" = true ] ; then
  /home/$RCR serve http CLOUDNAME: --addr :$PORT --buffer-size 256M --dir-cache-time 12h --vfs-read-chunk-size 256M --vfs-read-chunk-size-limit 2G --vfs-cache-mode writes > "$log" 2>&1 &

  while sleep 10
  do
    if fgrep --quiet "Bandwidth Limit Exceeded" "$log"
    then
      cd /Mega-index-heroku/quota-bypass
      bash bypass.sh
    fi
  done
else
  /home/$RCR serve http CLOUDNAME: --addr :$PORT --buffer-size 256M --dir-cache-time 12h --vfs-read-chunk-size 256M --vfs-read-chunk-size-limit 2G --vfs-cache-mode writes
fi
