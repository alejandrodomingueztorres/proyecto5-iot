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
| R5.2 | Publicación MQTT con TLS y autenticación | Mensajes publicados; cifrado verificado con Wireshark o logs | Rol 2 | ⬜ | [Ver](docs/evidencias/R5.2.md) |
| R5.3 | Esquema de topics documentado | Nuevos dispositivos adoptados sin modificar el consumidor | Rol 2 · Rol 5 | ⬜ | [Ver](docs/evidencias/R5.3.md) |
| R5.4 | Procesamiento Node-RED → InfluxDB | Datos almacenados; reglas verificadas con datos de prueba | Rol 3 | ✅ | [Ver](docs/evidencias/R5.4.md) |
| R5.5 | Dashboard en Grafana | Tiempo real; 5+ paneles con datos reales | Rol 4 | 🟨 | [Ver](docs/evidencias/R5.5.md) |
| R5.6 | Alertas por umbral | Recibida en menos de 30 s; demostrada en vivo | Rol 4 · Rol 3 | 🟨 | [Ver](docs/evidencias/R5.6.md) |
| R5.7 | Detección de dispositivo offline | Alerta tras 5 min sin datos; recuperación detectada | Rol 4 · Rol 1 | 🟨 | [Ver](docs/evidencias/R5.7.md) |
| R5.8 | Incorporación de un tercer dispositivo | Integrado en menos de 30 min con la guía; visible en el dashboard | Rol 5 · Rol 1 | ⬜ | [Ver](docs/evidencias/R5.8.md) |
| — | Escalado (objetivo del proyecto) | Consumo con 10 y 50 dispositivos medido | Rol 5 · Rol 2 | ⬜ | [Ver](docs/evidencias/escalado.md) |

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

> 🚧 **En construcción.** Los Roles 1 y 2 completan esta sección cuando el sistema esté estable, y el Rol 5 la valida siguiéndola desde cero.

### 1. Backend en Azure
```bash
git clone https://github.com/alejandrodomingueztorres/proyecto5-iot.git
cd proyecto5-iot/backend
cp .env.example .env      # completar con los valores reales 
docker compose up -d
```

### 2. Dispositivos
_Pendiente (Rol 1)._

### 3. Comprobar que todo funciona
_Pendiente._

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