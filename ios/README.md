# Next Appointment para iPhone (prototipo)

Prototipo nativo en SwiftUI de la app de cuentas atrás. Fases 1 y 2 de
`specs/016-ios-prototype/TRASPASO.md`. La app web del repo no se toca.

- iOS 17 o posterior, solo iPhone, sin dependencias externas.
- Bundle id `com.aleweing.nextappointment`; nombre bajo el icono: "Cuenta atrás".
- Hecho con Xcode 27.2.

## Abrir y ejecutar

Abre `NextAppointment/NextAppointment.xcodeproj` en Xcode, elige un simulador de
iPhone y pulsa ▶. Los tests se lanzan con ⌘U, o desde la terminal:

```bash
cd ios/NextAppointment
xcodebuild test -project NextAppointment.xcodeproj -scheme NextAppointment \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

Para instalarla en un iPhone real hay que elegir el equipo de firma en Xcode
(Signing & Capabilities → Team) en los dos targets: `NextAppointment` y
`NextAppointmentWidgetExtension`. Los dos usan el App Group
`group.com.aleweing.nextappointment`; con la firma automática Xcode debería
registrarlo en tu cuenta. Esto solo se ha probado en el simulador.

## Estructura

| Carpeta | Contenido |
|---|---|
| `NextAppointment/Core/` | Lógica sin interfaz, portada de la web: modelo `Event`, `Countdown` (recurrencia), archivado, orden y filtro, importación y línea de tiempo del widget. Se compila en la app, en el widget y en los tests. |
| `NextAppointment/Shared/` | Colores y estilos comunes a la app y al widget. |
| `NextAppointment/NextAppointment/` | La app: pantallas SwiftUI, `EventStore` y avisos locales. |
| `NextAppointment/NextAppointmentWidget/` | El widget de pantalla de inicio (tamaños pequeño y mediano). |
| `NextAppointment/NextAppointmentTests/` | Tests unitarios de toda la lógica de `Core`. |

Los eventos se guardan en `events.json`, con el mismo formato que el archivo de
exportación de la web, dentro del contenedor del App Group para que el widget
pueda leerlo. Si existe el archivo de la fase 1 (en Documentos), se mueve solo.

## Qué hace

- Carrusel con cuenta atrás en vivo, lista "Mis eventos" con búsqueda, filtro
  por categoría y cuatro órdenes; crear, editar y borrar; recurrencia completa.
- Aviso local antes del evento.
- Archivado automático al abrir la app (evento único a las 24 h de pasar,
  serie terminada al instante, borrado a los 30 días) y vista "Archivados" con
  restaurar.
- Celebración con confeti cuando llega un evento único.
- Importar el `.json` exportado por la web (menú ··· de "Mis eventos").
- Widget con el próximo evento; el tamaño mediano muestra además los dos
  siguientes. Se actualiza solo cuando cambian los eventos en la app.

## Datos de ejemplo (solo en depuración)

Lanzando la app con el argumento `-demo-data` se sustituyen los eventos por
unos de ejemplo. Añadiendo `-demo-aviso` se incluye un evento dentro de 4
minutos con aviso 2 minutos antes, para probar la notificación y la celebración:

```bash
xcrun simctl launch booted com.aleweing.nextappointment -demo-data -demo-aviso
```

Con `-import-file <ruta>` la lista "Mis eventos" importa ese archivo sin pasar
por el selector de archivos (el resto del flujo es el mismo).

## Diferencias conocidas con la web

- **Fin de mes y 29 de febrero.** Cada ocurrencia se calcula desde el ancla
  (ancla + N × intervalo). Un evento mensual del día 31 cae en 28/29 de febrero
  y vuelve al 31 en marzo; en la web, el 31 de enero + 1 mes desborda al 3 de
  marzo y la serie se queda desplazada. Un cumpleaños del 29 de febrero se
  celebra el 28 en los años no bisiestos.
- **Colores de acento.** Los colores muy claros se oscurecen en tema claro y
  los muy oscuros se aclaran en tema oscuro, solo en textos, para que se lean.
- **Formulario.** Usa controles de iOS: interruptores para repetición, límites
  y aviso, y ruedas para la antelación del aviso.
- **Borrar.** Además del botón del formulario, se puede deslizar una fila de
  "Mis eventos" hacia la izquierda.
- **Celebración.** La web solo celebra si la app está abierta en el instante en
  que llega el evento. Aquí se celebra la primera vez que se abre la pantalla
  principal después de que llegue (mientras no se haya archivado), porque en el
  móvil la app rara vez está abierta justo entonces. Un evento que se crea o se
  importa ya pasado no se celebra.
- **Orden y opciones de la lista.** El orden, "Archivados" e "Importar
  eventos…" están en el menú ··· en vez de en botones y chips sueltos.

## Sin hacer

Lo que el traspaso deja fuera del prototipo (push desde servidor, compartir por
enlace, página pública, App Store) y, de la web, el resumen de eventos
recurrentes cumplidos con la app cerrada y la exportación.
