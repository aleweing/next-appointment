/* =========================================
   Next Appointment — App logic (main)
   ========================================= */

const App = {
  currentEditId: null,
  tickInterval: null,

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
      UI.showView('view-list');
    });

    document.querySelectorAll('.back-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.renderAll();
        UI.showView(btn.dataset.target);
      });
    });

    document.getElementById('btn-create').addEventListener('click', () => this.openCreateForm());
    document.getElementById('btn-create-from-list').addEventListener('click', () => this.openCreateForm());
    document.getElementById('btn-empty-create').addEventListener('click', () => this.openCreateForm());

    document.getElementById('btn-delete-event').addEventListener('click', () => this.deleteCurrentEvent());

    // Form
    document.getElementById('event-form').addEventListener('submit', (e) => this.handleSubmit(e));
    ['event-name', 'event-date', 'event-time'].forEach((id) => {
      document.getElementById(id).addEventListener('input', () => this.updatePreview());
    });

    // Initial render
    this.renderAll();
    this.startTicking();

    // Service worker
    this.registerServiceWorker();
  },

  /** Renderiza carrusel + lista con los datos actuales */
  renderAll() {
    const events = Storage.getAll();
    UI.renderCarousel(events);
    UI.renderList(events);
    this.checkCelebrations(events);
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
      const listItems = document.querySelectorAll('#event-list .event-list-item');
      if (listItems.length === events.length) {
        const sorted = [...events].sort((a, b) => Countdown.diffMs(a) - Countdown.diffMs(b));
        listItems.forEach((li, i) => {
          const countEl = li.querySelector('.event-list-countdown');
          if (countEl && sorted[i]) countEl.textContent = Countdown.shortLabel(sorted[i]);
        });
      }

      // Update preview if form is open
      if (document.getElementById('view-form').classList.contains('view-active')) {
        this.updatePreview();
      }
    }, 1000);
  },

  /** Comprueba si algún evento acaba de llegar a cero y muestra celebración */
  checkCelebrations(events) {
    const now = Date.now();
    events.forEach((event) => {
      if (event.recurring) return;
      const diff = Countdown.diffMs(event);
      // Si el evento "acaba de" llegar (margen de 2s) y no se ha celebrado ya
      if (diff <= 0 && diff > -2000 && !event._celebrated) {
        event._celebrated = true;
        Storage.upsert(event);
        this.showCelebration(event);
      }
    });
  },

  showCelebration(event) {
    document.getElementById('celebration-emoji').textContent = event.emoji || '🎉';
    document.getElementById('celebration-name').textContent = `"${event.name}" — ¡hoy es el día!`;
    UI.showView('view-celebration');
    UI.launchConfetti();
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

    // Default date: tomorrow
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    document.getElementById('event-date').value = tomorrow.toISOString().slice(0, 10);

    UI.renderEmojiGrid('⏳');
    UI.renderColorGrid(COLOR_OPTIONS[0]);
    this.updatePreview();

    UI.showView('view-form');
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
    document.getElementById('event-recurring').checked = !!event.recurring;

    UI.renderEmojiGrid(event.emoji);
    UI.renderColorGrid(event.color);
    this.updatePreview();

    UI.showView('view-form');
  },

  /** Maneja el envío del formulario (crear o editar) */
  handleSubmit(e) {
    e.preventDefault();

    const name = document.getElementById('event-name').value.trim();
    const date = document.getElementById('event-date').value;
    const time = document.getElementById('event-time').value || '00:00';
    const emoji = document.getElementById('event-emoji').value || '⏳';
    const color = document.getElementById('event-color').value || COLOR_OPTIONS[0];
    const recurring = document.getElementById('event-recurring').checked;

    if (!name || !date) return;

    const existing = this.currentEditId ? Storage.getById(this.currentEditId) : null;

    const event = {
      id: this.currentEditId || generateId(),
      name,
      date,
      time,
      emoji,
      color,
      recurring,
      _celebrated: existing ? existing._celebrated : false,
    };

    Storage.upsert(event);
    this.renderAll();
    UI.showView('view-main');
  },

  /** Elimina el evento que se está editando */
  deleteCurrentEvent() {
    if (!this.currentEditId) return;
    if (!confirm('¿Eliminar este evento?')) return;

    Storage.remove(this.currentEditId);
    this.currentEditId = null;
    this.renderAll();
    UI.showView('view-main');
  },

  /** Actualiza la card de vista previa del formulario */
  updatePreview() {
    const name = document.getElementById('event-name').value.trim() || 'Nombre del evento';
    const date = document.getElementById('event-date').value;
    const time = document.getElementById('event-time').value || '00:00';
    const emoji = document.getElementById('event-emoji').value || '⏳';
    const color = document.getElementById('event-color').value || COLOR_OPTIONS[0];
    const recurring = document.getElementById('event-recurring')?.checked || false;

    document.getElementById('preview-emoji').textContent = emoji;
    document.getElementById('preview-name').textContent = name;
    document.getElementById('preview-card').style.setProperty('--accent-color', color);

    if (!date) {
      document.getElementById('preview-countdown').textContent = '--d --h --m --s';
      document.getElementById('preview-date').textContent = 'Selecciona una fecha';
      return;
    }

    const tempEvent = { date, time, recurring };
    document.getElementById('preview-date').textContent = Countdown.formatDate(tempEvent);

    if (Countdown.hasElapsed(tempEvent)) {
      document.getElementById('preview-countdown').textContent = '🎉 ¡Ya llegó!';
    } else {
      const { days, hours, minutes, seconds } = Countdown.breakdown(Countdown.diffMs(tempEvent));
      document.getElementById('preview-countdown').textContent =
        `${days}d ${pad(hours)}h ${pad(minutes)}m ${pad(seconds)}s`;
    }
  },

  /** Comparte un evento (Web Share API o copia el enlace) */
  shareEvent(id) {
    const event = Storage.getById(id);
    if (!event) return;

    const text = `${event.emoji} ${event.name}\n${Countdown.formatDate(event)}\n${Countdown.shortLabel(event)}\n\nCreado con Next Appointment ⏳`;

    if (navigator.share) {
      navigator.share({ title: event.name, text }).catch(() => {});
    } else if (navigator.clipboard) {
      navigator.clipboard.writeText(text).then(() => {
        alert('¡Copiado al portapapeles!');
      });
    } else {
      alert(text);
    }
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
