/* =========================================
   Next Appointment — Storage (localStorage)
   ========================================= */

const STORAGE_KEY = 'next-appointment:events';
const THEME_KEY = 'next-appointment:theme';

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
};

/**
 * Genera un id único simple.
 */
function generateId() {
  return 'evt_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 8);
}
