#!/usr/bin/env bash
# Genera la CA propia y el certificado del broker (Rol 2, R5.2).
#
# Uso, en la VM y desde la carpeta backend/:
#   sudo bash mosquitto/generar-certificados.sh
#
# Lee BROKER_HOST de backend/.env. El SAN del certificado incluye ese host
# (IP o DNS, según lo que sea) y "mosquitto", que es el nombre con el que
# Node-RED llega al broker dentro de Docker Compose.
#
# Resultado:
#   mosquitto/config/certs/ca.crt      público: va al repo y a device/
#   mosquitto/config/certs/server.crt  público
#   mosquitto/config/certs/server.key  privado (ignorado por .gitignore)
#   mosquitto/ca-privada/ca.key        privado: NUNCA sale de la VM
#
# Si la CA ya existe se reutiliza, así los dispositivos no necesitan un
# ca.crt nuevo cuando solo cambia el certificado del servidor.
set -euo pipefail

cd "$(dirname "$0")"   # backend/mosquitto

MOSQUITTO_UID=1883     # usuario "mosquitto" dentro de la imagen oficial
CA_DIR=ca-privada
CERT_DIR=config/certs
DIAS=365

BROKER_HOST=$(grep -E '^BROKER_HOST=' ../.env 2>/dev/null | cut -d= -f2- | tr -d '[:space:]"' || true)
if [ -z "$BROKER_HOST" ] || [ "$BROKER_HOST" = "IP_O_DNS_DE_LA_VM_AZURE" ]; then
  echo "Error: define BROKER_HOST en backend/.env con la IP pública o el DNS de la VM." >&2
  exit 1
fi

if [[ $BROKER_HOST =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  SAN="IP:$BROKER_HOST"
else
  SAN="DNS:$BROKER_HOST"
fi
SAN="$SAN,DNS:mosquitto,DNS:localhost,IP:127.0.0.1"

mkdir -p "$CA_DIR" "$CERT_DIR"
chmod 700 "$CA_DIR"

if [ -f "$CA_DIR/ca.key" ] && [ -f "$CERT_DIR/ca.crt" ]; then
  echo "La CA ya existe: se reutiliza."
else
  echo "Creando la CA (iot-ca)..."
  openssl genrsa -out "$CA_DIR/ca.key" 4096
  openssl req -x509 -new -nodes -key "$CA_DIR/ca.key" -sha256 -days "$DIAS" \
    -subj "/CN=iot-ca" -out "$CERT_DIR/ca.crt"
fi

echo "Creando el certificado del broker para $BROKER_HOST..."
openssl genrsa -out "$CERT_DIR/server.key" 2048
openssl req -new -key "$CERT_DIR/server.key" -subj "/CN=$BROKER_HOST" -out "$CA_DIR/server.csr"
printf 'subjectAltName=%s\n' "$SAN" > "$CA_DIR/san.ext"
openssl x509 -req -in "$CA_DIR/server.csr" \
  -CA "$CERT_DIR/ca.crt" -CAkey "$CA_DIR/ca.key" \
  -CAserial "$CA_DIR/ca.srl" -CAcreateserial \
  -out "$CERT_DIR/server.crt" -days "$DIAS" -sha256 -extfile "$CA_DIR/san.ext"
rm -f "$CA_DIR/server.csr" "$CA_DIR/san.ext"

# Mosquitto corre como uid 1883 y monta config/ en solo lectura,
# así que la clave del servidor tiene que ser de ese usuario.
chmod 600 "$CA_DIR/ca.key"
chown "$MOSQUITTO_UID:$MOSQUITTO_UID" "$CERT_DIR/server.key"
chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/ca.crt" "$CERT_DIR/server.crt"

echo
echo "Comprobación (el host del broker tiene que aparecer aquí):"
openssl x509 -in "$CERT_DIR/server.crt" -noout -subject -enddate -ext subjectAltName
openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/server.crt"
echo
echo "Listo. Si Mosquitto ya estaba corriendo: docker compose restart mosquitto"
