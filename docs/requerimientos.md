# Requerimientos y pruebas de aceptación

Fuente: enunciado del Proyecto 5 (Computación en la Nube) y plan de trabajo del grupo.
Los valores que se prueban (topics, puertos, umbral, tiempos) están en [contrato.md](contrato.md).

## Cómo usar este documento

- Cada requerimiento tiene pruebas numeradas (`P1.1`, `P1.2`, …).
- Un requerimiento está **cumplido** solo cuando **todas** sus pruebas pasan y tienen evidencia.
- El resultado de cada prueba se registra en `docs/evidencias/R5.x.md` usando la plantilla `docs/evidencias/PLANTILLA.md`.
- Las pruebas se hacen contra el **backend real en Azure**, no en local.
- En los comandos, las claves se escriben como variables (`$CLAVE_DEV01`). **Nunca** se escriben claves reales en este repositorio.
- Las pruebas marcadas *(opcional)* suman en la sustentación, pero no bloquean el requerimiento.

## Resumen

| Req. | Tema | Pruebas | Responsable | Depende de |
|---|---|---|---|---|
| R5.1 | Dispositivos en BalenaCloud con OTA | P1.1 – P1.4 | Rol 1 | Rol 2 (broker) |
| R5.2 | MQTT con TLS y autenticación | P2.1 – P2.8 | Rol 2 | — |
| R5.3 | Esquema de topics | P3.1 – P3.3 | Rol 2 · Rol 5 | Rol 3 |
| R5.4 | Node-RED hacia InfluxDB | P4.1 – P4.6 | Rol 3 | Rol 2 |
| R5.5 | Dashboard en Grafana | P5.1 – P5.4 | Rol 4 | Rol 3 |
| R5.6 | Alertas por umbral | P6.1 – P6.4 | Rol 4 · Rol 3 | Rol 3 |
| R5.7 | Dispositivo offline | P7.1 – P7.4 | Rol 4 · Rol 1 | Rol 1, Rol 3 |
| R5.8 | Tercer dispositivo | P8.1 – P8.4 | Rol 5 · Rol 1 | Todos |
| Escalado | Impacto de agregar dispositivos | PE.1 – PE.4 | Rol 5 · Rol 2 | Rol 1 |

---

## R5.1 — Dispositivos en BalenaCloud con OTA

**Enunciado:** Registrar y gestionar mínimo 2 dispositivos en BalenaCloud con aplicación en contenedor Docker desplegada remotamente (OTA).

**Criterio de aceptación del curso:** Actualización OTA ejecutada sin intervención manual; dispositivos visibles en el dashboard de Balena.

**Responsable:** Rol 1

| ID | Prueba | Resultado esperado | Evidencia |
|---|---|---|---|
| P1.1 | Abrir el dashboard de la flota (Generic x86_64 GPT) | `dev01` y `dev02` aparecen **Online** con la misma release | Captura del dashboard |
| P1.2 | Cambiar algo visible en el código del simulador, ejecutar `balena push <flota>` y **no tocar las VM** | Se crea una release nueva y ambos dispositivos se actualizan solos | Captura de la release antes y después |
| P1.3 | Cronometrar desde que termina el push hasta que ambos dispositivos corren la release nueva | Tiempo registrado; los datos MQTT siguen llegando después | Tiempo medido y salida de `mosquitto_sub` |
| P1.4 | Revisar las variables de entorno de cada dispositivo en Balena | Cada uno tiene su propio `DEVICE_ID`, `MQTT_USER` y `MQTT_PASSWORD`; la imagen es la misma | Captura de las variables (**clave oculta**) |

---

## R5.2 — Publicación MQTT con TLS y autenticación

**Enunciado:** Implementar publicación de datos de sensores (reales o simulados) vía MQTT a un broker configurado con autenticación TLS.

**Criterio de aceptación del curso:** Mensajes publicados correctamente; conexión verificada como cifrada con Wireshark o logs.

**Responsable:** Rol 2

