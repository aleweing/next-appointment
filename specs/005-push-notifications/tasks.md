# Plan de Tareas: Notificaciones push reales (Feature 005)

**Feature Branch**: `005-push-notifications`
**Spec relacionada**: `spec.md` (misma carpeta)
**Plan técnico**: `plan.md` (misma carpeta)
**Estado**: Borrador
**Total de tareas**: 16 (P1: 11, P2: 5)

**Nota general**: esta feature toca dos proyectos distintos — el Worker nuevo (`next-appointment-push-worker`, repo/proyecto separado) y el cliente de siempre (`next-appointment`). Las tareas están agrupadas por dónde viven.

---

## 🔴 P1 — Worker: lo mínimo para que un aviso llegue

### TASK-005-001: Elegir librería de cifrado Web Push para Workers

**Descripción**: Confirmar, al momento de implementar (no antes), qué librería usar para firmar VAPID y cifrar el payload en el entorno de Workers.

**Criterios de aceptación**:
1. Se evalúan al menos `web-push-neo` y `@block65/webcrypto-web-push` (candidatas identificadas en `plan.md`) contra estado de mantenimiento actual
2. Se hace una prueba mínima de "hola mundo": generar claves VAPID, suscribirse desde un navegador de prueba, enviar un push de prueba y verificar que llega
3. La elección y el motivo quedan anotados en un comentario al inicio del archivo del Worker que la usa

**Definición de listo**:
- ✅ Un push de prueba llega a un navegador de escritorio (Chrome/Firefox) antes de probar en iPhone

---

### TASK-005-002: Crear el Worker, KV namespaces y Cron Trigger (dashboard)

**Descripción**: Dar de alta la infraestructura en Cloudflare, toda desde el dashboard web, sin CLI.

**Criterios de aceptación**:
1. Nuevo Worker creado (ej. `next-appointment-push`)
2. Dos KV namespaces creados y bindeados al Worker: `SUBSCRIPTIONS` y `SCHEDULED`
3. Secrets configurados: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `APP_TOKEN` (generado una vez, valor propio)
4. Cron Trigger configurado desde la pestaña "Triggers" del Worker en el dashboard, expresión `* * * * *` (cada minuto) — **verificar en ese momento que el plan Free lo permite**; si no, ajustar a la menor frecuencia disponible y anotar el cambio en `plan.md`
5. El Worker responde algo (aunque sea un 200 vacío) en su URL pública, confirmando que el deploy funcionó

**Definición de listo**:
- ✅ URL del Worker anotada para usar en `js/push.js`
- ✅ Cron Trigger visible y activo en el dashboard

---

### TASK-005-003: Endpoint `POST /subscribe`

**Descripción**: Recibe y guarda una suscripción push por dispositivo.

**Criterios de aceptación**:
1. Rechaza la petición (401) si falta o no coincide el header `X-App-Token`
2. Body esperado: `{ deviceId, subscription: { endpoint, keys: { p256dh, auth } } }`
3. Guarda `SUBSCRIPTIONS[deviceId] = subscription`
4. Sobreescribe sin error si el `deviceId` ya existía (re-suscripción)

**Definición de listo**:
- ✅ Probado con curl/Postman: guarda y sobreescribe correctamente
- ✅ Sin token o con token incorrecto: 401

---

### TASK-005-004: Endpoint `POST /schedule`

**Descripción**: Recibe y guarda (o actualiza) el próximo aviso pendiente de un evento.

**Criterios de aceptación**:
1. Rechaza la petición (401) si falta o no coincide `X-App-Token`
2. Body esperado: `{ deviceId, eventId, title, fireAt, recurrenceUnit, recurrenceInterval, recurrenceEndDate, recurrenceMaxCount, anchorDate }`
3. Guarda `SCHEDULED[`${deviceId}:${eventId}`] = { ...body }`
4. Si ya existía una entrada para ese `deviceId:eventId`, la reemplaza por completo (no hace merge parcial)

**Definición de listo**:
- ✅ Programar dos veces el mismo evento deja solo la versión más reciente en KV

---

### TASK-005-005: Endpoint `POST /cancel`

