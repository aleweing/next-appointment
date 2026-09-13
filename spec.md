# Especificación de Funcionalidad: Next Appointment

**Feature Branch**: `001-next-appointment-core`
**Creado**: 2026-09-14
**Estado**: Completado
**Input**: Gestión y programación de próximas citas (agenda con cuenta atrás)

## Contexto

Next Appointment ya existe como PWA personal (vanilla JS + GitHub Pages + Cloudflare Worker) con un sistema de exportación/importación de backups. Esta especificación cubre el comportamiento esperado de las funcionalidades core: crear, editar, eliminar, persistir y respaldar citas.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Crear y ver próximas citas (Prioridad: P1)

Como usuario, quiero crear una cita con título, fecha y hora, y ver todas mis próximas citas ordenadas cronológicamente, para saber qué tengo pendiente sin tener que revisar varias fuentes.

**Por qué esta prioridad**: Es el valor mínimo del producto — sin esto no hay app. Debe funcionar de forma aislada del resto de historias.

**Prueba independiente**: Se puede probar creando 3 citas con fechas distintas y verificando que aparecen ordenadas de la más próxima a la más lejana, sin depender de edición, borrado ni backup.

**Escenarios de aceptación**:
1. **Dado** que no hay citas guardadas, **cuando** el usuario crea una cita con título, fecha y hora válidos, **entonces** la cita aparece en la lista de próximas citas.
2. **Dado** que existen varias citas con fechas distintas, **cuando** el usuario abre la app, **entonces** las citas se muestran ordenadas de la más cercana a la más lejana en el tiempo.
3. **Dado** que una cita tiene fecha/hora ya pasada y NO es recurrente, **cuando** el usuario abre la app, **entonces** la cita se archiva automáticamente (después de ≥24 horas) y NO aparece en "próximas citas".

### Historia de usuario 2 - Editar y eliminar citas (Prioridad: P1)

Como usuario, quiero editar o eliminar una cita existente, para corregir errores o quitar planes que ya no aplican.

**Por qué esta prioridad**: Sin esto, un error de entrada obliga a vivir con datos incorrectos o borrar y rehacer todo manualmente.

**Prueba independiente**: Se puede probar creando una cita, editando su fecha, y verificando que el nuevo valor se refleja y reordena la lista; luego eliminándola y verificando que desaparece.

**Escenarios de aceptación**:
1. **Dado** una cita existente, **cuando** el usuario edita su título, fecha u hora, **entonces** los cambios se guardan y la lista se reordena si corresponde.
2. **Dado** una cita existente, **cuando** el usuario la elimina, **entonces** desaparece de la lista de forma permanente.
3. **Dado** que el usuario intenta eliminar una cita, **cuando** confirma la acción, **entonces** se pide confirmación antes de borrar (evitar borrados accidentales).

### Historia de usuario 3 - Persistencia y respaldo de datos (Prioridad: P2)

Como usuario, quiero que mis citas se conserven entre sesiones y poder exportarlas/importarlas, para no perder mi agenda si cambio de dispositivo o se borran los datos locales.

**Por qué esta prioridad**: Complementa el valor core; sin esto la app es usable a corto plazo pero frágil.

**Prueba independiente**: Se puede probar cerrando y reabriendo la app y verificando que las citas persisten; exportando a JSON y reimportando en una instancia limpia.

**Escenarios de aceptación**:
1. **Dado** que el usuario ha creado citas, **cuando** cierra y reabre la app, **entonces** todas las citas siguen presentes.
2. **Dado** un conjunto de citas, **cuando** el usuario exporta, **entonces** obtiene un archivo (o portapapeles) con todos los datos en un formato reimportable.
3. **Dado** un archivo de exportación válido, **cuando** el usuario lo importa, **entonces** las citas se restauran sin duplicados.

### Historia de usuario 4 - Citas recurrentes (Prioridad: P1)

