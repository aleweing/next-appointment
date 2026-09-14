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
3. **Dado** un evento que ya agotó sus repeticiones, **cuando** se alcanza el límite, **entonces** el evento se archiva automáticamente y deja de aparecer en la lista de activos.

### Historia de usuario 2 - Definir una fecha de fin (Prioridad: P1)

Como usuario, quiero indicar una fecha límite hasta la cual se repite una cita, para eventos con un final natural conocido (ej. "cada 7 días hasta el 30 de noviembre").

**Prueba independiente**: Crear una recurrencia semanal con fecha de fin y verificar que ninguna ocurrencia calculada supera esa fecha.

**Escenarios de aceptación**:
1. **Dado** un evento recurrente con fecha de fin, **cuando** la próxima ocurrencia calculada superaría esa fecha, **entonces** el evento se trata como finalizado (no se genera esa ocurrencia).
2. **Dado** un evento recurrente con fecha de fin igual a una fecha de ocurrencia exacta, **cuando** se alcanza esa fecha, **entonces** esa ocurrencia sí cuenta como la última válida.
3. **Dado** que el usuario no define fecha de fin ni número de repeticiones, **cuando** guarda el evento, **entonces** se comporta como hoy (recurrencia indefinida) — este límite es opcional, no obligatorio.

### Historia de usuario 3 - Encontrar y reactivar una serie ya finalizada (Prioridad: P2)

Como usuario, quiero poder encontrar una serie recurrente que ya se archivó por haber llegado a su límite, y reactivarla si lo necesito, del mismo modo en que hoy puedo desarchivar cualquier evento pasado.

**Escenarios de aceptación**:
1. **Dado** una serie recurrente finalizada y archivada, **cuando** el usuario la busca, **entonces** la encuentra en la vista de archivados igual que cualquier otro evento vencido.
2. **Dado** una serie recurrente archivada por haber llegado a su límite, **cuando** el usuario la edita y extiende o quita el límite, **entonces** vuelve a estar activa y a generar próximas ocurrencias.

### Casos límite

- ¿Cómo interactúa esto con la corrección ya aplicada al bug de "recordatorios recurrentes perdidos" — el chequeo de ocurrencias pasadas debe respetar también el límite superior?
- Eventos ya existentes sin este campo: deben interpretarse como "sin límite" (retrocompatibilidad), igual que hoy.

## Requisitos *(obligatorio)*

- **FR-001**: El sistema DEBE permitir configurar, opcionalmente, un número máximo de repeticiones para un evento recurrente.
- **FR-002**: El sistema DEBE permitir configurar, opcionalmente, una fecha de fin para un evento recurrente.
- **FR-003**: El sistema DEBE dejar de calcular nuevas ocurrencias una vez alcanzado el límite (por conteo o por fecha), sin borrar el evento.
- **FR-004**: El sistema DEBE archivar automáticamente un evento recurrente en cuanto su serie alcanza el límite configurado (ver FR-008).
- **FR-005**: El sistema DEBE permitir encontrar una serie finalizada en la vista de archivados y reactivarla editando o quitando su límite.
- **FR-006**: Los eventos recurrentes sin límite configurado DEBEN seguir comportándose exactamente igual que hoy (sin límite).

### Entidades clave

- **Cita** (extendida): agrega `recurrenceEndDate` (fecha, opcional) y/o `recurrenceMaxCount` (número, opcional) y un contador o cálculo derivado de ocurrencias generadas hasta ahora.

## Criterios de éxito *(obligatorio)*

- **SC-001**: Un evento con límite de N repeticiones nunca muestra una ocurrencia N+1 en ningún punto de la UI.
- **SC-002**: Un evento con fecha de fin nunca muestra una ocurrencia posterior a esa fecha.
- **SC-003**: El 100% de los eventos recurrentes creados antes de esta funcionalidad siguen repitiendo indefinidamente sin cambios de comportamiento.

## Aclaraciones resueltas

- **Fecha de fin + número de repeticiones simultáneos**: se permiten ambos a la vez; gana el que se cumpla primero. Ej.: fecha de fin en 3 meses + límite de 4 repeticiones → si las 4 repeticiones se completan antes de esa fecha, la serie termina ahí; si la fecha llega antes de la 4ª repetición, termina en esa fecha.
- **Fin de la serie**: al alcanzar el límite (por fecha o por conteo), el evento se archiva automáticamente, con el mismo mecanismo de `runArchiveMaintenance()` que ya archiva eventos no recurrentes vencidos.

## Requisitos adicionales derivados de las aclaraciones

- **FR-007**: Si un evento tiene ambos límites configurados (fecha de fin y número de repeticiones), el sistema DEBE finalizar la serie en cuanto se cumpla cualquiera de los dos, lo que ocurra primero.
- **FR-008**: Al finalizar una serie recurrente (por cualquiera de los dos límites), el sistema DEBE archivar el evento automáticamente, de la misma forma que archiva hoy los eventos no recurrentes vencidos.

## Supuestos

- Por defecto, al crear una recurrencia nueva, el límite queda desactivado (comportamiento actual sin cambios salvo que el usuario lo configure).
- El archivado automático de una serie finalizada reutiliza la lógica de archivado ya existente en la app, en vez de crear un estado nuevo paralelo.
