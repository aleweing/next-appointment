/* =========================================
   Next Appointment — Notificaciones push (feature 005)
   =========================================

   Cliente del Worker `next-appointment-push`. Se ocupa de:
   - detectar si la app está instalada en pantalla de inicio (iOS lo exige),
   - identificar este dispositivo con un UUID propio,
   - suscribirse / desuscribirse de las notificaciones del sistema,
   - avisar al Worker de qué evento hay que notificar y cuándo.

   Todo lo que habla con el Worker va en try/catch: si el Worker no responde,
   la app debe seguir funcionando exactamente igual (guardar, editar y borrar
   eventos en local nunca depende de la red).
   ========================================= */

/* ─────────────────────────────────────────────────────────────────────────
   ⚙️ CONFIGURACIÓN — los tres valores que hay que rellenar una sola vez.
   (Ver el apartado "Qué pegar dónde" de la entrega de la feature 005.)
   ───────────────────────────────────────────────────────────────────────── */

// URL pública del Worker, sin barra final.
// Ej: 'https://next-appointment-push.alejandro.workers.dev'
const PUSH_WORKER_URL = 'https://next-appointment-push.alewein.workers.dev';

// Mismo valor que el secret APP_TOKEN del Worker.
// No es seguridad real (se ve en el código del cliente): solo evita que
// bots que escanean endpoints al azar escriban en el KV.
const PUSH_APP_TOKEN = 'PFK3gaeJ6W8eCyzhgx+0lF0uXd5LUACc60EXlV+r5vA=';

// Clave pública VAPID (la pública se puede exponer sin problema).
// Mismo valor que el secret VAPID_PUBLIC_KEY del Worker.
const VAPID_PUBLIC_KEY = 'BLciEqyQZCuMhFLJwwG1GR4Y8dTajxPvFniTob7XT05ZRwG7N_aVyqNg60oo8HSpxU8KmlendPPeutCxGn8iugE';

/* ───────────────────────────────────────────────────────────────────────── */

const PUSH_DEVICE_ID_KEY = 'next-appointment:push-device-id';
const PUSH_ENABLED_KEY = 'next-appointment:push-enabled';