Como usuario, quiero crear citas recurrentes (cada día, semana, mes o año), para no tener que recrear manualmente eventos que ocurren repetidamente.

**Por qué esta prioridad**: Evento core — sin recurrencia, un cumpleaños o aniversario requeriría recreación manual cada año.

**Prueba independiente**: Se puede probar creando una cita con recurrencia semanal, verificando que reaparece después de completarse, y editando el intervalo.

**Escenarios de aceptación**:
1. **Dado** que el usuario crea una cita marcada como recurrente cada 7 días, **cuando** la cita se cumple, **entonces** reaparece automáticamente 7 días después con la misma hora.
2. **Dado** una cita recurrente, **cuando** el usuario edita su intervalo de recurrencia, **entonces** el cambio se aplica a futuras repeticiones.
3. **Dado** una cita recurrente, **cuando** el usuario la elimina, **entonces** se elimina la serie completa (o solo la instancia actual, según diseño).

### Historia de usuario 5 - Categorización de citas (Prioridad: P2)

Como usuario, quiero asignar mis citas a categorías predefinidas (Cumpleaños, Viajes, etc.), para organizar visualmente mi agenda y filtrar por tipo.

**Por qué esta prioridad**: Valor de usabilidad — mejora significativamente la navegación en agendas grandes; depende de un set fijo de categorías.

**Prueba independiente**: Se puede probar creando citas en diferentes categorías, verificando que aparecen con colores/emojis distintos, y filtrando por categoría en la vista de lista.

**Escenarios de aceptación**:
1. **Dado** que el usuario crea una cita, **cuando** asigna una categoría, **entonces** la cita se etiqueta visualmente con el emoji y color de esa categoría.
2. **Dado** un conjunto de citas en varias categorías, **cuando** el usuario activa un filtro de categoría, **entonces** solo se muestran las citas de esa categoría.
3. **Dado** una cita existente, **cuando** el usuario edita su categoría, **entonces** el cambio se refleja inmediatamente.

### Historia de usuario 6 - Recordatorios/notificaciones (Prioridad: P3)

Como usuario, quiero recibir un aviso configurable antes de una cita próxima, para no olvidarla.

**Por qué esta prioridad**: Valor añadido, no bloqueante para el uso básico de la app; depende de permisos del navegador/OS que pueden fallar de forma no controlable.

**Prueba independiente**: Se puede probar creando una cita a pocos minutos de la hora actual con margen de aviso, y verificando que se dispara una notificación en el navegador.

**Escenarios de aceptación**:
1. **Dado** que el usuario configuró un margen de aviso en una cita, **cuando** la cita está a X minutos/horas/días de ocurrir, **entonces** recibe una notificación (si la app está abierta o el navegador tiene soporte).
2. **Dado** que el navegador no tiene permisos de notificación, **cuando** se cumple la condición de aviso, **entonces** la app no falla y muestra el recordatorio de forma alternativa (ej. badge visual en la app).
3. **Dado** una cita con aviso, **cuando** el usuario desactiva el margen o lo pone a cero, **entonces** no se genera más notificación.

### Casos límite

- ¿Qué pasa si el usuario crea dos citas con la misma fecha y hora exactas? → Se permiten; el orden dentro del mismo minuto es indefinido pero determinista.
- ¿Qué pasa si la fecha introducida ya pasó (cita retroactiva)? → Se permite la creación; se archiva después de 24 horas si no es recurrente.
- ¿Qué pasa si el usuario importa un backup con datos corruptos o de un formato antiguo? → La importación valida cada evento; los inválidos se omiten con advertencia; formatos antiguos se normalizan automáticamente.
- ¿Qué pasa si se deniegan los permisos de notificación después de haberlos concedido? → La app continúa funcionando; solo no se envían notificaciones del SO; se muestra alternativa en la app.
- ¿Cómo se comporta la app sin conexión (dado que es una PWA)? → Funciona 100% offline; todas las acciones se sincronizan al localStorage; el Service Worker caché los assets (v13 actual).

