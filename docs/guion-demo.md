# Guion de la demo (máximo 20 minutos)

> **Estado: propuesta de Rol 1 para ensayar y ajustar con el grupo.** Los tiempos de las alertas son los medidos el 2026-11-16 (ver [R5.6](evidencias/R5.6.md), [R5.7](evidencias/R5.7.md) y [R5.8](evidencias/R5.8.md)). Los tiempos del guion son estimados: **hay que ensayarlo con cronómetro**.

## Reglas de la presentación

1. Cada persona habla de **su rol** y muestra algo en vivo o su evidencia.
2. Se dice la verdad sobre el estado: lo que está ✅ y lo que sigue en 🟨 (ver la tabla de [README](../README.md)).
3. Ninguna clave en pantalla. Las claves MQTT se cargan sin eco (`read -rsp`). No se muestran el `.env` ni el chat ID de Telegram.
4. **Dos cosas son lentas y no se pueden acelerar:** la alerta de offline necesita más de 5 minutos sin datos, y arrancar una VM de balenaOS tarda ≈ 4 minutos. Por eso se **apaga `dev02` temprano** y se enciende a mitad de la demo (ver "Coreografía").

## Antes de la demo

**Con 1 hora de margen**

- [ ] Prender la VM de Azure (`vm-iot-backend`) y comprobar `Test-NetConnection 68.211.147.97 -Port 8883` → `True`. Se apaga sola a las 11 p. m.
- [ ] Prender `p5-dev01` y `p5-dev02`; en Balena, los dos **Online**.
- [ ] **El PC que proyecta tiene acceso a Grafana** (puerto 3000): con su IP autorizada por Rol 2, o con el túnel SSH (`ssh -N -L 3000:localhost:3000 -i "%USERPROFILE%\Downloads\practica-iaas-key.pem" azureuser@68.211.147.97`).
- [ ] Construida la imagen de `dev03` para la demo en vivo (`docker build -t p5-simulador device/`), y la clave de `dev03` a mano en el chat privado, **no** en pantalla.
- [ ] **Una sola vía de alertas activa a Telegram.** Hoy hay dos: las reglas de Grafana y el "Plan B" de Node-RED (otro bot). Si las dos están activas, llegan alertas duplicadas. El grupo decide cuál se usa.
- [ ] Sin `TEMP_FORZADA` en `dev01` ni `dev02`.
- [ ] Telegram de escritorio abierto en el chat de alertas (para ver la hora con segundos).

**Con 10 minutos de margen**

- [ ] Dashboard abierto con `device_id` en `All`, "Last 1 hour" y refresco 10 s.
- [ ] Balena abierto en `dev01` → *Device Variables*.
- [ ] Una terminal con `docker` lista y el historial limpio.
- [ ] Un cronómetro visible para el grupo.

## Cronograma

