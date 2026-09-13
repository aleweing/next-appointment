# Tasks: Next Appointment

**Derivado de**: plan.md  
**Formato**: Una tarea por historia + casos límite independientes  
**Verificabilidad**: Cada tarea tiene criterios de aceptación claros (del spec)

---

## 🔴 P1 — MVP Bloqueante

### TASK-H1: Crear y ver próximas citas (Historia 1)

**Objetivo**: Implementar CRUD mínimo de citas con visualización ordenada cronológicamente.

**Derivado de**: spec.md § Historia de usuario 1  
**Requisitos asociados**: FR-001, FR-002, FR-003  
**Criterios de éxito**: SC-001, SC-002  
**Casos límite relacionados**: CL-001, CL-002, CL-005

**Criterios de aceptación**:
1. ✅ El usuario puede crear una cita con título, fecha y hora válidos en menos de 15 segundos
2. ✅ La cita aparece inmediatamente en la lista de próximas citas
3. ✅ 3+ citas se muestran ordenadas de la más cercana a la más lejana (SC-002: verificar con 10 citas mínimo)
4. ✅ Las citas se persisten en localStorage (sin acción explícita del usuario)
5. ✅ La validación rechaza títulos vacíos y fechas/horas en formato inválido
6. ✅ El layout es responsivo y funciona en iPhone

**Implementación requerida**:
- Función de creación: `createAppointment(title, date, time)` → genera ID único, valida, almacena
- Función de lectura ordenada: `getSortedAppointments()` → retorna array ordenado por datetime
- Función de filtrado: `getUpcomingAppointments()` → excluye pasadas
- UI: Formulario de creación + vista de lista
- Storage: localStorage con clave `next-appointment:events`
- Validación: título no vacío, date YYYY-MM-DD, time HH:MM

**Pruebas**:
- Crear 3 citas con fechas diferentes, verificar orden
- Crear cita, cerrar/reabrir app, verificar persistencia
- Intentar crear con título vacío → error
- Intentar crear con fecha inválida → error

**Dependencias**: Ninguna (baseline)

**Estimación**: 2–3 días

---

### TASK-H2: Editar y eliminar citas (Historia 2)

**Objetivo**: Permitir modificación y eliminación segura de citas existentes.

**Derivado de**: spec.md § Historia de usuario 2  
**Requisitos asociados**: FR-004, FR-005  
**Criterios de éxito**: (ninguno explícito en SC, pero crítico para usabilidad)  
**Casos límite relacionados**: CL-001, CL-002

**Criterios de aceptación**:
1. ✅ El usuario puede editar título, fecha u hora de una cita existente
2. ✅ Los cambios se guardan inmediatamente y la lista se reordena si es necesario
3. ✅ El usuario puede eliminar una cita
4. ✅ Se solicita confirmación antes de eliminar (evitar borrados accidentales)
5. ✅ La cita eliminada desaparece permanentemente de la lista

**Implementación requerida**:
- Función de edición: `updateAppointment(id, updates)` → valida, actualiza, reordena
- Función de eliminación: `deleteAppointment(id)` → requiere confirmación
- UI: Modal/formulario de edición, botón de eliminar con diálogo de confirmación
- Validación: igual que en H1 (título no vacío, fechas válidas)
- Re-ordenamiento: após editar fecha/hora, volver a calcular orden en lista

**Pruebas**:
- Editar cita, verificar cambios reflejados
- Editar fecha a una anterior, verificar reorden
- Intentar eliminar, cancelar, verificar no se elimina
- Confirmar eliminación, verificar desaparece

**Dependencias**: TASK-H1 (debe existir cita para editar/eliminar)

**Estimación**: 1–2 días

---

### TASK-H4: Citas recurrentes (Historia 4)

**Objetivo**: Implementar recurrencia configurable con reaparición automática de citas.

**Derivado de**: spec.md § Historia de usuario 4 (H4 completada en spec actual)  
**Requisitos asociados**: FR-009, FR-010  
**Criterios de éxito**: SC-005  
**Casos límite relacionados**: CL-002 (cita retroactiva recurrente)

**Criterios de aceptación**:
1. ✅ El usuario puede configurar recurrencia al crear/editar una cita (ninguna, cada X días/semanas/meses/años)
2. ✅ Cita recurrente semanal reaparece exactamente 7 días después de completarse (SC-005)
3. ✅ El usuario puede editar el intervalo de una cita recurrente
4. ✅ La recurrencia se aplica a futuras instancias (o serie completa, según diseño)
5. ✅ Cita recurrente pasada NO se archiva; reaparece en la próxima recurrencia

