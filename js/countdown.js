/* =========================================
   Next Appointment — Countdown logic
   ========================================= */

const Countdown = {
  /**
   * Calcula la fecha objetivo de un evento, ajustando
   * a la próxima ocurrencia si es recurrente y ya pasó.
   * @param {Object} event
   * @returns {Date}
   */
  getTargetDate(event) {
    let target = new Date(`${event.date}T${event.time || '00:00'}:00`);

    if (event.recurring) {
      const now = new Date();
      while (target.getTime() <= now.getTime()) {
        target = new Date(target);
        target.setFullYear(target.getFullYear() + 1);
      }
    }

    return target;
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
    if (event.recurring) return false;
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
