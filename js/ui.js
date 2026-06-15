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

const UI = {
  /**
   * Cambia la vista activa.
   * @param {string} viewId
   */
  showView(viewId) {
    document.querySelectorAll('.view').forEach((el) => {
      el.classList.remove('view-active');
    });
    const target = document.getElementById(viewId);
    if (target) target.classList.add('view-active');
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

    // Sync dots with scroll position
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

    if (event.recurring) {
      const badge = document.createElement('div');
      badge.className = 'card-badge';
      badge.textContent = '🔁 Anual';
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
   * Renderiza la lista completa de eventos (vista lista).
   * @param {Array<Object>} events
   */
  renderList(events) {
    const list = document.getElementById('event-list');
    const emptyState = document.getElementById('list-empty-state');

    list.innerHTML = '';

    if (!events.length) {
      emptyState.classList.remove('hidden');
      return;
    }
    emptyState.classList.add('hidden');

    const sorted = [...events].sort(
      (a, b) => Countdown.diffMs(a) - Countdown.diffMs(b)
    );

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

      const date = document.createElement('div');
      date.className = 'event-list-date';
      date.textContent = Countdown.formatDate(event);

      info.appendChild(name);
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
