# ⏳ Next Appointment

Aplicación web de countdown 100% client-side. Crea tus propios eventos con nombre, fecha, hora, emoji y color, y mira la cuenta atrás en tiempo real. Sin registro, sin anuncios, funciona offline (PWA).

## 🚀 Demo local

No requiere build ni dependencias. Solo necesitas servir los archivos estáticos (el Service Worker no funciona con `file://`, necesita `http://`).

```bash
# Con Python
python3 -m http.server 8080

# Con Node (npx)
npx serve .
```

Luego abre `http://localhost:8080`.

## 📂 Estructura

```
next-appointment/
├── index.html          # Las 4 vistas: main, lista, formulario, celebración
├── manifest.json        # Configuración PWA
├── service-worker.js    # Cache offline
├── css/
│   └── styles.css
├── js/
│   ├── storage.js       # Persistencia en localStorage
│   ├── countdown.js     # Cálculo de cuentas atrás
│   ├── ui.js             # Renderizado de cards, listas, grids
│   └── app.js            # Lógica principal / eventos
└── icons/
    ├── icon-192.png
    └── icon-512.png
```

## ✅ Funcionalidades implementadas (MVP)

- Crear, editar y eliminar eventos (nombre, fecha, hora, emoji, color)
- Countdown en vivo (días, horas, minutos, segundos)
- Carrusel de eventos con swipe táctil real + scroll-snap + indicadores (dots)
- Vista de lista ordenada y filtrable (próximos, lejanos, nombre, recién creados)
- Vista previa en tiempo real al crear/editar
- Eventos recurrentes (anuales)
- Pantalla de celebración con confetti al llegar a cero
- Tema claro/oscuro (con detección automática del sistema)
- Transiciones de slide entre vistas
- Compartir evento vía enlace (el receptor puede importar una copia a su propia lista, sin backend)
- Avisos/notificaciones configurables (5 min / 1 hora / 1 día antes), mientras la app está abierta
- Todo en localStorage, sin backend
- PWA instalable con soporte offline básico

## ⚠️ Notas sobre notificaciones

Las notificaciones de aviso ("avisarme X antes") solo se disparan mientras la app está abierta o recién en segundo plano. iOS no permite alarmas programadas en background sin un servidor de Web Push, así que esta función es un complemento, no un recordatorio garantizado.

## 🔗 Compartir eventos

Al pulsar "Compartir" en un evento se genera un enlace con los datos codificados (`?import=...`). Quien abra ese enlace verá un modal para añadir una copia del evento a su propia lista. Es una copia independiente: si el creador edita el evento después, los cambios no se sincronizan automáticamente.

## 🔜 Pendiente / ideas futuras

- Exportar evento como imagen (canvas / html2canvas)
- Fondos personalizables (color, gradiente, foto)
- Modo "tiempo transcurrido" (eventos en el pasado)
- Sincronización en tiempo real entre dispositivos (requeriría backend ligero, ej. Firebase)

## 🛠️ Stack

HTML5, CSS3 y JavaScript vanilla. Sin frameworks ni dependencias externas.

## 📦 Despliegue

Compatible con GitHub Pages, Netlify, Vercel o cualquier hosting estático:

```bash
# GitHub Pages (rama main, carpeta raíz)
git add .
git commit -m "Initial commit"
git push origin main
# Activar GitHub Pages en Settings > Pages > Source: main / root
```

---

*Proyecto derivado de Next Match — misma filosofía: una pantalla, una función, sin ruido.*
