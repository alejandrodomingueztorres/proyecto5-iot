# Apaga y DESASIGNA la VM del backend para que no gaste crédito.
# Uso (PowerShell, con `az login` hecho):  .\backend\azure\vm-apagar.ps1
# Ojo: apagar desde Ubuntu (sudo shutdown) NO basta; Azure sigue cobrando la VM.
# Desasignada solo cobra el disco y la IP fija (la IP no cambia).

$grupo = 'rg-proyecto5-iot'
$vm = 'vm-iot-backend'

az vm deallocate -g $grupo -n $vm
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
az vm show -d -g $grupo -n $vm --query powerState -o tsv
