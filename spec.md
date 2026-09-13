# Especificación de Funcionalidad: Next Appointment

**Feature Branch**: `001-next-appointment-core`
**Creado**: 2026-09-14
**Estado**: Borrador
**Input**: Gestión y programación de próximas citas (agenda con cuenta atrás)

## Contexto

Next Appointment ya existe como PWA personal (vanilla JS + GitHub Pages + Cloudflare Worker) con un sistema de exportación/importación de backups. Esta especificación cubre el comportamiento esperado del producto — el "qué" y el "por qué" — no la arquitectura (eso vive en `plan.md`). Si esta spec es para una versión nueva desde cero, ignora las referencias a funcionalidad ya construida; si es para formalizar lo existente antes de seguir iterando, estas referencias sirven de línea base.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Crear y ver próximas citas (Prioridad: P1)

Como usuario, quiero crear una cita con título, fecha y hora, y ver todas mis próximas citas ordenadas cronológicamente, para saber qué tengo pendiente sin tener que revisar varias fuentes.

**Por qué esta prioridad**: Es el valor mínimo del producto — sin esto no hay app. Debe funcionar de forma aislada del resto de historias.

**Prueba independiente**: Se puede probar creando 3 citas con fechas distintas y verificando que aparecen ordenadas de la más próxima a la más lejana, sin depender de edición, borrado ni backup.

**Escenarios de aceptación**:
1. **Dado** que no hay citas guardadas, **cuando** el usuario crea una cita con título, fecha y hora válidos, **entonces** la cita aparece en la lista de próximas citas.
2. **Dado** que existen varias citas con fechas distintas, **cuando** el usuario abre la app, **entonces** las citas se muestran ordenadas de la más cercana a la más lejana en el tiempo.
3. **Dado** que una cita tiene fecha/hora ya pasada, **cuando** el usuario abre la app, **entonces** la cita pasada no se muestra en "próximas citas" (o se muestra claramente diferenciada, a decidir — ver Aclaraciones).

### Historia de usuario 2 - Editar y eliminar citas (Prioridad: P1)

Como usuario, quiero editar o eliminar una cita existente, para corregir errores o quitar planes que ya no aplican.

**Por qué esta prioridad**: Sin esto, un error de entrada obliga a vivir con datos incorrectos o borrar y rehacer todo manualmente.

**Prueba independiente**: Se puede probar creando una cita, editando su fecha, y verificando que el nuevo valor se refleja y reordena la lista; luego eliminándola y verificando que desaparece.

**Escenarios de aceptación**:
1. **Dado** una cita existente, **cuando** el usuario edita su título, fecha u hora, **entonces** los cambios se guardan y la lista se reordena si corresponde.
2. **Dado** una cita existente, **cuando** el usuario la elimina, **entonces** desaparece de la lista de forma permanente.
3. **Dado** que el usuario intenta eliminar una cita, **cuando** confirma la acción, **entonces** se pide confirmación antes de borrar (evitar borrados accidentales).

### Historia de usuario 3 - Persistencia y respaldo de datos (Prioridad: P2)

Como usuario, quiero que mis citas se conserven entre sesiones y poder exportarlas/importarlas, para no perder mi agenda si cambio de dispositivo o se borran los datos locales.

**Por qué esta prioridad**: Complementa el valor core; sin esto la app es usable a corto plazo pero frágil.

**Prueba independiente**: Se puede probar cerrando y reabriendo la app y verificando que las citas persisten; exportando a JSON y reimportando en una instancia limpia.

**Escenarios de aceptación**:
1. **Dado** que el usuario ha creado citas, **cuando** cierra y reabre la app, **entonces** todas las citas siguen presentes.
2. **Dado** un conjunto de citas, **cuando** el usuario exporta, **entonces** obtiene un archivo (o portapapeles) con todos los datos en un formato reimportable.
3. **Dado** un archivo de exportación válido, **cuando** el usuario lo importa, **entonces** las citas se restauran sin duplicados.

