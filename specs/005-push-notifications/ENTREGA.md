# Entrega: Notificaciones push reales (Feature 005)

**Estado**: implementada, pendiente de QA en iPhone (TASK-005-016)
**Fecha**: 2026-09-18

Las 16 tareas de `tasks.md` están implementadas (11 P1 + 5 P2). Este documento
recoge dónde va cada archivo, qué decisiones se tomaron sin consultarte, cómo
verificarlo todo vos solo y qué queda sin verificar.

---

## 1. Qué pegar dónde

### A) Cloudflare (dashboard → Worker `next-appointment-push` → Edit code)

| Archivo entregado | Dónde va |
|---|---|
| `worker.js` | Reemplaza **todo** el contenido del editor (el "Hello World" actual) y pulsá **Deploy**. Es un único archivo, sin imports ni `npm install`. |

No hace falta crear nada más: usa `env.SUBSCRIPTIONS`, `env.SCHEDULED`,
`env.VAPID_PUBLIC_KEY`, `env.VAPID_PRIVATE_KEY` y `env.APP_TOKEN` tal cual.

**Secret opcional** (solo si Apple rechaza los envíos con 403, ver Riesgos):
`VAPID_SUBJECT` = `mailto:tu@email.com`. Si no existe, el Worker usa
`https://aleweing.github.io/next-appointment/` como `sub` del JWT.

### B) Repo de GitHub `aleweing/next-appointment` (zip completo, como siempre)

| Archivo | Ruta exacta | Estado |
|---|---|---|
| `push.js` | `js/push.js` | **nuevo** |
| `app.js` | `js/app.js` | reemplaza |
| `countdown.js` | `js/countdown.js` | reemplaza (solo se añadió el comentario de sincronización con el Worker) |
| `index.html` | `index.html` | reemplaza |
| `service-worker.js` | `service-worker.js` | reemplaza (`CACHE_NAME` → `next-appointment-v16`) |
| `ENTREGA.md` | `specs/005-push-notifications/ENTREGA.md` | nuevo (este documento) |

`js/icons.js`, `js/storage.js`, `js/ui.js` y `css/styles.css` **no cambian**: el
icono `bell` ya existía y el modal reutiliza las clases `modal-overlay` /
`modal-card` / `modal-actions-col` que ya están en el CSS.

### C) ⚙️ Tres constantes que tenés que rellenar a mano

En `js/push.js`, líneas ~25-38 (están marcadas con un bloque de comentario):

```js
const PUSH_WORKER_URL  = 'https://next-appointment-push.TU-SUBDOMINIO.workers.dev';
const PUSH_APP_TOKEN   = 'PEGA-AQUI-EL-MISMO-VALOR-DEL-SECRET-APP_TOKEN';
const VAPID_PUBLIC_KEY = 'PEGA-AQUI-TU-VAPID_PUBLIC_KEY';
```

Mientras estén sin rellenar, la app funciona exactamente como hoy y el modal
de la campana avisa de que falta configurarlo (no rompe nada).

---

## 2. Decisiones tomadas

### D1 — Cifrado Web Push sin librería externa *(desviación de TASK-005-001)*

**Qué evalué**: `web-push-neo` y `@block65/webcrypto-web-push`, las dos
candidatas de `plan.md`.

**Qué decidí**: no usar ninguna. El Worker implementa VAPID (RFC 8292) y el
cifrado `aes128gcm` (RFC 8291 + RFC 8188) directamente con Web Crypto API, en
~150 líneas dentro del propio archivo.

**Por qué**: tu Worker se despliega pegando código en el editor del dashboard,
sin Wrangler y sin paso de build. Ahí no hay `npm install`: un `import` de un
paquete no se resuelve. Cualquiera de las dos librerías obligaría a introducir
exactamente la herramienta que `plan.md` descartó al elegir la Opción B. Las
dos hacen internamente lo mismo que ahora hace el Worker.

**Cómo lo verifiqué** (sustituye al "hola mundo" de la tarea): el cifrado se
contrasta contra el **vector de prueba oficial del RFC 8291 §5**, con sus claves
y su salt fijos: la cabecera y el ciphertext salen **idénticos byte a byte** a
los del RFC. Además se descifra el resultado con la clave privada del "user
agent" del propio RFC y se recupera el texto original. El JWT VAPID se verifica
con `crypto.subtle.verify`. Los scripts están en el zip del Worker
(`tests/`) por si querés volver a correrlos con `node test-worker.mjs`.

### D2 — Worker en un solo archivo *(desviación de TASK-005-006)*

La tarea pedía la recurrencia en su propio `recurrence.js`. Por el mismo motivo
de D1 (se pega un archivo en el dashboard), va todo en `worker.js`, dividido en
7 secciones con cabeceras bien visibles. La sección 3 es la copia de la
recurrencia y lleva el aviso de "si tocás esto, tocá también el cliente"; en
`js/countdown.js` quedó el comentario cruzado equivalente.

