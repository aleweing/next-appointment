# Plan de Implementación: Historial de ocurrencias recurrentes

**Feature Branch**: `003-recurrence-history`
**Spec relacionada**: `spec.md` (misma carpeta)
**Estado**: Borrador

## Stack

Vanilla JS, sin build step. Sin cambios de infraestructura — todo cliente. Se apoya directamente en la lógica de recurrencia ya existente de la feature 002 (`Countdown.getAnchorDate`, `Countdown.advanceByRecurrence`, `Countdown.getLastOccurrence`).

## Enfoque

Nada se persiste. El historial se recalcula cada vez que se abre, caminando desde `getAnchorDate(event)` hacia adelante con `advanceByRecurrence()` — la misma cadena de fechas que ya usa el countdown — y recolectando las que son `<= now`. Para series con límite (feature 002), el recorrido se detiene en `getLastOccurrence(event)`; para series indefinidas, se detiene en `now`. Un tope duro de iteraciones evita que una serie diaria de varios años bloquee el hilo principal.

## Cambios por archivo

### `js/countdown.js`

Nueva función `getOccurrenceHistory(event, { limit = 20, hardCap = 2000 } = {})`:

```js
getOccurrenceHistory(event, { limit = 20, hardCap = 2000 } = {}) {
  const { unit, interval } = this.getRecurrence(event);
  if (unit === 'none') return { occurrences: [], truncated: false };

  const anchor = this.getAnchorDate(event);
  const now = Date.now();
  const ceiling = this.getLastOccurrence(event); // null si es indefinida

  const all = [];
  let current = new Date(anchor);
  let guard = 0;

  // Recorre TODA la serie hasta el techo (ahora, o el límite de la feature 002),
  // hasta hardCap iteraciones — es el mismo patrón de guard ya usado en
  // getTargetDate/getLastOccurrence, solo que aquí acumulamos en vez de
  // quedarnos con el último valor.
  while (guard < hardCap) {
    if (current.getTime() > now) break;
    if (ceiling && current.getTime() > ceiling.getTime()) break;
    all.push(new Date(current));
    current = this.advanceByRecurrence(current, unit, interval);
    guard++;
  }

  const truncatedByHardCap = guard >= hardCap;
  const ordered = all.reverse(); // más reciente primero
  return {
    occurrences: ordered.slice(0, limit),
    truncated: truncatedByHardCap || ordered.length > limit,
    total: ordered.length,
  };
}
```

Notas:
- `hardCap` (2000) es una salvaguarda de rendimiento, no un límite de producto — a razón de una ocurrencia diaria, cubre más de 5 años antes de activarse. Si algún día hace falta más, se sube el número; no hace falta rediseñar nada.
- `limit` es el tamaño de página que pide la UI (20 por defecto, ver `spec.md`). Como la función recorre toda la serie igual (acotada por `hardCap`), "pedir más" es sencillamente volver a llamar con un `limit` mayor — no hace falta guardar posición ni cursores.
- Reutiliza `getAnchorDate`, `advanceByRecurrence` y `getLastOccurrence` tal cual quedaron de la feature 002, sin tocarlos.

### `js/icons.js`

Falta un ícono para "historial". Añadir uno nuevo siguiendo la convención Tabler ya usada (outline, `stroke-width="2"`), por ejemplo `history` (reloj con flecha de retroceso):

```js
history: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 8v4l3 2"/><path d="M3.5 9a9 9 0 1 1 -1 5"/><path d="M3.5 5v4h4"/></svg>',
```

### `index.html`

Nuevo modal, siguiente al de `modal-missed-recurring` (mismo patrón exacto):

```html
<div id="modal-recurrence-history" class="modal-overlay hidden">
  <div class="modal-card">
    <h2 id="recurrence-history-title">Historial</h2>
    <ul id="recurrence-history-list" class="recurrence-history-list"></ul>
    <p id="recurrence-history-empty" class="modal-hint" hidden>Todavía no tuvo ninguna ocurrencia.</p>
    <button id="btn-recurrence-history-more" class="btn-secondary" hidden>Ver más</button>
    <div class="modal-actions">
      <button id="btn-recurrence-history-close" class="btn-primary">Cerrar</button>
    </div>
  </div>
</div>
```

### `js/ui.js`

- En la función que arma cada card (junto a `editBtn`/`shareBtn`, ~línea 218), agregar un botón de historial **solo si el evento es recurrente**:
  ```js
  if (recurrence.unit !== 'none') {
    const historyBtn = document.createElement('button');
    historyBtn.className = 'icon-btn';
    setIcon(historyBtn, 'history');
    historyBtn.setAttribute('aria-label', 'Ver historial');
    historyBtn.onclick = () => App.showRecurrenceHistory(event.id);
    actions.appendChild(historyBtn);
  }
  ```
- Igual en la vista de archivados (donde se renderizan las cards de eventos archivados), para cubrir la Historia de usuario 2.
- Nueva función `UI.renderRecurrenceHistory(occurrences, { truncated, hasMore })` que limpia y repuebla `#recurrence-history-list`, reutilizando el mismo patrón visual que `missed-recurring-item` (emoji + nombre + fecha) pero solo con la fecha (sin nombre, ya que el modal ya tiene el nombre del evento en el título).

### `js/app.js`

- Nueva función `showRecurrenceHistory(id)`:
  ```js
  showRecurrenceHistory(id) {
    const event = Storage.getById(id);
    if (!event) return;
    this._historyEventId = id;
    this._historyLimit = 20;
    document.getElementById('recurrence-history-title').textContent = `Historial · ${event.name}`;
    this._renderHistoryPage();
    UI.showModal('modal-recurrence-history');
  },

  _renderHistoryPage() {
    const event = Storage.getById(this._historyEventId);
    if (!event) return;
    const { occurrences, truncated, total } = Countdown.getOccurrenceHistory(event, { limit: this._historyLimit });
    UI.renderRecurrenceHistory(occurrences);
    document.getElementById('recurrence-history-empty').hidden = occurrences.length > 0;
    document.getElementById('btn-recurrence-history-more').hidden = !(truncated && occurrences.length < total);
  },
  ```
- Listener de `btn-recurrence-history-more`: `this._historyLimit += 20; this._renderHistoryPage();`
- Listener de `btn-recurrence-history-close`: `UI.hideModal('modal-recurrence-history')`.
- Registrar ambos listeners junto a los de `modal-missed-recurring` en `init()`.

## Fuera de alcance para esta iteración

- Cualquier acción sobre una ocurrencia puntual del historial (editar, eliminar, marcar).
- Exportar el historial junto al evento.

## Riesgos / puntos de atención

- `getOccurrenceHistory` recorre la serie completa cada vez que se pide "Ver más" (no incremental). Para el `hardCap` de 2000 esto es instantáneo en cualquier dispositivo — no optimizar prematuramente.
- Confirmar en QA que el criterio "pasado = fecha `<= ahora`" no genera una sensación rara al crear un evento y verlo aparecer en su propio historial de inmediato si la hora ya pasó por segundos (ver "Decisiones tomadas" en spec.md — ajuste de una línea si hace falta).