| Minuto | Quién | Qué dice | Qué muestra o hace |
|---|---|---|---|
| 0:00 a 1:30 | **Rol 5** (Alejandro D.) | El problema y la arquitectura completa | Diagrama del README; tabla de requerimientos |
| 1:30 a 4:00 | **Rol 2** (Santiago) | Backend en Azure con Docker Compose; broker Mosquitto con TLS, usuarios y permisos por dispositivo | `docker compose ps` en la VM; captura de Wireshark con TLS 1.3 (R5.2); esquema de topics (R5.3) |
| 4:00 a 6:45 | **Rol 1** (Kevin) | Flota en BalenaCloud, simulador en Docker y variables por dispositivo | Flota con `dev01` y `dev02` Online; sus variables (clave oculta); log del simulador; releases con los tiempos de OTA |
| **6:45** | **Rol 1** | "Voy a apagar `dev02` ahora; en 5 minutos la alerta debe llegar" | ***Power off* de `p5-dev02`** y anotar la hora en voz alta |
| 6:45 a 9:15 | **Rol 3** (Isabella) | Node-RED valida, descarta lo inválido y guarda en InfluxDB | Flujo; publicar un mensaje inválido con `mosquitto_pub` y ver el descarte; datos en InfluxDB |
| 9:15 a 10:45 | **Rol 4** (Boris) | Dashboard con 6 paneles y la variable `device_id` | Panel con `All`, luego `dev01`; refresco en vivo |
| **10:45** | **Rol 1** + **Rol 4** | Alerta de temperatura mayor a 30 °C | Kevin pone `TEMP_FORZADA=35` en `dev01` (Balena). Boris muestra el panel en rojo |
| ≈ 11:15 | **Rol 4** | La alerta llega a Telegram | Mostrar el mensaje de *Temperatura Alta* de `dev01`. Medido: ≈ 25 a 35 s en total |
| ≈ 11:50 | **Rol 4** | **Alerta de offline de `dev02`** (más de 5 min sin datos), y `dev01` sigue en línea | Mostrar el mensaje de offline **solo de `dev02`** |
| 12:30 | **Rol 1** | Quita `TEMP_FORZADA` | Llega el *Resolved* de temperatura (≈ 15 s) |
| **13:15** | **Rol 1** | "Enciendo `dev02`; tarda ≈ 4 minutos en arrancar" | **Encender `p5-dev02`** y anotar la hora |
| 13:15 a 15:45 | **Rol 5** + **Rol 1** | Un dispositivo nuevo sin tocar el backend (R5.8) | `docker run` de `dev03` en vivo (la imagen ya está construida); `dev03` aparece en `device_id` y en los paneles; tabla de tiempos de la prueba |
| 15:45 a 17:15 | **Rol 2** + **Rol 5** | Escalado: 2, 10 y 50 simuladores | Tabla y capturas de [escalado](evidencias/escalado.md) (0 % de pérdida) |
| ≈ 17:15 | **Rol 1** | **Aviso de recuperación de `dev02`** | Mostrar el *Resolved* de offline en Telegram |
| 17:15 a 18:15 | **Rol 5** | Estado final, con lo que está ✅ y lo que sigue pendiente | Tabla de requerimientos del README |
| 18:15 a 20:00 | **Todos** | Cierre y preguntas | |

**Si el ensayo da más de 20 minutos:** el escalado pasa a una diapositiva (sin hablar en vivo), y la explicación de Node-RED se acorta. **No** se acortan las alertas: son lo más exigente de la demo.

## Coreografía de las esperas

El riesgo de la demo está en los tiempos de espera, no en la explicación:

```
6:45   Kevin apaga dev02 (power off)
       ├─ el panel de Grafana ya lo muestra OFFLINE al instante (Last Will)
       └─ la ALERTA llega ≈ 5 min después de su último dato → ≈ 11:50
10:45  Kevin pone TEMP_FORZADA=35 en dev01 → alerta ≈ 25 a 35 s después
12:30  Kevin quita TEMP_FORZADA → Resolved ≈ 15 s después
13:15  Kevin enciende dev02 → arranca ≈ 3 min 50 s → Resolved ≈ 17:15
```

- Mientras esperan, los demás **siguen hablando**: nadie queda mirando la pantalla.
- Si la alerta de offline **no llega** a los 6 minutos de apagar `dev02`, no se espera: se muestra la captura de [R5.7](evidencias/R5.7.md) (P7.1 y P7.2) y se explica la regla.

## Qué dice cada rol

**Rol 5, Alejandro Domínguez (apertura y cierre).** Un sistema IoT de punta a punta: dispositivos → MQTT con TLS → Node-RED → InfluxDB → Grafana → Telegram, y BalenaCloud para gestionar la flota. Cada rol trabajó en su rama y todo entró por pull request con aprobación de otra persona; cada requerimiento tiene su ficha de evidencia con capturas y tiempos.

**Rol 2, Santiago Osorio.** Una VM de Azure con IP fija y cuatro contenedores (Mosquitto, Node-RED, InfluxDB, Grafana). Solo el puerto 8883 está abierto al público (P2.8); el tráfico va cifrado con TLS 1.3 (Wireshark, P2.7) y cada dispositivo solo puede publicar en `iot/<su_id>/#`. Esquema de topics `iot/{device_id}/{sensor}`.