**Descripción**: Borra el aviso pendiente de un evento para un dispositivo.

**Criterios de aceptación**:
1. Rechaza la petición (401) si falta o no coincide `X-App-Token`
2. Body esperado: `{ deviceId, eventId }`
3. Borra `SCHEDULED[`${deviceId}:${eventId}`]` si existe; no falla si no existía

**Definición de listo**:
- ✅ Cancelar un evento no programado no produce error
- ✅ Cancelar un evento programado hace que el cron ya no lo procese

---

### TASK-005-006: Lógica de recurrencia portada al Worker

**Descripción**: Copia mínima (sin UI) de `getRecurrence`/`advanceByRecurrence`/`getLastOccurrence`/`isRecurrenceFinished` de `js/countdown.js`, para que el Worker pueda reprogramar sin el cliente.

**Criterios de aceptación**:
1. Misma lógica exacta que la versión del cliente (feature 002) — mismos resultados para los mismos inputs, incluyendo meses de largo variable y ambos límites compitiendo
2. Vive en un único archivo del Worker (ej. `recurrence.js`) con un comentario destacado: "Copia de js/countdown.js del cliente — si cambia allá, cambiar acá"
3. Se prueban al menos los mismos casos que ya se probaron en la feature 002 (serie mensual desde el 31, serie anual con bisiesto, ambos límites)

**Definición de listo**:
- ✅ Los mismos 19 casos de prueba de la feature 002 (adaptados) pasan también contra la copia del Worker

---

### TASK-005-007: Handler `scheduled()` del Cron Trigger

**Descripción**: El corazón del sistema — revisa qué avisos tocan enviar y los procesa.

**Criterios de aceptación**:
1. Lista las claves de `SCHEDULED` con `fireAt <= Date.now()`
2. Para cada una, envía el push (usando la librería de TASK-005-001) a la suscripción de `SUBSCRIPTIONS[deviceId]`
3. Si el envío falla con 404/410 (suscripción inválida o expirada), borra esa `SUBSCRIPTIONS[deviceId]` y todas las `SCHEDULED` de ese `deviceId`
4. Si `recurrenceUnit === 'none'`, borra la entrada de `SCHEDULED` tras enviar
5. Si repite y `isRecurrenceFinished()` (con la lógica portada) da `true`, borra la entrada sin reprogramar
6. Si repite y no está finalizada, calcula el siguiente `fireAt` y actualiza la entrada en KV
7. Un fallo al procesar una entrada no debe impedir que se procesen las demás (aislar errores por entrada, no por lote completo)

**Definición de listo**:
- ✅ Evento no recurrente: se envía una vez y desaparece de `SCHEDULED`
- ✅ Evento recurrente sin límite: se reprograma indefinidamente
- ✅ Evento recurrente con límite agotado: se envía la última vez y no se reprograma
- ✅ Suscripción inválida: se limpia sin afectar otras entradas

---

## 🔴 P1 — Cliente: activar y usar push

### TASK-005-008: `js/push.js` — helpers base

**Descripción**: Funciones de detección de entorno, identidad de dispositivo y wrapper del Worker.

**Criterios de aceptación**:
1. `isInstalledStandalone()` detecta correctamente PWA instalada vs. pestaña normal de Safari
2. `getOrCreateDeviceId()` persiste un UUID en `localStorage` bajo una clave propia, generándolo una sola vez
3. Constantes `VAPID_PUBLIC_KEY` y `WORKER_URL` centralizadas al inicio del archivo

**Archivos a modificar**:
- `js/push.js` (nuevo)
- `index.html` — agregar `<script src="js/push.js"></script>` antes de `js/app.js`

**Definición de listo**:
- ✅ `isInstalledStandalone()` devuelve `true` en la PWA instalada y `false` en una pestaña de Safari normal

---

### TASK-005-009: Suscribirse y desuscribirse

**Descripción**: `subscribeToPush()` y `unsubscribeFromPush()`.

