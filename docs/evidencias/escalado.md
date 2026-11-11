# Evidencia — Escalado: impacto de agregar dispositivos

| Campo | Valor |
|---|---|
| Objetivo del enunciado | Escalar el sistema agregando dispositivos y medir el impacto en la infraestructura. |
| Responsable | Rol 5 · Rol 2 |
| Estado | 🟨 En progreso (consumo y pérdida medidos con 2, 10 y 50 simuladores; falta la captura del dashboard bajo carga y la revisión del Rol 5) |
| Pruebas definidas en | [requerimientos.md](../requerimientos.md) |
| Plantilla | [PLANTILLA.md](PLANTILLA.md) |
| Capturas | `docs/evidencias/img/escalado/` |

## Resumen

| ID | Prueba | Veredicto | Fecha | Revisado por |
|---|---|---|---|---|
| PE.1 | Línea base con 2 dispositivos | ✅ (2 simuladores en lugar de dev01 y dev02) | 2026-11-11 | |
| PE.2 | 10 simuladores extra | 🟨 (falta la captura del dashboard) | 2026-11-11 | |
| PE.3 | 50 simuladores extra | 🟨 (falta la captura del dashboard) | 2026-11-11 | |
| PE.4 | Pérdida de mensajes | ✅ | 2026-11-11 | |

Leyenda: ⬜ Pendiente · ✅ Pasa · ❌ Falla · 🟨 Parcial

Condiciones de la prueba:

| Dato | Valor |
|---|---|
| Tamaño de la VM de Azure | Standard_B2als_v2 (2 vCPU, 4 GiB RAM, 30 GB SSD), Chile Central, Ubuntu 24.04 |
| Duración de cada escenario | 5 minutos |
| Usuario MQTT temporal | `escalado`, creado y eliminado por el script en cada corrida el 2026-11-11 (14:29–14:49) |
| Máquina que generó la carga | La misma VM: contenedores del simulador de `device/` en la red de Compose |

---

## Cómo se corrió (común a PE.1–PE.4)

| Campo | Valor |
|---|---|
| Ejecutada por | Santiago Osorio (Rol 2) |
| Fecha y hora | 2026-11-11, de 14:29 a 14:49 (19:29–19:49 UTC) |
| Entorno | VM `vm-iot-backend` · rama `rol2-infraestructura` en `3b9cd70` (= `main` + arreglos de `escalado.sh`) · Mosquitto 2.0.20, Node-RED 4.0 con el flujo del Rol 3, InfluxDB 2.7, Grafana 11.3.0 |
| Precondiciones | Backend arriba; flujo de Node-RED guardando en `lecturas`. dev01 y dev02 (VMs de Balena del Rol 1) **apagados** ese día |

En la VM, desde `~/proyecto5-iot/backend`, los tres escenarios seguidos (5 minutos cada uno):

```bash
sudo bash escalado/escalado.sh 2 5     # PE.1: línea base (2 simuladores en lugar de dev01 y dev02)
sudo bash escalado/escalado.sh 10 5    # PE.2
sudo bash escalado/escalado.sh 50 5    # PE.3
```

Cada corrida crea el usuario MQTT temporal `escalado`, lanza N contenedores del simulador de
`device/` (`sim001`, `sim002`, …, un mensaje por sensor cada 5 s), registra `docker stats` cada
15 s, cuenta lo que llega al broker (suscriptor con el usuario `nodered`) y lo que Node-RED guardó en
InfluxDB en la misma ventana de 300 s (PE.4). Al terminar borra los simuladores, sus puntos en
InfluxDB y el usuario temporal, y restaura `acl.conf`. Al mismo tiempo, un ciclo midió cada 15 s el
tiempo de respuesta de Grafana (`/api/health`), InfluxDB (`/health`) y Node-RED (`/`).

Archivos completos en [mediciones/](mediciones/): `escalado-N{2,10,50}-2026-11-11-resumen.txt`,
`-docker-stats.csv` y `-latencia.txt`.

## PE.1

### PE.1 — Línea base · Intento 1

**Qué se probó:** Consumo del backend con 2 dispositivos publicando.

**Resultado obtenido** (`escalado-N2-2026-11-11-resumen.txt`):

```
contenedor              CPU prom%   CPU max% Mem prom MiB  Mem max MiB
backend-grafana-1             0.1        0.2          241          241
backend-influxdb-1            0.1        0.4          236          256
backend-mosquitto-1           0.1        0.1            9            9
backend-nodered-1             0.1        0.5          141          142
simuladores (total)           0.1        0.2           26           26
Simuladores: esperados 240 · llegaron al broker 240 · guardados en InfluxDB 240
```

**Veredicto:** ✅ Pasa

**Observaciones:** dev01 y dev02 estaban apagados, así que la línea base se hizo con 2 simuladores
con el mismo código y el mismo intervalo que los de Balena (`device/simulador.py`). La carga es la
misma; lo único que cambia es que llegan por la red interna de Docker y no por Internet.

## PE.2

### PE.2 — 10 simuladores · Intento 1

**Resultado obtenido** (`escalado-N10-2026-11-11-resumen.txt`):

```
contenedor              CPU prom%   CPU max% Mem prom MiB  Mem max MiB
backend-grafana-1             0.1        0.1          241          241
backend-influxdb-1            0.4        0.8          240          242
backend-mosquitto-1           0.1        0.3            9            9
backend-nodered-1             0.4        0.7          141          142
simuladores (total)           0.3        0.5          129          130
Simuladores: esperados 1200 · llegaron al broker 1200 · guardados en InfluxDB 1200
Respuesta: Grafana prom 0,002 s (máx 0,012 s) · InfluxDB 0,001 s · Node-RED 0,001 s
```

