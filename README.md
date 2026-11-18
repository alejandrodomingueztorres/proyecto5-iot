# Proyecto 5 — Sistema IoT en la nube con ingesta, almacenamiento, análisis y alertas

**Computación en la Nube · Proyectos Final**

Sistema IoT de punta a punta. Dispositivos simulados en máquinas virtuales con balenaOS publican lecturas de **temperatura y humedad** por **MQTT cifrado con TLS** a un broker **Mosquitto**. **Node-RED** valida los mensajes, aplica las reglas de negocio y los guarda en **InfluxDB**. **Grafana** muestra el dashboard en tiempo real y envía **alertas por Telegram**. Todo el backend corre con **Docker Compose en una VM Ubuntu de Azure**, y **BalenaCloud** gestiona la flota de dispositivos y sus actualizaciones remotas (OTA).

```
  Dispositivos (VM balenaOS)          BalenaCloud: flota y actualizaciones OTA
  dev01 · dev02 · dev03
        │  MQTT + TLS (puerto 8883) + usuario y clave
        ▼
 ┌─────────────────── VM Ubuntu en Azure (Docker Compose) ───────────────────┐
 │                                                                           │
 │  Mosquitto ──► Node-RED ──► InfluxDB ──► Grafana ──► Alertas Telegram     │
 │  (broker)      (reglas)     (datos)      (dashboard)                      │
 │                                                                           │
 └───────────────────────────────────────────────────────────────────────────┘
```

---

## Estado de los requerimientos

Un requerimiento se marca ✅ solo cuando **todas** sus pruebas pasan y la evidencia está registrada.
Las pruebas de cada uno están en [docs/requerimientos.md](docs/requerimientos.md).

| ID | Requerimiento | Criterio de aceptación | Responsable | Estado | Evidencia |
|---|---|---|---|---|---|
| R5.1 | 2+ dispositivos en BalenaCloud con OTA | OTA sin intervención manual; dispositivos visibles en Balena | Rol 1 | ✅ | [Ver](docs/evidencias/R5.1.md) |
| R5.2 | Publicación MQTT con TLS y autenticación | Mensajes publicados; cifrado verificado con Wireshark o logs | Rol 2 | ✅ | [Ver](docs/evidencias/R5.2.md) |
| R5.3 | Esquema de topics documentado | Nuevos dispositivos adoptados sin modificar el consumidor | Rol 2 · Rol 5 | ✅ | [Ver](docs/evidencias/R5.3.md) |
| R5.4 | Procesamiento Node-RED → InfluxDB | Datos almacenados; reglas verificadas con datos de prueba | Rol 3 | ✅ | [Ver](docs/evidencias/R5.4.md) |
| R5.5 | Dashboard en Grafana | Tiempo real; 5+ paneles con datos reales | Rol 4 | ✅ | [Ver](docs/evidencias/R5.5.md) |
| R5.6 | Alertas por umbral | Recibida en menos de 30 s; demostrada en vivo | Rol 4 · Rol 3 | ✅ | [Ver](docs/evidencias/R5.6.md) |
| R5.7 | Detección de dispositivo offline | Alerta tras 5 min sin datos; recuperación detectada | Rol 4 · Rol 1 | ✅ | [Ver](docs/evidencias/R5.7.md) |
| R5.8 | Incorporación de un tercer dispositivo | Integrado en menos de 30 min con la guía; visible en el dashboard | Rol 5 · Rol 1 | ✅ | [Ver](docs/evidencias/R5.8.md) |
| — | Escalado (objetivo del proyecto) | Consumo con 10 y 50 dispositivos medido | Rol 5 · Rol 2 | ✅ | [Ver](docs/evidencias/escalado.md) |

**Leyenda:** ⬜ Pendiente · 🟨 En progreso · ✅ Cumplido · ❌ Falla

---

## Tecnologías

| Pieza | Tecnología | Para qué |
|---|---|---|
| Nube | Microsoft Azure (VM Ubuntu LTS) | Aloja todo el backend con una IP pública |
| Gestión de dispositivos | BalenaCloud + balenaOS en VirtualBox | Flota de dispositivos y actualizaciones OTA |
| Dispositivos | Simulador en Python (paho-mqtt) dentro de Docker | Genera lecturas de temperatura y humedad |
| Broker | Mosquitto 2 con TLS, usuarios y ACL | Recibe los mensajes de forma cifrada y autenticada |
| Procesamiento | Node-RED | Valida, aplica reglas y guarda los datos |
| Base de datos | InfluxDB 2.x | Series de tiempo |
| Visualización y alertas | Grafana + Telegram | Dashboard y notificaciones |
| Despliegue | Docker Compose | Levanta el backend con un comando |