| ID | Prueba | Resultado esperado | Evidencia |
|---|---|---|---|
| P2.1 | Publicar y suscribirse con TLS, `ca.crt` y credenciales válidas | El suscriptor recibe el mensaje | Salida de ambas terminales |
| P2.2 | Conectarse **sin usuario ni clave** al puerto 8883 | Conexión rechazada (`not authorised`) | Salida del comando |
| P2.3 | Conectarse con **clave incorrecta** | Conexión rechazada | Salida del comando |
| P2.4 | Conectarse **sin TLS**: al puerto 1883 y en texto plano al 8883 | Puerto 1883 cerrado; 8883 sin TLS falla | Salida de los comandos |
| P2.5 | Conectarse con un `ca.crt` **distinto** | Falla la verificación del certificado | Salida del comando |
| P2.6 | Con el usuario `dev01`, publicar en `iot/dev02/temperatura` mientras `nodered` escucha `iot/#` | El mensaje **no** llega (ACL) | Salida de ambas terminales |
| P2.7 | Capturar con Wireshark el tráfico al puerto 8883 mientras un dispositivo publica | Se ve el handshake TLS y luego datos ilegibles; ni el topic ni el JSON aparecen en claro | Captura de pantalla de Wireshark |
| P2.8 | Revisar las reglas del NSG de Azure y probar los puertos desde una red **ajena** al equipo (por ejemplo, datos del celular) | Solo el 8883 responde; 1880, 8086 y 3000 no | Captura de las reglas en el portal de Azure y salida de la prueba |
| P2.9 *(opcional)* | Contraste: capturar con Wireshark un broker local **sin** TLS | Ahí sí se leen el topic y el JSON | Captura junto a la de P2.7 |

Comandos de referencia:

```bash
# P2.1 – terminal A (escucha)
mosquitto_sub -h "$BROKER_HOST" -p 8883 --cafile ca.crt -u nodered -P "$CLAVE_NODERED" -t 'iot/#' -v

# P2.1 – terminal B (publica)
mosquitto_pub -h "$BROKER_HOST" -p 8883 --cafile ca.crt -u dev01 -P "$CLAVE_DEV01" -q 1 \
  -t iot/dev01/temperatura \
  -m '{"device_id":"dev01","sensor":"temperatura","value":27.4,"unit":"C","ts":"2026-10-28T20:00:00Z"}'

# P2.2 – sin credenciales
mosquitto_pub -h "$BROKER_HOST" -p 8883 --cafile ca.crt -t iot/dev01/temperatura -m prueba

# P2.3 – clave incorrecta
mosquitto_pub -h "$BROKER_HOST" -p 8883 --cafile ca.crt -u dev01 -P clave-mala -t iot/dev01/temperatura -m prueba

# P2.4 – sin TLS
nc -zv "$BROKER_HOST" 1883
mosquitto_pub -h "$BROKER_HOST" -p 8883 -u dev01 -P "$CLAVE_DEV01" -t iot/dev01/temperatura -m prueba

# P2.6 – dev01 intenta escribir en el topic de dev02
mosquitto_pub -h "$BROKER_HOST" -p 8883 --cafile ca.crt -u dev01 -P "$CLAVE_DEV01" -t iot/dev02/temperatura -m intruso
```

---

## R5.3 — Esquema de topics y protocolo documentado

**Enunciado:** Diseñar e implementar un esquema de topics MQTT estructurado (`iot/{device_id}/{sensor}`) y documentar el protocolo de mensajes con ejemplos.

**Criterio de aceptación del curso:** Esquema documentado; nuevos dispositivos adoptados sin modificar el consumidor.

**Responsables:** Rol 2 (escribe `docs/protocolo-mqtt.md`) · Rol 5 (revisa y prueba)

| ID | Prueba | Resultado esperado | Evidencia |
|---|---|---|---|
| P3.1 | Revisar `docs/protocolo-mqtt.md` contra esta lista: topics, formato del JSON con tipos, QoS y retención, usuarios y permisos, **3 o más ejemplos**, comandos de prueba | Todo presente y coincide con el contrato | Enlace al archivo y lista revisada |
| P3.2 | Publicar con un `device_id` que el sistema **nunca ha visto** (por ejemplo `dev03` antes de R5.8) y revisar el historial de Node-RED con `git log --oneline -- backend/nodered/` | Los datos aparecen en InfluxDB y Grafana **sin ningún cambio** en Node-RED | Consulta en InfluxDB y salida de `git log` |
| P3.3 | Con `dev01` publicando, suscribirse **después** a `iot/+/status` | Llega de inmediato el último estado (mensaje retenido) | Salida de `mosquitto_sub` |

---

## R5.4 — Procesamiento con Node-RED hacia InfluxDB

**Enunciado:** Implementar un servicio de procesamiento (Node-RED) que consuma los mensajes MQTT, aplique reglas de negocio y los persista en InfluxDB.

