# Especificación de Funcionalidad: Historial de ocurrencias recurrentes

**Feature Branch**: `003-recurrence-history`
**Creado**: 2026-09-16
**Estado**: Borrador
**Input**: Vista de historial de ocurrencias pasadas de un evento recurrente

## Contexto

Hoy, un evento recurrente solo muestra su **próxima** ocurrencia — no queda ningún rastro visible de las veces que ya se cumplió. Con la feature 002 (fin de recurrencia) ya existe la maquinaria para calcular ocurrencias de forma derivada, sin guardar contadores (`Countdown.getAnchorDate()`, `Countdown.advanceByRecurrence()`, `Countdown.getLastOccurrence()`). Esta especificación reutiliza esa misma lógica para construir, on-demand, la lista de fechas pasadas de una serie.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Ver las ocurrencias pasadas de un evento recurrente (Prioridad: P1)

Como usuario, quiero abrir un evento recurrente y ver una lista de las fechas en que ya se cumplió, para tener una noción de su historial sin tener que recordarlo de memoria.

**Por qué esta prioridad**: Es el valor central de la feature — sin esto no hay nada que mostrar.

**Prueba independiente**: Crear un evento semanal con ancla hace 5 semanas y verificar que el historial muestra exactamente 5 fechas, la más reciente primero.

**Escenarios de aceptación**:
1. **Dado** un evento recurrente cuya primera ocurrencia ya pasó, **cuando** el usuario abre su historial, **entonces** ve la lista de fechas en que ya ocurrió, ordenadas de la más reciente a la más antigua.
2. **Dado** un evento recurrente cuya primera ocurrencia todavía no llegó, **cuando** el usuario abre su historial, **entonces** ve un estado vacío indicando que todavía no tuvo ninguna ocurrencia.
3. **Dado** un evento no recurrente, **cuando** el usuario mira la card, **entonces** no existe ninguna opción de "ver historial" (no aplica).

### Historia de usuario 2 - Historial de una serie ya finalizada (Prioridad: P1)

Como usuario, quiero poder ver el historial completo de una serie que ya llegó a su límite (feature 002) y fue archivada, para revisar cuántas veces ocurrió en total.

**Prueba independiente**: Archivar una serie con 3 repeticiones agotadas y verificar que su historial muestra exactamente esas 3 fechas.

**Escenarios de aceptación**:
1. **Dado** una serie recurrente archivada por haber alcanzado su límite, **cuando** el usuario ve su historial (desde la vista de archivados), **entonces** ve todas las ocurrencias hasta la última válida, ninguna posterior.
2. **Dado** una serie sin límite configurado, **cuando** el usuario ve su historial, **entonces** ve todas las ocurrencias hasta hoy (no hay "última" predefinida).

### Historia de usuario 3 - Series muy largas o muy frecuentes (Prioridad: P2)

Como usuario, quiero que abrir el historial de un evento diario con años de antigüedad no trabe la app, para poder usarlo también en series de alta frecuencia.

**Prueba independiente**: Crear un evento diario con ancla de 3 años atrás y verificar que el historial se abre sin demora perceptible, mostrando un aviso de que hay más ocurrencias de las mostradas.

**Escenarios de aceptación**:
1. **Dado** un evento con más ocurrencias pasadas que el límite de visualización, **cuando** el usuario abre el historial, **entonces** ve las más recientes hasta ese límite y un indicador de que hay más.
2. **Dado** ese mismo caso, **cuando** el usuario pide ver más, **entonces** la lista se amplía sin recargar la página ni congelar la interfaz.

### Casos límite

- Evento recurrente creado hoy mismo, cuya única ocurrencia es "ahora mismo" (diff casi cero): ¿cuenta como ya ocurrida o como próxima? (ver Aclaraciones)
- Evento mensual con ancla el día 31: el historial debe reflejar las fechas reales que calcula `advanceByRecurrence` (que se desplaza al mes siguiente en meses cortos), no fechas "idealizadas" al día 31.
- Evento importado desde un backup antiguo sin fecha de fin ni máximo: se comporta como serie indefinida (historial hasta hoy).

## Requisitos *(obligatorio)*

- **FR-001**: El sistema DEBE ofrecer una forma de abrir el historial de ocurrencias desde cualquier evento recurrente (activo o archivado).
- **FR-002**: El sistema NO DEBE ofrecer esta opción para eventos no recurrentes.
- **FR-003**: El historial DEBE calcularse siempre de forma derivada (a partir de la fecha ancla y la recurrencia), nunca leyendo ni escribiendo un registro guardado de ocurrencias pasadas.
- **FR-004**: El historial DEBE mostrar las fechas ordenadas de la más reciente a la más antigua.
- **FR-005**: Para una serie con límite ya alcanzado (feature 002), el historial DEBE detenerse en la última ocurrencia válida, sin mostrar fechas posteriores.
- **FR-006**: Para una serie sin límite, el historial DEBE mostrar todas las ocurrencias hasta el momento actual.
- **FR-007**: El sistema DEBE limitar cuántas ocurrencias calcula y renderiza de una vez, con una forma de pedir más sin recargar la página, para no bloquear la interfaz en series antiguas o muy frecuentes.
- **FR-008**: Si un evento recurrente no tuvo ninguna ocurrencia pasada todavía, el sistema DEBE mostrar un estado vacío que lo indique claramente.

## Criterios de éxito *(obligatorio)*

- **SC-001**: Abrir el historial de un evento diario con 30 días de antigüedad muestra las 30 fechas correctas en menos de 1 segundo.
- **SC-002**: Abrir el historial de un evento con ancla futura muestra el estado vacío, nunca un error ni una lista con fechas futuras.
- **SC-003**: Abrir el historial de un evento diario con 3+ años de antigüedad no congela la interfaz ni cuelga el navegador.
- **SC-004**: El historial de una serie archivada por límite (feature 002) nunca muestra una fecha posterior a su última ocurrencia válida.

## Decisiones tomadas (sin frenar a preguntar, dado que se pidió spec+plan+tasks juntos)

- **Corte pasado/próximo**: una ocurrencia cuenta como "pasada" apenas su fecha/hora es `<= ahora`, sin margen especial — el mismo criterio que ya usa `Countdown.diffMs`/`hasElapsed` en el resto de la app. Si esto no se siente natural en el uso real (ej. la ocurrencia de "ahora mismo" debería seguir contando como próxima unos segundos más), es un ajuste de una sola línea en `getOccurrenceHistory` — se puede revisar tras la primera prueba en el iPhone.
- **Tamaño de página**: se muestran 20 ocurrencias iniciales, con un botón "Ver más" que añade 20 más cada vez, sin límite total salvo el techo de cómputo (ver plan.md). 20 es coherente con el resto de la UI, pensada para pantallas de iPhone.

## Supuestos

- No se requiere ninguna acción sobre una ocurrencia individual del historial (no se puede "editar" ni "borrar" una fecha puntual del pasado) — es una vista de solo lectura.
- El historial no necesita persistirse entre sesiones ni exportarse; siempre se recalcula al abrirlo.
