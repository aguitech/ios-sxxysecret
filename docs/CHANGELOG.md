# 📝 Changelog

Historial de cambios importantes de la app. Versiones siguen [Semantic Versioning](https://semver.org/) cuando esté lista para release.

---

## [Unreleased]

### Planned
- Calendar tab (cuando backend `/calendar/events` exista)
- Push notifications (cuando backend `/notifications` se implemente)
- Blog reader/admin en la app
- Tests unitarios + UI tests
- Onboarding en primer launch

---

## v1.0 — 2026-06-24 — "Full CRUD"

**Commit:** `a5141e5`

### Added
- ✅ **Clients CRUD completo** — list, search, status filter, create, edit, delete
- ✅ **Users CRUD completo** (admin-only) — list, role filter, create, edit, delete
- ✅ **Project edit form** — client picker, status, progress slider, budget, dates, members con roles
- ✅ **Task edit form** — project picker, status, priority, assignee, dueDate
- ✅ **MainTabView adaptativo** — admin ve tab Usuarios, no-admin no
- ✅ **Documentación completa** — ARCHITECTURE, API, MODELS, VIEWS, SETUP, PITFALLS

### Changed
- `Project.swift` ahora importa `SwiftUI` (para `ProjectMemberRole.color: Color`)
- `Client.swift` ahora tiene `ClientOwner` enum (String|UserRef polimórfico)
- `Chip` unificado en un solo struct (estaba duplicado)
- `ProjectDetailView` ahora recibe `projectId: String` y carga por su cuenta

### Fixed
- 🐛 Project create/update usaba `client` en vez de `clientId`
- 🐛 Project add member usaba `{user, role}` en vez de `{email, role}`
- 🐛 `TaskLink.id` crasheaba cuando `title` era nil
- 🐛 `InfoRow` colisionaba con el de ProfileView (renombrado a `InfoField`)

### Verified
- 11/11 endpoints CRUD probados contra `sxxysecret.com` (todos 200/201)
- Build SUCCEEDED en iPhone 17 Pro simulator (Xcode 26.5)
- Push al repo: `a5141e5`

---

## v0.5 — 2026-06-23 — "Chat + Projects"

**Commit:** `daba7c5`

### Added
- ✅ **Chat completo** — conversaciones por email, mensajes con adjuntos (imágenes/videos/documentos)
- ✅ **Paginación de mensajes** con cursor
- ✅ **Mark-as-read** automático
- ✅ **ProjectDetailView rico** — header, stats grid, miembros con tasks ratio, tareas agrupadas, comentarios

### Fixed
- 🐛 Polimorfismo `sender` en `ChatMessage` (backend alterna String vs UserRef)

---

## v0.4 — 2026-06-23 — "Chat base"

**Commit:** `10d2dfb`

### Added
- Chat list view + chat detail view (sin adjuntos todavía)

### Fixed
- 🐛 Data decoding en projects y tasks (MongoDB shapes)

---

## v0.3 — 2026-06-23 — "Login working"

**Commit:** `cffd6e9`

### Added
- ✅ Login con JWT contra `https://sxxysecret.com/api/auth/login`
- ✅ Keychain storage del token
- ✅ Auto-restore de sesión al reabrir la app
- ✅ Logout desde Profile

### Fixed
- 🐛 Login decoding errors (MongoDB `_id`, fractional seconds, opcionals)

---

## v0.1 — 2026-06-23 — "Bootstrap"

**Commit:** (initial)

### Added
- Estructura del proyecto Xcode
- Models básicos (User, Client, Project, ProjectTask)
- APIClient con auth + dashboard + projects + tasks
- Views: Login, Dashboard, Projects, Tasks, Clients, Profile
- Tema oscuro con acentos dorados
- ATS hardened para HTTPS en `sxxysecret.com`

---

## 📊 Métricas acumuladas

| Métrica | Valor |
|---|---|
| Swift files | 21 (3 models, 2 services, 2 utils, 14 views*) |
| Lines of code | ~3000 |
| Views | 16 |
| Endpoints integrados | 25+ |
| Bugs resueltos (ver PITFALLS.md) | 16 |
| Dependencias externas | 0 |

\* Algunas views tienen structs auxiliares (Pill, StatCard, etc.) que viven en el mismo archivo.
