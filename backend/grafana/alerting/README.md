# Alertas de Grafana (R5.6 y R5.7)

Exportación de las reglas y de la política de notificaciones que corren en el Grafana de la VM de Azure (Grafana 11.3.0). Se exportó el 2026-11-16 con la API de provisioning (`GET /api/v1/provisioning/...`). **No contiene tokens, chat ID ni claves.**

| Archivo | Qué es |
|---|---|
| `reglas-sensores.json` | Grupo de reglas `Sensores` (carpeta `Proyecto 5`): `Temperatura Alta` y `Alerta Dispositivo Offline`. Se evalúan cada 10 s |
| `politica-notificaciones.json` | Política raíz: envía todo al contact point `Telegram`, agrupa por carpeta, nombre y `device_id`, sin espera inicial (`group_wait` 0 s, `group_interval` 10 s) |

## Cómo funcionan

- **Temperatura Alta:** se activa cuando la última lectura de temperatura de un dispositivo (últimos 5 min) es **mayor a 30 °C**. El texto dice qué dispositivo.
- **Alerta Dispositivo Offline:** calcula, para cada dispositivo, los **segundos desde su última lectura** (ventana de 1 hora) y se activa cuando pasan de **300 s (5 min)**. Al volver los datos se resuelve sola y Grafana manda el aviso *Resolved*.
  - **Límite:** si un dispositivo lleva más de 1 hora apagado, su serie sale de la ventana y la alerta se resuelve sola. Es una limitación conocida de esta forma de medirlo.
- Las dos reglas llevan su propia configuración de notificaciones (`notification_settings`), así que los tiempos de la política raíz no las afectan: están repetidos dentro de cada regla.

## Qué no está aquí (a propósito)

El **contact point `Telegram`** guarda el token del bot y el chat ID. No se exporta. Se crea a mano en Grafana (*Alerting → Contact points → Telegram*) con los valores que entrega el Rol 2 por el chat privado del grupo; en la VM están en `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` del `.env`.

## Cómo restaurarlas en otro Grafana

Con un usuario administrador, después de crear la carpeta `Proyecto 5`, el data source de InfluxDB y el contact point `Telegram`:

```bash
# El UID de la carpeta y del data source debe coincidir con los del JSON (folderUid y datasourceUid)
curl -X PUT -H "Content-Type: application/json" -H "X-Disable-Provenance: true" \
  --user "$USUARIO:$CLAVE" --data @reglas-sensores.json \
  http://localhost:3000/api/v1/provisioning/folder/<UID_CARPETA>/rule-groups/Sensores

curl -X PUT -H "Content-Type: application/json" -H "X-Disable-Provenance: true" \
  --user "$USUARIO:$CLAVE" --data @politica-notificaciones.json \
  http://localhost:3000/api/v1/provisioning/policies
```

`$USUARIO` y `$CLAVE` son del administrador de ese Grafana y no se escriben en el repositorio.
