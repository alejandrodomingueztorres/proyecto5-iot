#!/usr/bin/env bash
# Prueba de escalado (Rol 2 + Rol 5): lanza N simuladores extra, mide el
# consumo con docker stats y cuenta los mensajes recibidos frente a los esperados.
#
# Uso, en la VM y desde la carpeta backend/:
#   sudo bash escalado/escalado.sh 0        # PE.1: línea base (solo dev01 y dev02)
#   sudo bash escalado/escalado.sh 10       # PE.2: 10 simuladores extra, 5 minutos
#   sudo bash escalado/escalado.sh 50       # PE.3: 50 simuladores extra, 5 minutos
#   sudo bash escalado/escalado.sh 2 1      # prueba corta: 2 simuladores, 1 minuto
#   ... --conservar-datos                   # no borrar de InfluxDB los puntos de la prueba
#
# Qué hace (y deshace al final, aunque se corte con Ctrl+C):
#   - Crea el usuario MQTT temporal "escalado" (puede escribir en iot/#) y lo
#     borra al terminar. Mosquitto recarga usuarios y ACL con SIGHUP: los
#     dispositivos reales no se desconectan.
#   - Lanza los simuladores como contenedores (imagen de device/) con
#     DEVICE_ID sim001, sim002, ... en la red de Compose.
#   - Mide: docker stats cada 15 s, mensajes que llegan al broker (suscriptor
#     nodered) y puntos guardados en InfluxDB por Node-RED (PE.4).
#   - Limpia: contenedores, usuario, estado retenido iot/simNNN/status y, salvo
#     --conservar-datos, los puntos simNNN en InfluxDB.
#
# Resultados en ~/escalado-resultados/<fecha>-N<n>/ (fuera del repo).
set -euo pipefail

cd "$(dirname "$0")/.."   # backend/

N=${1:?Uso: $0 <simuladores> [minutos] [--conservar-datos]}
MIN=${2:-5}
[ "${2:-}" = "--conservar-datos" ] && MIN=5
CONSERVAR=no; for a in "$@"; do [ "$a" = "--conservar-datos" ] && CONSERVAR=si; done
DUR=$((MIN * 60))
INTERVALO=5
IMG_MQTT=eclipse-mosquitto:2.0.20
IMG_SIM=p5-simulador:escalado
RED=backend_default
ACL=mosquitto/config/acl.conf
CERTS="$PWD/mosquitto/config/certs"
DC="docker compose"

set -a; . ./.env; set +a
HOME_REAL=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
OUT="$HOME_REAL/escalado-resultados/$(date -u +%Y%m%d-%H%M)-N$N"
mkdir -p "$OUT"
log() { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "$OUT/resumen.txt"; }
ids() { for i in $(seq 1 "$N"); do printf 'sim%03d\n' "$i"; done; }

limpiar() {
  set +e
  log "Limpiando..."
  # docker stop (SIGTERM): el simulador publica "offline" y se despide limpio,
  # así el broker no dispara el Last Will después de borrar el estado retenido.
  docker ps -q --filter label=p5-escalado=1 | xargs -r docker stop -t 5 >/dev/null
  docker ps -aq --filter label=p5-escalado=1 | xargs -r docker rm -f >/dev/null
  sleep 2
  if [ "$N" -gt 0 ] && [ -n "${CLAVE:-}" ]; then
    # Borra el estado retenido de los simuladores (mensaje vacío retenido).
    for id in $(ids); do
      docker run --rm --network "$RED" -v "$CERTS:/certs:ro" $IMG_MQTT mosquitto_pub -h mosquitto -p 8883 \
        --cafile /certs/ca.crt -u escalado -P "$CLAVE" -r -n -t "iot/$id/status" 2>/dev/null
    done
  fi
  docker run --rm --entrypoint mosquitto_passwd -v "$PWD/mosquitto/config:/mosquitto/config" $IMG_MQTT \
    -D /mosquitto/config/passwd escalado 2>/dev/null
  chown 1883:1883 mosquitto/config/passwd; chmod 600 mosquitto/config/passwd
  # El repo es de azureuser: git como root se niega a operar sobre él.
  if [ -n "${SUDO_USER:-}" ]; then sudo -u "$SUDO_USER" git checkout -q -- "$ACL"
  else git -c safe.directory='*' checkout -q -- "$ACL"; fi
  $DC kill -s SIGHUP mosquitto >/dev/null 2>&1
  if [ "$N" -gt 0 ] && [ "$CONSERVAR" = no ] && [ -n "${T0:-}" ]; then
    for id in $(ids); do
      $DC exec -T influxdb influx delete --org "$INFLUXDB_ORG" --bucket "$INFLUXDB_BUCKET" \
        --start 2000-01-01T00:00:00Z --stop 2100-01-01T00:00:00Z --predicate "device_id=\"$id\"" 2>/dev/null
    done
    log "Puntos sim* borrados de InfluxDB (usa --conservar-datos para dejarlos)."
  fi
  log "Usuario 'escalado' borrado, acl.conf restaurado, simuladores eliminados."
}

