> **Regla:** un cambio en este archivo solo se hace con acuerdo de todo el grupo,
> por pull request, y se anota en el historial al final.

## 1. Dispositivos y sensores

| Elemento | Valor acordado |
|---|---|
| Dispositivos | `dev01`, `dev02` y `dev03` (este último para la demo de R5.8) |
| Sensores | `temperatura` (°C, unidad `C`) y `humedad` (%, unidad `%`) |
| Frecuencia | 1 mensaje por sensor cada 5 segundos |
| Rango normal del simulador | temperatura entre 20 y 29 °C (por debajo del umbral) |
| Rangos físicos válidos | temperatura de −20 a 80 °C; humedad de 0 a 100 % |

## 2. MQTT

| Elemento | Valor acordado |
|---|---|
| Broker | Mosquitto 2 en la VM de Azure, puerto **8883 con TLS**, sin acceso anónimo |
| Topic de datos | `iot/{device_id}/{sensor}`, por ejemplo `iot/dev01/temperatura` |
| Topic de estado | `iot/{device_id}/status`, texto `online` u `offline`, **retenido**, QoS 1 |
| QoS de datos | 1 |
| Usuarios | `dev01`, `dev02`, `dev03` (uno por dispositivo, cada uno con su clave) y `nodered` |
| Permisos | Cada dispositivo solo publica en `iot/{su_id}/#`. `nodered` solo lee `iot/#` |
| Suscripción de Node-RED | `iot/+/+` (comodín: un dispositivo nuevo no requiere cambios) |
| Last Will | El dispositivo deja configurado `offline` en `iot/{device_id}/status` |

## 3. Formato del mensaje (payload JSON)

```json
{"device_id":"dev01","sensor":"temperatura","value":27.4,"unit":"C","ts":"2026-10-28T20:00:00Z"}
```

| Campo | Tipo | Regla |
|---|---|---|
| `device_id` | texto | Igual al segundo segmento del topic |
| `sensor` | texto | `temperatura` o `humedad`; igual al tercer segmento del topic |
| `value` | número | Decimal, no texto (`27.4`, no `"27.4"`) |
| `unit` | texto | `C` para temperatura, `%` para humedad |
| `ts` | texto | Hora UTC en formato ISO 8601 terminada en `Z` |

## 4. InfluxDB

| Elemento | Valor acordado |
|---|---|
| Versión | InfluxDB 2.x |
| Organización | `curso` |
| Bucket | `iot` |
| Medición de datos | `lecturas`: etiquetas `device_id` y `sensor`; campo `value` (decimal); campo `alerta` = 1 si supera el umbral |
| Medición de estado | `estado`: etiqueta `device_id`; campo `online` (1 o 0) |
| Medición de descartes | `descartados`: mensajes inválidos, con el motivo |
| Tokens | Uno de escritura para Node-RED y uno de solo lectura para Grafana |

## 5. Alertas

| Elemento | Valor acordado |
|---|---|
| Umbral | Temperatura **mayor a 30 °C** |
| Tiempo máximo de llegada | Menos de 30 segundos tras superar el umbral |
| Dispositivo offline | Sin datos durante **más de 5 minutos** |
| Canal | Telegram (email solo si sobra tiempo) |

## 6. Backend en Azure

| Puerto | Servicio | Acceso |
|---|---|---|
| 8883 | Mosquitto (MQTT con TLS) | Público |
| 1880 | Node-RED | Solo IP del equipo o túnel SSH |
| 8086 | InfluxDB | Solo IP del equipo o túnel SSH |
| 3000 | Grafana | Solo IP del equipo o túnel SSH |
| 22 | SSH | Solo IP del equipo |

## 7. Variables de entorno del dispositivo

| Variable | Valor | Dónde se define |
|---|---|---|
| `DEVICE_ID` | `dev01`, `dev02`, `dev03` | Variable de cada dispositivo en Balena |
| `MQTT_USER` | Igual al `DEVICE_ID` | Variable de cada dispositivo en Balena |
| `MQTT_PASSWORD` | Clave de ese usuario | Variable de cada dispositivo en Balena |
| `BROKER_HOST` | IP o DNS de la VM de Azure | Variable de la flota |
| `BROKER_PORT` | `8883` | Variable de la flota |
| `CA_CERT_PATH` | `/app/ca.crt` | Variable de la flota |
| `PUBLISH_INTERVAL` | `5` | Variable de la flota |
| `TEMP_FORZADA` | Opcional. Número en °C (por ejemplo `32`). Solo para demos y pruebas de alertas: el dispositivo publica esa temperatura ±0.5, limitada a −20…80 °C. Sin definir, el rango normal es 20–29 °C | Variable de cada dispositivo en Balena (o `-e` en Docker) |

## 8. Historial de cambios

| Fecha | Cambio | Motivo | Aprobado por |
|---|---|---|---|
| 2026-10-31 | Versión inicial, tomada del plan de trabajo | Arranque del proyecto | Equipo de trabajo |
| 2026-11-11 | Se agrega la variable opcional `TEMP_FORZADA` (sección 7). No cambia topics, payload ni rangos | Probar alertas (R5.6, R5.7, R5.8) con un dispositivo real, ya que el simulador normal nunca supera los 30 °C | **Pendiente del acuerdo del grupo.** El código lo aprobó Alejandro Domínguez en el PR #6 |