### D3 — El modelo de datos de `SCHEDULED` guarda más que `fireAt`

`plan.md` decía que el Worker solo necesita `fireAt` y avanzarlo. No alcanza,
por dos motivos reales:

1. **Zona horaria**: el Worker corre en UTC y vos no. Reinterpretar
   `"2026-09-01T10:00:00"` allá daría 10:00 UTC (dos horas de desfase en
   verano) y el error se acumularía en cada reprogramación.
2. **Meses y años**: avanzar el instante del *aviso* no es lo mismo que avanzar
   la *ocurrencia* y volver a restar el aviso (el caso "31 de enero + 1 mes"
   se desplaza).

Así que cada entrada guarda también `occurrenceLocal`, `anchorLocal`,
`notifyBefore` y `timeZone` (IANA, ej. `Europe/Madrid`). El Worker hace la
aritmética en "hora de pared" —idéntica a la del cliente, incluido el
desbordamiento de meses— y solo al final la convierte a instante real con la
zona horaria, respetando el horario de verano. Verificado con pruebas cruzadas
cliente↔Worker en Madrid y Buenos Aires.

### D4 — El aviso en primer plano que se suprime no es un `alert()`

TASK-005-013 habla de suprimir "el `alert()` de `checkNotifications()`". En el
código real no hay tal `alert`: `checkNotifications()` llama a
`fireNotification()`, que muestra una notificación del sistema vía
`showNotification()`. Es esa la que se suprime cuando el dispositivo tiene push
activo (que era el objetivo: no duplicar el aviso). Sin push, todo sigue igual
(FR-010).

### D5 — Claves de `localStorage` con el prefijo del proyecto

`tasks.md` proponía `na_device_id`. Uso `next-appointment:push-device-id` y
`next-appointment:push-enabled`, por coherencia con las cinco claves que ya
existen en `js/storage.js`.

### D6 — Dos endpoints extra de QA: `/debug` y `/test-push`

Ambos exigen el mismo `X-App-Token`. `GET /debug?deviceId=…` lista lo que hay
programado para ese dispositivo (sirve para comprobar `fireAt` sin bucear en el
dashboard de KV) y `POST /test-push` manda una notificación inmediata a un
dispositivo suscrito. Sin ellos, verificar los escenarios de TASK-005-016 en el
iPhone sería mucho más incómodo.

### D7 — CORS

No estaba en el plan y es imprescindible: la cabecera `X-App-Token` provoca un
*preflight* `OPTIONS`, y sin `Access-Control-Allow-*` el navegador bloquea todas
las llamadas desde GitHub Pages. Se permite cualquier origen (`*`): no hay
cookies ni credenciales, la protección real es el token.

### D8 — Fallos que no son 404/410: se reintenta, pero no para siempre

FR-008 solo habla de suscripciones inválidas. Un 500 del proveedor o un fallo
de red dejarían la entrada reintentándose cada minuto para siempre. Se añadió
un contador: tras **5 intentos fallidos** el aviso se descarta y se registra en
los logs del Worker.

### D9 — Sin ráfagas de avisos atrasados

Si un evento semanal pasa un mes sin que se pueda entregar nada, al reactivarse
se envía **un** aviso y se programa la siguiente ocurrencia futura, en vez de
disparar cuatro notificaciones seguidas de ocurrencias ya pasadas. Misma lógica
en el cliente, que al programar salta los avisos cuyo momento ya pasó (ej.
"avisarme 7 días antes" de un evento que es pasado mañana: no se programa nada
para esa ocurrencia).

### D10 — Sin endpoint `/unsubscribe`

Se sigue `plan.md`: desactivar push solo da de baja la suscripción en el
dispositivo. Las entradas huérfanas se limpian solas en el primer envío fallido
(404/410), que borra la suscripción y **todos** sus avisos pendientes.

### D11 — El caso "aviso a 0 minutos" de la spec

La UI actual no permite configurarlo: `notifyBefore` se guarda como `null` si
el total es 0, así que "0 minutos" equivale hoy a "sin aviso". No cambié la UI
(quedaba fuera del alcance de la feature). El código del Worker y del cliente
tratan el 0 sin ningún caso especial, así que si algún día se permite, funciona.

---

## 3. Checklist de verificación paso a paso

### Fase 0 — Antes de tocar nada (2 min)

1. Copiá `worker.js` en el editor del Worker y pulsá **Deploy**.
2. Abrí `https://next-appointment-push.TU-SUBDOMINIO.workers.dev/` en el
   navegador. Debe responder:
   `{"ok":true,"service":"next-appointment-push","version":"005.1"}`
   ✅ Si ves eso, el deploy funcionó. ❌ Si ves un error, revisá la pestaña
   **Logs** del Worker (real-time logs) antes de seguir.

