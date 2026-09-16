# Plan de Tareas: Historial de ocurrencias recurrentes (Feature 003)

**Feature Branch**: `003-recurrence-history`
**Spec relacionada**: `spec.md` (misma carpeta)
**Plan técnico**: `plan.md` (misma carpeta)
**Estado**: Borrador
**Total de tareas**: 8 (P1: 5, P2: 3)

---

## 🔴 P1: Bloqueante para que la feature sea usable

### TASK-003-001: Función `getOccurrenceHistory()` en Countdown

**Descripción**: Nueva función pura que calcula, sin guardar nada, la lista de ocurrencias pasadas de una serie recurrente.

**Criterios de aceptación**:
1. Devuelve `{ occurrences: [], truncated: false }` para eventos no recurrentes
2. Devuelve `{ occurrences: [], truncated: false, total: 0 }` para un evento cuya ancla todavía no llegó
3. Las ocurrencias devueltas están ordenadas de más reciente a más antigua
4. Para una serie con límite (feature 002) ya alcanzado, ninguna ocurrencia es posterior a `Countdown.getLastOccurrence(event)`
5. Para una serie sin límite, la última ocurrencia devuelta es `<=` a la hora actual
6. El parámetro `limit` acota cuántas se devuelven; `total` siempre refleja cuántas existen en realidad (para saber si hay más)
7. Un `hardCap` interno (2000 iteraciones) evita bloquear el hilo principal en series muy antiguas/frecuentes
8. Es una función pura: no lee ni escribe ningún campo del evento, no modifica estado global

**Archivos a modificar**:
- `js/countdown.js` — nueva función `getOccurrenceHistory(event, options)`

**Definición de listo**:
- ✅ Evento semanal, ancla hace 5 semanas: devuelve 5 ocurrencias
- ✅ Evento con ancla futura: devuelve lista vacía, sin error
- ✅ Evento con límite de 3 repeticiones ya agotado: nunca devuelve una 4ª
- ✅ Evento diario con 3 años de antigüedad: responde sin demora perceptible

---

### TASK-003-002: Ícono de historial

**Descripción**: Añadir un ícono nuevo (Tabler-style, coherente con los existentes) para el botón de historial.

**Criterios de aceptación**:
1. Sigue exactamente el mismo formato SVG que el resto de `ICONS` en `js/icons.js` (outline, `stroke-width="2"`)
2. Se aplica con el helper `setIcon(el, 'history')` ya existente, sin tocar su implementación

**Archivos a modificar**:
- `js/icons.js` — nueva entrada `history` en el objeto `ICONS`

**Definición de listo**:
- ✅ El ícono se ve correctamente en un botón de prueba
- ✅ No rompe ningún ícono existente

---

### TASK-003-003: Modal de historial en el HTML

**Descripción**: Agregar el modal `modal-recurrence-history` siguiendo el mismo patrón que `modal-missed-recurring`.

**Criterios de aceptación**:
1. Contiene: título con el nombre del evento, lista `#recurrence-history-list`, mensaje de estado vacío `#recurrence-history-empty` (oculto por defecto), botón `#btn-recurrence-history-more` (oculto por defecto), botón de cierre `#btn-recurrence-history-close`
2. Usa las mismas clases (`modal-overlay`, `modal-card`, `modal-hint`, `modal-actions`) que los modales existentes, para heredar sus estilos sin CSS nuevo de layout
3. Empieza oculto (`class="hidden"`)

**Archivos a modificar**:
- `index.html` — nuevo modal, junto a `modal-missed-recurring`

**Definición de listo**:
- ✅ El modal no se muestra al cargar la app
- ✅ Estructura validada visualmente contra el modal de "mientras no abrías la app"

---

### TASK-003-004: Botón de historial en las cards recurrentes

**Descripción**: Mostrar un botón de historial en la card de cada evento recurrente (activo o archivado), y en ningún evento no recurrente.

**Criterios de aceptación**:
1. En la función de renderizado de cards de `js/ui.js` (junto a `editBtn`/`shareBtn`), agregar el botón de historial solo cuando `Countdown.getRecurrence(event).unit !== 'none'`
2. El botón llama a `App.showRecurrenceHistory(event.id)` al hacer click
3. Se agrega tanto en la vista principal como en la vista de Archivados (misma función de render de card, o su equivalente para archivados)
4. Un evento no recurrente no muestra este botón en ningún lado

**Archivos a modificar**:
- `js/ui.js` — función de render de card (~línea 195–230) y su uso en la vista de archivados

**Definición de listo**:
- ✅ Evento recurrente activo: botón visible
- ✅ Evento recurrente archivado: botón visible
- ✅ Evento no recurrente: botón ausente

---

### TASK-003-005: Abrir y poblar el modal de historial

**Descripción**: Implementar `App.showRecurrenceHistory(id)` y el renderizado de la lista.

**Criterios de aceptación**:
1. `showRecurrenceHistory(id)` busca el evento, resetea la paginación a 20, pone el nombre del evento en el título del modal, renderiza la primera página y abre el modal
2. `UI.renderRecurrenceHistory(occurrences)` limpia `#recurrence-history-list` y agrega un `<li>` por ocurrencia con la fecha formateada (mismo estilo/formato que usa `checkMissedRecurringEvents` para las suyas: `weekday, day, month` en español, con mayúscula inicial)
3. Si `occurrences.length === 0`, se muestra `#recurrence-history-empty` y la lista queda vacía
4. El botón de cierre oculta el modal sin efectos secundarios

