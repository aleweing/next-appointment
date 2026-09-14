# Backlog de especificaciones — Next Appointment

Orden acordado de trabajo. Cada ítem se desarrolla como su propia feature branch
con `spec.md` → `plan.md` → `tasks.md`, siguiendo el flujo de Spec Kit.
Se completa uno antes de pasar al siguiente.

| # | Feature branch (sugerida) | Descripción |
|---|---|---|
| 002 | `002-recurrence-end` | Fecha de fin o número máximo de repeticiones para eventos recurrentes |
| 003 | `003-recurrence-history` | Vista de historial de ocurrencias pasadas de un evento recurrente |
| 004 | `004-recurrence-skip` | Pausar/saltar una ocurrencia puntual sin cancelar toda la serie |
| 005 | `005-push-notifications` | Notificaciones push reales vía Service Worker + Cloudflare Worker |
| 006 | `006-multiple-alerts` | Múltiples avisos por evento (ej. 1 semana antes + 1 día antes) |
| 007 | `007-calendar-view` | Vista de calendario mensual/semanal |
| 008 | `008-advanced-filters` | Filtros combinados (categoría + rango de fechas + búsqueda) |
| 009 | `009-category-management` | Gestión de categorías propias (crear/editar/eliminar) |
| 010 | `010-cloud-backup` | Backup automático a la nube (Cloudflare Worker/KV) |
| 011 | `011-ics-export` | Exportar a formato .ics para calendarios nativos |
| 012 | `012-device-sync` | Sincronización entre dispositivos |
| 013 | `013-accessibility-audit` | Auditoría de accesibilidad |
| 014 | `014-ios-widget` | Widget de iOS (Home Screen) con próximo countdown |
| 015 | `015-i18n` | Soporte multi-idioma |

**Estado actual**: `001-next-appointment-core` completo (spec + plan + tasks
confirmados). Bug de recordatorios recurrentes fantasma corregido fuera de
este flujo. Empezamos por `002-recurrence-end`.
