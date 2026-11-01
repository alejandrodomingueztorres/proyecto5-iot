# Evidencia — Escalado: impacto de agregar dispositivos

| Campo | Valor |
|---|---|
| Objetivo del enunciado | Escalar el sistema agregando dispositivos y medir el impacto en la infraestructura. |
| Responsable | Rol 5 · Rol 2 |
| Estado | ⬜ Pendiente |
| Pruebas definidas en | [requerimientos.md](../requerimientos.md) |
| Plantilla | [PLANTILLA.md](PLANTILLA.md) |
| Capturas | `docs/evidencias/img/escalado/` |

## Resumen

| ID | Prueba | Veredicto | Fecha | Revisado por |
|---|---|---|---|---|
| PE.1 | Línea base con 2 dispositivos | ⬜ | | |
| PE.2 | 10 simuladores extra | ⬜ | | |
| PE.3 | 50 simuladores extra | ⬜ | | |
| PE.4 | Pérdida de mensajes | ⬜ | | |

Leyenda: ⬜ Pendiente · ✅ Pasa · ❌ Falla · 🟨 Parcial

Condiciones de la prueba:

| Dato | Valor |
|---|---|
| Tamaño de la VM de Azure | |
| Duración de cada escenario | 5 minutos |
| Usuario MQTT temporal | Creado por Rol 2 el ____ y eliminado el ____ |
| Máquina que generó la carga | |

---

## PE.1
<!-- Pegar aquí el bloque de la plantilla llenado -->

## PE.2
<!-- Pegar aquí el bloque de la plantilla llenado -->

## PE.3
<!-- Pegar aquí el bloque de la plantilla llenado -->

## PE.4
<!-- Pegar aquí el bloque de la plantilla llenado -->

---

## Resultados consolidados

| Escenario | Dispositivos | CPU backend (%) | Memoria backend (MiB) | Contenedor más cargado | Puntos esperados | Puntos recibidos | Pérdida (%) | ¿Dashboard fluido? |
|---|---|---|---|---|---|---|---|---|
| Base | 2 | | | | 240 | | | |
| +10 | 12 | | | | 1 440 | | | |
| +50 | 52 | | | | 6 240 | | | |

Puntos esperados = dispositivos × 2 sensores × 60 mensajes (5 minutos, un mensaje cada 5 s).
Pérdida (%) = (esperados − recibidos) ÷ esperados × 100.

**Conclusión:** <qué recurso crece primero, hasta dónde aguanta la VM y qué se haría para escalar más>