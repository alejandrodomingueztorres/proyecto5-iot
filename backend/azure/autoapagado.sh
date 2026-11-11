#!/usr/bin/env bash
# Desasigna esta VM en Azure para que no gaste crédito (Rol 2).
#
# Corre todas las noches con cron (04:00 UTC = 11 pm en Colombia). Usa la
# identidad administrada de la VM, que solo tiene el rol "Virtual Machine
# Contributor" sobre esta misma VM. Hace falta porque el apagado automático
# de Azure no está disponible en Chile Central.
#
# Instalación (en la VM, desde backend/):
#   sudo install -m 755 azure/autoapagado.sh /usr/local/bin/autoapagado.sh
#   echo '0 4 * * * root /usr/local/bin/autoapagado.sh' | sudo tee /etc/cron.d/autoapagado
#
# Prueba sin apagar:  sudo /usr/local/bin/autoapagado.sh --probar
set -euo pipefail

IMDS=http://169.254.169.254/metadata
API=2024-07-01

ID=$(curl -fsS -H Metadata:true "$IMDS/instance/compute/resourceId?api-version=2021-02-01&format=text")
TOKEN=$(curl -fsS -H Metadata:true \
  "$IMDS/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')

if [ "${1:-}" = "--probar" ]; then
  curl -fsS -H "Authorization: Bearer $TOKEN" \
    "https://management.azure.com$ID/instanceView?api-version=$API" |
    python3 -c 'import json,sys; print([s["displayStatus"] for s in json.load(sys.stdin)["statuses"] if s["code"].startswith("PowerState")][0])'
  exit 0
fi

logger -t autoapagado "Desasignando la VM ($ID)"
curl -fsS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Length: 0" \
  "https://management.azure.com$ID/deallocate?api-version=$API"
