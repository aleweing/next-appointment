/* =========================================
   Next Appointment — Countdown logic
   ========================================= */

const Countdown = {
  /**
   * Normaliza la recurrencia de un evento a { unit, interval }, con
   * retrocompatibilidad con los dos formatos anteriores:
   * - `recurring: true/false` (formato más antiguo, equivalía a anual)
   * - `recurrence: 'yearly'` (formato intermedio, sin cantidad configurable)
   * @param {Object} event
   * @returns {{unit: 'none'|'day'|'week'|'month'|'year', interval: number}}
   */
  getRecurrence(event) {
    if (event.recurrenceUnit) {
      return {
        unit: event.recurrenceUnit,
        interval: Math.max(1, parseInt(event.recurrenceInterval, 10) || 1),
      };
    }
    // Formato intermedio: 'daily'|'weekly'|'monthly'|'yearly'|'none'
    if (event.recurrence) {
      const LEGACY_MAP = { daily: 'day', weekly: 'week', monthly: 'month', yearly: 'year', none: 'none' };
      return { unit: LEGACY_MAP[event.recurrence] || 'none', interval: 1 };
    }
    // Formato más antiguo: checkbox booleano
    return { unit: event.recurring ? 'year' : 'none', interval: 1 };
  },

  /**
   * Calcula la fecha objetivo de un evento, ajustando
   * a la próxima ocurrencia si es recurrente y ya pasó.
   * @param {Object} event
   * @returns {Date}
   */
  getTargetDate(event) {
    let target = new Date(`${event.date}T${event.time || '00:00'}:00`);
    const { unit, interval } = this.getRecurrence(event);

    if (unit !== 'none') {
      const now = new Date();
      let guard = 0; // evita bucles infinitos ante fechas corruptas
      while (target.getTime() <= now.getTime() && guard < 100000) {
        target = this.advanceByRecurrence(target, unit, interval);
        guard++;
      }
    }

    return target;
  },

  /**
   * Avanza una fecha una "unidad x cantidad" según el tipo de recurrencia.
   * @param {Date} date
   * @param {'day'|'week'|'month'|'year'} unit
   * @param {number} interval - cuántas unidades avanzar (ej. 3 días, 2 semanas)
   * @returns {Date}
   */
  advanceByRecurrence(date, unit, interval = 1) {
    const next = new Date(date);
    switch (unit) {
      case 'day':
        next.setDate(next.getDate() + interval);
        break;
      case 'week':
        next.setDate(next.getDate() + interval * 7);
        break;
      case 'month':
        next.setMonth(next.getMonth() + interval);
        break;
      case 'year':
        next.setFullYear(next.getFullYear() + interval);
        break;
      default:
        break;
    }
    return next;
  },

  /**
   * Devuelve la diferencia en milisegundos entre ahora y la fecha objetivo.
   * Puede ser negativa si ya pasó (y no es recurrente).
   * @param {Object} event
   */
  diffMs(event) {
    const target = this.getTargetDate(event);
    return target.getTime() - Date.now();
  },

  /**
   * Descompone una diferencia en ms en días, horas, minutos y segundos.
   * @param {number} ms
   */
  breakdown(ms) {
    const abs = Math.max(ms, 0);
    const totalSeconds = Math.floor(abs / 1000);

    const days = Math.floor(totalSeconds / 86400);
    const hours = Math.floor((totalSeconds % 86400) / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    return { days, hours, minutes, seconds };
  },

  /**
   * Indica si el evento ya llegó (diferencia <= 0) y no es recurrente.
   * @param {Object} event
   */
  hasElapsed(event) {
    if (this.getRecurrence(event).unit !== 'none') return false;
    return this.diffMs(event) <= 0;
  },

  /**
   * Formatea una fecha legible en español.
   * @param {Object} event
   */
  formatDate(event) {
    const target = this.getTargetDate(event);
    const options = {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    };
    let formatted = target.toLocaleDateString('es-ES', options);
    formatted = formatted.charAt(0).toUpperCase() + formatted.slice(1);

    if (event.time && event.time !== '00:00') {
      formatted += ` · ${event.time}`;
    }
    return formatted;
  },

  /**
   * Texto corto del countdown, ej: "12d 04h 33m"
   * @param {Object} event
   */
  shortLabel(event) {
    if (this.hasElapsed(event)) return '¡Ya llegó! 🎉';

    const ms = this.diffMs(event);
    const { days, hours, minutes } = this.breakdown(ms);

    if (days > 0) return `${days}d ${pad(hours)}h`;
    if (hours > 0) return `${hours}h ${pad(minutes)}m`;
    return `${minutes}m`;
  },
};

function pad(n) {
  return String(n).padStart(2, '0');
}
