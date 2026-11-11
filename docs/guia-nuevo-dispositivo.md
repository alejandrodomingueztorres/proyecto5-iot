# Guía: incorporar un dispositivo nuevo (R5.8)

Cómo sumar un dispositivo (por ejemplo `dev03`) al sistema **sin modificar la infraestructura**: ni `backend/`, ni Node-RED, ni Grafana. El objetivo del curso es hacerlo en **menos de 30 minutos** siguiendo solo esta guía.

> **Estado de esta guía: borrador.** La redactó Rol 1 y todavía **no** la ha seguido una persona que no la escribió (prueba P8.1 de [R5.8](evidencias/R5.8.md)). Los comandos de la Ruta B no se ejecutaron en el PC del autor (no tiene Docker) y la Ruta A se escribió a partir de lo que ya funcionó para `dev01` y `dev02`. Quien la pruebe debe anotar dónde se traba.

## Qué hace falta saber antes

Cada dispositivo es un contenedor con el simulador de `device/`. Lee su configuración de variables de entorno y publica temperatura y humedad por MQTT con TLS (puerto 8883) al broker de Azure. El esquema de topics y el formato de los mensajes están en [contrato.md](contrato.md).

Hay dos rutas. Las dos usan **la misma imagen** y el mismo simulador:

| | **Ruta B: Docker** (recomendada) | **Ruta A: BalenaCloud + VirtualBox** |
|---|---|---|
| Qué se crea | Un contenedor Docker en cualquier equipo | Una máquina virtual con balenaOS, gestionada desde Balena |
| Necesitas | Docker, este repositorio, la clave del dispositivo | VirtualBox, **acceso a la flota de Balena**, la clave del dispositivo |
| Aparece en Balena y recibe OTA | No | Sí |
| Cabe en 30 min | Sí | Ajustado (descarga de ~1.4 GB, conversión y arranque de la VM) |
| Cuándo usarla | Cualquier persona del grupo | Para demostrar la gestión de flota (R5.1) |

`dev01` y `dev02` usan la Ruta A. Para sumar `dev03` en la prueba P8.1, usa la Ruta B salvo que el profesor o el grupo pidan expresamente Balena.

## Requisitos comunes (para las dos rutas)

1. **El usuario MQTT del dispositivo ya existe.** Lo crea el Rol 2 con `crear-usuario.sh` (para `dev03` ya está creado). Si el `device_id` es otro, pídeselo a Rol 2 *antes de empezar*; eso es configuración del broker, no un cambio de `backend/`.
2. **La clave de ese usuario.** Rol 2 la entrega por el **chat privado del grupo**. No va nunca en el repositorio, en un commit, en un issue ni en una captura.
3. **El broker está encendido.** La VM de Azure se apaga sola por la noche y puede estar detenida. Pídele a Rol 2 que la prenda, y comprueba el puerto:

```powershell
Test-NetConnection 68.211.147.97 -Port 8883
```

   Resultado esperado: `TcpTestSucceeded : True`. Si da `False`, el broker está apagado y **no es un fallo del dispositivo**.
4. **El certificado de la CA del broker** está en el repositorio: `device/ca.crt` (es público, no contiene ninguna clave).

Valores para un dispositivo nuevo (según el [contrato](contrato.md), sección 7):

| Variable | Valor para `dev03` |
|---|---|
| `DEVICE_ID` | `dev03` |
| `MQTT_USER` | `dev03` (igual al `DEVICE_ID`) |
| `MQTT_PASSWORD` | la clave de `dev03` (chat privado) |
| `BROKER_HOST` | `68.211.147.97` (siempre la IP: el certificado está hecho para ella, no para un nombre DNS) |
| `BROKER_PORT` | `8883` |
| `CA_CERT_PATH` | `/app/ca.crt` |
| `PUBLISH_INTERVAL` | `5` |

---

## Ruta B: Docker (recomendada)

Siete pasos. Anota la hora de inicio y fin de cada uno: la tabla de tiempos de [R5.8](evidencias/R5.8.md) usa esta misma numeración.

### Paso 1. Comprobar que el broker responde

Es el comando de los requisitos comunes. Debe dar `True`.

### Paso 2. Descargar el repositorio

```bash
git clone https://github.com/alejandrodomingueztorres/proyecto5-iot.git
cd proyecto5-iot
```

Si ya lo tienes: `git pull`. Comprueba que existe `device/ca.crt`.

### Paso 3. Construir la imagen

```bash
docker build -t p5-simulador device/
```

**Esperado:** termina sin errores. Si falla con un mensaje sobre `ca.crt`, falta ese archivo (el `Dockerfile` lo exige a propósito): haz `git pull`.