### Fase 1 — El Worker, con curl (10 min, sin tocar el iPhone)

Definí primero estas variables en tu terminal:

```bash
W="https://next-appointment-push.TU-SUBDOMINIO.workers.dev"
T="el-valor-de-tu-APP_TOKEN"
```

| # | Comando | Resultado esperado |
|---|---|---|
| 1 | `curl -s $W/` | `{"ok":true,...}` |
| 2 | `curl -s -X POST $W/subscribe -d '{}'` | `{"error":"No autorizado"}` (401) |
| 3 | `curl -s -X POST $W/subscribe -H "X-App-Token: mal" -d '{}'` | 401 |
| 4 | `curl -s -X POST $W/schedule -H "X-App-Token: $T" -H "Content-Type: application/json" -d '{"deviceId":"test","eventId":"e1","title":"Prueba","fireAt":9999999999999}'` | `{"ok":true,...}` |
| 5 | `curl -s "$W/debug?deviceId=test" -H "X-App-Token: $T"` | muestra `e1` en `scheduled`, `subscribed:false` |
| 6 | Repetir el 4 con `"fireAt":8888888888888` y volver al 5 | sigue habiendo **una sola** entrada, con el `fireAt` nuevo |
| 7 | `curl -s -X POST $W/cancel -H "X-App-Token: $T" -H "Content-Type: application/json" -d '{"deviceId":"test","eventId":"e1"}'` | `{"ok":true}` |
| 8 | Repetir el 7 (cancelar algo ya cancelado) | `{"ok":true}`, sin error |
| 9 | Volver al 5 | `scheduled: []` |

✅ Si los 9 pasan, los endpoints, el token y el KV están bien.

### Fase 2 — Un push real, en el escritorio (10 min)

Antes del iPhone, porque iterar acá es mucho más rápido.

1. Subí el zip completo al repo y esperá a que GitHub Pages publique.
2. Abrí la app en **Chrome de escritorio** e **instalala** (icono de instalar en
   la barra de direcciones). Hay que abrirla desde la ventana instalada: en una
   pestaña normal el modal dirá, correctamente, que primero hay que instalarla.
3. En la vista de lista, tocá el icono 🔔 → **Activar notificaciones push** →
   aceptá el permiso del navegador.
   ✅ El modal debe pasar a "✅ Notificaciones push activadas".
4. Comprobá el registro en el Worker. El `deviceId` está en la consola:
   `localStorage.getItem('next-appointment:push-device-id')`.
   ```bash
   curl -s "$W/debug?deviceId=EL-DEVICE-ID" -H "X-App-Token: $T"
   ```
   ✅ `subscribed: true`.
5. Notificación de prueba inmediata:
   ```bash
   curl -s -X POST $W/test-push -H "X-App-Token: $T" -H "Content-Type: application/json" \
     -d '{"deviceId":"EL-DEVICE-ID"}'
   ```
   ✅ Debe aparecer la notificación del sistema en el escritorio y devolver
   `{"status":201,"ok":true,...}`.
   ❌ Si devuelve `ok:false` con 401/403, el problema son las claves VAPID (ver
   Riesgos R1).
6. Creá un evento con aviso a 2 minutos y comprobá con `/debug` que aparece en
   `scheduled` con su `fireAtISO` correcto.
   ✅ Esperá: la notificación debe llegar dentro del minuto siguiente a esa hora.
   Cerrá la ventana de la app mientras esperás: debe llegar igual.

### Fase 3 — Los 5 escenarios de QA en el iPhone (TASK-005-016)

Recordá: para cada comprobación de `fireAt` usá
`curl -s "$W/debug?deviceId=EL-DEVICE-ID-DEL-IPHONE" -H "X-App-Token: $T"`
(el `deviceId` del iPhone es distinto al del escritorio; se ve en el Web
Inspector con `localStorage.getItem('next-appointment:push-device-id')`).

1. **Aviso con la app cerrada**: instalá la app en pantalla de inicio, abrila
   desde ese icono, activá push desde 🔔, creá un evento con aviso a 2 minutos
   y **cerrá la app del todo** (deslizar hacia arriba, no solo bloquear).
   ✅ Llega la notificación con el nombre del evento.
2. **Serie recurrente**: creá una serie que repita **cada día** con aviso a 2
   minutos (para no esperar una semana), anotá el `fireAt` de `/debug`, esperá
   la notificación y volvé a mirar `/debug`.
   ✅ Llega el aviso y el `fireAt` pasa a ser el del día siguiente, sin que
   hayas abierto la app.
3. **Editar la fecha**: con un aviso pendiente, cambiá la hora del evento a 3
   minutos más tarde y guardá.
   ✅ En `/debug` el `fireAt` cambia al horario nuevo; la notificación llega en
   el horario nuevo y **no** en el viejo.