**Implementación requerida**:
- Modelo extendido: `recurrenceUnit` (none/day/week/month/year), `recurrenceInterval` (número)
- Función de cálculo: `calculateNextRecurrence(cita)` → suma intervalo a datetime
- Función de auto-reaparición: en cada tick o carga, verificar citas pasadas y recalcular
- UI: Selector de recurrencia en formulario (con opción de intervalo custom)
- Validación: `recurrenceInterval` ≥ 1
- Caso especial: cita recurrente retroactiva → calcula primer datetime futuro

**Pruebas**:
- Crear cita recurrente cada 7 días, pasar fecha, verificar reaparece en +7 días
- Crear cita recurrente cada 2 semanas, modificar a cada 3 semanas
- Crear cita recurrente pasada (ej. cumpleaños 2025-01-01), verificar calcula próxima ocurrencia correctamente

**Dependencias**: TASK-H1 (extiende modelo y lógica de creación)

**Estimación**: 2–3 días

---

## 🟠 P2 — Complementario

### TASK-H3: Persistencia y respaldo de datos (Historia 3)

**Objetivo**: Implementar exportación/importación de citas en JSON sin duplicados.

**Derivado de**: spec.md § Historia de usuario 3  
**Requisitos asociados**: FR-006, FR-007, FR-008  
**Criterios de éxito**: SC-003, SC-004  
**Casos límite relacionados**: CL-003 (datos corruptos en importación)

**Criterios de aceptación**:
1. ✅ El usuario puede exportar todas las citas a un archivo JSON descargable o copiable al portapapeles
2. ✅ El formato de exportación es válido y reimportable (`{ version: 1, app: "next-appointment", events: [...] }`)
3. ✅ El usuario puede importar un archivo JSON, enlace compartido o código base64
4. ✅ La importación restaura todas las citas sin generar duplicados (detecta por `id`)
5. ✅ Ninguna cita se pierde tras cerrar/reabrir app en 20 pruebas consecutivas (SC-003)
6. ✅ Un backup exportado recupera el 100% de citas originales en instancia limpia (SC-004)

**Implementación requerida**:
- Función de exportación: `exportAppointments()` → retorna JSON con estructura especificada
- Función de importación: `importAppointments(data)` → parsea, valida, detecta duplicados, restaura
- Normalización de formatos: soportar formatos históricos de recurrencia
- UI: Botón de exportar (con opción descarga/portapapeles) y botón de importar (con diálogo de selección de archivo/pegado)
- Validación: estructura JSON válida, campos requeridos presentes, IDs no duplicados
- Deduplicación: importación ignore citas con `id` existente (con advertencia)

**Pruebas**:
- Exportar 5 citas, reimportar en instancia limpia, verificar 5 citas presentes
- Exportar, añadir cita nueva en destino, reimportar original, verificar no hay duplicados
- Importar JSON malformado → error claro, app sigue funcionando
- Importar con 1 cita duplicada, 2 nuevas → 2 se importan, 1 omitida con aviso

**Dependencias**: TASK-H1 (existe modelo de citas)

**Estimación**: 2 días

---

### TASK-H5: Categorización de citas (Historia 5)

**Objetivo**: Asignar citas a categorías predefinidas con filtrado y visualización diferenciada.

**Derivado de**: spec.md (completadas en spec actualizado, no en versión vieja del spec.md anterior)  
**Requisitos asociados**: FR-011, FR-012  
**Criterios de éxito**: SC-006  
**Casos límite relacionados**: Ninguno específico

**Criterios de aceptación**:
1. ✅ El usuario puede asignar una categoría al crear/editar una cita (Cumpleaños, Salud, Fiestas, Ferias, Festivales, Viajes, Otros)
2. ✅ Cada categoría tiene emoji y color visual único
3. ✅ Las citas se muestran con el emoji y color de su categoría (SC-006: 100% sin excepción)
4. ✅ El usuario puede filtrar por categoría en la vista de lista
5. ✅ El cambio de categoría se refleja inmediatamente

**Implementación requerida**:
- Modelo extendido: `category` (string, uno de: `birthday`, `health`, `party`, `fair`, `festival`, `travel`, `other`)
- Constante de categorías: `CATEGORIES` en `js/ui.js` con `{ id, label, emoji, color }`
- Función de filtrado: `filterAppointmentsByCategory(category)` → retorna citas de esa categoría
- UI: Selector de categoría en formulario + chips de filtro en lista + rendering con emoji/color
- Validación: `category` es uno de los valores válidos

**Pruebas**:
- Crear cita en cada categoría, verificar emoji/color correcto
- Filtrar por categoría, verificar solo muestra esa categoría
- Editar categoría de una cita, verificar cambio inmediato
- Exportar citas con categorías, reimportar, verificar categorías preservadas

**Dependencias**: TASK-H1, TASK-H3 (debe existir modelo y exportación)

**Estimación**: 1–2 días

---

## 🟡 P3 — Valor Añadido

### TASK-H6: Recordatorios y notificaciones (Historia 6)

