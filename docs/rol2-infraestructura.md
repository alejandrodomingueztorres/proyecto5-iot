# Rol 2: backend en Azure y MQTT seguro

Guía paso a paso para levantar el backend (Mosquitto 2, Node-RED, InfluxDB 2.x y
Grafana) en una VM de Azure, con MQTT cifrado y autenticado. Cubre R5.2 y la
base de R5.3. Los valores salen de [contrato.md](contrato.md).

> Ninguna clave, token ni archivo `.env` se sube al repo. Se pasan por el chat
> privado del grupo.

## Archivos

| Archivo | Qué es | ¿Va al repo? |
|---|---|---|
| `backend/docker-compose.yml` | Los 4 servicios con volúmenes persistentes | Sí |
| `backend/.env` | Claves reales (copia de `.env.example`) | **No** |
| `backend/mosquitto/config/mosquitto.conf` | Listener 8883 con TLS, sin anónimos | Sí |
| `backend/mosquitto/config/acl.conf` | Permisos por usuario | Sí |
| `backend/mosquitto/config/passwd` | Hashes de las claves MQTT | **No** |
| `backend/mosquitto/config/certs/ca.crt` | Certificado público de la CA | Sí |
| `backend/mosquitto/config/certs/server.key` | Clave privada del broker | **No** |
| `backend/mosquitto/ca-privada/ca.key` | Clave privada de la CA | **No**, nunca sale de la VM |
| `backend/mosquitto/generar-certificados.sh` | Crea la CA y el certificado del broker | Sí |
| `backend/mosquitto/crear-usuario.sh` | Crea, cambia o borra usuarios MQTT | Sí |

## 1. Crear la VM en Azure

En el portal de Azure: **Máquinas virtuales → Crear**.

| Campo | Valor |
|---|---|
| Imagen | Ubuntu Server 24.04 LTS |
| Región | Chile Central (la más cercana de las que permite Azure for Students UAO) |
| Tamaño | Standard_B2als_v2 (2 vCPU, 4 GB). Con menos memoria no alcanza para los 4 servicios y la prueba de escalado. El B2s no existe en Chile Central |
| Autenticación | Clave pública SSH, usuario `azureuser` |
| Puertos de entrada | Solo SSH (22) por ahora |

La IP pública de SKU Standard es **estática**, así que no cambia al reiniciar
la VM. Esa IP es el `BROKER_HOST`. Si prefieren un nombre, en
**IP pública → Configuración → Etiqueta de nombre DNS** se obtiene
`<etiqueta>.<region>.cloudapp.azure.com`. Elijan uno solo (IP o DNS) y úsenlo
en todas partes, porque el certificado se genera para ese host.

**Cómo comprobarlo:** `ssh azureuser@<IP>` entra a la VM.

## 2. Firewall (grupo de seguridad de red, NSG)

En **VM → Redes → Reglas de puerto de entrada**:

| Prioridad | Puerto | Origen | Para qué |
|---|---|---|---|
| 100 | 8883/TCP | Any | MQTT con TLS (dispositivos) |
| 110 | 22/TCP | IP del equipo | SSH |
| 120 | 1880, 3000, 8086/TCP | IP del equipo | Node-RED, Grafana, InfluxDB |

No se abre el 1883. Si las IP de las casas cambian seguido, no abran la regla
120 y usen un túnel SSH:

```bash
ssh -L 1880:localhost:1880 -L 3000:localhost:3000 -L 8086:localhost:8086 azureuser@<IP>
```

Luego se abre `http://localhost:3000`, etc. en el navegador.

