# Plan de Tareas: Fin de recurrencia (Feature 002)

**Feature Branch**: `002-recurrence-end`  
**Spec relacionada**: `spec.md` (misma carpeta)  
**Plan técnico**: `plan.md` (misma carpeta)  
**Estado**: Borrador  
**Total de tareas**: 12 (P1: 7, P2: 5)

---

## 🔴 P1: Bloqueante para que la feature sea usable

### TASK-002-001: Extender modelo de datos en Storage

**Descripción**: Agregar los campos `recurrenceEndDate`, `recurrenceMaxCount` y `recurrenceOccurrenceCount` al objeto evento, con retrocompatibilidad.

**Criterios de aceptación**:
1. Todos los eventos existentes sin estos campos se comportan como hoy (sin límite)
2. Nuevos eventos pueden incluir opcionalmente `recurrenceEndDate` (string YYYY-MM-DD) o `recurrenceMaxCount` (número entero)
3. El contador `recurrenceOccurrenceCount` inicia en 0 y se puede incrementar
4. `Storage.upsert()` y `Storage.saveAll()` persisten estos campos sin error
5. Al importar JSON antiguo, los campos faltantes se asignan a `null` automáticamente

**Archivos a modificar**:
- `js/storage.js` — extender modelo en comentarios y ejemplos
- `js/app.js` — asegurar que `handleSubmit()` incluya estos campos

**Definición de listo**:
- ✅ localStorage contiene los nuevos campos
- ✅ Evento sin límite: se carga sin cambios
- ✅ Evento con límite: se persiste y recarga correctamente

---

### TASK-002-002: Función `isRecurrenceFinished()` en Countdown

**Descripción**: Nueva función que determina si una serie recurrente ha alcanzado su límite (por conteo o fecha).

**Criterios de aceptación**:
1. `isRecurrenceFinished(event)` devuelve `false` si `recurrenceMaxCount` y `recurrenceEndDate` son ambos `null` (indefinido)
2. Devuelve `true` si `recurrenceOccurrenceCount >= recurrenceMaxCount` (cuando maxCount está definido)
3. Devuelve `true` si la próxima ocurrencia calculada superaría `recurrenceEndDate` (cuando endDate está definido)
4. Si ambos límites están definidos, devuelve `true` cuando se cumpla **cualquiera** de los dos (lógica OR)
5. No modifica el estado del evento, solo consulta

**Archivos a modificar**:
- `js/countdown.js` — nueva función `isRecurrenceFinished(event)`

**Definición de listo**:
- ✅ Función creada y exportada
- ✅ Test manual: evento sin límite → false
- ✅ Test manual: evento con 3 repeticiones, conteo=3 → true
- ✅ Test manual: evento con fecha fin 2026-09-15, siguiente ocurrencia 2026-09-20 → true

---

### TASK-002-003: Modificar `Countdown.getTargetDate()` para respetar límites

**Descripción**: Adaptar la función existente para dejar de calcular nuevas ocurrencias cuando se alcanza un límite.

**Criterios de aceptación**:
1. Si `isRecurrenceFinished(event)` es true, devolver la última ocurrencia válida (antes de que se exceda el límite)
2. Si es false, comportarse como hoy (avanzar sin límite)
3. La retrocompatibilidad se mantiene: eventos sin límite siguen avanzando indefinidamente
4. No se modifica el estado del evento, solo se calcula la fecha de retorno

**Archivos a modificar**:
- `js/countdown.js` — lógica dentro de `getTargetDate(event)`

**Definición de listo**:
- ✅ Evento semanal con 3 repeticiones: la 3ª ocurrencia es válida, no hay 4ª
- ✅ Evento anual sin límite: sigue calculando años futuros
- ✅ Evento con fecha fin: nunca avanza más allá de esa fecha

---

### TASK-002-004: Agregar campos de entrada en formulario

**Descripción**: Extender el formulario existente (en `index.html`) con dos inputs opcionales para configurar límites de recurrencia.