### Historia de usuario 4 - Recordatorios/notificaciones (Prioridad: P3)

Como usuario, quiero recibir un aviso antes de una cita próxima, para no olvidarla.

**Por qué esta prioridad**: Valor añadido, no bloqueante para el uso básico de la app; depende de permisos del navegador/OS que pueden fallar de forma no controlable.

**Prueba independiente**: Se puede probar creando una cita a pocos minutos de la hora actual y verificando que se dispara una notificación en el margen configurado.

**Escenarios de aceptación**:
1. **Dado** que el usuario activó notificaciones, **cuando** una cita está a X minutos/horas de ocurrir, **entonces** recibe un aviso.
2. **Dado** que el navegador no tiene permisos de notificación, **cuando** se cumple la condición de aviso, **entonces** la app no falla y muestra el recordatorio de forma alternativa (ej. badge o resaltado en la UI).

### Casos límite

- ¿Qué pasa si el usuario crea dos citas con la misma fecha y hora exactas?
- ¿Qué pasa si la fecha introducida ya pasó (cita retroactiva)?
- ¿Qué pasa si el usuario importa un backup con datos corruptos o de un formato antiguo?
- ¿Qué pasa si se deniegan los permisos de notificación después de haberlos concedido?
- ¿Cómo se comporta la app sin conexión (dado que es una PWA)?

## Requisitos *(obligatorio)*

### Requisitos funcionales

- **FR-001**: El sistema DEBE permitir crear una cita con título, fecha y hora.
- **FR-002**: El sistema DEBE validar que el título no esté vacío y que fecha/hora tengan un formato válido antes de guardar.
- **FR-003**: El sistema DEBE mostrar las citas ordenadas cronológicamente (de la más próxima a la más lejana).
- **FR-004**: El sistema DEBE permitir editar cualquier campo de una cita existente.
- **FR-005**: El sistema DEBE permitir eliminar una cita, con confirmación previa.
- **FR-006**: El sistema DEBE persistir las citas entre sesiones sin acción explícita del usuario.
- **FR-007**: El sistema DEBE permitir exportar todas las citas a un archivo reimportable.
- **FR-008**: El sistema DEBE permitir importar un archivo de backup y restaurar las citas sin generar duplicados.
- **FR-009**: El sistema DEBERÍA (should) poder notificar al usuario antes de una cita próxima, si el usuario lo habilita.
- **FR-010**: El sistema DEBE funcionar en un layout responsivo, priorizando el uso en iPhone.

### Entidades clave

- **Cita**: título (texto), fecha (date), hora (time), estado derivado (próxima / pasada), identificador único.

## Criterios de éxito *(obligatorio)*

- **SC-001**: Un usuario puede crear una cita completa (título + fecha + hora) en menos de 15 segundos desde que abre la app.
- **SC-002**: El 100% de las citas se muestran en el orden cronológico correcto, verificado con al menos 10 citas de prueba.
- **SC-003**: Ninguna cita se pierde tras cerrar y reabrir la app en 20 pruebas consecutivas.
- **SC-004**: Un backup exportado se puede reimportar en una instancia limpia recuperando el 100% de las citas originales.

## Aclaraciones pendientes

- ¿Las citas pasadas deben desaparecer de la vista o quedar visibles en un historial?
- ¿Se permiten citas recurrentes (semanales, mensuales) o solo puntuales?
- ¿El margen de aviso de notificación es configurable por el usuario o fijo?
- ¿Se necesita algún tipo de categorización/etiquetado de citas (personal, trabajo, etc.)?

## Supuestos

- Un único usuario por instancia de la app (uso personal, sin multiusuario ni login).
- El formato de exportación es JSON, consistente con el resto de la serie de PWAs personales.
- No se requiere sincronización en tiempo real entre dispositivos; el respaldo/restauración cubre esa necesidad.