**Criterio de aceptación del curso:** Datos almacenados correctamente; reglas de transformación verificadas con datos de prueba.

**Responsable:** Rol 3

| ID | Prueba | Mensaje de prueba | Resultado esperado | Evidencia |
|---|---|---|---|---|
| P4.1 | Mensaje válido | `{"device_id":"dev01","sensor":"temperatura","value":27.4,"unit":"C","ts":"2026-10-28T20:00:00Z"}` | Punto nuevo en `lecturas` con `device_id=dev01`, `sensor=temperatura`, `value=27.4` | Captura del Data Explorer de InfluxDB |
| P4.2 | Fuera de rango | Igual al anterior con `"value":150` | **No** está en `lecturas`; sí en `descartados` con el motivo | Consulta de ambas mediciones |
| P4.3 | Malformado, y justo después uno válido | `temperatura=27.4` (no es JSON) | El malformado queda como descartado; el válido sí se guarda (el flujo no se detuvo) | Captura del debug de Node-RED y de InfluxDB |
| P4.4 | Estado | `online` y luego `offline` en `iot/dev01/status` | En `estado`, `online` pasa de 1 a 0 | Consulta de `estado` |
| P4.5 | Regla de umbral | Temperatura con `"value":31.2` | El punto se guarda con `alerta=1`; el de 27.4 no la tiene | Consulta con ambos puntos |
| P4.6 | Exportación | Importar `backend/nodered/flows.json` en un Node-RED limpio | Se importa sin errores y **no contiene contraseñas ni tokens** | Captura del flujo importado |

---

## R5.5 — Dashboard en Grafana

**Enunciado:** Configurar Grafana con datasource InfluxDB y crear un dashboard con: estado de dispositivos en vivo, series de tiempo por sensor, mapa de calor y estadísticas.

**Criterio de aceptación del curso:** Dashboard actualiza en tiempo real; al menos 5 paneles funcionando con datos reales.

**Responsable:** Rol 4

| ID | Prueba | Resultado esperado | Evidencia |
|---|---|---|---|
| P5.1 | Con `dev01` y `dev02` publicando, revisar los paneles: estado de dispositivos, serie de temperatura, serie de humedad, mapa de calor, estadísticas mín/máx/promedio, último valor | Al menos 5 paneles con **datos reales** y sin errores | Captura del dashboard completo |
| P5.2 | Con refresco automático, anotar la hora de un mensaje y la hora en que aparece en el panel | Aparece en 10 s o menos | Dos capturas con la hora visible |
| P5.3 | Cambiar la variable `device_id` del dashboard | Los paneles filtran por el dispositivo elegido | Captura con cada valor |
| P5.4 | Importar `backend/grafana/dashboard.json` en un Grafana limpio | Funciona sin editarlo | Captura del dashboard importado |

---

## R5.6 — Alertas por umbral

**Enunciado:** Implementar un sistema de alertas basado en umbrales configurables: cuando un sensor supera el umbral, enviar notificación vía email o Telegram.

**Criterio de aceptación del curso:** Alerta disparada y recibida en **menos de 30 segundos** tras superar el umbral; demostrado en vivo.

**Responsables:** Rol 4 (Grafana) · Rol 3 (alerta directa desde Node-RED si Grafana no baja de 30 s)

| ID | Prueba | Resultado esperado | Evidencia |
|---|---|---|---|
| P6.1 | En Grafana, botón **Test** del contact point de Telegram | Llega el mensaje de prueba al grupo | Captura de Telegram |
| P6.2 | Publicar 35 °C a mano y cronometrar hasta que llega la alerta. Repetir **5 veces**, esperando 2 minutos entre intentos | **Cada** intento llega en menos de 30 s; se anotan promedio y máximo | Tabla de tiempos y capturas de Telegram |
| P6.3 | Cambiar el umbral a 28 °C **sin tocar código**, publicar 29 °C y luego volver a 30 °C | Con 28 °C la alerta se dispara; con 30 °C no | Captura de la configuración y de la alerta |
| P6.4 | Dejar los dispositivos publicando valores normales (menos de 30 °C) durante 10 minutos | No llega **ninguna** alerta falsa | Captura del chat sin alertas en ese intervalo |

Cómo cronometrar P6.2: una persona publica el mensaje y arranca el cronómetro del celular en el mismo momento; otra persona lo detiene cuando llega la notificación.