## 3. Instalar Docker en la VM

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
exit   # volver a entrar por SSH para que tome el grupo docker
```

**Cómo comprobarlo:** `docker compose version` muestra la versión.

## 4. Clonar el repo y crear el `.env`

```bash
git clone https://github.com/alejandrodomingueztorres/proyecto5-iot.git
cd proyecto5-iot/backend
cp .env.example .env
nano .env
```

Llenar:
- `BROKER_HOST` con la IP o el DNS del paso 1.
- Las claves con valores aleatorios: `openssl rand -base64 18`.
- `INFLUXDB_ADMIN_TOKEN` con `openssl rand -hex 32`.

`TELEGRAM_*` lo completa el Rol 4 más adelante.

## 5. Certificados TLS

```bash
sudo bash mosquitto/generar-certificados.sh
```

**Cómo comprobarlo:** al final el script muestra el `subjectAltName`, que
debe incluir el `BROKER_HOST` (`IP Address:...` o `DNS:...`) y `DNS:mosquitto`,
y la línea `server.crt: OK`. Si el host no coincide con el que usan los
dispositivos, la conexión TLS falla aunque todo lo demás esté bien.

## 6. Usuarios MQTT

```bash
sudo bash mosquitto/crear-usuario.sh dev01
sudo bash mosquitto/crear-usuario.sh dev02
sudo bash mosquitto/crear-usuario.sh dev03
sudo bash mosquitto/crear-usuario.sh nodered "$(grep '^MQTT_NODERED_PASSWORD=' .env | cut -d= -f2-)"
```

Para cada `devXX` el script muestra la clave una sola vez: cópiala al chat
privado. La de `nodered` es la que ya está en el `.env`.

## 7. Levantar el stack

```bash
docker compose up -d
docker compose ps
docker compose logs mosquitto
```

**Cómo comprobarlo:**
- `ps` muestra los 4 servicios en `running`.
- El log de Mosquitto dice `Opening ipv4 listen socket on port 8883` y no muestra errores de certificados ni de passwd.

## La VM queda apagada cuando no se usa

Para no gastar el crédito de Azure for Students, la VM `vm-iot-backend`
(grupo `rg-proyecto5-iot`) se deja **desasignada** y se prende solo para
trabajar o probar. Desasignada no cobra la VM, solo el disco y la IP fija, y la
IP `68.211.147.97` no cambia. Al prenderla, el stack arranca solo.

```powershell
.\backend\azure\vm-prender.ps1   # antes de trabajar
.\backend\azure\vm-apagar.ps1    # al terminar
```

Apagar desde Ubuntu (`sudo shutdown`) no basta: Azure sigue cobrando la VM
hasta que se desasigna. Si un compañero necesita el broker, avisa al Rol 2
para que la prenda.

## 8. Entregar a los demás roles

| A quién | Qué | Por dónde |
|---|---|---|
| Rol 1 | `ca.crt`, `BROKER_HOST` (confirmado en el SAN), puerto 8883 | Repo (`ca.crt` es público) y chat |
| Rol 1 | Claves de `dev01`, `dev02` y `dev03` | Chat privado |
| Rol 3 | Acceso a Node-RED (1880) e InfluxDB (8086), clave de `nodered`, token admin de InfluxDB | Chat privado |
| Rol 4 | Acceso a Grafana (3000) y usuario admin | Chat privado |

Para subir el `ca.crt` desde la VM:

```bash
git add mosquitto/config/certs/ca.crt
git commit -m "backend: ca.crt del broker"
```

Dentro de Compose, Node-RED llega al broker como `mosquitto:8883`, con la CA en
`/certs/ca.crt`. Las variables `MQTT_NODERED_USER`, `MQTT_NODERED_PASSWORD`,
`INFLUXDB_URL`, `INFLUXDB_ORG` e `INFLUXDB_BUCKET` ya están definidas en el
contenedor. Node-RED no trae usuario y clave propios: por eso los puertos 1880
y 8086 solo se abren al equipo.

## 9. Pruebas de R5.2

Se corren en la VM, desde `backend/`. No hace falta instalar los clientes MQTT:
se usan los de la imagen de Mosquitto.

```bash
set -a; . ./.env; set +a
mqtt() { docker run --rm --network host -v "$PWD/mosquitto/config/certs:/certs:ro" -v /tmp:/tmp eclipse-mosquitto:2.0.20 "$@"; }
H=$BROKER_HOST
DEV01_PASS='...'   # la clave de dev01 (no la dejes en el historial: borra la línea después)
```

Si desde la VM no se llega a su propia IP pública, usen `H=localhost`, que
también está en el certificado.

**P2.1. Conexión válida.** En una terminal, suscribirse:

```bash
mqtt mosquitto_sub -h $H -p 8883 --cafile /certs/ca.crt -u nodered -P "$MQTT_NODERED_PASSWORD" -t 'iot/#' -v
```

En otra terminal, publicar:

```bash
mqtt mosquitto_pub -h $H -p 8883 --cafile /certs/ca.crt -u dev01 -P "$DEV01_PASS" -t iot/dev01/temperatura -m '{"device_id":"dev01","sensor":"temperatura","value":27.4,"unit":"C","ts":"2026-11-02T20:00:00Z"}'
```

Esperado: el suscriptor muestra el mensaje.

**P2.2. Sin usuario ni clave.**

```bash
mqtt mosquitto_sub -h $H -p 8883 --cafile /certs/ca.crt -t 'iot/#' -W 5
```

Esperado: `Connection Refused: not authorised`.

**P2.3. Clave incorrecta.**

```bash
mqtt mosquitto_sub -h $H -p 8883 --cafile /certs/ca.crt -u dev01 -P malaclave -t 'iot/#' -W 5
```

Esperado: `not authorised`.

**P2.4. Sin TLS.**

```bash
nc -vz -w 5 $H 1883
mqtt mosquitto_sub -h $H -p 8883 -u dev01 -P "$DEV01_PASS" -t 'iot/#' -W 5
```

Esperado: el 1883 no responde, y el 8883 sin TLS da error de protocolo o de conexión.

**P2.5. CA distinta.**

```bash
openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/otra-ca.key -out /tmp/otra-ca.crt -subj /CN=otra-ca -days 1
mqtt mosquitto_sub -h $H -p 8883 --cafile /tmp/otra-ca.crt -u nodered -P "$MQTT_NODERED_PASSWORD" -t 'iot/#' -W 5
```

Esperado: `certificate verify failed`.

**P2.6. ACL.** Con el suscriptor de P2.1 abierto, `dev01` publica en el topic
de `dev02`:

```bash
mqtt mosquitto_pub -h $H -p 8883 --cafile /certs/ca.crt -u dev01 -P "$DEV01_PASS" -t iot/dev02/temperatura -m prueba-acl
```

Esperado: el suscriptor **no** recibe nada. En MQTT 3.1.1 el broker descarta el
mensaje en silencio; `docker compose logs mosquitto` muestra el intento.

**P2.7. Wireshark.** Capturar en la VM mientras los dispositivos de Balena publican:

```bash
sudo tcpdump -i eth0 -w /tmp/r52.pcap 'tcp port 8883' -c 300
```

Copiar el archivo al PC con `scp azureuser@<IP>:/tmp/r52.pcap .` y abrirlo en
Wireshark. Esperado: se ve el handshake TLS (Client Hello, Server Hello) y
después solo `Application Data`, sin topics ni JSON legibles. El `.pcap` no se
sube al repo (está en el `.gitignore`); solo las capturas de pantalla.

**P2.8. Puertos desde afuera.** Desde una red que no sea la del equipo (por
ejemplo, los datos del celular):

```bash
nmap -Pn -p 1883,1880,3000,8086,8883 <IP>
```

Esperado: solo `8883 open`; los demás `filtered`.

Las capturas van en `docs/evidencias/img/R5.2/` y el resultado de cada prueba
en [evidencias/R5.2.md](evidencias/R5.2.md).

## Problemas frecuentes

- **Mosquitto se reinicia en bucle.** Ver `docker compose logs mosquitto`. Casi
  siempre es que falta `passwd` o `server.key` (paso 5 o 6), o que no son del
  usuario 1883. Volver a correr el script correspondiente con `sudo`.
  Los avisos de Mosquitto sobre permisos de `acl.conf` son normales y no
  impiden que arranque.
- **`certificate verify failed` con el `ca.crt` correcto.** El host al que se
  conecta el cliente no está en el SAN. Revisar con
  `openssl x509 -in mosquitto/config/certs/server.crt -noout -ext subjectAltName`.
- **Timeout desde afuera.** Falta la regla del 8883 en el NSG.
- **Cambié `acl.conf` o un usuario y no toma efecto.** `crear-usuario.sh`
  reinicia Mosquitto solo; tras editar `acl.conf`, ejecutar
  `docker compose restart mosquitto`.
- **Cambié el `.env` de InfluxDB y no pasa nada.** El setup inicial de InfluxDB
  solo corre con el volumen vacío. Para empezar de cero:
  `docker compose down && docker volume rm backend_influxdb_data backend_influxdb_config`
  (borra los datos).
