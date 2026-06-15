# ⏳ Next Appointment

## Concepto
Aplicación web genérica de countdown donde el usuario crea sus propios eventos con nombre, fecha, hora e icono emoji. Una pantalla para cualquier cosa que estés esperando.

## Problema que resuelve
Los contadores de cuenta regresiva existentes son feos, lentos o requieren registro. Next Anything es instantáneo, bonito y funciona offline. Bodas, viajes, cumpleaños, estrenos, exámenes — cualquier cosa.

## Funcionalidades core
- Crear eventos con: nombre, fecha, hora, emoji/icono y color de acento
- Card con countdown en días, horas, minutos y segundos
- Swipe entre eventos
- Al llegar a cero: mensaje de celebración animado
- Todo guardado en localStorage, sin login

## Funcionalidades secundarias
- Eventos recurrentes (cumpleaños anuales, aniversarios)
- Compartir evento como imagen o link
- Fondo personalizable (color, gradiente, foto)
- Modo "tiempo transcurrido" (cuánto hace que pasó algo)
- Notificaciones programadas (PWA)
- Tema claro/oscuro

## Casos de uso
- 🎂 Cumpleaños y aniversarios
- ✈️ Próximo viaje o vacaciones
- 🎓 Fecha de examen o entrega
- 🎬 Estreno de película o serie
- 💒 Boda
- 🏠 Mudanza
- 🍾 Fin de año
- 💼 Primer día de trabajo
- 🎮 Lanzamiento de videojuego

## Arquitectura
```
100% cliente — sin backend, sin APIs externas
localStorage → persistencia de eventos
Service Worker → notificaciones y uso offline
```

## Stack tecnológico
- HTML5 / CSS3 / JavaScript vanilla
- localStorage para todos los datos
- PWA (manifest + service worker) para instalación y notificaciones
- Canvas o html2canvas para exportar evento como imagen

## Retos técnicos
- Notificaciones push en iOS son limitadas (solo desde iOS 16.4 en PWA)
- Generar imagen compartible atractiva del countdown
- Sincronización entre dispositivos sin backend (opcional: usar URL con parámetros)

## Pantallas / vistas
1. **Main** — próximo evento con countdown
2. **Lista** — todos los eventos ordenados por fecha
3. **Crear/editar** — formulario simple con preview en tiempo real
4. **Celebración** — pantalla animada cuando llega el día

## Diferenciadores respecto a competidores
- Sin registro
- Sin anuncios
- Funciona offline
- Diseño minimalista y elegante
- Compartible sin que el receptor necesite la app

## Monetización potencial
- Versión gratuita con hasta 5 eventos
- Plan premium con eventos ilimitados, fondos personalizados y notificaciones avanzadas
- Versión de pago única (sin suscripción) — modelo más honesto para este tipo de utilidad

---
*Proyecto derivado de Next Match — misma filosofía: una pantalla, una función, sin ruido.*
