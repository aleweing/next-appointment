/* =========================================
   Next Appointment — UI rendering helpers
   ========================================= */

const EMOJI_OPTIONS = [
  '⏳', '🎂', '✈️', '🎓', '🎬', '💒', '🏠', '🍾',
  '💼', '🎮', '🎉', '❤️', '🌴', '🎄', '🐣', '🎁',
];

const COLOR_OPTIONS = [
  '#6c5ce7', '#e17055', '#00b894', '#0984e3',
  '#fdcb6e', '#e84393', '#2d3436', '#00cec9',
];

/**
 * ⚠️ ÚNICO LUGAR A EDITAR para añadir, quitar o renombrar categorías.
 * Cada categoría es { id, label, emoji }.
 * - "id" se guarda en los eventos y NO debe cambiarse una vez en uso
 *   (si lo cambias, los eventos ya creados con ese id quedarán como "Otros").
 * - "label" es el texto visible, se puede cambiar libremente.
 * - "emoji" se usa como icono en los chips de filtro.
 * El id 'other' siempre debe existir: es el valor por defecto/fallback.
 */
const CATEGORIES = [
  { id: 'birthday', label: 'Cumpleaños', emoji: '🎂' },
  { id: 'health', label: 'Salud', emoji: '🩺' },
  { id: 'party', label: 'Fiestas', emoji: '🎉' },
  { id: 'fair', label: 'Ferias', emoji: '🎪' },
  { id: 'festival', label: 'Festivales', emoji: '🎶' },
  { id: 'travel', label: 'Viajes', emoji: '✈️' },
  { id: 'other', label: 'Otros', emoji: '⏳' },
];

const DEFAULT_CATEGORY_ID = 'other';

/**
 * Devuelve el objeto de categoría a partir de su id, con fallback a "Otros".
 * @param {string} id
 */
function getCategoryById(id) {
  return CATEGORIES.find((c) => c.id === id) || CATEGORIES.find((c) => c.id === DEFAULT_CATEGORY_ID);
}

/**
 * Devuelve la etiqueta corta visible para un tipo de recurrencia.
 * @param {'none'|'daily'|'weekly'|'monthly'|'yearly'} recurrence
 */
function recurrenceLabel(recurrence) {
  switch (recurrence) {
    case 'daily': return 'Diario';
    case 'weekly': return 'Semanal';
    case 'monthly': return 'Mensual';
    case 'yearly': return 'Anual';
    default: return '';
  }
}

