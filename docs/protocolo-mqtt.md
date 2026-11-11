# Protocolo MQTT del Proyecto 5 IoT

Cómo hablan los dispositivos con el broker y cómo se consumen sus mensajes (R5.3).
Los valores salen de [contrato.md](contrato.md): si algo de aquí no coincide con el
contrato, manda el contrato y este archivo se corrige.

## 1. Conexión

| Elemento | Valor |
|---|---|
| Broker | Mosquitto 2.0.20 en la VM de Azure `vm-iot-backend` |
| Host | `68.211.147.97` (IP fija; es el `BROKER_HOST`) |
| Puerto | `8883`, solo con TLS. No existe el 1883 |
| TLS | TLS 1.2 o superior. El cliente verifica el certificado del broker con `ca.crt` (CA propia `iot-ca`, en `backend/mosquitto/config/certs/ca.crt`). El certificado incluye en su SAN `IP:68.211.147.97` y `DNS:mosquitto` |
| Autenticación | Usuario y clave obligatorios (sin acceso anónimo) |
| Versión de MQTT | 3.1.1 (la que usan por defecto `paho-mqtt` y los clientes de Mosquitto) |
| `client_id` | El `device_id` del dispositivo (`dev01`, `dev02`, …) |
| Keepalive | 30 s en el simulador. Si el broker no recibe nada en 1,5 × keepalive, publica el Last Will |

Dentro de Docker Compose, Node-RED llega al broker como `mosquitto:8883`, con la CA en
`/certs/ca.crt`.

## 2. Topics

| Topic | Para qué | Quién publica | Payload |
|---|---|---|---|
| `iot/{device_id}/{sensor}` | Lecturas del sensor | El dispositivo | JSON (sección 3) |
| `iot/{device_id}/status` | Estado de conexión | El dispositivo, o el broker con el Last Will | Texto `online` u `offline` |

Reglas de los segmentos:

- `device_id`: el identificador del dispositivo, en minúsculas y sin `/`, `+` ni `#`
  (`dev01`, `dev02`, `dev03`).
- `sensor`: `temperatura` o `humedad`.
- `status` es una palabra reservada: ningún sensor se puede llamar así.

Ejemplos: `iot/dev01/temperatura`, `iot/dev02/humedad`, `iot/dev01/status`.

**Suscripción del consumidor (Node-RED):** `iot/+/+`. El primer `+` acepta cualquier
dispositivo, así que **un dispositivo nuevo no requiere cambios en Node-RED**. El segundo `+`
recibe tanto sensores como `status`; Node-RED los separa por el último segmento, porque el
payload de `status` es texto y no JSON.

## 3. Formato del mensaje de datos

Un mensaje por sensor cada 5 segundos (`PUBLISH_INTERVAL`), en JSON UTF-8:

| Campo | Tipo | Regla |
|---|---|---|
| `device_id` | texto | Igual al segundo segmento del topic |
| `sensor` | texto | `temperatura` o `humedad`; igual al tercer segmento del topic |
| `value` | número | Decimal, no texto (`27.4`, no `"27.4"`). El simulador redondea a 1 decimal |
| `unit` | texto | `C` para temperatura, `%` para humedad |
| `ts` | texto | Hora UTC en ISO 8601 terminada en `Z`, con segundos (`2026-11-02T20:00:00Z`) |

Rangos físicos válidos (contrato, sección 1): temperatura de −20 a 80 °C y humedad de 0 a
100 %. Un mensaje que no cumple el formato o los rangos lo descarta el consumidor (medición
`descartados` en InfluxDB) sin detener el flujo.

## 4. QoS y retención

| Mensaje | QoS | Retenido | Por qué |
|---|---|---|---|
| Datos `iot/{device_id}/{sensor}` | 1 | No | Cada lectura llega al menos una vez; una lectura vieja no debe aparecer como nueva |
| `online` en `iot/{device_id}/status` | 1 | **Sí** | Quien se suscriba después sabe de inmediato el último estado |
| `offline` del Last Will | 1 | **Sí** | Lo publica el broker si el dispositivo se cae sin despedirse |
| `offline` al apagar limpio | 1 | **Sí** | Un `disconnect()` normal no activa el Last Will, por eso el simulador lo publica a mano |

Como el QoS es 1, el consumidor puede recibir un mensaje repetido. Se identifica por
`device_id`, `sensor` y `ts`.

## 5. Ciclo de vida de un dispositivo

1. Se conecta con TLS, su usuario y su clave, y deja configurado el Last Will
   (`offline`, QoS 1, retenido, en `iot/{device_id}/status`).
2. Al conectarse, y en cada reconexión, publica `online` retenido en su `status`.
3. Cada 5 s publica una lectura de `temperatura` y otra de `humedad`.
4. Si se cae la red o la VM, el broker publica el Last Will: `offline`.
5. Si se apaga limpio (por ejemplo, durante una actualización OTA), publica `offline` antes de
   desconectarse.

## 6. Usuarios y permisos (ACL)