const Push = {
  /** ¿Están rellenados los tres valores de configuración de arriba? */
  isConfigured() {
    return !PUSH_WORKER_URL.includes('alewein')
      && !PUSH_APP_TOKEN.startsWith('PPFK3gaeJ6W8eCyzhgx+0lF0uXd5LUACc60EXlV+r5vA=')
      && !VAPID_PUBLIC_KEY.startsWith('BLciEqyQZCuMhFLJwwG1GR4Y8dTajxPvFniTob7XT05ZRwG7N_aVyqNg60oo8HSpxU8KmlendPPeutCxGn8iugE');
  },

  /** ¿Este navegador soporta push del sistema? */
  isSupported() {
    return 'serviceWorker' in navigator
      && 'PushManager' in window
      && 'Notification' in window;
  },

  /**
   * ¿La app está abierta como PWA instalada en la pantalla de inicio?
   * iOS solo permite push en ese modo, no en una pestaña normal de Safari (FR-002).
   */
  isInstalledStandalone() {
    try {
      return window.matchMedia('(display-mode: standalone)').matches
        || window.navigator.standalone === true;
    } catch (e) {
      return false;
    }
  },

  /**
   * Identidad de este dispositivo: un UUID generado una sola vez y
   * persistido en localStorage. No hay cuentas de usuario (FR-009).
   */
  getOrCreateDeviceId() {
    let id = null;
    try {
      id = localStorage.getItem(PUSH_DEVICE_ID_KEY);
    } catch (e) {
      /* localStorage bloqueado: seguimos con un id efímero */
    }
    if (id) return id;

    id = (crypto && crypto.randomUUID)
      ? crypto.randomUUID()
      : 'dev_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10);

    try {
      localStorage.setItem(PUSH_DEVICE_ID_KEY, id);
    } catch (e) { /* ignorar */ }
    return id;
  },

  /**
   * ¿Este dispositivo tiene push activo? Es una lectura SÍNCRONA (se consulta
   * en cada tick del countdown), por eso se guarda una bandera en localStorage
   * en vez de preguntar al PushManager, que es asíncrono.
   */
  isEnabled() {
    try {
      return localStorage.getItem(PUSH_ENABLED_KEY) === 'true';
    } catch (e) {
      return false;
    }
  },

  _setEnabled(value) {
    try {
      localStorage.setItem(PUSH_ENABLED_KEY, value ? 'true' : 'false');
    } catch (e) { /* ignorar */ }
  },

  /**
   * Se llama una vez al arrancar la app:
   * 1. Sincroniza la bandera local con la suscripción real del navegador
   *    (el usuario puede haber revocado el permiso desde Ajustes de iOS).
   * 2. Si el push sigue activo, reprograma todos los avisos pendientes en el
   *    Worker (TASK-005-014): cubre eventos creados antes de activar push y
   *    cualquier desincronización. El Worker sobreescribe, así que reenviar
   *    lo ya programado es inocuo.
   */
  async init(events) {
    if (!this.isSupported() || !this.isConfigured()) {
      this._setEnabled(false);
      return;
    }

    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();
      const granted = Notification.permission === 'granted';
      const active = Boolean(subscription) && granted;

      this._setEnabled(active);
      if (active) await this.resyncAll(events || []);
    } catch (e) {
      console.warn('[push] no se pudo comprobar el estado de la suscripción', e);
    }
  },

  /**
   * Activa las notificaciones push en este dispositivo.
   * @returns {Promise<{ok: boolean, reason?: string}>}
   */
  async subscribeToPush() {
    if (!this.isSupported()) return { ok: false, reason: 'unsupported' };
    if (!this.isConfigured()) return { ok: false, reason: 'not-configured' };
    if (!this.isInstalledStandalone()) return { ok: false, reason: 'not-standalone' };

    try {
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') return { ok: false, reason: 'denied' };

      const registration = await navigator.serviceWorker.ready;

      let subscription = await registration.pushManager.getSubscription();
      if (!subscription) {
        subscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: this._urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
        });
      }

      const sent = await this._post('/subscribe', {
        deviceId: this.getOrCreateDeviceId(),
        subscription: subscription.toJSON(),
      });
      if (!sent.ok) return { ok: false, reason: 'worker-error' };

      this._setEnabled(true);
      return { ok: true };
    } catch (e) {
      console.warn('[push] error al suscribirse', e);
      return { ok: false, reason: 'error' };
    }
  },

  /**
   * Desactiva las notificaciones push en este dispositivo.
   * No hace falta avisar al Worker: al quedar la suscripción inválida, el
   * primer envío fallido (404/410) limpia sus entradas automáticamente.
   */
  async unsubscribeFromPush() {
    this._setEnabled(false);
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();
      if (subscription) await subscription.unsubscribe();
      return { ok: true };
    } catch (e) {
      console.warn('[push] error al desuscribirse', e);
      return { ok: false };
    }
  },

  /**
   * Programa (o reprograma) el aviso de un evento en el Worker.
   * No hace nada si el evento no tiene aviso o si push no está activo aquí.
   * @param {Object} event
   */
  async scheduleEventNotification(event) {
    if (!this.isEnabled() || !event) return;

    if (!event.notifyBefore) {
      await this.cancelEventNotification(event.id);
      return;
    }

    const next = this.computeNextFire(event);
    if (!next) {
      // Ya no quedan avisos futuros para este evento (serie terminada o
      // aviso cuyo momento ya pasó): mejor cancelar que dejar basura.
      await this.cancelEventNotification(event.id);
      return;
    }

    const { unit, interval, endDate, maxCount } = Countdown.getRecurrence(event);

    await this._post('/schedule', {
      deviceId: this.getOrCreateDeviceId(),
      eventId: event.id,
      title: `${event.emoji || '⏳'} ${event.name}`,
      body: this.notificationBody(event),
      fireAt: next.fireAt,
      occurrenceLocal: next.occurrenceLocal,
      anchorLocal: this.toWallClock(Countdown.getAnchorDate(event)),
      notifyBefore: Number(event.notifyBefore) || 0,
      timeZone: this.getTimeZone(),
      recurrenceUnit: unit,
      recurrenceInterval: interval,
      recurrenceEndDate: endDate,
      recurrenceMaxCount: maxCount,
    });
  },

  /** Cancela el aviso pendiente de un evento en este dispositivo. */
  async cancelEventNotification(eventId) {
    if (!this.isEnabled() || !eventId) return;
    await this._post('/cancel', {
      deviceId: this.getOrCreateDeviceId(),
      eventId,
    });
  },

  /**
   * Reprograma en el Worker todos los eventos activos con aviso configurado.
   * @param {Array<Object>} events
   */
  async resyncAll(events) {
    const withNotify = (events || []).filter((e) => !e.archivedAt && e.notifyBefore);
    for (const event of withNotify) {
      await this.scheduleEventNotification(event);
    }
  },

  /**
   * Calcula el próximo aviso realmente futuro de un evento.
   * @param {Object} event
   * @returns {{fireAt: number, occurrenceLocal: string}|null}
   */
  computeNextFire(event) {
    const notifyMs = (Number(event.notifyBefore) || 0) * 1000;
    const { unit, interval } = Countdown.getRecurrence(event);
    const last = Countdown.getLastOccurrence(event); // null = serie indefinida

    let target = Countdown.getTargetDate(event);
    let guard = 0;

    // Si el momento del aviso ya pasó (ej. "avisar 7 días antes" de un evento
    // que es pasado mañana), saltamos a la siguiente ocurrencia con aviso
    // futuro. En un evento no recurrente eso significa que ya no hay aviso.
    while (target.getTime() - notifyMs <= Date.now() && guard < 1000) {
      if (unit === 'none') return null;
      const next = Countdown.advanceByRecurrence(target, unit, interval);
      if (last && next.getTime() > last.getTime()) return null; // serie agotada
      target = next;
      guard++;
    }
    if (guard >= 1000) return null;

    return {
      fireAt: target.getTime() - notifyMs,
      occurrenceLocal: this.toWallClock(target),
    };
  },

  /** Texto del cuerpo de la notificación, fijo para todas las ocurrencias. */
  notificationBody(event) {
    const seconds = Number(event.notifyBefore) || 0;
    if (seconds <= 0) return '¡Es ahora!';

    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    const parts = [];
    if (days) parts.push(`${days} día${days !== 1 ? 's' : ''}`);
    if (hours) parts.push(`${hours} hora${hours !== 1 ? 's' : ''}`);
    if (minutes) parts.push(`${minutes} minuto${minutes !== 1 ? 's' : ''}`);

    return `Queda${parts.length === 1 && parts[0].startsWith('1 ') ? '' : 'n'} ${parts.join(' y ')} para este evento.`;
  },

  /** Zona horaria IANA de este dispositivo (la usa el Worker para reprogramar). */
  getTimeZone() {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
    } catch (e) {
      return 'UTC';
    }
  },

  /** Date → "YYYY-MM-DDTHH:mm:ss" en hora local (hora de pared del usuario). */
  toWallClock(date) {
    const p = (n) => String(n).padStart(2, '0');
    return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}`
      + `T${p(date.getHours())}:${p(date.getMinutes())}:${p(date.getSeconds())}`;
  },

  /** POST al Worker. Nunca lanza: un fallo de red no puede romper la app. */
  async _post(path, body) {
    if (!this.isConfigured()) return { ok: false };
    try {
      const response = await fetch(`${PUSH_WORKER_URL}${path}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-App-Token': PUSH_APP_TOKEN,
        },
        body: JSON.stringify(body),
      });
      if (!response.ok) console.warn(`[push] ${path} respondió ${response.status}`);
      return { ok: response.ok, status: response.status };
    } catch (e) {
      console.warn(`[push] no se pudo contactar al Worker (${path})`, e);
      return { ok: false };
    }
  },

  /** base64url (VAPID pública) → Uint8Array, que es lo que pide pushManager */
  _urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const raw = atob(base64);
    const output = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) output[i] = raw.charCodeAt(i);
    return output;
  },
};
