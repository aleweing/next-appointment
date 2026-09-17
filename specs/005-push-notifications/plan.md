# Plan de Implementación: Notificaciones push reales

**Feature Branch**: `005-push-notifications`
**Spec relacionada**: `spec.md` (misma carpeta)
**Estado**: Borrador

## La decisión de arquitectura central

Hay dos formas razonables de resolver "programar un aviso futuro sin servidor tradicional":

**Opción A — Durable Objects + Alarms** (la más elegante): un Durable Object por evento, con `setAlarm()` disparando exactamente en el momento del aviso. Están disponibles en el plan gratuito de Cloudflare desde 2025. El problema: los bindings de Durable Objects (clases + migraciones) se configuran en `wrangler.toml/jsonc` y se despliegan con **Wrangler CLI** — no existe (a la fecha de este plan) una forma de darlos de alta solo desde el dashboard web, a diferencia de un Worker simple. Esto rompe el patrón que ya usás en el resto de la serie ("deployado entero por interfaz web, sin CLI").

**Opción B — Worker + KV + Cron Trigger** (la elegida): un Worker simple con un namespace de KV para guardar suscripciones y avisos pendientes, y un Cron Trigger que se despierta cada minuto a revisar qué hay que enviar. Tanto el Worker como el KV namespace como el propio Cron Trigger se crean y bindean desde el dashboard de Cloudflare, sin tocar una terminal — igual que ya hacés con los Workers de Next Show y Next Trip.

Se elige la **Opción B** por consistencia con tu flujo de trabajo actual. Se pierde algo de precisión (el disparo ocurre en el próximo tick del minuto, no en el segundo exacto) y de elegancia (hay que portar una versión mínima de la lógica de recurrencia al Worker), pero se gana no depender de una herramienta nueva para un proyecto personal. Si en algún momento adoptás Wrangler para otra cosa, migrar a la Opción A más adelante es un cambio acotado (mismo modelo de datos, cambia solo el disparo).

## Componentes nuevos

```
Cliente (Next Appointment)          Cloudflare Worker (nuevo)           iPhone
─────────────────────────           ──────────────────────────         ──────
Service Worker                      KV: SUBSCRIPTIONS                  Notificación
 └─ evento 'push' ──────────────────┤   { deviceId → subscription }    del sistema
                                     KV: SCHEDULED
js/push.js (nuevo) ── /subscribe ──▶│   { eventId → { fireAt,
                    ── /schedule ──▶│      title, recurrencia... } }
                    ── /cancel ────▶│
                                     Cron Trigger (cada 1 min)
                                      └─ escanea SCHEDULED,
                                         envía Web Push,
                                         reprograma o borra
```

## Librería de cifrado Web Push

Enviar un push exige firmar un JWT VAPID y cifrar el payload (RFC 8291/8292) — no es viable a mano en el tiempo de este proyecto. Hay librerías ya adaptadas a Workers (Web Crypto API en vez de `node:crypto`): `web-push-neo` y `@block65/webcrypto-web-push` son las dos opciones vigentes que encontré. Cualquiera de las dos sirve; quedará a elección de quien implemente, verificando en ese momento cuál sigue mejor mantenida. **Tarea explícita en `tasks.md` para confirmarlo antes de escribir el Worker**, en vez de asumir una desde ahora — el ecosistema de paquetes cambia y no quiero que el plan quede atado a un nombre que puede haber quedado obsoleto para cuando se implemente.

## Autenticación mínima del Worker

El Worker queda expuesto en internet sin login (FR-009). Para que no cualquiera pueda escribir en el KV, los endpoints `/subscribe` y `/schedule` exigen un header `X-App-Token` fijo, generado una vez y guardado como secret del Worker en el dashboard, embebido también en `js/push.js` del cliente. No es seguridad real (cualquiera que inspeccione el código del cliente lo ve, igual que ya pasa con las claves de las otras Workers de la serie que actúan de proxy) — es una barrera contra bots que escanean endpoints al azar, proporcional a que esto es una app personal sin datos sensibles de terceros.

