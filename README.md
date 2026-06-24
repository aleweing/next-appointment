# ⏳ Next Appointment

Aplicación web PWA de countdown donde el usuario crea sus propios eventos con nombre, fecha, hora, emoji, color, categoría y recurrencia. Una pantalla para cualquier cosa que estés esperando.

## Concepto
Sin registro, sin anuncios, funciona offline. Bodas, viajes, cumpleaños, estrenos, exámenes — cualquier cosa.

## Stack tecnológico
- HTML5 / CSS3 / JavaScript vanilla (sin frameworks)
- localStorage para todos los datos
- PWA (manifest + service worker) para instalación offline
- Iconos SVG inline propios (estilo Tabler, sin dependencias externas)

## Arquitectura
```
100% cliente — sin backend, sin APIs externas
localStorage → persistencia de eventos
Service Worker (network-first para JS/CSS/HTML) → uso offline
```

## Estructura de archivos
```
next-appointment/
├── index.html              # 5 vistas: main, lista, formulario, celebración, archivados
├── manifest.json
├── service-worker.js       # Cache v11, network-first para assets de código
├── css/
│   └── styles.css
├── js/
│   ├── icons.js            # ⚠️ SVG inline de todos los iconos de interfaz
│   ├── storage.js          # localStorage: eventos, tema, sort, onboarding, lastSeen
│   ├── countdown.js        # Lógica de cuenta atrás y recurrencia
│   ├── ui.js               # ⚠️ CATEGORIES aquí: renderizado de vistas y componentes
│   └── app.js              # Lógica principal, navegación, tick optimizado
└── icons/
    ├── icon-192.png
    └── icon-512.png
```

## Funcionalidades implementadas

### Eventos
- Crear, editar y eliminar eventos con: nombre, fecha, hora, emoji, color de acento, categoría
- Countdown en vivo (días/horas/min/seg), actualizado cada segundo
- Recurrencia configurable: cada X días / semanas / meses / años
- Aviso configurable: X días/horas/min antes (solo si la app está abierta)
- Retrocompatibilidad con tres formatos antiguos de recurrencia

### Categorías
- ⚠️ **Único lugar a editar**: `js/ui.js`, constante `CATEGORIES`
- Actuales: Cumpleaños, Salud, Fiestas, Ferias, Festivales, Viajes, Otros
- Cada categoría: `{ id, label, emoji }` — el `id` no debe cambiarse una vez en uso

### Carrusel principal
- Swipe nativo vía CSS scroll-snap — sin JS de touch (solución canónica, no revertir)
- Tick optimizado: solo actualiza la card visible

### Vista "Mis eventos"
- Buscador en vivo por nombre (insensible a mayúsculas y acentos)
- Chips de ordenación y filtro por categoría (combinables)

### Archivado automático
- Eventos NO recurrentes pasados hace ≥24h → se archivan
- Archivados hace ≥30 días → se eliminan definitivamente
- Vista "Archivados" con botón de restaurar

### Compartir e importar
- Link con evento codificado en base64 (`?import=...`)
- Botón "Importar" manual en "Mis eventos" (resuelve limitación de iOS con PWA)

### Onboarding
- Primera apertura: evento de ejemplo con botón "Crear mi propio evento"
- Flag en localStorage — nunca vuelve a aparecer

### Modo rápido de creación
- Formulario: solo nombre + fecha + hora visibles por defecto
- "Más opciones" despliega el resto

### Avisos de eventos recurrentes cumplidos
- Banner-resumen al abrir/volver a la app con eventos recurrentes cumplidos en el intervalo cerrado
- Umbral mínimo: 1 minuto (evita dispararse en recargas normales)

### PWA / Offline
- `touch-action: manipulation` bloquea zoom accidental sin afectar accesibilidad
- Service Worker v11, network-first para HTML/CSS/JS
- Icono: arco de cuenta atrás + calendario (azul #0984e3)

## Modelo de datos

```js
{
  id: 'evt_xxx',
  name: 'Viaje a Japón',
  date: '2026-09-01',
  time: '08:00',
  emoji: '✈️',
  color: '#0984e3',
  category: 'travel',
  recurrenceUnit: 'none',       // 'none'|'day'|'week'|'month'|'year'
  recurrenceInterval: 1,
  notifyBefore: 3600,           // segundos, o null
  archivedAt: null,             // timestamp ms, o null
  isOnboardingExample: false,
  _celebrated: false,
  _notifiedKey: null,
}
```

## Claves de localStorage
| Clave | Contenido |
|---|---|
| `next-appointment:events` | Array JSON de todos los eventos |
| `next-appointment:theme` | `'light'` \| `'dark'` |
| `next-appointment:sort` | Modo de orden de la lista |
| `next-appointment:onboarding-seen` | `'true'` si ya se vio el ejemplo |
| `next-appointment:last-seen` | Timestamp de la última apertura |

## Despliegue
GitHub Pages (rama main, carpeta raíz). URL: `https://aleweing.github.io/next-appointment/`

**Importante**: siempre subir el zip completo sobrescribiendo todos los archivos — nunca archivos sueltos.

## Decisiones técnicas clave
- **Swipe**: 100% CSS scroll-snap, sin JS de touch. No revertir.
- **Service Worker**: network-first para código, cache-first para imágenes. Versión: `v11`.
- **Iconos de interfaz**: SVG inline en `js/icons.js`, `setIcon(el, iconName)`. Los emojis de eventos/categorías se mantienen como emoji.
- **Recurrencia**: `recurrenceUnit` + `recurrenceInterval`. `Countdown.getRecurrence(event)` normaliza los tres formatos históricos.