---

## Inicio rápido

Pasos para montar el sistema completo desde cero, en este orden. Cada paso dice cómo comprobar
que quedó bien antes de seguir. El detalle de cada uno está en
[docs/rol2-infraestructura.md](docs/rol2-infraestructura.md) (backend),
[backend/nodered/README.md](backend/nodered/README.md) (Node-RED) y la
[guía de dispositivo nuevo](docs/guia-nuevo-dispositivo.md) (dispositivos).

**Se necesita:** una suscripción de Azure; en el PC, Git, un cliente SSH y una llave SSH
(`ssh-keygen`); y para los dispositivos, Docker o una cuenta de BalenaCloud con VirtualBox.

### 1. Backend en Azure

**1.1 Crear la VM.** En el portal de Azure: *Máquinas virtuales → Crear*, con Ubuntu Server 24.04
LTS, tamaño **Standard_B2als_v2** (2 vCPU, 4 GB; con menos no alcanza para los 4 servicios),
autenticación con la llave SSH pública y usuario `azureuser`. La IP pública Standard es **fija**:
esa IP es el `BROKER_HOST` de todo el proyecto.
Comprobar: `ssh azureuser@<IP>` entra a la VM.

**1.2 Abrir el firewall (NSG).** En *VM → Redes → Reglas de puerto de entrada*:

| Prioridad | Puerto | Origen | Para qué |
|---|---|---|---|
| 100 | 8883/TCP | Internet | MQTT con TLS, para los dispositivos |
| 110 | 22/TCP | Solo las IP del equipo (`/32`) | SSH |
| 120 | 1880, 3000, 8086/TCP | Solo las IP del equipo (`/32`) | Node-RED, Grafana e InfluxDB |

El 1883 (MQTT sin cifrar) **no** se abre. Todo lo demás lo bloquea la regla por defecto
`DenyAllInBound`.

**1.3 Instalar Docker en la VM:**

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
exit                      # volver a entrar por SSH para que tome el grupo docker
```

**1.4 Clonar el repositorio y crear el `.env`:**

```bash
git clone https://github.com/alejandrodomingueztorres/proyecto5-iot.git
cd proyecto5-iot/backend
cp .env.example .env
nano .env
```

En el `.env` se pone la IP de la VM en `BROKER_HOST`, cada clave con `openssl rand -base64 18` y
`INFLUXDB_ADMIN_TOKEN` con `openssl rand -hex 32`. Los dos tokens por servicio se llenan en el
paso 1.7. El `.env` **nunca** se sube al repositorio.

**1.5 Certificados TLS y usuarios MQTT:**

```bash
sudo bash mosquitto/generar-certificados.sh      # CA propia y certificado del broker para BROKER_HOST
sudo bash mosquitto/crear-usuario.sh dev01       # muestra la clave una sola vez: guárdala
sudo bash mosquitto/crear-usuario.sh dev02
sudo bash mosquitto/crear-usuario.sh dev03
sudo bash mosquitto/crear-usuario.sh nodered "$(grep '^MQTT_NODERED_PASSWORD=' .env | cut -d= -f2-)"
```

Comprobar: el primer script termina con `server.crt: OK` y el `subjectAltName` incluye la IP de
la VM. Los permisos de cada usuario ya están en
[mosquitto/config/acl.conf](backend/mosquitto/config/acl.conf): cada dispositivo solo escribe en
`iot/<su id>/#` y `nodered` solo lee.

**1.6 Levantar los 4 servicios:**

```bash
docker compose up -d
docker compose ps         # mosquitto, nodered, influxdb y grafana en "Up"
```

**1.7 Tokens de InfluxDB por servicio.** Node-RED recibe un token que **solo escribe** en el bucket
`iot` y Grafana uno que **solo lee**:

```bash
BUCKET_ID=$(docker compose exec -T influxdb influx bucket list --org curso --name iot --hide-headers | cut -f1)
docker compose exec -T influxdb influx auth create --org curso --description "nodered: escribe en iot" --write-bucket "$BUCKET_ID" --hide-headers | cut -f3
docker compose exec -T influxdb influx auth create --org curso --description "grafana: lee iot" --read-bucket "$BUCKET_ID" --hide-headers | cut -f3
```

Cada comando imprime un token: el primero va en `INFLUXDB_NODERED_TOKEN` y el segundo en
`INFLUXDB_GRAFANA_TOKEN` del `.env`. Después, `docker compose up -d` para que los tomen.

**1.8 Node-RED (flujo de ingesta).** Abrir `http://<IP>:1880`, instalar el nodo
`node-red-contrib-influxdb` (*Manage palette*), importar
[backend/nodered/flows.json](backend/nodered/flows.json), escribir las credenciales como
variables (`${MQTT_NODERED_USER}`, `${MQTT_NODERED_PASSWORD}`, `${INFLUXDB_TOKEN}`) y pulsar
**Deploy**. Paso a paso con capturas en [backend/nodered/README.md](backend/nodered/README.md).
Comprobar: debajo del nodo `iot/+/+` dice **connected**.

**1.9 Grafana (dashboard y alertas).** Para las alertas por Telegram, poner antes el token del
bot y el chat ID en `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` del `.env`. Luego, un solo comando:

```bash
python3 grafana/configurar-grafana.py
```

Crea el data source de InfluxDB, la carpeta *Proyecto 5*, el dashboard de
[grafana/dashboard.json](backend/grafana/dashboard.json), el contact point de Telegram y las dos
alertas de [grafana/alerting/](backend/grafana/alerting/). Usa los mismos identificadores (UID)
de esos archivos, por eso no conviene crearlos a mano. Si se corre otra vez, no duplica nada.
Comprobar: termina con `Listo.` y la línea `Prueba del data source: OK`.

**1.10 Apagar la VM cuando no se usa** (Azure cobra mientras esté prendida):

```bash
az vm deallocate -g <grupo> -n <vm>     # apagar y dejar de pagar la VM
az vm start -g <grupo> -n <vm>          # prender: los 4 servicios arrancan solos
```

La VM del proyecto (`vm-iot-backend`, IP `68.211.147.97`) además se apaga sola cada noche a las
11 pm (ver [docs/rol2-infraestructura.md](docs/rol2-infraestructura.md)).

### 2. Dispositivos
Cada dispositivo es un contenedor con el simulador de [`device/`](device/). Hay dos formas de crear uno, las dos descritas paso a paso en la **[guía de dispositivo nuevo](docs/guia-nuevo-dispositivo.md)**:

- **BalenaCloud + VirtualBox (principal):** la usada para `dev01` y `dev02`; es la tecnología que pide el proyecto para gestionar dispositivos. Necesita acceso a la flota de Balena.
- **Docker (alternativa rápida, plan B):** necesita Docker, este repositorio y la clave MQTT del dispositivo (la entrega el Rol 2 por el chat privado del grupo).

Con Docker, resumido (los detalles y la forma segura de cargar la clave están en la guía):

```bash
docker build -t p5-simulador device/
docker run -d --name dev03 -e DEVICE_ID=dev03 -e MQTT_USER=dev03 -e MQTT_PASSWORD \
  -e BROKER_HOST=<IP_DE_LA_VM_AZURE> -e BROKER_PORT=8883 p5-simulador
```

`MQTT_PASSWORD` va sin valor: Docker lo toma de tu terminal, para que la clave no quede escrita en el comando.

### 3. Comprobar que todo funciona

En la VM, desde `proyecto5-iot/backend`, con al menos un dispositivo publicando:

```bash
# 1. Los 4 servicios arriba
docker compose ps

# 2. Llegan mensajes al broker por TLS (lectura con el usuario de Node-RED; Ctrl+C para salir)
docker run --rm --network host -v "$PWD/mosquitto/config/certs:/certs:ro" eclipse-mosquitto:2.0.20 \
  mosquitto_sub -h <IP> -p 8883 --cafile /certs/ca.crt -u nodered \
  -P "$(grep '^MQTT_NODERED_PASSWORD=' .env | cut -d= -f2-)" -t 'iot/#' -v

# 3. Node-RED los guarda en InfluxDB (lecturas por dispositivo en los últimos 5 minutos)
docker compose exec -T influxdb influx query --org curso \
  'from(bucket:"iot") |> range(start:-5m) |> filter(fn:(r)=> r._measurement=="lecturas") |> group(columns:["device_id"]) |> count()'
```

