# Plan de Implementación: Fin de recurrencia

**Feature Branch**: `002-recurrence-end`
**Spec relacionada**: `spec.md` (misma carpeta)
**Estado**: Borrador

## Stack

Vanilla JS, sin build step, GitHub Pages. Persistencia en `localStorage` vía `js/storage.js`. Sin cambios de infraestructura para esta funcionalidad — todo el trabajo es lógica de cliente.

## Modelo de datos

Extender el objeto evento (definido/gestionado en `js/storage.js` y `js/app.js`) con dos campos opcionales, ambos `null` por defecto (retrocompatible con eventos existentes):

```js
{
  // ...campos existentes (recurrenceUnit, recurrenceInterval, etc.)
  recurrenceEndDate: null,     // string 'YYYY-MM-DD' o null
  recurrenceMaxCount: null,    // entero o null
  recurrenceOccurrenceCount: 0 // contador de ocurrencias ya "vividas", derivado
}
```

`recurrenceOccurrenceCount` se necesita porque hoy no existe ningún registro de cuántas veces ya ocurrió un evento recurrente — `Countdown.getTargetDate()` solo calcula "la próxima", sin memoria de las pasadas. Se incrementa cada vez que una ocurrencia se da por cumplida (ver más abajo).

## Cambios por archivo

### `js/countdown.js`

- **`getRecurrence(event)`**: sin cambios en la firma; ahora también debe devolver `endDate` y `maxCount` normalizados, para que el resto del código no tenga que leerlos directo del evento:
  ```js
  return { unit, interval, endDate: event.recurrenceEndDate || null, maxCount: event.recurrenceMaxCount || null };
  ```
- **Nueva función `isRecurrenceFinished(event)`**: true si `recurrenceOccurrenceCount >= maxCount` (cuando `maxCount` está definido) O si la próxima ocurrencia calculada superaría `endDate` (cuando `endDate` está definido). Devuelve false si ninguno de los dos límites está configurado.
- **`getTargetDate(event)`**: antes de avanzar con `advanceByRecurrence`, comprobar `isRecurrenceFinished`. Si la serie ya está finalizada, devolver la última fecha válida en vez de seguir avanzando (esto evita que el countdown muestre una fecha "fantasma" post-límite mientras el archivado automático corre en el siguiente ciclo de mantenimiento).

### `js/app.js`

- **`runArchiveMaintenance()`**: hoy archiva eventos NO recurrentes vencidos +24h (ver lógica existente en torno a la línea 433). Añadir una segunda pasada: para eventos recurrentes, si `Countdown.isRecurrenceFinished(event)` es true, archivar igual que a los no recurrentes (mismo campo `archivedAt`, mismo mecanismo de purga a +30 días). Esto resuelve FR-004/FR-008.
- **`checkMissedRecurringEvents()`**: la corrección ya aplicada (ancla real + tope inferior) sigue funcionando igual, pero ahora hay que sumar un tope superior: al generar ocurrencias con `advanceByRecurrence` en el bucle de "avanzar desde start", cortar si `Countdown.isRecurrenceFinished` se vuelve true en algún punto intermedio, para no reportar como "perdidas" ocurrencias que están más allá del límite configurado. Resuelve el caso límite pendiente sobre la interacción con el fix anterior.
- **`saveEvent()` / `handleSubmit()`**: al construir el objeto evento a guardar, incluir `recurrenceEndDate` y `recurrenceMaxCount` desde los nuevos campos del formulario. Si el usuario reactiva una serie archivada extendiendo el límite (editar formulario), limpiar `archivedAt` (mismo patrón que ya deben tener otros flujos de edición de eventos archivados, si existen — si no existen, es un pequeño agregado nuevo).
- **Formulario** (`index.html` + manejadores en `app.js`): agregar dos campos opcionales en la fila de repetición (`repeat-row`): input de fecha para "hasta" e input numérico para "repeticiones". Ambos vacíos por defecto. Mostrar el contador de ocurrencias restantes en la vista de edición como ayuda visual (no bloqueante para esta iteración si complica el scope).

### `js/ui.js`

- **`recurrenceLabel(recurrence)`**: cuando la recurrencia tiene `endDate` o `maxCount`, añadir un sufijo breve al badge existente, ej. `🔁 Cada 7 días · hasta 30 nov` o `🔁 Cada 7 días · 4x`. Mantener el formato actual cuando no hay límite (sin cambios visuales para eventos existentes).

### `js/storage.js`

- Extender la función que arma el objeto evento al leer/escribir (la misma que ya maneja compatibilidad con formatos legacy de recurrencia) para incluir `recurrenceEndDate`, `recurrenceMaxCount` y `recurrenceOccurrenceCount` con valores por defecto `null`/`0` cuando no existan en el JSON guardado — mismo patrón de retrocompatibilidad que ya usa para `recurrenceUnit`/`recurrenceInterval`.

## Fuera de alcance para esta iteración

- Notificar al usuario cuando una serie está por finalizar (ej. "última repetición"). Podría ser un ítem propio del backlog si se necesita.
- Editar el límite desde la vista de archivados directamente (por ahora: desarchivar → editar → guardar, reutilizando flujo existente).

## Riesgos / puntos de atención

- El conteo de ocurrencias (`recurrenceOccurrenceCount`) debe incrementarse en el momento correcto (cuando una ocurrencia "se cumple", no cuando se calcula). Definir con precisión ese punto en `tasks.md` para evitar off-by-one (contar de más o de menos una repetición).
- Verificar que el archivado automático de series finalizadas no interfiera con `checkCelebrations`, que ya excluye eventos recurrentes de la celebración — confirmar que el archivado no dispara una celebración fuera de lugar en la última ocurrencia.
