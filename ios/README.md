# Next Appointment para iPhone (prototipo)

Prototipo nativo en SwiftUI de la app de cuentas atrás. Fase 1 de
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

Para instalarla en un iPhone real hay que elegir el equipo de firma en
Xcode (target NextAppointment → Signing & Capabilities → Team).

## Estructura

| Carpeta | Contenido |
|---|---|
| `NextAppointment/Core/` | Modelo `Event`, catálogo y `Countdown` (lógica portada de `js/countdown.js`). Se compila en la app y en los tests; servirá también para el widget. |
| `NextAppointment/NextAppointment/` | La app: pantallas SwiftUI, `EventStore` (JSON en Documentos) y avisos locales. |
| `NextAppointment/NextAppointmentTests/` | Tests unitarios de recurrencia, avisos y lectura/escritura del modelo. |

Los eventos se guardan en `Documents/events.json`, con el mismo formato que el
archivo de exportación de la web.

## Datos de ejemplo (solo en depuración)

Lanzando la app con el argumento `-demo-data` se sustituyen los eventos por
unos de ejemplo. Añadiendo `-demo-aviso` se incluye un evento dentro de 4
minutos con aviso 2 minutos antes, para probar la notificación:

```bash
xcrun simctl launch booted com.aleweing.nextappointment -demo-data -demo-aviso
```

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

## Pendiente (fase 2)

Widget, archivado automático y vista "Archivados", celebración con confeti,
importar el `.json` de la web, filtro por categoría y resto de órdenes. Sin
archivado, un evento único que ya llegó se queda en el carrusel hasta borrarlo.