**Archivos a modificar**:
- `js/app.js` — `showRecurrenceHistory(id)`, `_renderHistoryPage()`, listeners de apertura/cierre en `init()`
- `js/ui.js` — `renderRecurrenceHistory(occurrences)`

**Definición de listo**:
- ✅ Abrir historial de un evento con ocurrencias: se ven en la lista, más reciente primero
- ✅ Abrir historial de un evento sin ocurrencias: se ve el mensaje de estado vacío
- ✅ Cerrar el modal no dejar residuos (la próxima apertura no arrastra items viejos)

---

## 🟠 P2: Complementario (paginación y estilos)

### TASK-003-006: Botón "Ver más" con paginación incremental

**Descripción**: Permitir ampliar la lista de 20 en 20 sin recargar la página, cuando hay más ocurrencias de las mostradas.

**Criterios de aceptación**:
1. El botón `#btn-recurrence-history-more` se muestra solo si `total > limit` actual
2. Al pulsarlo, `this._historyLimit += 20` y se vuelve a renderizar la página (sin cerrar el modal)
3. El botón desaparece cuando ya no quedan más ocurrencias por mostrar

**Archivos a modificar**:
- `js/app.js` — listener de `btn-recurrence-history-more`, uso de `_historyLimit`/`_renderHistoryPage()`

**Definición de listo**:
- ✅ Evento con 45 ocurrencias: se ven 20, "Ver más" las lleva a 40, luego a 45 y el botón desaparece
- ✅ Evento con menos de 20 ocurrencias: el botón nunca aparece

---

### TASK-003-007: Estilos del modal y la lista de historial

**Descripción**: CSS para `.recurrence-history-list` y sus items, coherente con el resto de modales.

**Criterios de aceptación**:
1. Reutiliza variables de diseño existentes (`--bg-card`, `--border`, `--radius-sm`, `--text-muted`) en vez de valores nuevos sueltos
2. La lista es scrolleable si excede el alto del modal (`max-height` + `overflow-y: auto`), para que "Ver más" no rompa el layout
3. Visualmente coherente con `.missed-recurring-list` ya existente (mismo espaciado, misma tipografía)

**Archivos a modificar**:
- `css/styles.css` — nuevas reglas `.recurrence-history-list`, `.recurrence-history-item`

**Definición de listo**:
- ✅ Modal con 20 ocurrencias no desborda la pantalla en iPhone
- ✅ Estética coherente con el resto de modales de la app

---

### TASK-003-008: Verificación de series con meses de largo variable

**Descripción**: Confirmar visualmente que el historial de una serie mensual con ancla en día 29/30/31 muestra las fechas reales calculadas por `advanceByRecurrence` (que se desplaza en meses cortos), no fechas "corregidas" o idealizadas.

**Criterios de aceptación**:
1. Crear un evento mensual con ancla el 31 de un mes, dejar pasar varias ocurrencias, y verificar que el historial coincide exactamente con lo que ya muestra el countdown/badge para esa misma serie (sin discrepancias entre vistas)

**Archivos a modificar**: ninguno (tarea de verificación/QA, no debería requerir cambios si TASK-003-001 reutiliza `advanceByRecurrence` tal cual)

**Definición de listo**:
- ✅ Las fechas del historial coinciden con las que muestra `Countdown.formatDate` para cada ocurrencia individual

---

## 📊 Matriz de Dependencias

```
TASK-003-001 (getOccurrenceHistory)
    ├──→ TASK-003-005 (Abrir y poblar modal)
    │        ├──→ TASK-003-006 (Paginación)
    │        └──→ TASK-003-008 (Verificación meses variables)
    └──→ TASK-003-004 (Botón en cards, usa getRecurrence ya existente)

TASK-003-002 (Ícono) ──→ TASK-003-004 (Botón en cards)
TASK-003-003 (Modal HTML) ──→ TASK-003-005
TASK-003-007 (Estilos) — independiente, se puede hacer en paralelo
```

---

## 🧪 Test Coverage

| Task | Test Manual |
|------|-------------|
| 003-001 | Evento semanal 5 semanas de antigüedad → 5 ocurrencias; ancla futura → vacío; serie con límite agotado → nunca pasa la última válida |
| 003-002 | Ícono visible y coherente con el resto |
| 003-003 | Modal oculto al cargar, estructura correcta |
| 003-004 | Botón solo en eventos recurrentes, en activos y archivados |
| 003-005 | Abrir historial con y sin ocurrencias; cerrar sin residuos |
| 003-006 | Evento con 45 ocurrencias: paginación de a 20 hasta agotar |
| 003-007 | Modal no desborda en iPhone, estilo coherente |
| 003-008 | Serie mensual día 31: historial coincide con el countdown |

---

## 📝 Notas Finales

- **Orden recomendado de ejecución**: 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008
- **Reutiliza sin modificar**: `getAnchorDate`, `advanceByRecurrence`, `getLastOccurrence`, `getRecurrence` (todas de la feature 002) — si alguna cambia de firma, revisar esta feature también
- **Regression**: verificar que agregar el botón de historial no descuadra el layout de `card-actions` en cards con muchos botones ya (editar, compartir, notificar)
