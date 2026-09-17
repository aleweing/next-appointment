# Especificación de Funcionalidad: Notificaciones push reales

**Feature Branch**: `005-push-notifications`
**Creado**: 2026-09-16
**Estado**: Borrador
**Input**: Notificaciones push vía Service Worker + Cloudflare Worker, para que los avisos lleguen aunque la app esté cerrada

## Contexto

Hoy, `notifyBefore` (el "avisarme antes" configurado por evento) solo funciona si la app está abierta en primer plano — `checkNotifications()` corre en el bucle de renderizado del cliente y no hay nada que lo dispare con la app cerrada. Esta especificación introduce notificaciones push reales, entregadas por el sistema operativo, que llegan aunque Next Appointment no esté abierta.

Es la primera funcionalidad de la app que necesita un componente servidor con estado (hasta ahora, "zero backend" era una convención fija del proyecto). Esa convención se rompe deliberadamente acá — ver `plan.md` para el detalle de por qué y con qué alcance mínimo.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Activar avisos aunque la app esté cerrada (Prioridad: P1)

Como usuario, quiero activar notificaciones push en mi iPhone, para que un aviso me llegue aunque no tenga la app abierta ni el teléfono desbloqueado.

**Por qué esta prioridad**: Es la razón de ser de la feature — sin esto, no hay nada nuevo que ofrecer respecto a hoy.

**Prueba independiente**: Activar push en un dispositivo, configurar un evento con aviso a 1 minuto, cerrar completamente la app y verificar que el aviso llega igual.

**Escenarios de aceptación**:
1. **Dado** que el usuario abre Next Appointment instalada en la pantalla de inicio del iPhone, **cuando** activa "Notificaciones push" desde la app, **entonces** el sistema le pide permiso de notificaciones y, al concederlo, el dispositivo queda registrado para recibir avisos.
2. **Dado** un dispositivo con push activado y un evento con "avisarme antes" configurado, **cuando** llega el momento del aviso y la app está cerrada, **entonces** el sistema operativo muestra una notificación con el nombre del evento.
3. **Dado** que el usuario abre Next Appointment desde una pestaña normal de Safari (no instalada en pantalla de inicio), **cuando** intenta activar push, **entonces** la app le explica que primero debe añadirla a la pantalla de inicio (limitación de iOS, no de la app).

### Historia de usuario 2 - Los avisos siguen llegando para series recurrentes, sin que el usuario tenga que hacer nada (Prioridad: P1)

Como usuario, quiero que una serie recurrente con aviso configurado me siga notificando en cada ocurrencia futura, sin tener que reabrir la app para "renovar" el aviso.

**Prueba independiente**: Configurar una serie semanal con aviso, dejar pasar dos ocurrencias sin abrir la app, y verificar que llegó un aviso por cada una.

**Escenarios de aceptación**:
1. **Dado** una serie recurrente con aviso activo, **cuando** se cumple una ocurrencia y llega su aviso, **entonces** el sistema programa automáticamente el aviso de la siguiente ocurrencia, sin intervención del usuario.
2. **Dado** una serie recurrente que alcanza su límite (feature 002), **cuando** se envía el aviso de su última ocurrencia, **entonces** no se programa ningún aviso adicional para esa serie.

### Historia de usuario 3 - Editar o borrar un evento actualiza sus avisos pendientes (Prioridad: P1)

Como usuario, quiero que si edito la fecha, el aviso o borro un evento, el aviso programado se actualice o cancele en consecuencia, para no recibir avisos de algo que ya cambió o ya no existe.

**Escenarios de aceptación**:
1. **Dado** un evento con aviso programado, **cuando** el usuario cambia su fecha/hora o el tiempo de aviso, **entonces** el aviso pendiente se reprograma con los nuevos datos.
2. **Dado** un evento con aviso programado, **cuando** el usuario lo borra o desactiva "avisarme antes", **entonces** el aviso pendiente se cancela y no llega.

### Historia de usuario 4 - Desactivar push en un dispositivo (Prioridad: P2)