**Criterios de aceptación**:
1. Dentro de `repeat-row` (que solo se muestra si está activado "Repetir"), agregar:
   - Input de fecha tipo `type="date"` con label "Hasta (opcional)" — vinculado a `event-recurrence-end-date`
   - Input numérico `type="number"` con label "Máximo X repeticiones (opcional)" — vinculado a `event-recurrence-max-count`
2. Ambos campos están ocultos por defecto (si el evento no tiene límite)
3. Al activar "Repetir", los campos aparecen junto a intervalo/unidad
4. Al desactivar "Repetir", los valores se limpian

**Archivos a modificar**:
- `index.html` — agregar inputs dentro de `repeat-row` (líneas ~137–147)

**Definición de listo**:
- ✅ Inputs visibles y accesibles
- ✅ No interfieren con flujo existente
- ✅ Son opcionales (pueden dejarse vacíos)

---

### TASK-002-005: Guardar límites desde formulario a evento

**Descripción**: Conectar los valores de los nuevos campos del formulario con el objeto evento antes de guardarlo.

**Criterios de aceptación**:
1. En `handleSubmit()`, leer `event-recurrence-end-date` y `event-recurrence-max-count` del formulario
2. Si están vacíos, asignar `null` (no guardar 0 o strings vacías)
3. Si están completos, validar:
   - `recurrenceEndDate` debe ser una fecha válida posterior a hoy (o igual a la fecha base del evento)
   - `recurrenceMaxCount` debe ser un número entero > 0
4. Si la validación falla, mostrar error sin guardar el evento
5. Si la validación pasa, incluir los valores en el objeto evento antes de `Storage.upsert()`

**Archivos a modificar**:
- `js/app.js` — lógica dentro de `handleSubmit()` (líneas ~695–753)

**Definición de listo**:
- ✅ Guardar evento con límite persiste correctamente
- ✅ Guardar evento sin límite lo deja con null
- ✅ Validación rechaza fecha pasada
- ✅ Validación rechaza conteo <= 0

---

### TASK-002-006: Cargar límites en formulario al editar

**Descripción**: Cuando se abre un evento recurrente para editar, pre-rellenar los campos de límite si están configurados.

**Criterios de aceptación**:
1. En `openEditForm(id)`, después de leer el evento existente, incluir:
   - `document.getElementById('event-recurrence-end-date').value = event.recurrenceEndDate || ''`
   - `document.getElementById('event-recurrence-max-count').value = event.recurrenceMaxCount || ''`
2. Los campos aparecen rellenados o vacíos según corresponda
3. El usuario puede modificar o borrar los límites

**Archivos a modificar**:
- `js/app.js` — lógica dentro de `openEditForm()` (líneas ~648–692)

**Definición de listo**:
- ✅ Editar evento con límite: valores pre-rellenados
- ✅ Editar evento sin límite: campos vacíos
- ✅ Modificar límite: se guarda el nuevo valor

---

### TASK-002-007: Archivar automáticamente series finalizadas en `runArchiveMaintenance()`

**Descripción**: Extender la lógica de mantenimiento de archivado para detectar series recurrentes que alcanzaron su límite y archivarlas automáticamente.

**Criterios de aceptación**:
1. `runArchiveMaintenance()` (líneas ~438–469) hoy archiva eventos NO recurrentes vencidos +24h
2. Agregar una segunda pasada: para eventos recurrentes activos, si `isRecurrenceFinished(event)` es true, archivar inmediatamente
3. No esperar 24h como con eventos no recurrentes (una serie terminada es archivable al instante)
4. Verificar que eventos recurrentes sin límite no se afecten
5. Reutilizar `Storage.archive(id)` existente

**Archivos a modificar**:
- `js/app.js` — lógica dentro de `runArchiveMaintenance()` (líneas ~438–469)

