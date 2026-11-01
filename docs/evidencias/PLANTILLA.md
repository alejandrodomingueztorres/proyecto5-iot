# Plantilla de evidencia

Cada vez que ejecutes una prueba de `docs/requerimientos.md`, copia el bloque de abajo
en la ficha del requerimiento (`docs/evidencias/R5.x.md`), debajo del encabezado de esa prueba, y llénalo.

## Reglas

1. **Un bloque por intento.** Si repites una prueba, agrega un intento nuevo debajo, **sin borrar el anterior**. Los fallos también son evidencia del proceso.
2. **Hora** de Bogotá, formato `AAAA-MM-DD HH:MM`. En pruebas de tiempo (alertas) anota también los segundos.
3. **Comandos copiados exactos**, con las claves reemplazadas por variables (`$CLAVE_DEV01`). Nunca una clave real.
4. **Capturas** en `docs/evidencias/img/R5.x/` con el nombre `P<n.m>-<descripcion>-<AAAA-MM-DD>.png`.
   Ejemplo: `img/R5.2/P2.7-wireshark-tls-2026-11-04.png`. Antes de subirla, revisa que no muestre tokens, claves ni el chat ID de Telegram.
5. **Veredicto:** `✅ Pasa`, `❌ Falla` o `🟨 Parcial`. Si no pasa, en *Observaciones* va qué se hará.
6. **Revisado por:** otra persona del grupo confirma que la evidencia es suficiente. Nadie revisa su propia evidencia.
7. Después de llenar el bloque, actualiza la **tabla resumen** al inicio de la ficha.

---

## Bloque para copiar

~~~~markdown
### P<n.m> — <nombre corto de la prueba> · Intento <k>

| Campo | Valor |
|---|---|
| Requerimiento | R5.x |
| Ejecutada por | <nombre> (Rol <n>) |
| Fecha y hora | AAAA-MM-DD HH:MM |
| Entorno | VM Azure `<nombre>` · commit `<hash corto>` · <versiones relevantes> |
| Precondiciones | <qué tenía que estar funcionando antes> |

**Qué se probó:** <una frase, en términos del criterio de aceptación>

**Cómo (pasos y comandos exactos):**

1. …
2. …

```bash
<comandos>
```

**Resultado esperado:** <copiado de docs/requerimientos.md>

**Resultado obtenido:**

```
<salida del comando o log, recortada a lo esencial>
```

**Mediciones:** <tiempos, conteos o porcentajes; si no aplica: "No aplica">

**Captura:**

![<descripción>](img/R5.x/P<n.m>-<descripcion>-<AAAA-MM-DD>.png)

**Veredicto:** ✅ Pasa / ❌ Falla / 🟨 Parcial

**Observaciones:** <qué falló, la causa y qué se cambió; o "Ninguna">

**Revisado por:** <nombre>, AAAA-MM-DD
~~~~

---

## Ejemplo llenado

### P2.3 — Conexión con clave incorrecta · Intento 1

| Campo | Valor |
|---|---|
| Requerimiento | R5.2 |
| Ejecutada por | Nombre Apellido (Rol 2) |
| Fecha y hora | 2026-11-04 19:12 |
| Entorno | VM Azure `vm-iot-p5` · commit `a1b2c3d` · Mosquitto 2.0 |
| Precondiciones | Broker con TLS en 8883 y `allow_anonymous false` |

**Qué se probó:** Que el broker rechaza a un cliente que usa TLS pero con una clave incorrecta.

**Cómo (pasos y comandos exactos):**

```bash
mosquitto_pub -h "$BROKER_HOST" -p 8883 --cafile ca.crt -u dev01 -P clave-mala -t iot/dev01/temperatura -m prueba
```

**Resultado esperado:** Conexión rechazada.

**Resultado obtenido:**

```
Connection error: Connection Refused: not authorised.
Error: The connection was refused.
```

**Mediciones:** No aplica.

**Captura:** `img/R5.2/P2.3-clave-incorrecta-2026-11-04.png`

**Veredicto:** ✅ Pasa

**Observaciones:** Ninguna.

**Revisado por:** Alejandro Domínguez Torres, 2026-10-31

> Ejemplo ilustrativo: en la prueba real se pega la salida del broker de Azure.