**Objetivo**: Notificar al usuario antes de cita próxima con margen configurable.

**Derivado de**: spec.md § Historia de usuario 4 (H6 en spec actualizado) — pero spec.md viejo solo menciona "Historia 4"  
**Requisitos asociados**: FR-013  
**Criterios de éxito**: SC-008  
**Casos límite relacionados**: CL-004 (denegación de permisos post-concesión)

**Criterios de aceptación**:
1. ✅ El usuario puede configurar un margen de aviso por cita (X minutos/horas/días antes, o ninguno)
2. ✅ Si la app está abierta, se dispara notificación en el navegador cuando se cumple margen
3. ✅ Si el navegador no tiene permisos, se muestra badge visual o alerta en-app (fallback)
4. ✅ No se genera notificación si el margen está desactivado (`null`)
5. ✅ Margen de 60 minutos dispara notificación como máximo 61 minutos antes (SC-008)

**Implementación requerida**:
- Modelo extendido: `notifyBefore` (número en segundos, o `null`)
- Función de notificación: `checkAndNotify(cita)` → calcula si debe notificar basado en margen
- Tick de verificación: cada minuto (o configurable), verifica citas próximas
- Fallback UI: badge o banner en-app si Web Notifications API no disponible
- Petición de permisos: al crear/editar cita con margen, solicita permiso si no ya concedido
- Deduplicación: flag interno (`_notifiedKey`) para evitar múltiples notificaciones de mismo evento

**Pruebas**:
- Crear cita a 65 minutos de ahora con margen de 60 min, verificar notificación después de 4–5 minutos
- Crear cita con margen, rechazar permisos, verificar fallback en-app funciona
- Crear cita sin margen, verificar no hay notificación
- Editar margen de 0 a 30 min, verificar cambio aplica

**Dependencias**: TASK-H1 (existe modelo de citas y tick de app)

**Estimación**: 2 días

---

## 🔵 Casos Límite Independientes

### TASK-CL-001: Dos citas con fecha/hora exactamente iguales

**Objetivo**: Validar que el sistema permite y ordena determinísticamente citas simultáneas.

**Derivado de**: spec.md § Casos límite  
**Requisitos**: FR-003 (ordenamiento)  
**Historia relacionada**: H1

**Criterios de aceptación**:
1. ✅ El usuario puede crear dos citas con fecha y hora exactamente iguales (sin error)
2. ✅ Ambas citas aparecen en la lista
3. ✅ El orden entre ellas es determinístico (ej. por ID, por orden de creación)
4. ✅ No hay corrupción de datos ni comportamiento undefined

**Pruebas**:
- Crear cita A: 2026-10-01 14:00
- Crear cita B: 2026-10-01 14:00
- Verificar ambas aparecen
- Verificar orden es consistente (recargar varias veces)
- Exportar/reimportar, verificar orden se mantiene

**Estimación**: 0.5 días (validación, no nuevo feature)

---

### TASK-CL-002: Cita retroactiva (fecha/hora ya pasada)

**Objetivo**: Validar que se permite crear cita con datetime pasado y se archiva correctamente.

**Derivado de**: spec.md § Casos límite  
**Requisitos**: FR-001, FR-014 (archivado automático)  
**Historia relacionada**: H1, H4

**Criterios de aceptación**:
1. ✅ El usuario puede crear cita con fecha/hora ya pasada sin error
2. ✅ Cita retroactiva NO recurrente NO aparece en "próximas citas"
3. ✅ Cita retroactiva NO recurrente se archiva automáticamente después de 24h
4. ✅ Cita retroactiva recurrente calcula correctamente la próxima ocurrencia (futuro)

**Pruebas**:
- Crear cita: 2026-01-01 10:00 (pasada), verificar no aparece en próximas
- Esperar 24h (simular con timestamp), verificar se archiva
- Crear cumpleaños retroactivo: 1990-01-15 (recurrente anual), verificar calcula siguiente 2027-01-15
- Exportar/reimportar, verificar comportamiento se mantiene

**Estimación**: 0.5 días (validación)

---

### TASK-CL-003: Importación con datos corruptos o formato antiguo

**Objetivo**: Validar robustez de importación ante JSON malformado y normalización de formatos históricos.

**Derivado de**: spec.md § Casos límite  
**Requisitos**: FR-008 (importación tolerante)  
**Historia relacionada**: H3

**Criterios de aceptación**:
1. ✅ Importar JSON inválido → error claro, app sigue funcionando, datos previos intactos
2. ✅ Importar con campos requeridos faltantes → omite esa cita con advertencia
3. ✅ Importar con formato recurrencia antiguo → normaliza automáticamente a nueva estructura
4. ✅ Importar con IDs corruptos → regenera IDs evitando colisiones
5. ✅ Importar parcialmente válido (5 OK, 2 inválidas) → importa 5, advierte de 2