**Criterios de aceptación**:
1. `subscribeToPush()` pide permiso de notificaciones, se suscribe vía `pushManager.subscribe()` con la VAPID pública, y envía el resultado a `/subscribe` con el `deviceId`
2. Si el usuario deniega el permiso, la función falla de forma controlada (sin excepción no capturada) y lo indica a quien la llamó
3. `unsubscribeFromPush()` da de baja la suscripción localmente (`subscription.unsubscribe()`)

**Archivos a modificar**:
- `js/push.js`

**Definición de listo**:
- ✅ Suscribirse desde un iPhone con la app instalada: llega el registro al Worker (verificar en KV)
- ✅ Denegar el permiso no rompe la app

---

### TASK-005-010: Programar y cancelar avisos por evento

**Descripción**: `scheduleEventNotification(event)` y `cancelEventNotification(eventId)`, conectadas al ciclo de vida del evento.

**Criterios de aceptación**:
1. `scheduleEventNotification(event)` no hace nada si `notifyBefore` es `null` o si push no está activo en este dispositivo
2. Si corresponde, calcula `fireAt = Countdown.getTargetDate(event).getTime() - event.notifyBefore * 1000` y hace `POST /schedule` con todos los datos de recurrencia del evento
3. `cancelEventNotification(eventId)` hace `POST /cancel`
4. En `js/app.js`, `handleSubmit()` llama a una u otra según corresponda tras guardar
5. En `js/app.js`, `deleteCurrentEvent()` llama a `cancelEventNotification` antes de borrar

**Archivos a modificar**:
- `js/push.js`
- `js/app.js` — `handleSubmit()`, `deleteCurrentEvent()`

**Definición de listo**:
- ✅ Crear evento con aviso y push activo: aparece en `SCHEDULED` del Worker
- ✅ Editar la fecha de ese evento: `fireAt` se actualiza en el Worker
- ✅ Borrar el evento: desaparece de `SCHEDULED`

---

### TASK-005-011: `service-worker.js` — recibir y mostrar el push

**Descripción**: Manejar el evento `push` y mostrar la notificación del sistema.

**Criterios de aceptación**:
1. Listener `push` muestra `self.registration.showNotification()` con el título y cuerpo recibidos
2. Listener `notificationclick` cierra la notificación y abre/enfoca la app
3. `CACHE_NAME` incrementado a la siguiente versión

**Archivos a modificar**:
- `service-worker.js`

**Definición de listo**:
- ✅ Notificación de prueba enviada manualmente desde el Worker se ve correctamente en el iPhone, con la app cerrada

---

## 🟠 P2 — Cliente: UI y pulido

### TASK-005-012: Modal de ajustes de push

**Descripción**: UI para activar/desactivar push en el dispositivo actual.

**Criterios de aceptación**:
1. Nuevo botón `btn-open-push-settings` (ícono `bell`, ya existente) en `topbar-actions` de `view-list`
2. Nuevo modal `modal-push-settings`: muestra el estado actual (activado/desactivado) y un botón para alternarlo
3. Si `!isInstalledStandalone()`, el modal muestra el mensaje de "añadí la app a tu pantalla de inicio primero" en vez del botón de activar

**Archivos a modificar**:
- `index.html` — botón + modal
- `js/app.js` — listeners de apertura/cierre y del botón de alternar

**Definición de listo**:
- ✅ Desde Safari normal: se ve el mensaje de instalación, no el botón de activar
- ✅ Desde la PWA instalada: se puede activar y desactivar

---

### TASK-005-013: Suprimir el aviso en primer plano cuando push está activo

**Descripción**: Evitar el doble aviso (push del sistema + `alert()` de `checkNotifications`) cuando el dispositivo ya tiene push activo.

**Criterios de aceptación**:
1. `checkNotifications()` no dispara su `alert()` si este dispositivo tiene push activo
2. Sin push activo, el comportamiento actual no cambia (FR-010 de la spec)

**Archivos a modificar**:
- `js/app.js` — `checkNotifications()`

**Definición de listo**:
- ✅ Con push activo: solo llega la notificación del sistema, no el alert
- ✅ Sin push activo: sigue llegando el alert como hoy

---

### TASK-005-014: Re-sincronizar avisos pendientes al abrir la app

**Descripción**: Cubrir el caso de eventos creados/editados antes de activar push por primera vez, o cualquier desincronización entre el cliente y lo que el Worker tiene guardado.

