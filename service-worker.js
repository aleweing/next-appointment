/* =========================================
   Next Appointment — Service Worker
   ========================================= */

const CACHE_NAME = 'next-appointment-v18';

const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './manifest.json',
  './css/styles.css',
  './js/icons.js',
  './js/storage.js',
  './js/countdown.js',
  './js/ui.js',
  './js/push.js',
  './js/app.js',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

// Instalación: precachear assets estáticos
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS_TO_CACHE))
  );
  self.skipWaiting();
});

// Activación: limpiar caches antiguas
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// Fetch: network-first para HTML/CSS/JS (evita servir versiones desincronizadas
// entre archivos tras una actualización), cache-first para imágenes (no cambian).
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  const isCodeAsset = /\.(html|js|css)$/.test(url.pathname) || url.pathname.endsWith('/');

  if (isCodeAsset) {
    // Network-first: intenta red, y si responde, actualiza la caché.
    // Si no hay red, cae al último HTML/JS/CSS cacheado.
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response && response.status === 200) {
            const responseClone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
          }
          return response;
        })
        .catch(() => caches.match(event.request).then((cached) => cached || caches.match('./index.html')))
    );
    return;
  }

  // Cache-first para el resto (iconos, imágenes): no cambian a menudo,
  // priorizar velocidad y uso offline.
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request)
        .then((response) => {
          if (response && response.status === 200) {
            const responseClone = response.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, responseClone);
            });
          }
          return response;
        })
        .catch(() => caches.match('./index.html'));
    })
  );
});

// Notificaciones push reales (feature 005): el Cloudflare Worker envía el
// aviso y este listener lo muestra, aunque la app esté completamente cerrada.
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    // Payload no-JSON (ej. una prueba manual): lo usamos como cuerpo.
    data = { body: event.data ? event.data.text() : '' };
  }

  const title = data.title || 'Next Appointment';
  const options = {
    body: data.body || '',
    icon: './icons/icon-192.png',
    badge: './icons/icon-192.png',
    // Un aviso por evento: si llega otro del mismo evento, lo reemplaza
    // en vez de acumular notificaciones repetidas.
    tag: data.tag || data.eventId || 'next-appointment',
    data: { eventId: data.eventId || null },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Al tocar la notificación: abrir la app (o enfocarla si ya estaba abierta)
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((clients) => {
      if (clients.length > 0) {
        return clients[0].focus();
      }
      return self.clients.openWindow('./');
    })
  );
});