## Requisitos *(obligatorio)*

### Requisitos funcionales

- **FR-001**: El sistema DEBE permitir crear una cita con título, fecha y hora obligatorios.
- **FR-002**: El sistema DEBE validar que el título no esté vacío y que fecha/hora tengan un formato válido antes de guardar.
- **FR-003**: El sistema DEBE mostrar las citas ordenadas cronológicamente (de la más próxima a la más lejana).
- **FR-004**: El sistema DEBE permitir editar cualquier campo de una cita existente (título, fecha, hora, categoría, recurrencia, aviso).
- **FR-005**: El sistema DEBE permitir eliminar una cita, con confirmación previa.
- **FR-006**: El sistema DEBE persistir las citas entre sesiones sin acción explícita del usuario, usando localStorage.
- **FR-007**: El sistema DEBE permitir exportar todas las citas a un archivo JSON reimportable, descargable o copiable al portapapeles.
- **FR-008**: El sistema DEBE permitir importar un archivo de backup, enlace compartido o código base64 y restaurar las citas sin generar duplicados.
- **FR-009**: El sistema DEBE permitir configurar recurrencia por cita (ninguna, cada X días/semanas/meses/años).
- **FR-010**: El sistema DEBE reasignar automáticamente citas recurrentes después de completarse, sumando el intervalo configurado.
- **FR-011**: El sistema DEBE permitir asignar una categoría a cada cita (Cumpleaños, Salud, Fiestas, Ferias, Festivales, Viajes, Otros).
- **FR-012**: El sistema DEBE permitir filtrar y buscar citas por categoría y nombre en la vista de lista.
- **FR-013**: El sistema DEBERÍA (should) poder notificar al usuario X minutos/horas/días antes de una cita si lo habilita, con margen configurable por cita.
- **FR-014**: El sistema DEBE archivar automáticamente citas NO recurrentes pasadas después de ≥24 horas, quitándolas de la vista principal.
- **FR-015**: El sistema DEBE permitir restaurar citas archivadas desde una sección "Archivados", o eliminarlas permanentemente después de ≥30 días.
- **FR-016**: El sistema DEBE funcionar en un layout responsivo, priorizando el uso en iPhone, sin dependencias externas (vanilla JS, HTML, CSS).

### Entidades clave

- **Cita**: 
  - `id` (string, único, formato `evt_xxx`)
  - `name` (string, título, no vacío)
  - `date` (date, formato YYYY-MM-DD)
  - `time` (time, formato HH:MM)
  - `emoji` (string, emoji seleccionado por el usuario)
  - `color` (string, color hex, ej. `#0984e3`)
  - `category` (string, uno de: `'birthday'`, `'health'`, `'party'`, `'fair'`, `'festival'`, `'travel'`, `'other'`)
  - `recurrenceUnit` (string, uno de: `'none'`, `'day'`, `'week'`, `'month'`, `'year'`)
  - `recurrenceInterval` (number, ≥1, pasos entre recurrencias, ej. `1` = cada semana, `2` = cada 2 semanas)
  - `notifyBefore` (number, segundos antes del evento, o `null` para sin notificación)
  - `archivedAt` (number, timestamp en ms del archivado, o `null`)
  - `isOnboardingExample` (boolean, si es el evento de ejemplo inicial)
  - `_celebrated` (boolean, flag interno de celebración)
  - `_notifiedKey` (string, clave interna para evitar duplicar notificaciones)

- **Categoría** (constante, no editable en v1):
  - `{ id: 'birthday', label: 'Cumpleaños', emoji: '🎂' }`
  - `{ id: 'health', label: 'Salud', emoji: '🏥' }`
  - `{ id: 'party', label: 'Fiestas', emoji: '🎉' }`
  - `{ id: 'fair', label: 'Ferias', emoji: '🎪' }`
  - `{ id: 'festival', label: 'Festivales', emoji: '🎭' }`
  - `{ id: 'travel', label: 'Viajes', emoji: '✈️' }`
  - `{ id: 'other', label: 'Otros', emoji: '📌' }`