```bash
mosquitto_pub -h "$BROKER_HOST" -p 8883 --cafile ca.crt -u dev01 -P "$CLAVE_DEV01" -q 1 \
  -t iot/dev01/temperatura \
  -m "{\"device_id\":\"dev01\",\"sensor\":\"temperatura\",\"value\":35.0,\"unit\":\"C\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
```

---

## R5.7 — Detección de dispositivos offline

**Enunciado:** Implementar detección de dispositivos offline: si un dispositivo no envía datos por más de 5 minutos, generar alerta de desconexión.

**Criterio de aceptación del curso:** Alerta generada al desconectar manualmente un dispositivo; recuperación detectada al reconectar.

**Responsables:** Rol 4 (regla de alerta) · Rol 1 (Last Will y apagado de la VM)

| ID | Prueba | Resultado esperado | Evidencia |
|---|---|---|---|
| P7.1 | Apagar la VM de `dev02` y anotar la hora exacta | Alerta de desconexión **pasados 5 minutos**, no antes | Hora de apagado, hora de la alerta y captura de Telegram |
| P7.2 | Encender de nuevo `dev02` y anotar la hora | Aviso de recuperación; el panel vuelve a «en línea» | Captura de Telegram y del panel |
| P7.3 | Con `mosquitto_sub -t 'iot/+/status'` abierto, desconectar de golpe el adaptador de red de la VM de `dev01` | El broker publica `offline` en `iot/dev01/status` (Last Will) | Salida de `mosquitto_sub` |
| P7.4 | Durante P7.1, revisar `dev01` | `dev01` sigue en línea y **no** genera alerta | Captura del panel con ambos dispositivos |

---

## R5.8 — Incorporación de un tercer dispositivo

**Enunciado:** Documentar y demostrar el proceso de incorporación de un tercer dispositivo al sistema sin modificar la infraestructura existente.

**Criterio de aceptación del curso:** Nuevo dispositivo integrado en **menos de 30 minutos** siguiendo la guía; datos visibles en el dashboard.

**Responsables:** Rol 5 (redacción y prueba) · Rol 1 (contenido técnico)

| ID | Prueba | Resultado esperado | Evidencia |
|---|---|---|---|
| P8.1 | Una persona que **no escribió** la guía la sigue desde cero, con cronómetro y sin ayuda | `dev03` integrado en menos de 30 minutos | Tiempo total y tiempo por paso |
| P8.2 | Comparar el backend antes y después: `git diff <commit-anterior> -- backend/` y `docker compose ps` en la VM | Sin cambios en `backend/` ni reinicio de servicios | Salida de ambos comandos |
| P8.3 | Abrir el dashboard tras la integración | `dev03` aparece en la variable y en los paneles con datos | Captura del dashboard |
| P8.4 | Repetir una alerta de umbral y una de offline con `dev03` | Funcionan sin configurar nada adicional | Capturas de las alertas |

Si P8.1 falla o pasa de 30 minutos: anotar dónde se trabó la persona, corregir la guía y repetir con **otra** persona.

---

## Escalado — Impacto de agregar dispositivos

**Objetivo del enunciado:** Escalar el sistema agregando dispositivos y medir el impacto en la infraestructura.

**Responsables:** Rol 5 · Rol 2

Los simuladores extra se lanzan como contenedores Docker con distinto `DEVICE_ID`. Publican con un usuario MQTT temporal que crea el Rol 2 para la prueba y **borra al terminar**. El consumo se mide en la VM de Azure con `docker stats`.

| ID | Prueba | Resultado esperado | Evidencia |
|---|---|---|---|
| PE.1 | Línea base: solo `dev01` y `dev02` durante 5 minutos | CPU y memoria de cada contenedor del backend registradas | Salida de `docker stats` |
| PE.2 | 10 simuladores extra durante 5 minutos | Consumo registrado; el dashboard sigue respondiendo | Salida de `docker stats` y captura del dashboard |
| PE.3 | 50 simuladores extra durante 5 minutos | Consumo registrado; se anota si algo se degrada | Salida de `docker stats` y captura del dashboard |
| PE.4 | Contar en InfluxDB los puntos recibidos frente a los esperados | Porcentaje de pérdida calculado | Tabla comparativa |

Puntos esperados en 5 minutos = dispositivos × 2 sensores × 60 mensajes (un mensaje cada 5 segundos).
Ejemplo: 10 simuladores → 10 × 2 × 60 = 1 200 puntos.