## Modelo de datos en KV

```jsonc
// SUBSCRIPTIONS: key = deviceId (UUID generado por el cliente y guardado en localStorage)
{
  "endpoint": "...",
  "keys": { "p256dh": "...", "auth": "..." }
}

// SCHEDULED: key = `${deviceId}:${eventId}`
{
  "deviceId": "...",
  "eventId": "...",
  "title": "🎂 Cumple de Juan",
  "fireAt": 1799999999000,        // epoch ms del próximo aviso a enviar
  "recurrenceUnit": "week",       // 'none' si el evento no repite
  "recurrenceInterval": 1,
  "recurrenceEndDate": null,
  "recurrenceMaxCount": null,
  "anchorDate": "2026-09-01T10:00:00"
}
```

`fireAt` ya incluye el `notifyBefore` restado (lo calcula el cliente al programar). El Worker nunca necesita saber cuántos segundos de aviso configuró el usuario — solo el instante exacto en que debe disparar.

## Cambios por archivo

### Nuevo: Worker (proyecto separado, ej. `next-appointment-push-worker`)

- `index.js` (o `src/index.js`):
  - `POST /subscribe` — valida `X-App-Token`, guarda la suscripción en KV `SUBSCRIPTIONS[deviceId]`.
  - `POST /schedule` — valida token, guarda/actualiza `SCHEDULED[deviceId:eventId]`.
  - `POST /cancel` — valida token, borra `SCHEDULED[deviceId:eventId]`.
  - `scheduled(event, env, ctx)` (handler de Cron Trigger) — lista claves de `SCHEDULED` con `fireAt <= now`, para cada una:
    1. Envía el push a la suscripción correspondiente (librería elegida en la tarea de investigación).
    2. Si la respuesta es 404/410 (suscripción inválida), borra esa entrada de `SUBSCRIPTIONS` y todas sus `SCHEDULED` asociadas.
    3. Si el evento no repite (`recurrenceUnit === 'none'`), borra la entrada de `SCHEDULED`.
    4. Si repite, calcula la siguiente ocurrencia con una función **portada** de `Countdown.advanceByRecurrence` + `Countdown.isRecurrenceFinished` (ver más abajo) y actualiza `fireAt`, o borra la entrada si la serie ya está finalizada.
- Lógica de recurrencia portada al Worker: una copia mínima (sin las partes de UI) de `getRecurrence`/`advanceByRecurrence`/`getLastOccurrence`/`isRecurrenceFinished` de `js/countdown.js`. **Riesgo marcado abajo**: mantener dos copias sincronizadas.
- `wrangler.toml` o configuración por dashboard: binding de KV (`SUBSCRIPTIONS`, `SCHEDULED`), secret `APP_TOKEN`, secrets `VAPID_PUBLIC_KEY`/`VAPID_PRIVATE_KEY`, Cron Trigger `* * * * *` (cada minuto).

### `service-worker.js` (Next Appointment)

- Nuevo listener:
  ```js
  self.addEventListener('push', (event) => {
    const data = event.data ? event.data.json() : {};
    event.waitUntil(
      self.registration.showNotification(data.title || 'Next Appointment', {
        body: data.body || '',
        icon: '/icons/icon-192.png',
        badge: '/icons/icon-192.png',
      })
    );
  });

  self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(clients.openWindow('/'));
  });
  ```
- Bump de `CACHE_NAME` (siguiente versión disponible).

### Nuevo: `js/push.js`