## Criterios de éxito *(obligatorio)*

- **SC-001**: Un usuario puede crear una cita completa (título + fecha + hora) en menos de 15 segundos desde que abre la app.
- **SC-002**: El 100% de las citas se muestran en el orden cronológico correcto, verificado con al menos 10 citas de prueba.
- **SC-003**: Ninguna cita se pierde tras cerrar y reabrir la app en 20 pruebas consecutivas.
- **SC-004**: Un backup exportado se puede reimportar en una instancia limpia recuperando el 100% de las citas originales (incluidas recurrentes, categorías, avisos).
- **SC-005**: Una cita recurrente semanal reaparece exactamente 7 días después de su fecha/hora de cumplimiento.
- **SC-006**: Las citas de cada categoría aparecen con el emoji y color correcto sin excepción.
- **SC-007**: Una cita pasada NO recurrente desaparece de "próximas citas" después de 24 horas y aparece en "Archivados".
- **SC-008**: Un margen de aviso de 60 minutos dispara una notificación (o alerta en-app) como máximo 61 minutos antes de la cita.

## Decisiones técnicas

- **Archivado automático**: Citas NO recurrentes con timestamp ≤ ahora - 24h se marcan como `archivedAt = <timestamp>` y se filtran de "próximas". Aparecen en sección "Archivados". Citas archivadas > 30 días se eliminan definitivamente.
- **Recurrencia**: Almacenada como tupla `(recurrenceUnit, recurrenceInterval)`. Normaliza formatos históricos. `Countdown.getRecurrence(event)` resuelve el próximo timestamp.
- **Categorías**: Set fijo, definido en `js/ui.js` como constante `CATEGORIES`. No se permite crear nuevas en v1. Se extiende fácilmente en v2.
- **Notificaciones**: Configurable por cita en segundos (`notifyBefore`). Solo se dispara si la app está abierta o el navegador soporta Web Notifications API. Fallback a badge visual en-app.
- **PWA offline**: Service Worker v13, network-first para código, cache-first para imágenes. Funciona 100% offline.

## Aclaraciones resueltas

✅ **¿Las citas pasadas deben desaparecer o quedar visibles?**  
→ Se archivan automáticamente ≥24h después de pasar y desaparecen de "próximas citas", pero permanecen accesibles en la sección "Archivados" durante ≥30 días. Luego se eliminan permanentemente.

✅ **¿Se permiten citas recurrentes?**  
→ **Sí**. Intervalos configurables por cita: cada X días/semanas/meses/años. Reaparecen automáticamente en el próximo ciclo.

✅ **¿El margen de aviso es configurable?**  
→ **Sí**. Cada cita puede tener un margen de aviso independiente (en segundos, minutos, horas o días). Se puede desactivar poniendo a `null`.

✅ **¿Se necesita categorización?**  
→ **Sí**. Set fijo de 7 categorías predefinidas (Cumpleaños, Salud, Fiestas, Ferias, Festivales, Viajes, Otros). No se permiten categorías personalizadas en v1; se extiende en v2 si se requiere.

## Supuestos

- Un único usuario por instancia de la app (uso personal, sin multiusuario ni login).
- El formato de exportación es JSON, consistente con el resto de la serie de PWAs personales.
- No se requiere sincronización en tiempo real entre dispositivos; el respaldo/restauración cubre esa necesidad.
- Las citas archivadas son inmutables (no se pueden editar desde "Archivados", solo restaurar o eliminar).
- Las categorías son solo etiquetas visuales; no afectan el ordenamiento cronológico ni lógica de recurrencia.
