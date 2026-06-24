/* =========================================
   Next Appointment — Iconos SVG inline (estilo Tabler)
   ========================================= */

/**
 * Iconos de la interfaz como SVG inline, sin dependencias externas.
 * Todos usan stroke="currentColor" para heredar el color del texto
 * del botón que los contiene (así respetan el tema claro/oscuro).
 *
 * ⚠️ Estos son iconos de CONTROLES de la interfaz (editar, compartir,
 * tema, etc.). Los emojis elegidos por el usuario para sus eventos y
 * categorías (🎂✈️🎉...) se mantienen como emoji, no se tocan aquí.
 */
const Icons = {
  moon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1 -9 -9z"/></svg>',

  sun: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 3v1M12 20v1M3 12h1M20 12h1M5.6 5.6l.7.7M17.7 17.7l.7.7M5.6 18.4l.7-.7M17.7 6.3l.7-.7"/></svg>',

  list: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01"/></svg>',

  plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>',

  arrowLeft: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M5 12l6-6M5 12l6 6"/></svg>',

  trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M10 11v6M14 11v6M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2l1-12M9 7V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v3"/></svg>',

  pencil: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/><path d="M15 5l4 4"/></svg>',

  share: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="M8.2 10.8l7.6-4.6M8.2 13.2l7.6 4.6"/></svg>',

  bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 18a2 2 0 0 0 4 0"/><path d="M6 17v-6a6 6 0 1 1 12 0v6l1.5 2h-15Z"/></svg>',

  bellOff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 18a2 2 0 0 0 4 0"/><path d="M9 6.3A6 6 0 0 1 18 11v6l1.5 2h-4"/><path d="M6 9v2l-1.5 6h9"/><path d="M3 3l18 18"/></svg>',

  download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12M7 11l5 5 5-5"/><path d="M5 19h14"/></svg>',

  upload: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3M7 7l5-5 5 5"/><path d="M5 19h14"/></svg>',

  search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="10" r="6"/><path d="M20 20l-5.5-5.5"/></svg>',

  x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 5l14 14M19 5L5 19"/></svg>',

  hourglassEmpty: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h12M6 21h12"/><path d="M7 3c0 5 4 6 5 9 1-3 5-4 5-9"/><path d="M7 21c0-5 4-6 5-9 1 3 5 4 5 9"/></svg>',

  moodEmpty: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M9 10h.01M15 10h.01M9 16h6"/></svg>',

  searchOff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="10" r="6"/><path d="M20 20l-5.5-5.5M3 3l18 18"/></svg>',

  archive: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9"/><path d="M10 13h4"/></svg>',

  rotateCcw: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9a8 8 0 1 1 1.5 6.5"/><path d="M4 4v5h5"/></svg>',
};

/**
 * Inserta un icono dentro de un elemento, reemplazando su contenido.
 * Defensivo: si por algún motivo el set de iconos no estuviera disponible
 * (ej. caché desincronizada de una actualización a medias), no debe romper
 * el resto de la app — simplemente deja el botón sin icono visual.
 * @param {HTMLElement} el
 * @param {string} iconName - clave de Icons
 */
function setIcon(el, iconName) {
  try {
    if (!el) return;
    const svg = (typeof Icons !== 'undefined' && Icons[iconName]) || '';
    el.innerHTML = svg;
    el.classList.add('icon-svg-wrap');
  } catch (e) {
    console.warn('No se pudo aplicar el icono', iconName, e);
  }
}