Como usuario, quiero poder desactivar las notificaciones push en un dispositivo, para dejar de recibir avisos del sistema si ya no los quiero.

**Escenarios de aceptación**:
1. **Dado** un dispositivo con push activado, **cuando** el usuario lo desactiva desde la app, **entonces** deja de recibir avisos en ese dispositivo.
2. **Dado** que el usuario revocó el permiso de notificaciones desde los Ajustes del iPhone (no desde la app), **cuando** el servidor intenta enviar un aviso y falla por permiso revocado, **entonces** el sistema deja de intentar enviar a ese dispositivo y no acumula errores indefinidamente.

### Casos límite

- El usuario tiene la app instalada en más de un dispositivo (ej. iPhone y iPad): ambos deberían poder recibir avisos de forma independiente.
- El usuario borra la app de la pantalla de inicio sin desactivar push primero: el servidor eventualmente detecta el envío fallido y limpia esa suscripción.
- El usuario configura un aviso "a 0 minutos" (justo en el momento del evento): debe comportarse igual que cualquier otro aviso, sin caso especial.
- Falla de red o del proveedor de push en el momento de enviar: no debe bloquear ni afectar la próxima notificación programada de otros eventos.

## Requisitos *(obligatorio)*

- **FR-001**: El sistema DEBE permitir activar notificaciones push desde dentro de la app instalada en la pantalla de inicio del dispositivo.
- **FR-002**: El sistema DEBE detectar si la app no está instalada en pantalla de inicio y explicarlo antes de intentar activar push (limitación conocida de iOS/Safari).
- **FR-003**: El sistema DEBE entregar el aviso configurado (`notifyBefore`) de un evento como notificación del sistema operativo, aunque la app esté cerrada.
- **FR-004**: El sistema DEBE reprogramar automáticamente el aviso de la siguiente ocurrencia de una serie recurrente después de enviar el de la ocurrencia actual, sin requerir que el usuario abra la app.
- **FR-005**: El sistema DEBE respetar el fin de una serie recurrente limitada (feature 002): no debe programar avisos más allá de su última ocurrencia válida.
- **FR-006**: El sistema DEBE actualizar o cancelar el aviso programado de un evento cuando el usuario lo edita o lo borra.
- **FR-007**: El sistema DEBE permitir desactivar push en un dispositivo desde la propia app.
- **FR-008**: El sistema DEBE dejar de enviar a una suscripción que el proveedor de push reporta como inválida o expirada, sin reintentar indefinidamente.
- **FR-009**: El sistema NO DEBE requerir ninguna cuenta de usuario ni login — sigue siendo una app personal sin autenticación de usuarios.
- **FR-010**: El sistema DEBE seguir funcionando exactamente igual que hoy (aviso solo en primer plano) para quien no active push — la feature es aditiva, no reemplaza nada por defecto.

## Criterios de éxito *(obligatorio)*

- **SC-001**: Un aviso configurado a N minutos antes de un evento llega como notificación del sistema con la app completamente cerrada, con una demora razonable respecto al minuto exacto (ver plan.md para la granularidad real del sistema).
- **SC-002**: Una serie recurrente con aviso sigue notificando en cada ocurrencia durante al menos 4 ciclos consecutivos sin que el usuario abra la app entre medio.
- **SC-003**: Editar la fecha de un evento con aviso pendiente hace que el próximo aviso llegue en el horario nuevo, nunca en el viejo.
- **SC-004**: Borrar un evento con aviso pendiente hace que ese aviso no llegue nunca.

## Supuestos

- Sigue sin haber cuentas de usuario: la identidad de "quién recibe qué" se resuelve por dispositivo (cada instalación en pantalla de inicio es una suscripción independiente), no por usuario autenticado.
- El alcance es notificaciones informativas (nombre del evento + cuándo), no accionables (no hay botones dentro de la notificación en esta primera iteración).
- Como es una app personal sin usuarios reales más allá de Alejandro, no se prioriza escalar a miles de dispositivos — la solución puede ser simple aunque no sea la más sofisticada posible.
