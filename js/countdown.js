/* =========================================
   Next Appointment — Countdown logic
   =========================================

   ⚠️ SINCRONIZACIÓN CON EL WORKER DE PUSH (feature 005)
   Las funciones getRecurrence / advanceByRecurrence / getLastOccurrence /
   isRecurrenceFinished están DUPLICADAS en el Worker
   `next-appointment-push` (sección 3 de su worker.js), que las necesita para
   reprogramar avisos sin el cliente. Si cambiás el algoritmo de recurrencia
   acá, hay que replicar el cambio allá (y al revés).
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
    // Límites opcionales de fin de serie (feature 002). Ausentes o nulos
    // en todos los eventos anteriores: serie indefinida, como siempre.
    const endDate = event.recurrenceEndDate || null;
    const rawMax = parseInt(event.recurrenceMaxCount, 10);
    const maxCount = Number.isFinite(rawMax) && rawMax > 0 ? rawMax : null;

    if (event.recurrenceUnit) {
      return {
        unit: event.recurrenceUnit,
        interval: Math.max(1, parseInt(event.recurrenceInterval, 10) || 1),
        endDate,
        maxCount,
      };
    }
    // Formato intermedio: 'daily'|'weekly'|'monthly'|'yearly'|'none'
    if (event.recurrence) {
      const LEGACY_MAP = { daily: 'day', weekly: 'week', monthly: 'month', yearly: 'year', none: 'none' };
      return { unit: LEGACY_MAP[event.recurrence] || 'none', interval: 1, endDate, maxCount };
    }
    // Formato más antiguo: checkbox booleano
    return { unit: event.recurring ? 'year' : 'none', interval: 1, endDate, maxCount };
  },

  /**
   * Devuelve el ancla de la serie: la primera ocurrencia tal como la
   * introdujo el usuario, sin ningún auto-avance.
   * @param {Object} event
   * @returns {Date}
   */
  getAnchorDate(event) {
    return new Date(`${event.date}T${event.time || '00:00'}:00`);
  },

  /**
   * Calcula la ÚLTIMA ocurrencia válida de una serie recurrente limitada.
   * Devuelve null si el evento no es recurrente o si la serie es indefinida
   * (sin fecha de fin ni número máximo de repeticiones).
   *
   * El conteo de repeticiones NO se guarda en ningún campo: se deriva
   * siempre avanzando desde el ancla con la misma función que usa el resto
   * del countdown, así que es exacto también para meses y años (que no
   * tienen una duración fija en milisegundos).
   *
   * Si están definidos los dos límites, gana el que se cumpla primero:
   * el bucle se detiene en cuanto cualquiera de los dos se alcanza.
   * @param {Object} event
   * @returns {Date|null}
   */
  getLastOccurrence(event) {
    const { unit, interval, endDate, maxCount } = this.getRecurrence(event);
    if (unit === 'none') return null;
    if (!endDate && !maxCount) return null; // serie indefinida

    const end = endDate ? new Date(`${endDate}T23:59:59`) : null;
    const max = maxCount || Infinity;

    let last = this.getAnchorDate(event); // la 1ª ocurrencia siempre existe
    let count = 1;
    let guard = 0;

    while (count < max && guard < 100000) {
      const next = this.advanceByRecurrence(last, unit, interval);
      if (end && next.getTime() > end.getTime()) break; // gana la fecha de fin
      last = next;
      count++;
      guard++;
    }

    return last;
  },

  /**
   * Indica si una serie recurrente ya agotó su límite (por número de
   * repeticiones o por fecha de fin). Función pura: no lee ni escribe
   * ningún contador, solo calcula a partir del ancla y la hora actual.
   * @param {Object} event
   * @returns {boolean}
   */
  isRecurrenceFinished(event) {
    const last = this.getLastOccurrence(event);
    if (!last) return false; // sin límite configurado
    return Date.now() > last.getTime();
  },

  /**
   * Calcula la fecha objetivo de un evento, ajustando
   * a la próxima ocurrencia si es recurrente y ya pasó.
   * @param {Object} event
   * @returns {Date}
   */
  getTargetDate(event) {
    let target = this.getAnchorDate(event);
    const { unit, interval } = this.getRecurrence(event);

    if (unit !== 'none') {
      const last = this.getLastOccurrence(event); // null si la serie es indefinida
      const now = new Date();
      let guard = 0; // evita bucles infinitos ante fechas corruptas
      while (target.getTime() <= now.getTime() && guard < 100000) {
        // Serie limitada: no avanzar más allá de la última ocurrencia válida.
        if (last && target.getTime() >= last.getTime()) break;
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
    if (this.getRecurrence(event).unit !== 'none') {
      // Una serie indefinida nunca "llega": su countdown siempre apunta al
      // futuro. Una serie limitada sí, cuando pasa su última ocurrencia.
      return this.isRecurrenceFinished(event);
    }
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