**Pruebas**:
- Importar `{ invalid json }`  → error
- Importar `{ version: 1, events: [{ name: "Cita" }] }` (sin date/time) → omite con aviso
- Importar evento con formato recurrencia histórico → normaliza
- Importar 5 citas válidas + 2 inválidas → resumen "Importadas: 5, Ignoradas: 2"

**Estimación**: 1 día

---

### TASK-CL-004: Denegación de permisos de notificación post-concesión

**Objetivo**: Validar que app no falla si usuario revoca permisos de notificación después de concederlos.

**Derivado de**: spec.md § Casos límite  
**Requisitos**: FR-013 (notificaciones con fallback)  
**Historia relacionada**: H6

**Criterios de aceptación**:
1. ✅ Usuario concede permisos, luego los revoca en settings del navegador
2. ✅ App detecta revocación (Notification.permission === 'denied')
3. ✅ App no falla ni intenta notificar
4. ✅ App muestra recordatorio alternativo en-app (badge, banner)
5. ✅ Usuario puede re-solicitar permisos si quiere

**Pruebas**:
- Crear cita con margen, conceder permisos, verificar notificación
- Ir a navegador settings, revocar permisos para el sitio
- Volver a app, crear otra cita con margen próximo
- Verificar que no hay error en consola y fallback en-app aparece

**Estimación**: 0.5 días (validación)

---

### TASK-CL-005: Funcionamiento offline (PWA completo)

**Objetivo**: Validar que app funciona 100% offline con localStorage y Service Worker.

**Derivado de**: spec.md § Casos límite  
**Requisitos**: FR-006 (persistencia), FR-016 (PWA)  
**Historia relacionada**: H1–H6 (todas)

**Criterios de aceptación**:
1. ✅ App se abre offline (SW caché assets HTML/CSS/JS v13)
2. ✅ Crear cita offline, datos se guardan en localStorage
3. ✅ Editar/eliminar cita offline, cambios persisten
4. ✅ Exportar/importar offline, funciona
5. ✅ Volver online, cambios se sincronizan (si aplica Cloudflare Worker, pero no requerido en spec)
6. ✅ No hay errores de red en consola

**Pruebas**:
- Abrir DevTools → Network → Offline
- Crear 3 citas, verificar en localStorage
- Editar una, verificar cambio en localStorage
- Cerrar tab, reabrir offline, verificar citas aún presentes
- Ir online, verificar no hay errores de sincronización (PWA solo, sin backend)

**Estimación**: 1 día (validación, no nuevo feature, requiere configurar SW)

---

## Resumen de tareas

| ID | Nombre | Prioridad | Dependencias | Estimación | Historia |
|----|--------|-----------|--------------|------------|---------|
| TASK-H1 | Crear y ver próximas citas | P1 | Ninguna | 2–3d | H1 |
| TASK-H2 | Editar y eliminar citas | P1 | TASK-H1 | 1–2d | H2 |
| TASK-H4 | Citas recurrentes | P1 | TASK-H1 | 2–3d | H4 |
| TASK-H3 | Persistencia y respaldo | P2 | TASK-H1 | 2d | H3 |
| TASK-H5 | Categorización | P2 | TASK-H1, TASK-H3 | 1–2d | H5 |
| TASK-H6 | Notificaciones | P3 | TASK-H1 | 2d | H6 |
| TASK-CL-001 | Citas simultáneas | P1 | TASK-H1 | 0.5d | H1 |
| TASK-CL-002 | Cita retroactiva | P1 | TASK-H1, TASK-H4 | 0.5d | H1/H4 |
| TASK-CL-003 | Import con datos corruptos | P2 | TASK-H3 | 1d | H3 |
| TASK-CL-004 | Permisos denegados | P3 | TASK-H6 | 0.5d | H6 |
| TASK-CL-005 | Offline completo | P1 | TASK-H1–H6 | 1d | H1–H6 |

**Total estimado**: 14–16 días (MVP P1 ~1 semana, P2 ~4 días, P3 ~2.5 días + casos límite)

---

## Orden de ejecución recomendado

```
Sprint 1 (P1 Core):
  1. TASK-H1 (Crear/ver)
  2. TASK-H2 (Editar/eliminar)
  3. TASK-CL-001, TASK-CL-002, TASK-CL-005 (validaciones P1)

Sprint 2 (P1 Extensión + P2 Inicio):
  4. TASK-H4 (Recurrencia)
  5. TASK-H3 (Persistencia)
  6. TASK-CL-003 (Import robusto)

Sprint 3 (P2 Fin + P3):
  7. TASK-H5 (Categorías)
  8. TASK-H6 (Notificaciones)
  9. TASK-CL-004 (Fallback permisos)
```