| Qué | Resultado esperado |
|---|---|
| `docker compose ps` | Los 4 servicios en `Up` |
| `mosquitto_sub` | Cada 5 s, una línea por sensor: `iot/dev01/temperatura {"device_id": "dev01", ...}` |
| Consulta a InfluxDB | Un conteo por dispositivo: unas 120 lecturas en 5 minutos (60 por sensor). Si no sale nada, no hay dispositivos publicando |
| Grafana, `http://<IP>:3000` | El *Dashboard Oficial* con los dispositivos en tiempo real |
| Un dispositivo nuevo | Aparece solo en InfluxDB y Grafana, sin cambiar Node-RED ([P3.2](docs/evidencias/R5.3.md)) |
| Apagar un dispositivo | A los 5 minutos llega la alerta *offline* a Telegram |

Las pruebas completas de cada requerimiento, con sus resultados, están en
[docs/evidencias/](docs/evidencias/).

---

## Estructura del repositorio

```
proyecto5-iot/
├── README.md                 # este archivo
├── .gitignore                # evita subir secretos
├── docs/
│   ├── contrato.md           # valores acordados entre roles (topics, puertos, formato)
│   ├── requerimientos.md     # R5.1–R5.8 con sus pruebas de aceptación
│   └── evidencias/           # plantilla, una ficha por requerimiento y capturas
├── backend/                  # Docker Compose, Mosquitto, Node-RED y Grafana
├── device/                   # simulador y configuración de Balena
└── diapositivas/             # presentación final
```

| Documento | Contenido |
|---|---|
| [Contrato compartido](docs/contrato.md) | Topics, formato del mensaje, puertos, base de datos y umbrales |
| [Requerimientos y pruebas](docs/requerimientos.md) | Qué se prueba, cómo y qué resultado se espera |
| [Plantilla de evidencias](docs/evidencias/PLANTILLA.md) | Formato para registrar cada prueba |
| [Protocolo MQTT](docs/protocolo-mqtt.md) | Conexión, topics, JSON, QoS, permisos, ejemplos y alta de dispositivos |
| [Backend en Azure (Rol 2)](docs/rol2-infraestructura.md) | VM, firewall, TLS, usuarios, pruebas de R5.2 y escalado |

---

## Equipo

| Rol | Responsabilidad | Integrante | Usuario GitHub |
|---|---|---|---|
| 1 | Dispositivos y BalenaCloud | Kevin Aristizabal | [KevinAristizabal](https://github.com/KevinAristi) |
| 2 | Infraestructura en Azure y MQTT seguro | Santiago Osorio | [SantiagoOsorio](https://github.com/rrolface) |
| 3 | Node-RED e InfluxDB | Isabella Castañeda Zapata |[Ludovia](https://github.com/icastaneda21) |
| 4 | Grafana y alertas | Alejandro Boris Garces | [Boris200306](https://github.com/Boris200306) |
| 5 | Documentación, pruebas y presentación | Alejandro Domínguez Torres | [alejandrodomingueztorres](https://github.com/alejandrodomingueztorres) |

---

## Cómo trabajamos

1. Cada rol trabaja en su rama: `rol1-dispositivos`, `rol2-infraestructura`, `rol3-nodered`, `rol4-grafana`, `rol5-documentacion`.
2. Los cambios entran a `main` **solo por pull request** con una aprobación.
3. Una tarea está terminada cuando **funciona, tiene evidencia y está documentada**.
4. **Nunca** se suben contraseñas, tokens, claves privadas ni archivos `.env`. Los secretos se comparten solo por el chat privado del grupo.
5. El [contrato](docs/contrato.md) solo cambia con acuerdo de todo el grupo.

---

## Entrega

| Entregable | Estado |
|---|---|
| Repositorio con código, configuración y guía paso a paso | 🟨 En progreso |
| Diapositivas (carpeta `diapositivas/`) | ⬜ Pendiente |
| Presentación y demo en vivo (máximo 20 minutos) | ⬜ Pendiente |

Fecha de entrega: **18 de noviembre de 2026**.