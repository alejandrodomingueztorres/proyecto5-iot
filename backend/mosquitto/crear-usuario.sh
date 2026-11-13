#!/usr/bin/env bash
# Crea un usuario MQTT o le cambia la clave (Rol 2, R5.2).
#
# Uso, en la VM y desde la carpeta backend/:
#   sudo bash mosquitto/crear-usuario.sh dev01            # genera una clave aleatoria
#   sudo bash mosquitto/crear-usuario.sh nodered "$CLAVE" # usa la clave indicada
#   sudo bash mosquitto/crear-usuario.sh dev04 --borrar   # elimina el usuario
#
# La clave se muestra UNA vez en pantalla: pásala por el chat privado del
# grupo, nunca al repo. El archivo passwd guarda solo el hash y está en el
# .gitignore. Recuerda que el usuario también necesita su bloque en acl.conf.
set -euo pipefail

cd "$(dirname "$0")"   # backend/mosquitto

IMAGEN=eclipse-mosquitto:2.0.20
MOSQUITTO_UID=1883
PASSWD=config/passwd

USUARIO=${1:-}
CLAVE=${2:-}
if [ -z "$USUARIO" ]; then
  echo "Uso: $0 <usuario> [clave | --borrar]" >&2
  exit 1
fi

# mosquitto_passwd se ejecuta dentro de la imagen de Mosquitto, así no hay
# que instalar nada en la VM y el hash queda en el formato que usa el broker.
# --entrypoint evita que la imagen le cambie el dueño a todo config/.
mosquitto_passwd() {
  docker run --rm --entrypoint mosquitto_passwd \
    -v "$PWD/config:/mosquitto/config" "$IMAGEN" "$@"
}

if [ "$CLAVE" = "--borrar" ]; then
  mosquitto_passwd -D /mosquitto/config/passwd "$USUARIO"
  echo "Usuario $USUARIO eliminado."
else
  GENERADA=no
  if [ -z "$CLAVE" ]; then
    CLAVE=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
    GENERADA=si
  fi
  if [ -f "$PASSWD" ]; then
    mosquitto_passwd -b /mosquitto/config/passwd "$USUARIO" "$CLAVE"
  else
    mosquitto_passwd -c -b /mosquitto/config/passwd "$USUARIO" "$CLAVE"
  fi
  echo "Usuario $USUARIO listo."
  if [ "$GENERADA" = si ]; then
    echo "Clave generada (cópiala ahora, no se vuelve a mostrar): $CLAVE"
  fi
fi

chown "$MOSQUITTO_UID:$MOSQUITTO_UID" "$PASSWD"
chmod 600 "$PASSWD"

# SIGHUP: Mosquitto recarga passwd y acl.conf sin desconectar a nadie. La señal se
# manda desde dentro del contenedor: con "docker compose kill -s SIGHUP", Docker marca el
# contenedor como detenido a mano y no lo vuelve a levantar al prender la VM.
if docker compose -f ../docker-compose.yml ps --status running --services 2>/dev/null | grep -qx mosquitto; then
  docker compose -f ../docker-compose.yml exec -T mosquitto kill -HUP 1 </dev/null >/dev/null 2>&1
  echo "Mosquitto recargó usuarios y permisos."
fi
