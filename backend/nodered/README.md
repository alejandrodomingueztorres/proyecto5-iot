# Node-RED — Rol 3 (R5.4)

Node-RED recibe todos los mensajes MQTT de los dispositivos, los valida según el [contrato](../../docs/contrato.md) y los guarda en InfluxDB.

```
Mosquitto (8883, TLS) ──► iot/+/+ ──► Validar y transformar ──┬─► lecturas    (value, alerta=1 si > 30 °C)
                                                              ├─► estado       (online 1/0)
                                                              └─► descartados  (motivo, payload)
                                                                        │
                                                                        ▼
                                                               InfluxDB · bucket iot
```

| Archivo | Contenido |
|---|---|
| `flows.json` | Flujo exportado "Proyecto 5 - Ingesta". **No contiene claves**: las credenciales se leen de variables de entorno |

Evidencia de las pruebas: [docs/evidencias/R5.4.md](../../docs/evidencias/R5.4.md).

## Qué hace el flujo

| Nodo | Función |
|---|---|
| `iot/+/+` | Se suscribe a todos los dispositivos y sensores con QoS 1. Un dispositivo nuevo no requiere cambios |
| `Validar y transformar` | Revisa el JSON, los campos, los tipos, la unidad, el rango físico (temperatura −20 a 80 °C, humedad 0 a 100 %) y que `device_id` y `sensor` coincidan con el topic. Marca `alerta = 1` si la temperatura supera `UMBRAL_TEMPERATURA` (30 °C por defecto) |
| `Bucket iot` | Escribe en InfluxDB las mediciones `lecturas`, `estado` y `descartados` |
| `lecturas`, `estado`, `descartados`, `errores` | Nodos de depuración para ver qué pasa en el panel debug |

El punto se guarda con la hora del campo `ts` del mensaje, no con la hora de llegada.

## Variables de entorno

Las define `backend/docker-compose.yml` en el servicio `nodered`, a partir del `.env`, que **nunca** se sube al repositorio.

| Variable | Uso | Valor en Azure |
|---|---|---|
| `MQTT_BROKER_HOST` | Host del broker | `mosquitto` |
| `MQTT_BROKER_PORT` | Puerto del broker | `8883` |
| `MQTT_CA_CERT_PATH` | Certificado de la CA para TLS | `/certs/ca.crt` |
| `MQTT_NODERED_USER` / `MQTT_NODERED_PASSWORD` | Usuario MQTT de solo lectura | del `.env` |
| `INFLUXDB_URL` | Dirección de InfluxDB | `http://influxdb:8086` |
| `INFLUXDB_ORG` / `INFLUXDB_BUCKET` | Organización y bucket | `curso` / `iot` |
| `INFLUXDB_TOKEN` | Token de escritura de InfluxDB | del `.env` |
| `UMBRAL_TEMPERATURA` | (Opcional) Umbral de alerta en °C | `30` si no se define |

## Instalación paso a paso

Requisitos: el backend levantado con `docker compose up -d` (ver `docs/rol2-infraestructura.md`), y tu IP autorizada en el puerto 1880 del firewall de Azure (pídesela al Rol 2).

### 1. Abrir Node-RED

`http://<IP_DE_LA_VM>:1880`

### 2. Instalar el nodo de InfluxDB (antes de importar)

☰ → **Manage palette** → **Install** → `node-red-contrib-influxdb` → **Install**.

**Comprobación:** en la paleta de la izquierda aparece la categoría **storage** con *influxdb in*, *influxdb out* e *influxdb batch*. Si importas el flujo antes de instalarlo, el nodo *Bucket iot* aparece con borde rojo punteado (*unknown*).

### 3. Importar el flujo

☰ → **Import** → **select a file to import** → `backend/nodered/flows.json`.

Si aparece el aviso *"Some of the nodes you are importing already exist"* marcando solo **Flow 1**, desmarca *Flow 1* (es la pestaña vacía por defecto) y pulsa **Import selected**.

### 4. Escribir las credenciales (obligatorio)

Node-RED **no exporta credenciales**, así que después de importar hay que escribirlas. Se escriben como referencias a variables de entorno, **nunca** la clave real:

| Nodo de configuración | Cómo llegar | Campo | Valor |
|---|---|---|---|
| *Mosquitto (contrato)* | Doble clic en `iot/+/+` → ✏️ junto a **Server** → pestaña **Security** | Username | `${MQTT_NODERED_USER}` |
| | | Password | `${MQTT_NODERED_PASSWORD}` |
| *Mosquitto (contrato)* | Pestaña **Connection** | Use TLS | ✅ marcado (CA del broker = `${MQTT_CA_CERT_PATH}`) |
| *InfluxDB (contrato)* | Doble clic en `Bucket iot` → ✏️ junto a **Server** | Token | `${INFLUXDB_TOKEN}` |

**Update** → **Done** en cada uno.

### 5. Desplegar

Botón **Deploy**.

**Comprobación:**
- Debajo de `iot/+/+` dice **connected**.
- En el panel debug 🐞 llegan lecturas de los dispositivos cada 5 s.
- El nodo `errores` no muestra mensajes.

### 6. Verificar en InfluxDB

`http://<IP_DE_LA_VM>:8086` → **Data Explorer** → **SCRIPT EDITOR**, con **View Raw Data** activado:

```
from(bucket: "iot")
  |> range(start: -15m)
  |> filter(fn: (r) => r._measurement == "lecturas")
```

Deben aparecer filas de cada dispositivo, con `device_id`, `sensor` y `value`.

## Enviar mensajes de prueba

Desde un PC con Docker, con el `ca.crt` del broker en la carpeta personal (`~/ca.crt`) y la clave del dispositivo leída sin escribirla en el comando:

```bash
read -rsp "Clave MQTT de dev01: " CLAVE_DEV01; echo
P() { MSYS_NO_PATHCONV=1 docker run --rm -v "$(cygpath -w ~)":/w eclipse-mosquitto:2.0.20 \
      mosquitto_pub -h <IP_DE_LA_VM> -p 8883 --cafile /w/ca.crt -u dev01 -P "$CLAVE_DEV01" -q 1 "$@"; }
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ); echo $TS
P -t iot/dev01/temperatura -m "{\"device_id\":\"dev01\",\"sensor\":\"temperatura\",\"value\":27.4,\"unit\":\"C\",\"ts\":\"$TS\"}"
```

En Linux o macOS, cambia `"$(cygpath -w ~)"` por `"$HOME"` y quita `MSYS_NO_PATHCONV=1`.

**Genera un `TS` nuevo antes de cada mensaje.** Dos puntos con el mismo dispositivo, sensor y hora son el mismo punto en InfluxDB, y el segundo reemplaza al primero.

Para buscar un mensaje de prueba entre los datos reales, filtra por su hora exacta:

```
from(bucket: "iot")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "lecturas" and r.device_id == "dev01" and r._field == "value")
  |> filter(fn: (r) => r._time == 2026-11-08T21:04:57Z)
```

## Actualizar el flujo en el repositorio

1. En Node-RED: ☰ → **Export** → **All flows** → **Download**.
2. Reemplaza `backend/nodered/flows.json`.
3. Comprueba que no tiene claves (no debe mostrar nada):

```bash
grep -iE '"(password|token|user)"' backend/nodered/flows.json
```

4. Súbelo por pull request desde la rama `rol3-nodered`.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `errores` muestra `HttpError: unauthorized access` | El Token de *InfluxDB (contrato)* está vacío o mal escrito | Paso 4: Token `${INFLUXDB_TOKEN}` y Deploy |
| `iot/+/+` en *disconnected* | Falta usuario/clave del broker o *Use TLS* | Paso 4: credenciales y TLS |
| `Error: ENOENT ... ${MQTT_CA_CERT_PATH}` | La variable no existe en ese entorno (por ejemplo, un simulacro local sin TLS) | En Azure no ocurre. En local, definir `MQTT_CA_CERT_PATH: ""` o ignorarlo si *Use TLS* está desmarcado |
| *Bucket iot* con borde rojo punteado | Se importó antes de instalar `node-red-contrib-influxdb` | Instalar el nodo (paso 2) y reimportar |
| *"nodes already exist"* al importar | Solo choca la pestaña vacía *Flow 1* | Desmarcar *Flow 1* → **Import selected** |
| InfluxDB: *organization not found* | La pestaña del navegador apunta a una organización vieja (después de recrear el contenedor) | Abrir de nuevo `http://<IP>:8086` y entrar a Data Explorer desde el menú |
| Un mensaje de prueba no aparece en InfluxDB | Se reutilizó un `TS` y el punto se sobrescribió | Generar un `TS` nuevo y volver a enviar |
| Mensajes en `descartados` | El mensaje no cumple el contrato | Ver el campo `motivo`: fuera de rango, no es JSON, unidad incorrecta, etc. |