contar_influx() {  # $1 = regex de device_id, $2 = inicio, $3 = fin (RFC3339)
  $DC exec -T influxdb influx query --org "$INFLUXDB_ORG" --raw "
from(bucket: \"$INFLUXDB_BUCKET\")
  |> range(start: $2, stop: $3)
  |> filter(fn: (r) => r._measurement == \"lecturas\" and r._field == \"value\" and r.device_id =~ /$1/)
  |> group() |> count()" 2>/dev/null | awk -F, '$0 ~ /^,_result/ {s += $NF} END {print s + 0}'
}

log "Escalado: $N simuladores extra, $MIN min. Resultados en $OUT"
log "VM: $(nproc) vCPU, $(free -m | awk '/Mem:/ {print $2}') MiB RAM"

if [ "$N" -gt 0 ]; then
  trap limpiar EXIT
  log "Construyendo la imagen del simulador desde device/..."
  CTX=$(mktemp -d); cp ../device/Dockerfile ../device/requirements.txt ../device/simulador.py "$CTX"/
  cp mosquitto/config/certs/ca.crt "$CTX"/
  docker build -q -t $IMG_SIM "$CTX" >/dev/null; rm -rf "$CTX"

  log "Creando el usuario MQTT temporal 'escalado'..."
  CLAVE=$(openssl rand -hex 16)
  docker run --rm --entrypoint mosquitto_passwd -v "$PWD/mosquitto/config:/mosquitto/config" $IMG_MQTT \
    -b /mosquitto/config/passwd escalado "$CLAVE" 2>&1 | grep -v "^Warning" || true
  chown 1883:1883 mosquitto/config/passwd; chmod 600 mosquitto/config/passwd
  printf '\nuser escalado\ntopic write iot/#\n' >> "$ACL"
  $DC kill -s SIGHUP mosquitto >/dev/null 2>&1
  sleep 2

  log "Lanzando $N simuladores..."
  for id in $(ids); do
    docker run -d --name "esc-$id" --label p5-escalado=1 --network "$RED" --restart no \
      -e DEVICE_ID="$id" -e MQTT_USER=escalado -e MQTT_PASSWORD="$CLAVE" \
      -e BROKER_HOST=mosquitto -e BROKER_PORT=8883 -e CA_CERT_PATH=/app/ca.crt \
      -e PUBLISH_INTERVAL=$INTERVALO $IMG_SIM >/dev/null
  done
  sleep 15
  CONECTADOS=$(for id in $(ids); do docker logs "esc-$id" 2>&1 | grep -c 'conectado a' ; done | awk '$1>0' | wc -l)
  log "Simuladores conectados: $CONECTADOS de $N"
fi

# Ventana de medición
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log "Midiendo durante $DUR s (desde $T0)..."
docker run --rm --name escalado-contador --network "$RED" -v "$CERTS:/certs:ro" $IMG_MQTT mosquitto_sub -h mosquitto -p 8883 \
  --cafile /certs/ca.crt -u "$MQTT_NODERED_USER" -P "$MQTT_NODERED_PASSWORD" -t 'iot/+/+' -v -W "$DUR" \
  > "$OUT/mensajes.txt" 2>/dev/null &
SUB=$!
echo "hora,contenedor,cpu,memoria" > "$OUT/docker-stats.csv"
FIN=$(( $(date +%s) + DUR ))
while [ "$(date +%s)" -lt "$FIN" ]; do
  H=$(date -u +%H:%M:%S)
  docker stats --no-stream --format '{{.Name}},{{.CPUPerc}},{{.MemUsage}}' | sed "s/^/$H,/" >> "$OUT/docker-stats.csv"
  sleep 15
done
wait $SUB || true
T1=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sleep 5   # margen para que Node-RED termine de escribir

# Resultados
ESPERADOS_SIM=$(( N * 2 * DUR / INTERVALO ))
REC_SIM=$(grep -cE '^iot/sim[0-9]+/(temperatura|humedad) ' "$OUT/mensajes.txt" || true)
REC_DEV=$(grep -cE '^iot/dev[0-9]+/(temperatura|humedad) ' "$OUT/mensajes.txt" || true)
INF_SIM=$(contar_influx '^sim' "$T0" "$T1")
INF_DEV=$(contar_influx '^dev' "$T0" "$T1")

{
  echo
  echo "=== Consumo (docker stats, promedio y máximo por contenedor) ==="
  printf "%-22s %10s %10s %12s %12s\n" "contenedor" "CPU prom%" "CPU max%" "Mem prom MiB" "Mem max MiB"
  awk -F, 'NR>1 && $2 != "escalado-contador" {
      c=$2; gsub(/esc-sim[0-9]+/, "simuladores (total)", c)
      cpu=$3; sub(/%/, "", cpu)
      m=$4; sub(/ \/.*/, "", m); f=1
      if (m ~ /GiB/) f=1024; else if (m ~ /KiB/) f=1/1024; else if (m ~ /kB/) f=1/1000
      gsub(/[A-Za-z]/, "", m); mem=m*f
      k=c SUBSEP $1; cpuT[k]+=cpu; memT[k]+=mem; ts[c SUBSEP $1]=1
    }
    END {
      for (k in cpuT) { split(k, p, SUBSEP); c=p[1]
        sc[c]+=cpuT[k]; sm[c]+=memT[k]; n[c]++
        if (cpuT[k] > mc[c]) mc[c]=cpuT[k]; if (memT[k] > mm[c]) mm[c]=memT[k] }
      for (c in sc) printf "%-22s %10.1f %10.1f %12.0f %12.0f\n", c, sc[c]/n[c], mc[c], sm[c]/n[c], mm[c]
    }' "$OUT/docker-stats.csv" | sort
  echo
  echo "=== Mensajes en la ventana de $DUR s ==="
  if [ "$N" -gt 0 ]; then
    echo "Simuladores: esperados $ESPERADOS_SIM · llegaron al broker $REC_SIM · guardados en InfluxDB $INF_SIM"
    awk -v e="$ESPERADOS_SIM" -v b="$REC_SIM" -v i="$INF_SIM" 'BEGIN {
      printf "Pérdida en el broker: %.1f %%\n", (e-b)/e*100
      if (i > 0) printf "Pérdida hasta InfluxDB: %.1f %%\n", (e-i)/e*100
      else print "InfluxDB: 0 puntos (¿Node-RED ya guarda en lecturas?)" }'
  fi
  echo "dev01/dev02: llegaron al broker $REC_DEV · guardados en InfluxDB $INF_DEV"
  echo "(Con 2 dispositivos reales se esperan $(( 2 * 2 * DUR / INTERVALO )) si los dos estaban publicando.)"
  echo "Nota: ±1 mensaje por dispositivo y sensor por el borde de la ventana."
} | tee -a "$OUT/resumen.txt"

log "Listo. Archivos: $OUT/{resumen.txt,docker-stats.csv,mensajes.txt}"