### Paso 4. Cargar la clave sin dejarla escrita en el comando

La clave se escribe una sola vez, **sin que se vea** y sin que quede en el historial.

Git Bash, Linux o macOS:

```bash
read -rsp "Clave MQTT de dev03: " MQTT_PASSWORD; echo
export MQTT_PASSWORD
```

PowerShell:

```powershell
$s = Read-Host "Clave MQTT de dev03" -AsSecureString
$env:MQTT_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
```

### Paso 5. Ejecutar el dispositivo

Observa que `MQTT_PASSWORD` va **sin valor**: Docker lo toma de tu terminal.

```bash
docker run -d --name dev03 --restart unless-stopped \
  -e DEVICE_ID=dev03 \
  -e MQTT_USER=dev03 \
  -e MQTT_PASSWORD \
  -e BROKER_HOST=68.211.147.97 \
  -e BROKER_PORT=8883 \
  -e CA_CERT_PATH=/app/ca.crt \
  -e PUBLISH_INTERVAL=5 \
  p5-simulador
```

En PowerShell, escribe el comando en una sola línea (sin las `\`).

### Paso 6. Comprobar en el log del dispositivo

```bash
docker logs dev03
```

**Esperado**, en este orden:

```
simulador v3 <hora UTC>
<hora> [dev03] conectado a 68.211.147.97:8883
<hora> [dev03] temperatura=24.1
<hora> [dev03] humedad=61.3
```

Y una pareja `temperatura`/`humedad` nueva cada 5 segundos.

### Paso 7. Comprobar que los datos llegaron al sistema

Con el dashboard de Grafana (Rol 4) abierto: `dev03` debe aparecer en la variable `device_id` y en los paneles con datos. **Sin tocar ningún archivo de `backend/`** (prueba P8.2).

Una comprobación directa en el broker, que hace Rol 2 o quien tenga acceso a la VM (solo lectura): `mosquitto_sub -t 'iot/dev03/#' -v` debe mostrar `iot/dev03/status online` y las lecturas.

### Al terminar

```bash
docker stop dev03
docker rm dev03
```

`docker stop` hace que el simulador publique `offline` antes de cerrar. Si en cambio cortas la red de golpe, el broker publica `offline` solo, a los ~45 s (Last Will, prueba P7.3).

---

## Ruta A: BalenaCloud + VirtualBox

Es la ruta con la que se crearon `dev01` y `dev02`. Aquí **cada dispositivo necesita su propia imagen de Balena**: reutilizar una descarga clona la identidad y el segundo dispositivo no aparece.

### Requisito adicional: acceso a la flota de Balena

La imagen se descarga de la flota `proyecto5-iot` del Rol 1. Quien siga esta ruta necesita su propia cuenta de Balena (gratuita) y que Rol 1 la agregue a la flota: dashboard → flota → pestaña **Members**, invitando por **correo**. No compartas nunca la contraseña de la cuenta, solo la invitación. *[Verificar: rol que necesita para descargar la imagen y si el plan gratuito lo permite.]*

### A1. Registrar el dispositivo en Balena

Flota → **Add device** → Tipo **Generic x86_64 (GPT)**, balenaOS **9.0.4** (Production), conexión **solo Ethernet**, Secure Boot apagado. Descargar el `.zip` (≈ 1.4 GB) y extraerlo en una **carpeta nueva** (queda un `.img` de ≈ 4 GB).

### A2. Convertir la imagen a disco de VirtualBox

Es un *flasher*: se convierte a un disco propio de ese dispositivo.

```cmd
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" convertfromraw "RUTA\archivo.img" "C:\p5-vms\dev03-instalador.vdi" --format VDI
```

Si da `VERR_FILE_NOT_FOUND`, usa la ruta completa del `.img` o entra a esa carpeta con `cd /d`.

### A3. Crear la máquina virtual

| Ajuste | Valor |
|---|---|
| Nombre | `p5-dev03` |
| Tipo | Other/Unknown (64-bit) |
| Firmware | EFI activado |
| CPU / RAM | 1 CPU, 2048 MB |
| Controlador | SATA/AHCI |
| Disco puerto 0 | disco **vacío** nuevo de 16 GB (destino) |
| Disco puerto 1 | `dev03-instalador.vdi` (solo durante la instalación) |
| Red | NAT |

El **disco vacío va primero** (puerto 0) y el instalador segundo; al revés, la VM se queda en el logo de VirtualBox. Después apaga el I/O APIC (la casilla está bloqueada en la interfaz):

```cmd
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "p5-dev03" --ioapic off --cpus 1
```

Comprueba antes de arrancar:

```cmd
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" showvminfo "p5-dev03" --machinereadable | findstr /i "vdi ioapic cpus firmware"
```

Debes ver firmware `EFI`, `ioapic="off"`, `cpus=1`, el disco propio en el puerto 0 y **el instalador de `dev03`** en el puerto 1 (no el de otro dispositivo).

### A4. Instalar balenaOS

1. Arranca la VM. El dispositivo aparece en el dashboard como *Post provisioning*.
2. Se graba en el disco y la VM se **apaga sola**.
3. Quita el instalador del puerto 1 y vuelve a arrancar. En 1–2 minutos pasa a **Online**.
4. Renómbralo a `dev03` en el dashboard.

### A5. Cargar las variables del dispositivo

Dashboard → `dev03` → **Device Variables**:

| Variable | Valor |
|---|---|
| `DEVICE_ID` | `dev03` |
| `MQTT_USER` | `dev03` |
| `MQTT_PASSWORD` | la clave de `dev03` (**pégala tú en el dashboard**) |

`BROKER_HOST`, `BROKER_PORT`, `CA_CERT_PATH` y `PUBLISH_INTERVAL` ya vienen de la **flota**. La clave de cada dispositivo debe pegarse en *su* dispositivo: si se cruzan, el broker rechaza la conexión por la ACL.

El dispositivo recibe automáticamente la release actual, sin que tengas que hacer `balena push`.

### A6. Comprobar

Panel de **Logs** del dispositivo (o `balena device logs <UUID>`): las mismas líneas del Paso 6 de la Ruta B. Luego, el Paso 7.

---

## Probar las alertas con el dispositivo nuevo (P8.4)

El simulador normal publica 20–29 °C y nunca supera el umbral de 30 °C. Para disparar la alerta de temperatura con `dev03` define la variable opcional `TEMP_FORZADA`:

- **Ruta B:** agrega `-e TEMP_FORZADA=32` al `docker run` (o recrea el contenedor con ella).
- **Ruta A:** Balena → `dev03` → *Device Variables* → `TEMP_FORZADA` = `32`.

El dispositivo publica entonces entre 31.5 y 32.5 °C. **Bórrala al terminar** para volver a lo normal. Para la alerta de offline, detén el contenedor o apaga la VM y espera más de 5 minutos.

## Solución de problemas

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `Test-NetConnection` da `False` | La VM de Azure está apagada | Pedir a Rol 2 que la prenda; no es un fallo del dispositivo |
| El log muestra `KeyError: 'MQTT_PASSWORD'` (o `'DEVICE_ID'`, `'BROKER_HOST'`) y el contenedor se reinicia | Falta una variable obligatoria | Cargar `DEVICE_ID`, `MQTT_PASSWORD` y `BROKER_HOST` |
| `NO_CERTIFICATE_OR_CRL_FOUND` | La imagen se construyó con un `ca.crt` vacío o ausente | `git pull` y reconstruir la imagen |
| `conexion rechazada: Not authorized` | Clave equivocada o cruzada con otro dispositivo | Pedir de nuevo la clave y comprobar que corresponde a este `device_id` |
| `esperando conexion con el broker...` sin fin | Broker apagado o sin salida a internet por el puerto 8883 | Comprobar el Paso 1 y la red |
| No aparece en el dashboard pero el log está bien | El dashboard aún no lee el dispositivo nuevo o la variable no se actualizó | Actualizar el dashboard y avisar a Rol 4 / Rol 3 |
| (Ruta A) Dos VM con la misma identidad | Se reutilizó la imagen de otro dispositivo | Descargar una imagen nueva por dispositivo |
| (Ruta A) La VM se queda en el logo | Instalador en el puerto 0 o I/O APIC activo | Disco vacío primero; `--ioapic off --cpus 1` |

## Qué no se toca (R5.8, prueba P8.2)

Para que cuente como "sin modificar la infraestructura", incorporar un dispositivo **no** cambia nada de `backend/`: ni `docker-compose.yml`, ni Mosquitto, ni Node-RED, ni Grafana. Node-RED acepta cualquier `device_id` nuevo siempre que publique los sensores del contrato (`temperatura` y `humedad`), y el dashboard de Grafana lo lista por la variable `device_id` (prueba P5.3 de Rol 4). Lo único que se hace fuera del dispositivo es crear su usuario MQTT, que es configuración en ejecución del broker (no se sube al repositorio).

## Seguridad

- Ninguna clave en el repositorio, en commits, en capturas ni en el chat general.
- Revisa las capturas antes de subirlas: sin claves ni tokens, y sin la IP pública de tu equipo.
- El archivo `device/ca.crt` es público (es el certificado de la CA); la clave privada del broker **nunca** sale de la VM de Azure.