**Definición de listo**:
- ✅ Serie con 2 repeticiones (ambas pasadas): se archiva automáticamente
- ✅ Serie semanal sin límite: permanece activa
- ✅ Ejecutar `runArchiveMaintenance()` múltiples veces: no re-archiva ni causa errores

---

## 🟠 P2: Complementario (mejora de experiencia)

### TASK-002-008: Actualizar `recurrenceLabel()` para mostrar límites

**Descripción**: Extender el badge de recurrencia en cards para mostrar visualmente si hay límite (ej. "🔁 Cada 7 días · 3 reps" o "🔁 Cada semana · hasta 30-11").

**Criterios de aceptación**:
1. En `js/ui.js` — función `recurrenceLabel(recurrence)` (línea ~50–66)
2. Si hay `maxCount`, añadir sufijo: ` · ${maxCount} reps`
3. Si hay `endDate`, añadir sufijo: ` · hasta ${formatDate(endDate)}`
4. Si hay ambos, mostrar ambos sufijos
5. El sufijo se añade al label existente sin romper formato

**Archivos a modificar**:
- `js/ui.js` — lógica dentro de `recurrenceLabel()`

**Definición de listo**:
- ✅ Card con límite de repeticiones: muestra "· 3 reps"
- ✅ Card con fecha de fin: muestra "· hasta 30 nov"
- ✅ Card sin límite: muestra solo "Cada..." (sin cambios)

---

### TASK-002-009: Mostrar límites en vista previa del formulario

**Descripción**: Cuando se crea/edita un evento recurrente con límite, mostrar el límite en la card de vista previa.

**Criterios de aceptación**:
1. En `updatePreview()` (líneas ~788–820), después de renderizar el countdown, verificar si hay `recurrenceEndDate` o `recurrenceMaxCount`
2. Si existen, añadir una línea bajo el countdown: "🔁 Hasta 30-11 · máx 3 reps"
3. El texto debe ser claro y no interferir con el countdown

**Archivos a modificar**:
- `js/app.js` — lógica dentro de `updatePreview()`

**Definición de listo**:
- ✅ Crear evento con límites: preview muestra "🔁 Hasta ..."
- ✅ Crear sin límites: preview no muestra nada extra
- ✅ Editar límites: preview actualiza en vivo

---

### TASK-002-010: Soporte en `checkMissedRecurringEvents()` para límites

**Descripción**: Adaptar la lógica de detección de recurrentes perdidos (mientras la app estaba cerrada) para respetar los límites superiores.

**Criterios de aceptación**:
1. En `checkMissedRecurringEvents()` (líneas ~477–571), al generar ocurrencias con `advanceByRecurrence()`, respetar `isRecurrenceFinished()`
2. No reportar ocurrencias que habrían sucedido después del límite
3. El mecanismo de búsqueda en ventana (lastSeen, now] sigue siendo igual, solo se filtra por límite
4. Compatibilidad: eventos sin límite se comportan exactamente igual que hoy

**Archivos a modificar**:
- `js/app.js` — lógica dentro de `checkMissedRecurringEvents()`

**Definición de listo**:
- ✅ Serie de 3 semanas que alcanzó su límite: no aparece en "eventos perdidos"
- ✅ Serie indefinida: sigue reportando todas las ocurrencias como antes
- ✅ App abierta después de 10 días: no reporte ocurrencia 4 de una serie con 3 reps

---

### TASK-002-011: Permitir reactivar serie desde vista de archivados

**Descripción**: Cuando se edita un evento archivado por límite de recurrencia, permitir extender o eliminar el límite para reactivarlo.

**Criterios de aceptación**:
1. En vista de archivados, hacer click en evento → abre formulario de edición (igual que hoy)
2. El usuario puede:
   - Aumentar `recurrenceMaxCount` o mover `recurrenceEndDate` hacia el futuro
   - Dejar los campos vacíos para eliminar el límite
3. Al guardar, el evento se des-archiva automáticamente (reutilizar `Storage.unarchive()`)
4. Si el evento se re-activa, `Countdown.getTargetDate()` calcula la próxima ocurrencia correctamente