- `isInstalledStandalone()` — `window.matchMedia('(display-mode: standalone)').matches || navigator.standalone` (FR-002).
- `getOrCreateDeviceId()` — UUID persistido en `localStorage` (clave nueva, ej. `na_device_id`), generado una sola vez.
- `subscribeToPush()` — pide permiso, `registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: VAPID_PUBLIC_KEY })`, envía el resultado a `/subscribe`.
- `unsubscribeFromPush()` — `subscription.unsubscribe()` local + no hace falta avisar al Worker (las entradas huérfanas se limpian solas en el próximo intento de envío fallido, ver Worker).
- `scheduleEventNotification(event)` — calcula `fireAt` (próxima ocurrencia con `notifyBefore` restado, usando `Countdown.getTargetDate`/`getRecurrence` ya existentes) y hace `POST /schedule`. No hace nada si `notifyBefore` es `null` o push no está activo en este dispositivo.
- `cancelEventNotification(eventId)` — `POST /cancel`.
- La `VAPID_PUBLIC_KEY` (clave pública, segura de exponer) y la URL del Worker quedan como constantes al inicio del archivo.

### `js/app.js`

- En `handleSubmit()`: después de `Storage.upsert(event)`, si push está activo en este dispositivo, llamar `Push.scheduleEventNotification(event)` cuando `notifyBefore` esté configurado, o `Push.cancelEventNotification(event.id)` si se quitó el aviso.
- En `deleteCurrentEvent()`: llamar `Push.cancelEventNotification(id)` antes de `Storage.remove(id)`.
- Nuevo botón en `topbar-actions` de `view-list` (junto a archivo/exportar/importar), ícono `bell`, que abre un modal simple: estado actual (activado/desactivado en este dispositivo) + botón para alternar. Si `!isInstalledStandalone()`, el modal explica que hace falta añadir la app a la pantalla de inicio primero, en vez de mostrar el botón de activar.
- Suprimir el `alert()` de `checkNotifications()` (el aviso en primer plano de hoy) cuando push está activo en este dispositivo, para no duplicar aviso — queda como único mecanismo para quien no activó push (FR-010).

### `index.html`

- Nuevo modal `modal-push-settings` (mismo patrón que los demás modales).
- Nuevo botón `btn-open-push-settings` en `topbar-actions` de `view-list`.
- `<script src="js/push.js"></script>` antes de `js/app.js`.

### `js/icons.js`

- Reutiliza el ícono `bell` que ya existe — no hace falta ninguno nuevo.

## Fuera de alcance para esta iteración

- Notificaciones accionables (botones dentro de la notificación, ej. "posponer").
- Sincronizar el estado de push entre dispositivos (cada dispositivo se activa/desactiva de forma independiente, ver spec.md).
- Analítica o panel de qué avisos se enviaron.

## Riesgos / puntos de atención

- **Duplicación de lógica de recurrencia**: el Worker necesita su propia copia de `advanceByRecurrence`/`isRecurrenceFinished` para poder reprogramar sin el cliente. Si el algoritmo de recurrencia cambia en `js/countdown.js` (ej. una futura feature 004 que salte ocurrencias), hay que replicar el cambio en el Worker. Vale la pena, al implementar, dejar ambas copias con un comentario cruzado ("si tocás esto, tocá también Worker/cliente") en vez de confiar en la memoria.
- **Granularidad de 1 minuto**: un aviso configurado "a 0 minutos" puede llegar hasta 59 segundos después del instante exacto, por el propio ciclo del Cron Trigger. Aceptable para un recordatorio personal; documentarlo en el spec (ya está en SC-001) para no sorprenderse en QA.
- **Límite de Cron Triggers en el plan gratuito**: confirmar al configurar que la cuenta de Cloudflare de Alejandro permite un trigger de cada 1 minuto en el plan Free (los límites de Cloudflare cambian con el tiempo; verificar en el dashboard al momento de crear el trigger, no asumir desde este plan).
- **iOS y notificaciones en primer plano**: falta confirmar en QA real si iOS muestra la notificación del sistema incluso con la PWA abierta en primer plano, o si hace falta lógica adicional para evitar un doble aviso (el de push + el `alert()` de `checkNotifications`, ya cubierto arriba suprimiendo el segundo, pero vale la pena confirmarlo con el dispositivo en mano).
