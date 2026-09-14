# Plan de Desarrollo: Next Appointment

**Derivado de**: spec.md  
**Estrategia**: Prioridad + descomposición por historia de usuario  
**Validación**: Cada sección es extraíble del spec sin suposiciones.

---

## Mapa de historias por prioridad

### 🔴 P1 — Core bloqueante (MVP)

Sin estas historias, la app no es funcional como producto.

| Historia | FRs asociados | Criterio de éxito |
|----------|---------------|------------------|
| **H1: Crear y ver próximas citas** | FR-001, FR-002, FR-003 | SC-001, SC-002 |
| **H2: Editar y eliminar citas** | FR-004, FR-005 | - |
| **H4: Citas recurrentes** | FR-009, FR-010 | SC-005 |

**Duración estimada**: ~2–3 sprints  
**Liberación**: v1.0

---

### 🟠 P2 — Complementario (estabilidad + usabilidad)

Sin estas historias, la app es frágil o inconveniente; no es bloqueante.

| Historia | FRs asociados | Criterio de éxito |
|----------|---------------|------------------|
| **H3: Persistencia y respaldo** | FR-006, FR-007, FR-008 | SC-003, SC-004 |
| **H5: Categorización** | FR-011, FR-012 | SC-006 |

**Duración estimada**: ~1–2 sprints  
**Liberación**: v1.0 o v1.1 (según capacidad)

---

### 🟡 P3 — Valor añadido (opcionales)

Valor percibido alto; no bloqueante; depende de permisos del SO.

| Historia | FRs asociados | Criterio de éxito |
|----------|---------------|------------------|
| **H6: Recordatorios/notificaciones** | FR-013 | SC-008 |

**Duración estimada**: ~1 sprint  
**Liberación**: v1.1 o posterior

---

## Casos límite como tareas independientes

Cada caso límite es verificable de forma aislada. Se trata como tarea separada en tasks.md:

| Caso límite | Historia relacionada | Validación |
|-------------|---------------------|-----------|
| **CL-001: Dos citas simultáneas** | H1 | Se permiten; orden determinista dentro del mismo minuto |
| **CL-002: Cita retroactiva** | H1 | Se permite creación; archiva ≥24h si no es recurrente |
| **CL-003: Importación con datos corruptos** | H3 | Validación por evento; inválidos omitidos con advertencia; formatos antiguos normalizados |
| **CL-004: Denegación de permisos post-concesión** | H6 | App continúa; fallback a badge visual |
| **CL-005: Funcionamiento offline (PWA)** | H1–H6 | 100% offline; localStorage sincronizado; SW v13 caché assets |

---

## Requisitos transversales (aplican a todas las historias)

- **FR-016**: Layout responsivo, prioridad iPhone, vanilla JS/HTML/CSS
- **Modelo de datos**: Entidad `Cita` con todos los campos (id, name, date, time, emoji, color, category, recurrence*, notifyBefore, archivedAt, etc.)
- **Validación**: Título no vacío, fecha/hora formato válido, IDs únicos
- **Offline-first**: localStorage + Service Worker v13

---

## Dependencias de historias

```
H1 (Core CRUD) ← base para todas
├─ H2 (Editar/eliminar) — depende de H1
├─ H4 (Recurrencia) — depende de H1, extiende modelo
├─ H3 (Persistencia) — depende de H1, extiende storage
├─ H5 (Categorías) — depende de H1, extiende modelo + UI
└─ H6 (Notificaciones) — depende de H1, complementaria

Orden recomendado: H1 → H2/H4 → H3 → H5 → H6
```

---

## Artefactos de validación por historia

Cada historia tiene:
1. **Criterio de aceptación** (del spec)
2. **Escenarios de prueba** (del spec)
3. **Requisitos asociados** (FR-*)
4. **Success criteria** (SC-*)
5. **Casos límite** (si aplican)

Todos extraíbles del spec.md sin ambigüedad.

---

## Matriz de rastreabilidad

| Historia | Prioridad | Estado | FRs | SCs | Casos límite | Sprint |
|----------|-----------|--------|-----|-----|-------------|--------|
| H1 | P1 | Planeada | FR-001..003 | SC-001,002 | CL-001, CL-002, CL-005 | S1 |
| H2 | P1 | Planeada | FR-004, FR-005 | - | - | S1 |
| H4 | P1 | Planeada | FR-009, FR-010 | SC-005 | - | S2 |
| H3 | P2 | Planeada | FR-006..008 | SC-003, SC-004 | CL-003 | S2–S3 |
| H5 | P2 | Planeada | FR-011, FR-012 | SC-006 | - | S2–S3 |
| H6 | P3 | Planeada | FR-013 | SC-008 | CL-004 | S3+ |

---

## Definición de "Hecho"

Una historia se considera completa cuando:
1. ✅ Todos los escenarios de aceptación pasan
2. ✅ Todos los criterios de éxito (SC-*) se verifican
3. ✅ Todos los requisitos funcionales (FR-*) se cumplen
4. ✅ Los casos límite apliquen y se validen
5. ✅ No hay dependencias bloqueadas
6. ✅ La feature está integrada en main y deployada