**Criterios de aceptación**:
1. Al abrir la app con push activo, se recorren los eventos activos con `notifyBefore` configurado y se llama `scheduleEventNotification()` para cada uno (el Worker sobreescribe, así que es seguro reenviar aunque ya estuviera programado)
2. No se hace esto en cada render — solo una vez por apertura de app (mismo patrón que `runArchiveMaintenance`/`checkMissedRecurringEvents`, llamados desde `init()`)

**Archivos a modificar**:
- `js/app.js` — `init()`

**Definición de listo**:
- ✅ Activar push por primera vez con eventos ya existentes: todos quedan programados sin tener que editarlos uno por uno

---

### TASK-005-015: Manejo de errores de red hacia el Worker

**Descripción**: Que un fallo de red al llamar `/subscribe`, `/schedule` o `/cancel` no rompa el flujo normal de crear/editar/borrar eventos.

**Criterios de aceptación**:
1. Las llamadas al Worker desde `js/push.js` están en `try/catch`; un fallo se registra en consola pero no interrumpe `handleSubmit()`/`deleteCurrentEvent()`
2. El evento se guarda/edita/borra localmente igual, aunque el Worker no haya podido confirmarlo

**Archivos a modificar**:
- `js/push.js`

**Definición de listo**:
- ✅ Desconectar la red y crear un evento con aviso: el evento se guarda igual, sin error visible para el usuario

---

### TASK-005-016: QA end-to-end en iPhone

**Descripción**: Verificación manual completa del flujo real, único punto donde de verdad se valida la feature.

**Criterios de aceptación**:
1. Instalar la app en pantalla de inicio, activar push, crear evento con aviso a 1-2 minutos, cerrar la app por completo (deslizar para cerrar, no solo bloquear pantalla) y confirmar que llega la notificación
2. Repetir con una serie recurrente semanal y confirmar que, tras la primera notificación, se programa sola la siguiente (verificar `fireAt` actualizado en el KV del Worker)
3. Editar la fecha de un evento con aviso pendiente y confirmar que el próximo aviso llega en el horario nuevo
4. Borrar un evento con aviso pendiente y confirmar que no llega ningún aviso
5. Revocar el permiso de notificaciones desde Ajustes de iOS y confirmar que, tras el próximo intento de envío, el Worker deja de reintentar sin acumular errores

**Definición de listo**:
- ✅ Los 5 escenarios anteriores confirmados en el dispositivo real

---

## 📊 Matriz de Dependencias

```
TASK-005-001 (Librería) ──→ TASK-005-007 (Handler del cron)
TASK-005-002 (Infra) ──→ TASK-005-003/004/005 (Endpoints) ──→ TASK-005-007
TASK-005-006 (Recurrencia portada) ──→ TASK-005-007

TASK-005-008 (Helpers) ──→ TASK-005-009 (Sub/unsub) ──→ TASK-005-010 (Schedule/cancel)
                                                              ├──→ TASK-005-012 (Modal UI)
                                                              ├──→ TASK-005-013 (Suprimir alert)
                                                              └──→ TASK-005-014 (Re-sync al abrir)
TASK-005-011 (Service worker push) — en paralelo, se puede probar con push manual antes de tener el flujo completo

TASK-005-015 (Manejo de errores) — transversal, aplicar a medida que se escribe 009/010
TASK-005-016 (QA) — al final, depende de todo lo anterior
```

---

## 📝 Notas Finales

- **Orden recomendado**: primero todo el Worker (001→007) probado con curl/Postman y un navegador de escritorio, después el cliente (008→015), y recién ahí el QA real en iPhone (016) — probar en iPhone antes de tener el Worker funcionando a mano es perder tiempo por cada iteración.
- **Esta es la feature más compleja del backlog hasta ahora** — a diferencia de 002/003, acá sí hay estado del lado servidor y dos copias de la lógica de recurrencia a mantener sincronizadas (ver riesgo en `plan.md`).
- **Regression**: verificar que desactivar/no tener push activado deja el comportamiento de avisos exactamente igual que antes de esta feature.