4. **Borrar el evento**: con un aviso pendiente, borralo.
   ✅ Desaparece de `/debug` y no llega ninguna notificación.
5. **Permiso revocado**: Ajustes de iOS → Notificaciones → Next Appointment →
   desactivar. Creá (antes de revocar) un evento con aviso a 2 minutos y esperá.
   ✅ En los logs del Worker aparece `suscripción caducada (410), limpiando …`
   y en `/debug` desaparecen la suscripción y todos los avisos de ese
   dispositivo. No se acumulan errores en ticks siguientes.
   ⚠️ Puede que iOS tarde en invalidar el endpoint: si el Worker sigue
   recibiendo 201, volvé a abrir la app, desactivá push desde 🔔 y repetí.

### Fase 4 — Regresión (5 min)

6. Desactivá push desde 🔔 (o probá en un dispositivo sin activarlo): creá un
   evento con aviso a 2 minutos y dejá la app abierta.
   ✅ Sigue llegando el aviso en primer plano, como antes de esta feature.
7. Con push activo y la app abierta: ✅ llega **una sola** notificación (la del
   sistema), no dos.
8. Modo avión: creá, editá y borrá un evento con aviso.
   ✅ Todo se guarda igual, sin errores visibles (solo avisos en consola).

---

## 4. Riesgos conocidos

Lo que **sí** pude verificar: el cifrado contra el vector oficial del RFC 8291,
la firma VAPID, la paridad exacta de la recurrencia entre cliente y Worker (los
casos de la feature 002 más 25 avances encadenados por caso), la conversión de
zona horaria con horario de verano, y una simulación completa del Worker con
un KV en memoria y un servicio de push falso (alta, programación, cancelación,
cron, reprogramación, series agotadas, 410, fallos aislados). En total 103
comprobaciones automáticas, todas en verde.

Lo que **no** pude verificar y conviene tener presente:

**R1 — Formato de tus claves VAPID.** No las he visto. El Worker acepta los dos
formatos habituales (escalar de 32 bytes en base64url, que es lo que genera
`web-push`, y PKCS#8 en base64). Si las generaste con otra herramienta y el
formato es distinto, `/test-push` devolverá un error de importación de clave:
lo verás claro en la respuesta JSON. Solución: regenerar el par con el
generador estándar y actualizar los dos secrets + `VAPID_PUBLIC_KEY` en
`js/push.js`.

**R2 — El `sub` del JWT y Apple.** Apple es la más estricta con el claim `sub`.
Por defecto va la URL de la app. Si los envíos al endpoint
`web.push.apple.com` devuelven **403**, creá el secret `VAPID_SUBJECT` con
`mailto:tu@email.com` y volvé a probar. No hace falta tocar el código.

**R3 — No he ejecutado nada en el runtime real de Cloudflare.** Las pruebas
corrieron en Node 22 con Web Crypto, que implementa las mismas APIs, y con un
KV simulado. Diferencias posibles: comportamiento exacto de `list()` con más de
1000 claves (no te va a pasar) y los límites de CPU del plan Free (el Worker
procesa como máximo 50 avisos por tick para no acercarse a ellos).

**R4 — Consistencia eventual del KV.** Una escritura puede tardar hasta ~60
segundos en verse desde otra región. En la práctica: si editás un evento y su
aviso era inminente (menos de un minuto), el cron podría usar todavía el valor
anterior y mandar el aviso viejo. Para avisos con minutos u horas de margen no
se nota. No lo he podido medir en producción.

**R5 — Granularidad de 1 minuto.** Ya estaba en el plan (SC-001): el aviso puede
llegar hasta 59 segundos tarde. Además, el Cron Trigger de Cloudflare no
garantiza puntualidad al segundo y bajo carga puede retrasarse algo más.

**R6 — iOS en primer plano.** Sigue sin estar confirmado con el dispositivo en
mano si iOS muestra la notificación del sistema con la PWA abierta en primer
plano. La duplicación que dependía de nosotros ya está resuelta (D4), pero el
comportamiento de iOS en sí solo se ve probando: es el punto 7 de la Fase 4.

**R7 — Reinstalar la app.** Si borrás la PWA de la pantalla de inicio y la
volvés a instalar, iOS puede generar un `deviceId` nuevo (localStorage se
pierde). La suscripción vieja queda en el KV hasta que su primer envío falle
con 410 y se limpie sola. No molesta, pero explica que `/debug` muestre
dispositivos "fantasma" un tiempo.

**R8 — Límite de Cron Triggers en el plan Free.** Ya lo tenés creado y activo,
así que está resuelto de hecho; queda anotado porque los límites de Cloudflare
cambian y el Worker depende de que ese trigger siga corriendo cada minuto.
