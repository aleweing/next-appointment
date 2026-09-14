# Especificación de Funcionalidad: Fin de recurrencia

**Feature Branch**: `002-recurrence-end`
**Creado**: 2026-09-14
**Estado**: Borrador
**Input**: Permitir que una recurrencia tenga un límite (fecha de fin o número de repeticiones), en vez de repetir indefinidamente

## Contexto

Hoy, un evento recurrente (`recurrenceUnit` + `recurrenceInterval`) repite para siempre: `Countdown.getTargetDate()` siempre avanza a la próxima ocurrencia sin ningún tope. Esta especificación añade la posibilidad de que el usuario limite una recurrencia, de modo que deje de generar próximas ocurrencias al alcanzar el límite.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Definir un número máximo de repeticiones (Prioridad: P1)

Como usuario, quiero indicar que una cita recurrente se repita solo N veces, para que deje de aparecer automáticamente cuando ya no aplica (ej. "cada 7 días, 4 veces").

**Prueba independiente**: Crear una recurrencia semanal con límite de 3 repeticiones y verificar que, tras la 3ª ocurrencia, el evento no vuelve a generar una próxima fecha.

**Escenarios de aceptación**:
1. **Dado** un evento recurrente con límite de N repeticiones, **cuando** se alcanza la ocurrencia N, **entonces** esa es la última y no se calcula una siguiente.
2. **Dado** un evento recurrente con límite de N repeticiones, **cuando** el usuario edita el límite a un número mayor, **entonces** la serie vuelve a generar próximas ocurrencias.
3. **Dado** un evento que ya agotó sus repeticiones, **cuando** el usuario lo ve en la lista, **entonces** se distingue visualmente de uno recurrente activo (ej. ya no muestra el badge 🔁, o muestra "finalizado").

### Historia de usuario 2 - Definir una fecha de fin (Prioridad: P1)

Como usuario, quiero indicar una fecha límite hasta la cual se repite una cita, para eventos con un final natural conocido (ej. "cada 7 días hasta el 30 de noviembre").

**Prueba independiente**: Crear una recurrencia semanal con fecha de fin y verificar que ninguna ocurrencia calculada supera esa fecha.

**Escenarios de aceptación**:
1. **Dado** un evento recurrente con fecha de fin, **cuando** la próxima ocurrencia calculada superaría esa fecha, **entonces** el evento se trata como finalizado (no se genera esa ocurrencia).
2. **Dado** un evento recurrente con fecha de fin igual a una fecha de ocurrencia exacta, **cuando** se alcanza esa fecha, **entonces** esa ocurrencia sí cuenta como la última válida.
3. **Dado** que el usuario no define fecha de fin ni número de repeticiones, **cuando** guarda el evento, **entonces** se comporta como hoy (recurrencia indefinida) — este límite es opcional, no obligatorio.

### Historia de usuario 3 - Qué pasa cuando la serie termina (Prioridad: P2)

Como usuario, quiero saber claramente cuándo una serie recurrente ha llegado a su fin, para no esperar una próxima ocurrencia que no va a llegar.

**Escenarios de aceptación**:
1. **Dado** una serie recurrente finalizada, **cuando** el usuario abre el detalle del evento, **entonces** ve un indicador de "recurrencia finalizada" en vez del countdown normal.
2. **Dado** una serie recurrente finalizada, **cuando** el usuario la edita, **entonces** puede extender el límite o quitarlo para reactivarla.

### Casos límite

- ¿Qué pasa si el usuario define fecha de fin Y número de repeticiones a la vez? (¿gana la que se cumpla primero, o es mutuamente excluyente?)
- ¿Qué pasa con un evento recurrente finalizado: se archiva automáticamente, o queda visible como "finalizado" hasta que el usuario decida?
- ¿Cómo interactúa esto con la corrección ya aplicada al bug de "recordatorios recurrentes perdidos" — el chequeo de ocurrencias pasadas debe respetar también el límite superior?
- Eventos ya existentes sin este campo: deben interpretarse como "sin límite" (retrocompatibilidad), igual que hoy.

## Requisitos *(obligatorio)*

- **FR-001**: El sistema DEBE permitir configurar, opcionalmente, un número máximo de repeticiones para un evento recurrente.
- **FR-002**: El sistema DEBE permitir configurar, opcionalmente, una fecha de fin para un evento recurrente.
- **FR-003**: El sistema DEBE dejar de calcular nuevas ocurrencias una vez alcanzado el límite (por conteo o por fecha), sin borrar el evento.
- **FR-004**: El sistema DEBE mostrar un estado visual distinto para un evento recurrente cuya serie ha finalizado.
- **FR-005**: El sistema DEBE permitir editar o quitar el límite de una serie ya finalizada para reactivarla.
- **FR-006**: Los eventos recurrentes sin límite configurado DEBEN seguir comportándose exactamente igual que hoy (sin límite).

### Entidades clave

- **Cita** (extendida): agrega `recurrenceEndDate` (fecha, opcional) y/o `recurrenceMaxCount` (número, opcional) y un contador o cálculo derivado de ocurrencias generadas hasta ahora.

## Criterios de éxito *(obligatorio)*

- **SC-001**: Un evento con límite de N repeticiones nunca muestra una ocurrencia N+1 en ningún punto de la UI.
- **SC-002**: Un evento con fecha de fin nunca muestra una ocurrencia posterior a esa fecha.
- **SC-003**: El 100% de los eventos recurrentes creados antes de esta funcionalidad siguen repitiendo indefinidamente sin cambios de comportamiento.

## Aclaraciones pendientes

- Fecha de fin + número de repeticiones simultáneos: ¿se permite o son mutuamente excluyentes en la UI?
- Al finalizar la serie, ¿se archiva automáticamente (como los eventos no recurrentes pasados) o requiere acción manual del usuario?

## Supuestos

- Por defecto, al crear una recurrencia nueva, el límite queda desactivado (comportamiento actual sin cambios salvo que el usuario lo configure).
