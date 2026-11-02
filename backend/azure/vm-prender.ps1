# Prende la VM del backend y espera a que el broker responda en 8883.
# Uso (PowerShell, con `az login` hecho):  .\backend\azure\vm-prender.ps1
# El stack de Docker arranca solo al prender la VM (restart: unless-stopped).

$grupo = 'rg-proyecto5-iot'
$vm = 'vm-iot-backend'
$ip = '68.211.147.97'

az vm start -g $grupo -n $vm
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "VM prendida. Esperando a Mosquitto en ${ip}:8883..."
for ($i = 0; $i -lt 30; $i++) {
    if ((Test-NetConnection $ip -Port 8883 -WarningAction SilentlyContinue).TcpTestSucceeded) {
        Write-Host "Broker listo en ${ip}:8883. Acuerdate de apagarla con vm-apagar.ps1."
        exit 0
    }
    Start-Sleep -Seconds 5
}
Write-Host "El broker no respondió todavía. Revisa con: ssh azureuser@$ip 'cd proyecto5-iot/backend && docker compose ps'"
