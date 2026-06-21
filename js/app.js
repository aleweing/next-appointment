/* =========================================
   Next Appointment — App logic (main)
   ========================================= */

const App = {
  currentEditId: null,
  tickInterval: null,
  activeCategory: 'all',

  init() {
    // Theme
    const savedTheme = Storage.getTheme();
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const theme = savedTheme || (prefersDark ? 'dark' : 'light');
    UI.applyTheme(theme);

    document.getElementById('btn-theme').addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme');
      const next = current === 'dark' ? 'light' : 'dark';
      UI.applyTheme(next);
      Storage.setTheme(next);
    });

    // Navigation
    document.getElementById('btn-list').addEventListener('click', () => {
      this.renderAll();
      UI.showView('view-list', 'right');
    });

    document.querySelectorAll('.back-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.renderAll();
        UI.showView(btn.dataset.target, 'left');
      });
    });

    document.getElementById('btn-create').addEventListener('click', () => this.openCreateForm());
    document.getElementById('btn-create-from-list').addEventListener('click', () => this.openCreateForm());
    document.getElementById('btn-empty-create').addEventListener('click', () => this.openCreateForm());

    document.getElementById('btn-delete-event').addEventListener('click', () => this.deleteCurrentEvent());

    // Sort bar
    document.querySelectorAll('.sort-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        Storage.setSortMode(chip.dataset.sort);
        UI.renderSortBar(chip.dataset.sort);
        UI.renderList(Storage.getAll(), chip.dataset.sort, this.activeCategory);
      });
    });

    // Form
    document.getElementById('event-form').addEventListener('submit', (e) => this.handleSubmit(e));
    ['event-name', 'event-date', 'event-time'].forEach((id) => {
      document.getElementById(id).addEventListener('input', () => this.updatePreview());
    });

    // Repeat toggle (cantidad + unidad, estilo alarma)
    document.getElementById('event-repeat-toggle').addEventListener('change', (e) => {
      this.toggleRepeatRow(e.target.checked);
      this.updatePreview();
    });
    document.getElementById('event-recurrence-interval').addEventListener('input', () => this.updatePreview());
    document.getElementById('event-recurrence-unit').addEventListener('change', () => this.updatePreview());

    // Share modal
    document.getElementById('btn-copy-link').addEventListener('click', () => this.copyShareLink());
    document.getElementById('btn-share-close').addEventListener('click', () => UI.hideModal('modal-share'));
    document.getElementById('btn-share-native').addEventListener('click', () => this.nativeShareLink());

    // Import modal
    document.getElementById('btn-import-cancel').addEventListener('click', () => this.dismissImport());
    document.getElementById('btn-import-accept').addEventListener('click', () => this.acceptImport());

    // Paste-to-import modal
    document.getElementById('btn-open-import').addEventListener('click', () => this.openPasteImportModal());
    document.getElementById('btn-paste-import-cancel').addEventListener('click', () => UI.hideModal('modal-paste-import'));
    document.getElementById('btn-paste-import-confirm').addEventListener('click', () => this.confirmPasteImport());
    document.getElementById('modal-paste-import').addEventListener('click', (e) => {
      if (e.target.id === 'modal-paste-import') UI.hideModal('modal-paste-import');
    });

    // Close modals when clicking the overlay (outside the card)
    document.getElementById('modal-import').addEventListener('click', (e) => {
      if (e.target.id === 'modal-import') this.dismissImport();
    });
    document.getElementById('modal-share').addEventListener('click', (e) => {
      if (e.target.id === 'modal-share') UI.hideModal('modal-share');
    });

    // Initial render
    this.renderAll();
    this.startTicking();

    // Service worker
    this.registerServiceWorker();

    // Check if URL has a shared event to import
    this.checkForSharedEvent();
  },

  /** Renderiza carrusel + lista con los datos actuales */
  renderAll() {
    const events = Storage.getAll();
    const sortMode = Storage.getSortMode();
    UI.renderCarousel(events);
    UI.renderCategoryFilterBar(events, this.activeCategory);
    UI.renderList(events, sortMode, this.activeCategory);
    UI.renderSortBar(sortMode);
    this.checkCelebrations(events);
    this.checkNotifications(events);
  },

  /**
   * Cambia la categoría activa del filtro en la vista lista y vuelve a renderizar.
   * @param {string} categoryId - 'all' o id de categoría
   */
  setActiveCategory(categoryId) {
    this.activeCategory = categoryId;
    const events = Storage.getAll();
    UI.renderCategoryFilterBar(events, this.activeCategory);
    UI.renderList(events, Storage.getSortMode(), this.activeCategory);
  },

  /** Actualiza solo los números del countdown cada segundo, sin re-renderizar todo */
  startTicking() {
    if (this.tickInterval) clearInterval(this.tickInterval);

    this.tickInterval = setInterval(() => {
      const events = Storage.getAll();
      const cards = document.querySelectorAll('#event-carousel .event-card');

      cards.forEach((card) => {
        const event = events.find((e) => e.id === card.dataset.id);
        if (event) UI.updateCardCountdown(card, event);
      });

      // Update list countdowns (lightweight, only text)
      const filteredEvents = this.activeCategory === 'all'
        ? events
        : events.filter((e) => (e.category || 'other') === this.activeCategory);
      const listItems = document.querySelectorAll('#event-list .event-list-item');
      if (listItems.length === filteredEvents.length) {
        const sorted = UI.sortEvents(filteredEvents, Storage.getSortMode());
        listItems.forEach((li, i) => {
          const countEl = li.querySelector('.event-list-countdown');
          if (countEl && sorted[i]) countEl.textContent = Countdown.shortLabel(sorted[i]);
        });
      }

      // Update preview if form is open
      if (document.getElementById('view-form').classList.contains('view-active')) {
        this.updatePreview();
      }

      this.checkCelebrations(events);
      this.checkNotifications(events);
    }, 1000);
  },

  /** Comprueba si algún evento acaba de llegar a cero y muestra celebración */
  checkCelebrations(events) {
    events.forEach((event) => {
      if (Countdown.getRecurrence(event).unit !== 'none') return;
      const diff = Countdown.diffMs(event);
      // Si el evento "acaba de" llegar (margen de 2s) y no se ha celebrado ya
      if (diff <= 0 && diff > -2000 && !event._celebrated) {
        event._celebrated = true;
        Storage.upsert(event);

        // No interrumpir si el usuario está editando un formulario o con un modal abierto
        const formOpen = document.getElementById('view-form').classList.contains('view-active');
        const modalOpen = !document.getElementById('modal-import').classList.contains('hidden')
          || !document.getElementById('modal-share').classList.contains('hidden');

        if (!formOpen && !modalOpen) {
          this.showCelebration(event);
        }
      }
    });
  },

  showCelebration(event) {
    document.getElementById('celebration-emoji').textContent = event.emoji || '🎉';
    document.getElementById('celebration-name').textContent = `"${event.name}" — ¡hoy es el día!`;
    UI.showView('view-celebration', 'right');
    UI.launchConfetti();
  },

  /**
   * Comprueba si algún evento debe disparar una notificación de aviso previo.
   * Solo funciona mientras la app está abierta (sin push remoto).
   * @param {Array<Object>} events
   */
  checkNotifications(events) {
    if (!('Notification' in window)) return;
    if (Notification.permission !== 'granted') return;

    events.forEach((event) => {
      if (!event.notifyBefore) return;

      const diffSeconds = Countdown.diffMs(event) / 1000;
      const notifyAt = Number(event.notifyBefore);

      // Ventana de 2 segundos para no perder el disparo entre ticks
      if (diffSeconds <= notifyAt && diffSeconds > notifyAt - 2) {
        const key = `${event.id}_${this.getTargetTimeKey(event)}`;
        if (event._notifiedKey === key) return;

        event._notifiedKey = key;
        Storage.upsert(event);
        this.fireNotification(event);
      }
    });
  },

  /** Devuelve una clave única para la fecha objetivo actual (sirve para recurrentes) */
  getTargetTimeKey(event) {
    return Countdown.getTargetDate(event).getTime();
  },

  /** Muestra una notificación del sistema para un evento */
  fireNotification(event) {
    const label = Countdown.shortLabel(event);
    const title = `${event.emoji || '⏳'} ${event.name}`;
    const body = `Queda ${label} para este evento.`;

    if (navigator.serviceWorker && navigator.serviceWorker.controller) {
      navigator.serviceWorker.ready.then((reg) => {
        reg.showNotification(title, { body, icon: 'icons/icon-192.png' });
      });
    } else {
      try {
        new Notification(title, { body, icon: 'icons/icon-192.png' });
      } catch (e) {
        console.warn('No se pudo mostrar la notificación', e);
      }
    }
  },

  /** Pide permiso de notificaciones al usuario (debe llamarse tras una interacción) */
  requestNotificationPermission() {
    if (!('Notification' in window)) {
      alert('Tu navegador no soporta notificaciones.');
      return Promise.resolve('unsupported');
    }
    if (Notification.permission === 'granted') return Promise.resolve('granted');
    return Notification.requestPermission();
  },

  /** Abre el formulario en modo creación */
  openCreateForm() {
    this.currentEditId = null;
    document.getElementById('form-title').textContent = 'Nuevo evento';
    document.getElementById('btn-delete-event').classList.add('hidden');
    document.getElementById('event-form').reset();
    document.getElementById('event-id').value = '';

    // Defaults
    document.getElementById('event-time').value = '00:00';
    document.getElementById('event-emoji').value = '⏳';
    document.getElementById('event-color').value = COLOR_OPTIONS[0];
    document.getElementById('event-category').value = DEFAULT_CATEGORY_ID;
    document.getElementById('event-repeat-toggle').checked = false;
    document.getElementById('event-recurrence-interval').value = 1;
    document.getElementById('event-recurrence-unit').value = 'year';
    this.toggleRepeatRow(false);
    document.getElementById('event-notify-days').value = 0;
    document.getElementById('event-notify-hours').value = 0;
    document.getElementById('event-notify-minutes').value = 0;

    // Default date: tomorrow
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    document.getElementById('event-date').value = tomorrow.toISOString().slice(0, 10);

    UI.renderEmojiGrid('⏳');
    UI.renderColorGrid(COLOR_OPTIONS[0]);
    UI.renderCategoryGrid(DEFAULT_CATEGORY_ID);
    this.updatePreview();

    UI.showView('view-form', 'right');
  },

  /** Abre el formulario en modo edición */
  openEditForm(id) {
    const event = Storage.getById(id);
    if (!event) return;

    this.currentEditId = id;
    document.getElementById('form-title').textContent = 'Editar evento';
    document.getElementById('btn-delete-event').classList.remove('hidden');

    document.getElementById('event-id').value = event.id;
    document.getElementById('event-name').value = event.name;
    document.getElementById('event-date').value = event.date;
    document.getElementById('event-time').value = event.time || '00:00';
    document.getElementById('event-emoji').value = event.emoji || '⏳';
    document.getElementById('event-color').value = event.color || COLOR_OPTIONS[0];
    document.getElementById('event-category').value = event.category || DEFAULT_CATEGORY_ID;

    const { unit, interval } = Countdown.getRecurrence(event);
    const repeats = unit !== 'none';
    document.getElementById('event-repeat-toggle').checked = repeats;
    document.getElementById('event-recurrence-interval').value = interval;
    document.getElementById('event-recurrence-unit').value = repeats ? unit : 'year';
    this.toggleRepeatRow(repeats);

    const notifySeconds = Number(event.notifyBefore) || 0;
    document.getElementById('event-notify-days').value = Math.floor(notifySeconds / 86400);
    document.getElementById('event-notify-hours').value = Math.floor((notifySeconds % 86400) / 3600);
    document.getElementById('event-notify-minutes').value = Math.floor((notifySeconds % 3600) / 60);

    UI.renderEmojiGrid(event.emoji);
    UI.renderColorGrid(event.color);
    UI.renderCategoryGrid(event.category || DEFAULT_CATEGORY_ID);
    this.updatePreview();

    UI.showView('view-form', 'right');
  },

  /** Maneja el envío del formulario (crear o editar) */
  async handleSubmit(e) {
    e.preventDefault();

    const name = document.getElementById('event-name').value.trim();
    const date = document.getElementById('event-date').value;
    const time = document.getElementById('event-time').value || '00:00';
    const emoji = document.getElementById('event-emoji').value || '⏳';
    const color = document.getElementById('event-color').value || COLOR_OPTIONS[0];
    const category = document.getElementById('event-category').value || DEFAULT_CATEGORY_ID;

    const repeats = document.getElementById('event-repeat-toggle').checked;
    const recurrenceUnit = repeats ? document.getElementById('event-recurrence-unit').value : 'none';
    const recurrenceInterval = repeats
      ? Math.max(1, parseInt(document.getElementById('event-recurrence-interval').value, 10) || 1)
      : 1;

    const notifyDays = Math.max(0, parseInt(document.getElementById('event-notify-days').value, 10) || 0);
    const notifyHours = Math.max(0, parseInt(document.getElementById('event-notify-hours').value, 10) || 0);
    const notifyMinutes = Math.max(0, parseInt(document.getElementById('event-notify-minutes').value, 10) || 0);
    const notifySeconds = notifyDays * 86400 + notifyHours * 3600 + notifyMinutes * 60;
    const notifyBefore = notifySeconds > 0 ? notifySeconds : null;

    if (!name || !date) return;

    const existing = this.currentEditId ? Storage.getById(this.currentEditId) : null;

    // Si el usuario activa un aviso, pedir permiso de notificaciones
    if (notifyBefore) {
      const permission = await this.requestNotificationPermission();
      if (permission !== 'granted') {
        alert('Para recibir avisos, permite las notificaciones en tu navegador. El evento se guardará sin aviso activo.');
      }
    }

    // Si cambia la fecha/hora o la repetición, reseteamos la marca de "ya notificado"
    const existingRecurrence = existing ? Countdown.getRecurrence(existing) : null;
    const targetChanged = !existing || existing.date !== date || existing.time !== time
      || existingRecurrence.unit !== recurrenceUnit || existingRecurrence.interval !== recurrenceInterval
      || existing.notifyBefore !== notifyBefore;

    const event = {
      id: this.currentEditId || generateId(),
      name,
      date,
      time,
      emoji,
      color,
      category,
      recurrenceUnit,
      recurrenceInterval,
      notifyBefore,
      _celebrated: existing ? existing._celebrated : false,
      _notifiedKey: targetChanged ? null : (existing ? existing._notifiedKey : null),
    };

    Storage.upsert(event);
    this.renderAll();
    UI.showView('view-main', 'left');
  },

  /** Elimina el evento que se está editando */
  deleteCurrentEvent() {
    if (!this.currentEditId) return;
    if (!confirm('¿Eliminar este evento?')) return;

    Storage.remove(this.currentEditId);
    this.currentEditId = null;
    this.renderAll();
    UI.showView('view-main', 'left');
  },

  /** Muestra u oculta el bloque de cantidad+unidad de repetición */
  toggleRepeatRow(show) {
    document.getElementById('repeat-row').hidden = !show;
    document.getElementById('repeat-hint').hidden = !show;
  },

  /** Actualiza la card de vista previa del formulario */
  updatePreview() {
    const name = document.getElementById('event-name').value.trim() || 'Nombre del evento';
    const date = document.getElementById('event-date').value;
    const time = document.getElementById('event-time').value || '00:00';
    const emoji = document.getElementById('event-emoji').value || '⏳';
    const color = document.getElementById('event-color').value || COLOR_OPTIONS[0];
    const repeats = document.getElementById('event-repeat-toggle')?.checked || false;
    const recurrenceUnit = repeats ? (document.getElementById('event-recurrence-unit')?.value || 'year') : 'none';
    const recurrenceInterval = repeats
      ? Math.max(1, parseInt(document.getElementById('event-recurrence-interval')?.value, 10) || 1)
      : 1;

    document.getElementById('preview-emoji').textContent = emoji;
    document.getElementById('preview-name').textContent = name;
    document.getElementById('preview-card').style.setProperty('--accent-color', color);

    if (!date) {
      document.getElementById('preview-countdown').textContent = '--d --h --m --s';
      document.getElementById('preview-date').textContent = 'Selecciona una fecha';
      return;
    }

    const tempEvent = { date, time, recurrenceUnit, recurrenceInterval };
    document.getElementById('preview-date').textContent = Countdown.formatDate(tempEvent);

    if (Countdown.hasElapsed(tempEvent)) {
      document.getElementById('preview-countdown').textContent = '🎉 ¡Ya llegó!';
    } else {
      const { days, hours, minutes, seconds } = Countdown.breakdown(Countdown.diffMs(tempEvent));
      document.getElementById('preview-countdown').textContent =
        `${days}d ${pad(hours)}h ${pad(minutes)}m ${pad(seconds)}s`;
    }
  },

  /** Abre el modal de compartir con un enlace que el destinatario puede importar */
  shareEvent(id) {
    const event = Storage.getById(id);
    if (!event) return;

    const encoded = encodeEventForShare(event);
    const url = new URL(window.location.href);
    url.search = '';
    url.hash = '';
    url.searchParams.set('import', encoded);

    this.pendingShareUrl = url.toString();

    const input = document.getElementById('share-link-input');
    input.value = this.pendingShareUrl;

    const nativeBtn = document.getElementById('btn-share-native');
    if (navigator.share) {
      nativeBtn.classList.remove('hidden');
    } else {
      nativeBtn.classList.add('hidden');
    }

    UI.showModal('modal-share');
  },

  /** Copia el enlace de compartir al portapapeles */
  copyShareLink() {
    const input = document.getElementById('share-link-input');
    input.select();

    if (navigator.clipboard) {
      navigator.clipboard.writeText(input.value).then(() => {
        const btn = document.getElementById('btn-copy-link');
        const original = btn.textContent;
        btn.textContent = '¡Copiado!';
        setTimeout(() => { btn.textContent = original; }, 1500);
      });
    } else {
      document.execCommand('copy');
    }
  },

  /** Usa la Web Share API nativa para compartir el enlace */
  nativeShareLink() {
    if (!navigator.share || !this.pendingShareUrl) return;
    navigator.share({ url: this.pendingShareUrl }).catch(() => {});
  },

  /**
   * Comprueba si la URL actual contiene un evento compartido (?import=...)
   * y, si es así, muestra el modal de importación.
   */
  checkForSharedEvent() {
    const params = new URLSearchParams(window.location.search);
    const encoded = params.get('import');
    if (!encoded) return;

    this.tryShowImportPreview(encoded, { cleanUrl: true });
  },

  /**
   * Extrae el código base64 a partir de lo que el usuario haya pegado:
   * puede ser una URL completa con ?import=..., o solo el código.
   * @param {string} rawInput
   * @returns {string|null}
   */
  extractEncodedFromInput(rawInput) {
    const trimmed = (rawInput || '').trim();
    if (!trimmed) return null;

    // ¿Es una URL? intentamos extraer el parámetro "import"
    try {
      const url = new URL(trimmed);
      const fromUrl = url.searchParams.get('import');
      if (fromUrl) return fromUrl;
    } catch (e) {
      // No es una URL válida, seguimos asumiendo que es el código directo
    }

    // Si parece contener "import=" sin ser una URL completa (ej. pegaron solo la query)
    const match = trimmed.match(/import=([^&\s]+)/);
    if (match) return decodeURIComponent(match[1]);

    // Asumimos que el texto pegado es directamente el código
    return trimmed;
  },

  /**
   * Decodifica un código y, si es válido, muestra el modal de preview de import.
   * @param {string} encoded
   * @param {{cleanUrl?: boolean}} options
   * @returns {boolean} true si se pudo decodificar y mostrar
   */
  tryShowImportPreview(encoded, options = {}) {
    const decoded = decodeSharedEvent(encoded);
    if (!decoded) return false;

    this.pendingImport = decoded;

    document.getElementById('import-emoji').textContent = decoded.emoji;
    document.getElementById('import-name').textContent = decoded.name;
    document.getElementById('import-date').textContent = Countdown.formatDate(decoded);

    UI.showModal('modal-import');

    if (options.cleanUrl) this.cleanImportFromUrl();

    return true;
  },

  /** Abre el modal para pegar manualmente un enlace o código de evento compartido */
  openPasteImportModal() {
    document.getElementById('paste-import-input').value = '';
    document.getElementById('paste-import-error').classList.add('hidden');
    UI.showModal('modal-paste-import');
    setTimeout(() => document.getElementById('paste-import-input').focus(), 50);
  },

  /** Confirma el contenido pegado, lo intenta decodificar y pasa al preview */
  confirmPasteImport() {
    const raw = document.getElementById('paste-import-input').value;
    const encoded = this.extractEncodedFromInput(raw);
    const errorEl = document.getElementById('paste-import-error');

    const success = encoded && this.tryShowImportPreview(encoded);

    if (!success) {
      errorEl.classList.remove('hidden');
      return;
    }

    errorEl.classList.add('hidden');
    UI.hideModal('modal-paste-import');
  },

  /** Acepta el evento importado y lo añade a los eventos del usuario */
  acceptImport() {
    if (!this.pendingImport) return;

    const event = {
      id: generateId(),
      name: this.pendingImport.name,
      date: this.pendingImport.date,
      time: this.pendingImport.time,
      emoji: this.pendingImport.emoji,
      color: this.pendingImport.color,
      category: this.pendingImport.category || DEFAULT_CATEGORY_ID,
      recurrenceUnit: this.pendingImport.recurrenceUnit || 'none',
      recurrenceInterval: this.pendingImport.recurrenceInterval || 1,
      notifyBefore: null,
      _celebrated: false,
      _notifiedKey: null,
    };

    Storage.upsert(event);
    this.pendingImport = null;
    UI.hideModal('modal-import');
    this.renderAll();
  },

  /** Descarta el evento importado sin guardarlo */
  dismissImport() {
    this.pendingImport = null;
    UI.hideModal('modal-import');
  },

  /** Elimina el parámetro ?import= de la URL sin recargar la página */
  cleanImportFromUrl() {
    const url = new URL(window.location.href);
    url.searchParams.delete('import');
    window.history.replaceState({}, '', url.toString());
  },

  /** Registra el service worker (si está disponible) */
  registerServiceWorker() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('service-worker.js').catch((err) => {
        console.warn('Service worker no registrado:', err);
      });
    }
  },
};

document.addEventListener('DOMContentLoaded', () => App.init());
