/* =========================================
   Next Appointment — Storage (localStorage)
   ========================================= */

const STORAGE_KEY = 'next-appointment:events';
const THEME_KEY = 'next-appointment:theme';
const SORT_KEY = 'next-appointment:sort';
const ONBOARDING_KEY = 'next-appointment:onboarding-seen';

const Storage = {
  /**
   * Devuelve todos los eventos guardados.
   * @returns {Array<Object>}
   */
  getAll() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : [];
    } catch (e) {
      console.error('Error leyendo eventos', e);
      return [];
    }
  },

  /**
   * Guarda la lista completa de eventos.
   * @param {Array<Object>} events
   */
  saveAll(events) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(events));
    } catch (e) {
      console.error('Error guardando eventos', e);
    }
  },

  /**
   * Añade o actualiza un evento.
   * @param {Object} event
   */
  upsert(event) {
    const events = this.getAll();
    const index = events.findIndex((e) => e.id === event.id);
    if (index >= 0) {
      events[index] = event;
    } else {
      events.push(event);
    }
    this.saveAll(events);
    return event;
  },

  /**
   * Elimina un evento por id.
   * @param {string} id
   */
  remove(id) {
    const events = this.getAll().filter((e) => e.id !== id);
    this.saveAll(events);
  },

  /**
   * Busca un evento por id.
   * @param {string} id
   */
  getById(id) {
    return this.getAll().find((e) => e.id === id) || null;
  },

  /**
   * Tema guardado ('light' | 'dark').
   */
  getTheme() {
    return localStorage.getItem(THEME_KEY) || null;
  },

  setTheme(theme) {
    localStorage.setItem(THEME_KEY, theme);
  },

  /**
   * Modo de ordenación de la lista.
   */
  getSortMode() {
    return localStorage.getItem(SORT_KEY) || 'date-asc';
  },

  setSortMode(mode) {
    localStorage.setItem(SORT_KEY, mode);
  },

  /**
   * Indica si ya se mostró el evento de ejemplo de onboarding alguna vez.
   * Una vez visto (creado, editado a propio, o borrado por el usuario),
   * nunca debe volver a generarse, aunque la persona se quede sin eventos.
   */
  hasSeenOnboarding() {
    return localStorage.getItem(ONBOARDING_KEY) === 'true';
  },

  markOnboardingSeen() {
    localStorage.setItem(ONBOARDING_KEY, 'true');
  },

  /**
   * Marca un evento como archivado (se le añade archivedAt con la fecha actual).
   * @param {string} id
   */
  archive(id) {
    const events = this.getAll();
    const event = events.find((e) => e.id === id);
    if (!event) return;
    event.archivedAt = Date.now();
    this.saveAll(events);
  },

  /**
   * Quita la marca de archivado de un evento (lo devuelve a la lista activa).
   * @param {string} id
   */
  unarchive(id) {
    const events = this.getAll();
    const event = events.find((e) => e.id === id);
    if (!event) return;
    delete event.archivedAt;
    this.saveAll(events);
  },

  /**
   * Devuelve solo los eventos NO archivados (lo que se ve en carrusel/lista normal).
   * @returns {Array<Object>}
   */
  getActive() {
    return this.getAll().filter((e) => !e.archivedAt);
  },

  /**
   * Devuelve solo los eventos archivados.
   * @returns {Array<Object>}
   */
  getArchived() {
    return this.getAll().filter((e) => !!e.archivedAt);
  },
};

/**
 * Genera un id único simple.
 */
function generateId() {
  return 'evt_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 8);
}

/**
 * Codifica un evento como string seguro para usar en una URL (base64 + URI safe).
 * Solo se exportan los campos relevantes (no el id local ni flags internos).
 * @param {Object} event
 * @returns {string}
 */
function encodeEventForShare(event) {
  const { unit, interval } = Countdown.getRecurrence(event);
  const payload = {
    name: event.name,
    date: event.date,
    time: event.time,
    emoji: event.emoji,
    color: event.color,
    category: event.category,
    recurrenceUnit: unit,
    recurrenceInterval: interval,
  };
  const json = JSON.stringify(payload);
  const base64 = btoa(unescape(encodeURIComponent(json)));
  return base64;
}

/**
 * Decodifica un string generado por encodeEventForShare.
 * Devuelve null si el formato no es válido.
 * @param {string} encoded
 * @returns {Object|null}
 */
function decodeSharedEvent(encoded) {
  try {
    const json = decodeURIComponent(escape(atob(encoded)));
    const data = JSON.parse(json);
    if (!data.name || !data.date) return null;

    const VALID_UNITS = ['none', 'day', 'week', 'month', 'year'];
    // Soporta el código compartido más reciente (recurrenceUnit/Interval) y,
    // por compatibilidad, enlaces antiguos generados con 'recurrence' o 'recurring'.
    const { unit, interval } = Countdown.getRecurrence(data);

    return {
      name: String(data.name).slice(0, 40),
      date: data.date,
      time: data.time || '00:00',
      emoji: data.emoji || '⏳',
      color: data.color || '#6c5ce7',
      category: data.category || 'other',
      recurrenceUnit: VALID_UNITS.includes(unit) ? unit : 'none',
      recurrenceInterval: Math.max(1, interval || 1),
    };
  } catch (e) {
    return null;
  }
}
