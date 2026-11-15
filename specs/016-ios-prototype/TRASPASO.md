# Traspaso — Prototipo de Next Appointment para iPhone

Documento para la sesión que va a construir el prototipo en el Mac, con Xcode.
Esa sesión empieza sin el contexto de las conversaciones anteriores: aquí está
todo lo que necesita. El código fuente de la app web (este mismo repo) es la
referencia final; si algo de aquí contradice al código, manda el código.

## 1. Qué se quiere

Un **prototipo nativo para iPhone** de Next Appointment, la app de cuentas
atrás, para probarlo en el simulador y en el iPhone de Alejandro.

- Es un prototipo: tiene que funcionar y verse bien, no estar listo para el App Store.
- **Nativo en SwiftUI**, no la web metida en un `WKWebView`. Motivos: Apple
  suele rechazar apps que son solo una web envuelta, y así no se aprovechan
  los avisos locales ni el widget, que son la razón de hacerla nativa.
- La app web sigue existiendo y no se toca.

## 2. Qué es la app (resumen)

El usuario crea eventos con nombre, fecha, hora, emoji, color y categoría, y
ve cuánto falta para cada uno. Sin registro, sin anuncios, sin servidor: todo
se guarda en el dispositivo. Texto de la interfaz en **español de España**.

Dónde mirar en la web:

| Archivo | Qué contiene |
|---|---|
| `js/countdown.js` | Lógica de cuenta atrás y recurrencia. **Hay que portarla tal cual.** |
| `js/storage.js` | Persistencia y formato de compartir (`encodeEventForShare` / `decodeSharedEvent`). |
| `js/ui.js` | Categorías, emojis, colores, etiquetas de recurrencia, ordenación. |
| `js/app.js` | Flujo: formulario, archivado, avisos, celebración, importar/exportar. |
| `css/styles.css` | Aspecto visual (colores, radios, tema claro y oscuro). |
| `README.md` | Descripción funcional completa. |

## 3. Alcance del prototipo

### Fase 1 — lo mínimo para probarlo

1. **Pantalla principal**: carrusel horizontal de eventos, una tarjeta por
   pantalla, con emoji, nombre, fecha y cuenta atrás en vivo (días, horas,
   minutos, segundos). La tarjeta usa el color del evento.
2. **Lista "Mis eventos"**: todos los eventos activos con su cuenta atrás corta,
   búsqueda por nombre y orden "Próximos primero".
3. **Crear, editar y borrar** un evento. Formulario rápido: nombre, fecha y
   hora visibles; "Más opciones" despliega emoji, color, categoría, repetición
   y aviso.
4. **Recurrencia** completa (sección 5), incluida la etiqueta ("Anual",
   "Cada 3 días", "· 5 reps", "· hasta 30 nov").
5. **Aviso local** antes del evento con `UNUserNotificationCenter` (sección 6).
6. **Persistencia** en el dispositivo (sección 7).
7. Tema claro y oscuro siguiendo el del sistema.
8. Estado vacío: "Nada en el horizonte todavía", con botón para crear.

### Fase 2 — si la fase 1 queda bien

- **Widget de pantalla de inicio** (WidgetKit) con la próxima cuenta atrás.
  Es el ítem 014 del backlog y lo que una web no puede hacer.
- Archivado automático y vista "Archivados" (sección 8).
- Pantalla de celebración con confeti cuando un evento llega.
- Importar el archivo `.json` de la app web, para traer los eventos existentes
  (formato en la sección 9).
- Filtro por categoría y resto de órdenes de la lista.

### Fuera del prototipo

- Notificaciones push desde servidor (el Worker `next-appointment-push`): en
  nativo los avisos locales lo sustituyen.
- Compartir evento por enlace y página pública `cuenta.html`.
- Compras dentro de la app, cuentas, sincronización entre dispositivos.
- Publicar en el App Store o TestFlight.

## 4. Modelo de datos

Un evento en la web (`localStorage`, clave `next-appointment:events`):