| Usuario | Lo usa | Puede publicar en | Puede leer |
|---|---|---|---|
| `dev01` | Dispositivo dev01 | `iot/dev01/#` | Nada |
| `dev02` | Dispositivo dev02 | `iot/dev02/#` | Nada |
| `dev03` | Dispositivo dev03 (R5.8) | `iot/dev03/#` | Nada |
| `nodered` | Node-RED (Rol 3) | Nada | `iot/#` |

Lo que no está permitido en [acl.conf](../backend/mosquitto/config/acl.conf) queda prohibido. Si
un dispositivo publica fuera de su rama (por ejemplo, `dev01` en `iot/dev02/temperatura`), con
MQTT 3.1.1 el broker descarta el mensaje en silencio y nadie lo recibe (prueba P2.6). Las claves
nunca van al repo: se pasan por el chat privado del grupo.

## 7. Ejemplos de mensajes

**1. Lectura de temperatura de dev01**

```
topic:   iot/dev01/temperatura      QoS 1, no retenido
payload: {"device_id":"dev01","sensor":"temperatura","value":27.4,"unit":"C","ts":"2026-11-02T20:00:00Z"}
```

**2. Lectura de humedad de dev02**

```
topic:   iot/dev02/humedad          QoS 1, no retenido
payload: {"device_id":"dev02","sensor":"humedad","value":63.1,"unit":"%","ts":"2026-11-02T20:00:05Z"}
```

**3. Temperatura sobre el umbral (dispara la alerta, contrato sección 5)**

```
topic:   iot/dev01/temperatura      QoS 1, no retenido
payload: {"device_id":"dev01","sensor":"temperatura","value":31.2,"unit":"C","ts":"2026-11-02T20:00:10Z"}
```

**4. Dispositivo conectado**

```
topic:   iot/dev03/status           QoS 1, retenido
payload: online
```

**5. Dispositivo caído (Last Will publicado por el broker)**

```
topic:   iot/dev02/status           QoS 1, retenido
payload: offline
```

**6. Mensaje inválido (el consumidor lo descarta)**

```
topic:   iot/dev01/temperatura
payload: {"device_id":"dev01","sensor":"temperatura","value":"27.4","unit":"C","ts":"2026-11-02T20:00:00Z"}
motivo:  value es texto, no número
```

## 8. Agregar un dispositivo nuevo

Ejemplo con `dev04`. **No se toca Node-RED**: su suscripción `iot/+/+` ya lo incluye.

1. **Rol 2**, en la VM, desde `~/proyecto5-iot/backend`:
   - Agregar a `mosquitto/config/acl.conf`:
     ```
     user dev04
     topic write iot/dev04/#
     ```
   - Crear el usuario. El script muestra la clave una sola vez y recarga Mosquitto
     sin desconectar a los demás:
     ```bash
     sudo bash mosquitto/crear-usuario.sh dev04
     ```
2. **Rol 1**, en Balena: crear el dispositivo y definir sus variables `DEVICE_ID=dev04`,
   `MQTT_USER=dev04` y `MQTT_PASSWORD=<la clave>`. Las variables de la flota (`BROKER_HOST`,
   `BROKER_PORT`, `CA_CERT_PATH`, `PUBLISH_INTERVAL`) ya sirven.
3. Comprobar con el suscriptor de la sección 9 que llegan `iot/dev04/...`.

`dev03` ya está creado en el broker para la demo de R5.8.

## 9. Comandos para probar a mano

Se necesita `ca.crt` en la carpeta actual y los clientes de Mosquitto (en Windows, el
instalador de mosquitto.org; o Docker con la imagen `eclipse-mosquitto:2.0.20`). Las claves
van en variables, nunca escritas en un archivo del repo.

```bash
H=68.211.147.97

# Ver todo lo que llega (lectura con el usuario de Node-RED)
mosquitto_sub -h $H -p 8883 --cafile ca.crt -u nodered -P "$CLAVE_NODERED" -t 'iot/#' -v

# Publicar una lectura a mano como dev01
mosquitto_pub -h $H -p 8883 --cafile ca.crt -u dev01 -P "$CLAVE_DEV01" -q 1 -t iot/dev01/temperatura \
  -m '{"device_id":"dev01","sensor":"temperatura","value":27.4,"unit":"C","ts":"2026-11-02T20:00:00Z"}'

# Último estado de cada dispositivo (llega de inmediato por ser retenido; P3.3)
mosquitto_sub -h $H -p 8883 --cafile ca.crt -u nodered -P "$CLAVE_NODERED" -t 'iot/+/status' -v -W 5
```

Con Docker en vez de los clientes instalados, desde la carpeta que tiene `ca.crt`:

```bash
docker run --rm -v "$PWD:/certs:ro" eclipse-mosquitto:2.0.20 mosquitto_sub -h 68.211.147.97 -p 8883 --cafile /certs/ca.crt -u nodered -P "$CLAVE_NODERED" -t 'iot/#' -v
```

Las pruebas de seguridad (sin clave, sin TLS, con otra CA, ACL) están en
[evidencias/R5.2.md](evidencias/R5.2.md).