**Rol 1, Kevin Aristizabal.**
- *Qué hice:* dos dispositivos simulados (VM con balenaOS en VirtualBox) registrados en una flota de BalenaCloud. Todos corren la **misma imagen**; lo que cambia son las variables (`DEVICE_ID`, `MQTT_USER`, `MQTT_PASSWORD`). Las claves nunca están en el repositorio.
- *OTA:* con un `balena push` se actualizaron los dos dispositivos sin tocar las VM: **41 s** la primera vez y **258 s** la segunda (no investigué la diferencia).
- *Last Will:* al cortar la red de `dev01`, el broker publicó `offline` a los **46 s**, y `online` a los 21 s de reconectar.
- *Alertas:* para probar R5.6 y R5.7 con un dispositivo real agregué la variable opcional `TEMP_FORZADA`: con ella `dev01` publica 32 a 35 °C sin tocar la VM. Con las reglas corregidas, la alerta de temperatura llega ≈ 25 a 35 s después y la de offline pasados los 5 minutos.
- *Qué aprendí:* encontré que la regla de offline estaba invertida y la corregí; también que el contenedor de Mosquitto no arrancaba solo con la VM.

**Rol 3, Isabella Castañeda.** Node-RED se suscribe a `iot/+/+` (un dispositivo nuevo no requiere cambios), valida rangos (temperatura de −20 a 80 °C, humedad de 0 a 100 %) y la hora en UTC, y separa las salidas en `lecturas`, `estado` y `descartados`. Marca `alerta = 1` si la temperatura supera 30 °C.

**Rol 4, Alejandro Boris Garces.** Dashboard de Grafana con 6 paneles (temperatura, humedad, estado, mapa de calor, estadísticas y último valor) y la variable `device_id`. Alertas por Telegram: temperatura mayor a 30 °C y dispositivo sin datos por más de 5 minutos, con aviso de recuperación.

## Diapositivas sugeridas (una por bloque)

1. Título, equipo y roles.
2. Arquitectura (el diagrama del README).
3. Backend y seguridad: Azure, Mosquitto con TLS, usuarios y ACL.
4. Dispositivos y BalenaCloud: flota, variables y OTA (con los tiempos).
5. Procesamiento: Node-RED e InfluxDB (reglas de validación).
6. Grafana y alertas: paneles, umbrales y los tiempos medidos.
7. Dispositivo nuevo (R5.8) y escalado (2, 10 y 50).
8. Estado de los requerimientos, lecciones aprendidas y preguntas.

## Plan B

| Si falla… | Se hace |
|---|---|
| La VM de Azure no responde | Se explica con las capturas de las fichas y un video grabado con anticipación. Se prende desde el portal (≈ 2 min) |
| `dev01` / `dev02` (el PC de Kevin) | Un segundo equipo con Docker corre el simulador (`docker run`, Ruta B de la [guía](guia-nuevo-dispositivo.md)) |
| Telegram no recibe | Mostrar el estado de las reglas en Grafana (*Alerting*) y las capturas de las fichas |
| No hay acceso a Grafana desde el PC que proyecta | Túnel SSH desde el PC de Kevin |
| La alerta de offline tarda | Seguir con el guion y mostrar la captura de R5.7 |

**Grabar hoy** un video corto de cada demo (temperatura, offline y recuperación, `dev03` en vivo) para tener el respaldo.

## Preguntas probables y respuesta honesta

- **¿Por qué los dispositivos son VM en un PC?** Es una simulación sin hardware: la VM corre balenaOS igual que un dispositivo real, y Balena los gestiona igual.
- **¿Por qué la alerta de offline tarda 5 minutos?** Es el criterio del contrato: más de 5 minutos sin datos. El `offline` instantáneo del Last Will se ve en el panel, pero la alerta espera el plazo.
- **¿Se cumplen los 30 s de la alerta de temperatura?** Grafana la dispara 3 s después de la lectura; de punta a punta con Telegram midió ≈ 25 a 35 s. Solo hay 2 de las 5 mediciones pedidas (ver R5.6).
- **¿Qué pasa si un dispositivo lleva más de una hora apagado?** La regla de offline mira la última hora; pasada esa hora, la alerta se resuelve sola. Es un límite conocido (ver `backend/grafana/alerting/README.md`).
- **¿Qué falta?** Lo que aparezca en 🟨 en la tabla del README.

## Pendientes que bloquean la demo

- Fichas R5.5 y R5.6 sin llenar (Rol 4): P5.2, P5.3, P5.4, P6.1 y la captura de P6.4.
- R5.8 con la ruta de Balena (P8.1) y la parte de Telegram de P8.4.
- Decidir la **vía única de alertas** (Grafana o Node-RED).
- Diapositivas y ensayo con cronómetro.