```js
{
  id: 'evt_xxx',
  name: 'Viaje a Japón',        // máx. 40 caracteres
  date: '2026-09-01',           // YYYY-MM-DD, hora LOCAL del dispositivo
  time: '08:00',                // HH:MM, '00:00' si no se indica
  emoji: '✈️',                  // por defecto '⏳'
  color: '#0984e3',             // por defecto '#6c5ce7'
  category: 'travel',           // id de categoría, por defecto 'other'
  recurrenceUnit: 'none',       // 'none' | 'day' | 'week' | 'month' | 'year'
  recurrenceInterval: 1,        // entero >= 1
  recurrenceEndDate: null,      // 'YYYY-MM-DD' o null
  recurrenceMaxCount: null,     // entero 1..9999 o null
  notifyBefore: 3600,           // segundos antes del evento, o null
  archivedAt: null,             // timestamp en ms, o null
}
```

En Swift, un `struct Event: Codable, Identifiable` con esos campos. Recomendado
guardar `date` y `time` como texto (como en la web) y calcular el `Date` al
vuelo: así el evento significa "las 08:00 de donde esté el usuario" y el
archivo `.json` de la web se importa sin conversiones.

**Categorías** (el `id` no debe cambiar; `other` es el valor por defecto):

| id | Etiqueta | Emoji |
|---|---|---|
| `birthday` | Cumpleaños | 🎂 |
| `health` | Salud | 🩺 |
| `party` | Fiestas | 🎉 |
| `fair` | Ferias | 🎪 |
| `festival` | Festivales | 🎶 |
| `travel` | Viajes | ✈️ |
| `other` | Otros | ⏳ |

**Emojis del selector**: ⏳ 🎂 ✈️ 🎓 🎬 💒 🏠 🍾 💼 🎮 🎉 ❤️ 🌴 🎄 🐣 🎁

**Colores del selector**: `#6c5ce7` `#e17055` `#00b894` `#0984e3` `#fdcb6e`
`#e84393` `#2d3436` `#00cec9`

## 5. Reglas de recurrencia (portar de `js/countdown.js`)

Son la parte delicada. Portar la lógica función por función y cubrirla con
tests unitarios antes de hacer la interfaz.

- **Ancla**: la primera ocurrencia es `date` + `time` en hora local, tal como
  la escribió el usuario. Nunca se modifica al avanzar la serie.
- **Avanzar** una ocurrencia: sumar `interval` días, semanas (×7 días), meses
  o años **de calendario** (no milisegundos fijos). En Swift:
  `Calendar.current.date(byAdding:)`.
  - Ojo con el fin de mes: en JavaScript, 31 de enero + 1 mes da el 3 de marzo
    (desborda); `Calendar` da el 28 o 29 de febrero. Para un prototipo vale el
    comportamiento de `Calendar`, que es el que el usuario espera, pero hay que
    dejarlo anotado como diferencia conocida con la web.
- **Fecha objetivo** (`getTargetDate`): si el evento no es recurrente, es el
  ancla. Si lo es, se avanza desde el ancla mientras la fecha sea `<= ahora`,
  sin pasar nunca de la última ocurrencia válida.
- **Límites de la serie** (opcionales): `recurrenceEndDate` (incluido ese día
  hasta las 23:59:59) y `recurrenceMaxCount` (número total de ocurrencias,
  contando la primera). Si están los dos, gana el que se cumpla antes. Sin
  ninguno, la serie es indefinida.
- **Última ocurrencia** (`getLastOccurrence`): se calcula avanzando desde el
  ancla; no se guarda ningún contador.
- **Serie terminada** (`isRecurrenceFinished`): `ahora > última ocurrencia`.
- **¿Ya llegó?** (`hasElapsed`): no recurrente → `objetivo <= ahora`. Serie
  indefinida → nunca. Serie limitada → cuando está terminada.
- **Texto corto** (`shortLabel`): "12d 04h" si quedan días, "3h 07m" si quedan
  horas, "15m" si no; "¡Ya llegó! 🎉" si ya pasó.
- **Fecha legible** (`formatDate`): "Jueves, 1 de abril de 2027 · 08:00"; la
  hora se omite si es 00:00.
- **Etiqueta de recurrencia** (`recurrenceLabel` en `js/ui.js`): con intervalo
  1, "Diario", "Semanal", "Mensual", "Anual"; con más, "Cada N días / semanas
  / meses / años". Sufijos: " · N rep(s)" y " · hasta 30 nov".

Casos de prueba mínimos: evento único futuro y pasado; anual con ancla hace
años (cumpleaños); cada 3 días; mensual desde un día 31; serie con fecha de
fin; serie con máximo de repeticiones; serie con los dos límites; serie ya
terminada.