**Veredicto:** 🟨 Parcial: consumo registrado y servicios respondiendo; falta la captura del dashboard.

**Observaciones:** El dashboard de R5.5 todavía no está montado en el Grafana de la VM, así que no
hay captura con datos. La respuesta de Grafana se midió por su API.

## PE.3

### PE.3 — 50 simuladores · Intento 1

**Resultado obtenido** (`escalado-N50-2026-11-11-resumen.txt`):

```
contenedor              CPU prom%   CPU max% Mem prom MiB  Mem max MiB
backend-grafana-1             0.1        0.2          241          241
backend-influxdb-1            1.7        2.0          250          250
backend-mosquitto-1           0.4        0.5           10           10
backend-nodered-1             2.3        9.0          152          154
simuladores (total)           1.4        1.6          645          646
Simuladores: esperados 6000 · llegaron al broker 6000 · guardados en InfluxDB 6000
Respuesta: Grafana prom 0,001 s · InfluxDB 0,001 s · Node-RED prom 0,001 s (máx 0,004 s)
```

**Veredicto:** 🟨 Parcial: consumo registrado, nada se degradó; falta la captura del dashboard.

**Observaciones:** Con 50 simuladores, Node-RED tuvo picos de 9 % de CPU y InfluxDB subió a 1,7 %
de promedio. Ningún servicio se degradó. La VM quedó con unos 3 GiB de RAM disponibles, y la mayor
parte de la memoria nueva la usan los propios simuladores (≈ 13 MiB cada uno), no el backend.

## PE.4

### PE.4 — Pérdida de mensajes · Intento 1

| Escenario | Esperados | Llegaron al broker | Guardados en InfluxDB | Pérdida |
|---|---|---|---|---|
| 2 simuladores | 240 | 240 | 240 | 0,0 % |
| 10 simuladores | 1 200 | 1 200 | 1 200 | 0,0 % |
| 50 simuladores | 6 000 | 6 000 | 6 000 | 0,0 % |

Esperados = simuladores × 2 sensores × 60 mensajes (300 s, uno cada 5 s).

**Veredicto:** ✅ Pasa

**Observaciones:**
- Hubo dos corridas previas el mismo día que no cuentan, porque fallaban por errores del script, no
  del sistema. En la primera, el conteo de InfluxDB daba siempre 0 porque la salida de `influx query`
  deja vacía la columna `result` (commit `8a09ff9`). En la segunda, InfluxDB contaba unos segundos de
  más, porque la ventana se cerraba después del último `docker stats`, y daba pérdida negativa
  (commit `3b9cd70`). En esas dos corridas el broker igual recibió 99,8–100 % de los mensajes.
- Como el QoS es 1, un mensaje repetido se guarda en InfluxDB con la misma hora (`ts`) y la misma
  serie, así que reemplaza al anterior y no infla el conteo.

---

## Resultados consolidados

| Escenario | Dispositivos | CPU backend (%) | Memoria backend (MiB) | Contenedor más cargado | Puntos esperados | Puntos recibidos | Pérdida (%) | ¿Dashboard fluido? |
|---|---|---|---|---|---|---|---|---|
| Base | 2 | 0,4 | 627 | Grafana (memoria) | 240 | 240 | 0,0 | Sin captura; API responde en 0,001 s |
| 10 | 10 | 1,0 | 631 | InfluxDB y Node-RED (CPU 0,4 %) | 1 200 | 1 200 | 0,0 | Sin captura; API responde en 0,002 s |
| 50 | 50 | 4,5 | 653 | Node-RED (CPU 2,3 %, picos de 9 %) | 6 000 | 6 000 | 0,0 | Sin captura; API responde en 0,001 s |

Como dev01 y dev02 estaban apagados, cada escenario tiene solo los simuladores, no
"2 + N". CPU y memoria del backend = suma de los promedios de Mosquitto, Node-RED, InfluxDB y
Grafana (`docker stats`, el 100 % equivale a un vCPU), sin contar los simuladores.
Puntos esperados = dispositivos × 2 sensores × 60 mensajes (5 minutos, un mensaje cada 5 s).
Pérdida (%) = (esperados − recibidos) ÷ esperados × 100.

**Conclusión:** Lo que más crece con la carga es la CPU de Node-RED y de InfluxDB: con 25 veces
más dispositivos (2 → 50), el backend pasa de 0,4 % a 4,5 % de un vCPU, con picos de Node-RED de
9 %. Mosquitto casi no cambia (0,1 → 0,4 % y 9 → 10 MiB), y la memoria del backend sube solo 26 MiB.
Con 50 dispositivos (10 mensajes por segundo) no se perdió ningún mensaje y la VM quedó con unos
3 GiB de RAM libres, así que la B2als_v2 aguanta con mucha holgura la carga del proyecto. Por la
tendencia (CPU casi lineal con los mensajes por segundo), el primer límite sería la CPU de
Node-RED, varios cientos de dispositivos más arriba. Para escalar más se haría, en orden: subir el
intervalo o agrupar lecturas en lotes, escribir en InfluxDB por lotes desde Node-RED, darle más
vCPU a la VM, y por último separar InfluxDB en otra VM o servicio administrado.