**Archivos a modificar**:
- `js/app.js` — en `handleSubmit()`, si el evento estaba archivado, llamar `Storage.unarchive(id)` después de guardar

**Definición de listo**:
- ✅ Serie archivada por límite: editar y extender límite
- ✅ Guardar: evento reaparece en lista activa
- ✅ Próxima ocurrencia: se calcula correctamente

---

### TASK-002-012: Importar/exportar con soporte para límites

**Descripción**: Garantizar que los límites de recurrencia se preservan en export/import (JSON y compartir).

**Criterios de aceptación**:
1. En `_buildExportJson()` (líneas ~1024–1041), incluir `recurrenceEndDate` y `recurrenceMaxCount` en cada evento exportado
2. En `acceptBulkJsonImport()` (líneas ~1158–1195), al importar eventos, leer y guardar correctamente estos campos
3. En `encodeEventForShare()` (storage.js líneas ~176–191), incluir opcionales en la carga compartida
4. En `decodeSharedEvent()` (storage.js líneas ~199–223), restaurar correctamente si están presentes

**Archivos a modificar**:
- `js/app.js` — `_buildExportJson()`, `acceptBulkJsonImport()`
- `js/storage.js` — `encodeEventForShare()`, `decodeSharedEvent()`

**Definición de listo**:
- ✅ Exportar evento con límite: JSON incluye campos
- ✅ Importar JSON: campos se restauran
- ✅ Compartir evento recurrente: límite se preserva en enlace
- ✅ Retrocompatibilidad: eventos antiguos sin campos se importan como "sin límite"

---

## 📊 Matriz de Dependencias

```
TASK-002-001 (Modelo datos)
    ↓
TASK-002-002 (isRecurrenceFinished)
    ↓
TASK-002-003 (Modificar getTargetDate)
    ├──→ TASK-002-007 (Archivar en maintenance)
    ├──→ TASK-002-009 (Preview)
    └──→ TASK-002-010 (checkMissedRecurringEvents)

TASK-002-004 (Inputs en formulario)
    ├──→ TASK-002-005 (Guardar límites)
    └──→ TASK-002-006 (Cargar límites)
            ├──→ TASK-002-011 (Reactivar desde archivados)
            └──→ TASK-002-012 (Export/import)

TASK-002-008 (Etiqueta en cards)
    (independiente, pero usa isRecurrenceFinished)
```

---

## 🧪 Test Coverage

Cada tarea debe incluir test manual:

| Task | Test Manual |
|------|-------------|
| 002-001 | Crear evento, guardar, recargar → campos persisten |
| 002-002 | Llamar función con evento sin límite (false) y con límite (true) |
| 002-003 | Evento semanal 3 reps: getTargetDate nunca devuelve ocurrencia 4 |
| 002-004 | Abrir formulario de creación → inputs aparecen dentro de repeat-row |
| 002-005 | Llenar límites, guardar → Storage contiene valores |
| 002-006 | Editar evento con límite → campos pre-rellenados |
| 002-007 | Crear evento 2 reps, esperar a que ambas pasen → archivado auto |
| 002-008 | Card muestra "🔁 Cada 7d · 3 reps" o "hasta 30-11" |
| 002-009 | Preview del formulario muestra límite en texto |
| 002-010 | Evento 3 reps: app cerrada 4 semanas → no reporta ocurrencia 4 |
| 002-011 | Evento archivado por límite: editar, aumentar límite, reactivar |
| 002-012 | Exportar evento con límite → JSON incluye campos; reimportar → OK |

---

## 📝 Notas Finales

- **Orden recomendado de ejecución**: 001 → 002 → 003 → 004/005/006 → 007/008/009/010 → 011/012
- **Estimación**: ~8–10 horas (depende de familiaridad con codebase)
- **Revisión**: Verificar que eventos existentes sin límite no cambien comportamiento
- **Regression**: Ejecutar todas las pruebas del feature 001 tras cada cambio