## 6. Avisos

- En la web, `notifyBefore` son los segundos de antelación (el formulario pide
  días, horas y minutos, y los suma). `null` = sin aviso.
- En nativo: al guardar un evento con aviso, pedir permiso de notificaciones y
  programar una notificación local para `objetivo − notifyBefore`. Al editar o
  borrar el evento, cancelar la anterior (identificador = `id` del evento).
- Texto: título `"<emoji> <nombre>"`, cuerpo `"Queda <texto corto> para este evento."`
- Recurrentes: programar el aviso de la próxima ocurrencia y reprogramar el
  siguiente al abrir la app. Para un prototipo es suficiente.
- Si el usuario deniega el permiso, el evento se guarda igual, sin aviso.

## 7. Persistencia

Para la fase 1 basta un archivo JSON en el directorio de documentos de la app,
con un `EventStore` observable. Si se hace el widget (fase 2), el archivo tiene
que estar en un **App Group** para que el widget lo lea. No hace falta Core
Data ni SwiftData para el prototipo.

## 8. Archivado automático (fase 2)

Al abrir la app (`runArchiveMaintenance` en `js/app.js`):

- Evento **no recurrente** que pasó hace 24 horas o más → se archiva.
- Serie recurrente **terminada** → se archiva al instante.
- Archivado hace 30 días o más → se borra definitivamente.
- Editar un evento archivado de modo que vuelva a tener futuro lo reactiva.

## 9. Formato del archivo de exportación de la web (fase 2)

```json
{
  "version": 1,
  "app": "next-appointment",
  "events": [ { "id": "...", "name": "...", "date": "...", "time": "...",
                "emoji": "...", "color": "...", "category": "...",
                "recurrenceUnit": "...", "recurrenceInterval": 1,
                "recurrenceEndDate": null, "recurrenceMaxCount": null,
                "notifyBefore": null } ]
}
```

Al importar, los duplicados se detectan por `id` y se omiten. Hay eventos
antiguos con otros formatos de recurrencia (`recurrence: 'yearly'` o
`recurring: true`): `getRecurrence` en `js/countdown.js` muestra cómo
normalizarlos.

## 10. Aspecto

- Color de marca: `#6c5ce7`. Icono de la app: `icons/icon-512.png` (arco de
  cuenta atrás con calendario, azul `#0984e3`); se puede usar como icono
  provisional.
- Tarjetas con esquinas muy redondeadas (24 pt), sombra suave, y el color del
  evento como acento.
- Tema claro: fondo `#f5f6fa`, tarjeta `#ffffff`, texto `#1e1e2e`.
  Tema oscuro: fondo `#0f1117`, tarjeta `#1a1d29`, texto `#f5f6fa`.
- Los números de la cuenta atrás, con dígitos de ancho fijo para que no bailen.
- Seguir las convenciones de iOS (navegación, hojas, selector de fecha
  nativo) antes que copiar la web píxel a píxel.

## 11. Decisiones tomadas y pendientes

Tomadas:

- SwiftUI nativo, solo iPhone, interfaz en español.
- Sin dependencias externas.
- Sin servidor: todo local.

Pendientes (preguntar a Alejandro si hacen falta para avanzar):

- **Dónde vive el código.** Propuesta: carpeta `ios/` en esta misma rama
  (`ios-prototipo`), sin fusionar a `main` por ahora. Motivo: `main` se publica
  entero en GitHub Pages, y el proyecto de Xcode no pinta nada ahí. Si el
  prototipo sigue adelante, lo natural es un repo propio.
- **Versión mínima de iOS.** Propuesta: iOS 17, que simplifica SwiftUI y los
  widgets. Confirmar qué iOS tiene su iPhone.
- **Identificador de la app** (bundle id) y equipo de firma: hacen falta para
  instalarla en el iPhone real; para el simulador no.
- **Nombre visible** de la app: "Next Appointment" por ahora.

## 12. Cómo se da por bueno el prototipo

- Compila sin avisos relevantes y arranca en el simulador de iPhone.
- Los tests de recurrencia pasan.
- Se puede crear un evento, verlo contar en vivo, editarlo, borrarlo, y sigue
  ahí al cerrar y volver a abrir la app.
- Un evento con aviso muestra la notificación a su hora.
- Alejandro lo ha probado y ha dicho qué cambiaría.