const UI = {
  /**
   * Cambia la vista activa, con una transición de slide.
   * @param {string} viewId
   * @param {'left'|'right'|null} direction - dirección de la animación de entrada
   */
  showView(viewId, direction = 'right') {
    document.querySelectorAll('.view').forEach((el) => {
      el.classList.remove('view-active', 'view-slide-in-right', 'view-slide-in-left');
    });
    const target = document.getElementById(viewId);
    if (target) {
      target.classList.add('view-active');
      if (direction === 'left') {
        target.classList.add('view-slide-in-left');
      } else if (direction === 'right') {
        target.classList.add('view-slide-in-right');
      }
    }
    window.scrollTo(0, 0);
  },

  /**
   * Aplica el tema (light/dark) al documento.
   * @param {'light'|'dark'} theme
   */
  applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    const btn = document.getElementById('btn-theme');
    if (btn) btn.textContent = theme === 'dark' ? '☀️' : '🌙';
  },

  /**
   * Renderiza el carrusel principal con todas las cards de eventos.
   * @param {Array<Object>} events
   */
  renderCarousel(events) {
    const carousel = document.getElementById('event-carousel');
    const dotsContainer = document.getElementById('carousel-dots');
    const emptyState = document.getElementById('empty-state');

    carousel.innerHTML = '';
    dotsContainer.innerHTML = '';

    if (!events.length) {
      emptyState.classList.remove('hidden');
      carousel.classList.add('hidden');
      dotsContainer.classList.add('hidden');
      return;
    }

    emptyState.classList.add('hidden');
    carousel.classList.remove('hidden');
    dotsContainer.classList.remove('hidden');

    const sorted = [...events].sort(
      (a, b) => Countdown.diffMs(a) - Countdown.diffMs(b)
    );

    sorted.forEach((event, i) => {
      carousel.appendChild(this.buildEventCard(event));

      const dot = document.createElement('div');
      dot.className = 'dot' + (i === 0 ? ' active' : '');
      dotsContainer.appendChild(dot);
    });

    // Sync dots with scroll position (el gesto de swipe lo gestiona
    // el navegador de forma nativa vía scroll-snap en CSS; aquí solo
    // escuchamos el scroll para mantener los puntos sincronizados)
    carousel.onscroll = () => {
      const index = Math.round(carousel.scrollLeft / carousel.clientWidth);
      [...dotsContainer.children].forEach((dot, i) => {
        dot.classList.toggle('active', i === index);
      });
    };
  },

  /**
   * Crea el elemento DOM de una card de evento (vista principal).
   * @param {Object} event
   */
  buildEventCard(event) {
    const card = document.createElement('div');
    card.className = 'event-card';
    card.style.setProperty('--accent-color', event.color || '#6c5ce7');
    card.dataset.id = event.id;

    const elapsed = Countdown.hasElapsed(event);
    if (elapsed) card.classList.add('elapsed');

    const category = getCategoryById(event.category);
    const categoryBadge = document.createElement('div');
    categoryBadge.className = 'card-category-badge';
    categoryBadge.textContent = `${category.emoji} ${category.label}`;
    card.appendChild(categoryBadge);

    const recurrence = Countdown.getRecurrence(event);
    if (recurrence !== 'none') {
      const badge = document.createElement('div');
      badge.className = 'card-badge';
      badge.textContent = `🔁 ${recurrenceLabel(recurrence)}`;
      card.appendChild(badge);
    }

    const emoji = document.createElement('div');
    emoji.className = 'card-emoji';
    emoji.textContent = event.emoji || '⏳';
    card.appendChild(emoji);

    const name = document.createElement('div');
    name.className = 'card-name';
    name.textContent = event.name;
    card.appendChild(name);

    const countdownWrap = document.createElement('div');
    countdownWrap.className = 'card-countdown-units';
    countdownWrap.dataset.role = 'countdown';
    card.appendChild(countdownWrap);

    const date = document.createElement('div');
    date.className = 'card-date';
    date.textContent = Countdown.formatDate(event);
    card.appendChild(date);

    const actions = document.createElement('div');
    actions.className = 'card-actions';

    const editBtn = document.createElement('button');
    editBtn.className = 'icon-btn';
    editBtn.textContent = '✏️';
    editBtn.setAttribute('aria-label', 'Editar');
    editBtn.onclick = () => App.openEditForm(event.id);
    actions.appendChild(editBtn);

    const shareBtn = document.createElement('button');
    shareBtn.className = 'icon-btn';
    shareBtn.textContent = '📤';
    shareBtn.setAttribute('aria-label', 'Compartir');
    shareBtn.onclick = () => App.shareEvent(event.id);
    actions.appendChild(shareBtn);

    const notifyBtn = document.createElement('button');
    notifyBtn.className = 'icon-btn';
    notifyBtn.textContent = event.notifyBefore ? '🔔' : '🔕';
    if (event.notifyBefore) notifyBtn.classList.add('notify-active');
    notifyBtn.setAttribute('aria-label', 'Aviso');
    notifyBtn.onclick = () => App.openEditForm(event.id);
    actions.appendChild(notifyBtn);

    card.appendChild(actions);

    this.updateCardCountdown(card, event);

    return card;
  },

  /**
   * Actualiza los números del countdown dentro de una card.
   * @param {HTMLElement} card
   * @param {Object} event
   */
  updateCardCountdown(card, event) {
    const wrap = card.querySelector('[data-role="countdown"]');
    if (!wrap) return;

    if (Countdown.hasElapsed(event)) {
      wrap.innerHTML = '<div class="card-countdown">🎉 ¡Ya llegó el día!</div>';
      return;
    }

    const ms = Countdown.diffMs(event);
    const { days, hours, minutes, seconds } = Countdown.breakdown(ms);

    wrap.innerHTML = '';
    const units = [
      { value: days, label: 'Días' },
      { value: hours, label: 'Horas' },
      { value: minutes, label: 'Min' },
      { value: seconds, label: 'Seg' },
    ];

    units.forEach((u) => {
      const unitEl = document.createElement('div');
      unitEl.className = 'countdown-unit';

      const value = document.createElement('div');
      value.className = 'countdown-value';
      value.textContent = String(u.value).padStart(2, '0');

      const label = document.createElement('div');
      label.className = 'countdown-label';
      label.textContent = u.label;

      unitEl.appendChild(value);
      unitEl.appendChild(label);
      wrap.appendChild(unitEl);
    });
  },

  /**
   * Ordena eventos según el modo elegido.
   * @param {Array<Object>} events
   * @param {string} sortMode
   * @returns {Array<Object>}
   */
  sortEvents(events, sortMode) {
    const list = [...events];
    switch (sortMode) {
      case 'date-desc':
        return list.sort((a, b) => Countdown.diffMs(b) - Countdown.diffMs(a));
      case 'name':
        return list.sort((a, b) => a.name.localeCompare(b.name, 'es', { sensitivity: 'base' }));
      case 'created':
        return list.sort((a, b) => {
          const aTime = parseInt((a.id || '').split('_')[1] || '0', 36);
          const bTime = parseInt((b.id || '').split('_')[1] || '0', 36);
          return bTime - aTime;
        });
      case 'date-asc':
      default:
        return list.sort((a, b) => Countdown.diffMs(a) - Countdown.diffMs(b));
    }
  },

  /**
   * Marca el chip de ordenación activo.
   * @param {string} sortMode
   */
  renderSortBar(sortMode) {
    document.querySelectorAll('.sort-chip').forEach((chip) => {
      chip.classList.toggle('active', chip.dataset.sort === sortMode);
    });
  },

  /**
   * Renderiza la lista completa de eventos (vista lista).
   * @param {Array<Object>} events
   * @param {string} sortMode - 'date-asc' | 'date-desc' | 'name' | 'created'
   * @param {string} categoryFilter - 'all' o id de categoría
   */
  renderList(events, sortMode = 'date-asc', categoryFilter = 'all') {
    const list = document.getElementById('event-list');
    const emptyState = document.getElementById('list-empty-state');

    list.innerHTML = '';

    const filtered = categoryFilter === 'all'
      ? events
      : events.filter((e) => (e.category || DEFAULT_CATEGORY_ID) === categoryFilter);

    if (!filtered.length) {
      emptyState.classList.remove('hidden');
      emptyState.querySelector('p:last-of-type').textContent = events.length
        ? 'No hay eventos en esta categoría.'
        : 'No hay eventos creados todavía.';
      return;
    }
    emptyState.classList.add('hidden');

    const sorted = this.sortEvents(filtered, sortMode);

    sorted.forEach((event) => {
      const li = document.createElement('li');
      li.className = 'event-list-item';
      li.onclick = () => App.openEditForm(event.id);

      const emoji = document.createElement('div');
      emoji.className = 'event-list-emoji';
      emoji.style.background = (event.color || '#6c5ce7') + '22';
      emoji.textContent = event.emoji || '⏳';

      const info = document.createElement('div');
      info.className = 'event-list-info';

      const name = document.createElement('div');
      name.className = 'event-list-name';
      name.textContent = event.name;

      const category = getCategoryById(event.category);
      const recurrence = Countdown.getRecurrence(event);
      const categoryTag = document.createElement('span');
      categoryTag.className = 'event-list-category';
      categoryTag.textContent = recurrence !== 'none'
        ? `${category.emoji} ${category.label} · 🔁 ${recurrenceLabel(recurrence)}`
        : `${category.emoji} ${category.label}`;

      const date = document.createElement('div');
      date.className = 'event-list-date';
      date.textContent = Countdown.formatDate(event);

      info.appendChild(name);
      info.appendChild(categoryTag);
      info.appendChild(date);

      const countdown = document.createElement('div');
      countdown.className = 'event-list-countdown';
      countdown.style.color = event.color || '#6c5ce7';
      countdown.textContent = Countdown.shortLabel(event);

      li.appendChild(emoji);
      li.appendChild(info);
      li.appendChild(countdown);

      list.appendChild(li);
    });
  },

  /**
   * Renderiza el grid de selección de emoji en el formulario.
   * @param {string} selected
   */
  renderEmojiGrid(selected) {
    const grid = document.getElementById('emoji-grid');
    grid.innerHTML = '';

    EMOJI_OPTIONS.forEach((emoji) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'emoji-option' + (emoji === selected ? ' selected' : '');
      btn.textContent = emoji;
      btn.onclick = () => {
        document.getElementById('event-emoji').value = emoji;
        grid.querySelectorAll('.emoji-option').forEach((el) => el.classList.remove('selected'));
        btn.classList.add('selected');
        App.updatePreview();
      };
      grid.appendChild(btn);
    });
  },

  /**
   * Renderiza el grid de selección de color en el formulario.
   * @param {string} selected
   */
  renderColorGrid(selected) {
    const grid = document.getElementById('color-grid');
    grid.innerHTML = '';

    COLOR_OPTIONS.forEach((color) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'color-option' + (color === selected ? ' selected' : '');
      btn.style.background = color;
      btn.onclick = () => {
        document.getElementById('event-color').value = color;
        grid.querySelectorAll('.color-option').forEach((el) => el.classList.remove('selected'));
        btn.classList.add('selected');
        App.updatePreview();
      };
      grid.appendChild(btn);
    });
  },

  /**
   * Renderiza el grid de selección de categoría en el formulario.
   * @param {string} selected - id de categoría
   */
  renderCategoryGrid(selected) {
    const grid = document.getElementById('category-grid');
    grid.innerHTML = '';

    CATEGORIES.forEach((cat) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'category-option' + (cat.id === selected ? ' selected' : '');
      btn.innerHTML = `<span class="category-emoji">${cat.emoji}</span><span>${cat.label}</span>`;
      btn.onclick = () => {
        document.getElementById('event-category').value = cat.id;
        grid.querySelectorAll('.category-option').forEach((el) => el.classList.remove('selected'));
        btn.classList.add('selected');
      };
      grid.appendChild(btn);
    });
  },

  /**
   * Renderiza los chips de filtro por categoría en la vista de lista.
   * @param {Array<Object>} events - para calcular qué categorías tienen eventos
   * @param {string} activeCategory - 'all' o id de categoría
   */
  renderCategoryFilterBar(events, activeCategory) {
    const bar = document.getElementById('category-filter-bar');
    bar.innerHTML = '';

    const allChip = document.createElement('button');
    allChip.type = 'button';
    allChip.className = 'category-chip' + (activeCategory === 'all' ? ' active' : '');
    allChip.textContent = 'Todas';
    allChip.onclick = () => App.setActiveCategory('all');
    bar.appendChild(allChip);

    CATEGORIES.forEach((cat) => {
      const hasEvents = events.some((e) => (e.category || DEFAULT_CATEGORY_ID) === cat.id);
      if (!hasEvents) return;

      const chip = document.createElement('button');
      chip.type = 'button';
      chip.className = 'category-chip' + (activeCategory === cat.id ? ' active' : '');
      chip.textContent = `${cat.emoji} ${cat.label}`;
      chip.onclick = () => App.setActiveCategory(cat.id);
      bar.appendChild(chip);
    });
  },

  /**
   * Muestra un modal por id.
   * @param {string} modalId
   */
  showModal(modalId) {
    document.getElementById(modalId).classList.remove('hidden');
  },

  /**
   * Oculta un modal por id.
   * @param {string} modalId
   */
  hideModal(modalId) {
    document.getElementById(modalId).classList.add('hidden');
  },

  /**
   * Lanza confetti animado en la pantalla de celebración.
   */
  launchConfetti() {
    const container = document.getElementById('confetti');
    container.innerHTML = '';
    const colors = COLOR_OPTIONS;

    for (let i = 0; i < 60; i++) {
      const piece = document.createElement('div');
      piece.className = 'confetti-piece';
      piece.style.left = Math.random() * 100 + '%';
      piece.style.background = colors[Math.floor(Math.random() * colors.length)];
      piece.style.animationDuration = 2 + Math.random() * 2 + 's';
      piece.style.animationDelay = Math.random() * 1.5 + 's';
      container.appendChild(piece);
    }
  },
};
