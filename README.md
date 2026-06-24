# 🔥 SxxySecret iOS

App iOS nativa para **SxxySecret / Aguitech Core** — la agencia de marketing digital.

> **Estado actual:** v1.0 con CRUD completo — login, dashboard, proyectos, clientes, usuarios, tareas, chat con adjuntos.
> Compatible con iOS 17+. Build target: Xcode 26.5 (iOS 26.5 SDK).

---

## 📚 Documentación

Toda la documentación del proyecto vive en [`docs/`](./docs). Antes de tocar código, lee:

| Doc | Qué cubre |
|---|---|
| **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** | Cómo está estructurada la app — carpetas, capas, patrones. **Empieza aquí.** |
| **[docs/API.md](./docs/API.md)** | Todos los endpoints del backend que consume la app, con shapes exactos |
| **[docs/MODELS.md](./docs/MODELS.md)** | Los modelos Swift, enums polimórficos, fechas flexibles |
| **[docs/VIEWS.md](./docs/VIEWS.md)** | Catálogo de las 16 vistas, navegación, adaptatividad por rol |
| **[docs/SETUP.md](./docs/SETUP.md)** | Cómo abrir el proyecto, build, correr, troubleshooting |
| **[docs/PITFALLS.md](./docs/PITFALLS.md)** | Bugs que ya encontramos y cómo se arreglaron — leer antes de mergear |

---

## ✨ Features

### Autenticación
- 🔐 **Login con JWT** contra `https://sxxysecret.com/api/auth/login` (admin@aguittech.com / admin123)
- 🔑 **Keychain storage** — token persistido de forma segura, sesión auto-restaurada

### Secciones principales
- 📊 **Dashboard** — KPIs en tiempo real (Total, Activos, Completados, Progreso promedio)
- 📁 **Proyectos** — lista con búsqueda + chips de status; **CRUD completo** con cliente, miembros, roles
- 👥 **Clientes** — **CRUD completo** con búsqueda, notas, status, navegación a proyectos asociados
- ✅ **Tareas** — **CRUD completo** con filtros, asignación, prioridades, dueDate
- 👤 **Usuarios** (admin-only) — **CRUD completo** con búsqueda, filtros por rol, asignación de role/password
- 💬 **Chat** — conversaciones por email con adjuntos (imágenes/videos/documentos), paginación, mark-read
- 👤 **Perfil** — info del usuario, rol, logout

### Patrones
- 🎨 **UI premium** — tema oscuro con acentos dorados (`#d4af37`), glassmorphism, smooth animations
- 🧱 **SwiftUI puro** — sin Storyboards, sin UIKit
- ⚡ **Async/Await** para todo el networking
- 🔒 **Actor pattern** para `APIClient` (thread-safe)
- 📱 **ATS hardened** — HTTPS-only para `sxxysecret.com`

---

## 🛠️ Stack

- **SwiftUI** (iOS 17+)
- **Async/Await** + `actor` para networking
- **Keychain** (vía wrapper propio) para JWT
- **PhotosUI** para selección de imágenes en chat
- **Xcode 26.5** / Swift 5.0 / iOS 17 deployment target

---

## 🚀 Quick start

```bash
# Clonar
git clone git@github.com:aguitech/ios-sxxysecret.git
cd ios-sxxysecret

# Abrir en Xcode
open sxxysecret.xcodeproj

# Compilar desde CLI
xcodebuild -project sxxysecret.xcodeproj \
           -scheme sxxysecret \
           -sdk iphonesimulator \
           -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
           build

# Instalar y abrir
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/sxxysecret-*/Build/Products/Debug-iphonesimulator/sxxysecret.app
xcrun simctl launch booted com.aguitech.sxxysecret
```

Ver [docs/SETUP.md](./docs/SETUP.md) para más detalle (booted simulators, signing, etc).

---

## 🔗 Backend

La app consume el backend **Aguitech Core / SxxySecret**:

- **API base:** `https://sxxysecret.com/api/`
- **Auth:** JWT con expiración de 7 días
- **Stack:** MERN (MongoDB + Express + React + Node.js)
- **Source:** `aguitech/aguitechcore` en GitHub

Catálogo completo de endpoints en [docs/API.md](./docs/API.md).

---

## 📂 Estructura

```
ios-sxxysecret/
├── README.md                  ← este archivo
├── docs/                      ← documentación técnica
│   ├── ARCHITECTURE.md
│   ├── API.md
│   ├── MODELS.md
│   ├── VIEWS.md
│   ├── SETUP.md
│   └── PITFALLS.md
├── sxxysecret/                ← código fuente
│   ├── SxxySecretApp.swift   ← @main
│   ├── Info.plist
│   ├── Models/               ← DTOs / Codable structs
│   │   ├── User.swift
│   │   ├── Project.swift
│   │   └── Client.swift      ← también ProjectTask, ChatMessage, etc
│   ├── Services/             ← networking + auth
│   │   ├── APIClient.swift   ← actor; todos los endpoints
│   │   └── AuthService.swift ← ObservableObject; token+user state
│   ├── Utils/                ← cross-cutting
│   │   ├── Theme.swift       ← colores, fonts
│   │   └── Keychain.swift
│   └── Views/                ← SwiftUI screens
│       ├── LoginView.swift
│       ├── MainTabView.swift
│       ├── DashboardView.swift
│       ├── ProjectsView.swift
│       ├── ProjectDetailView.swift
│       ├── ProjectEditView.swift      ← crear/editar
│       ├── ClientsView.swift
│       ├── ClientDetailView.swift
│       ├── ClientEditView.swift       ← crear/editar
│       ├── TasksView.swift
│       ├── TaskEditView.swift         ← crear/editar (en TasksView)
│       ├── UsersView.swift
│       ├── UserDetailView.swift
│       ├── UserEditView.swift         ← crear/editar
│       ├── ChatView.swift             ← ChatListView + ChatDetailView
│       └── ProfileView.swift
└── sxxysecret.xcodeproj/
    └── project.pbxproj       ← Xcode project
```

---

## 🤝 Contribuir

Lee primero [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) y [docs/PITFALLS.md](./docs/PITFALLS.md).

Para cambios grandes, abrir issue primero con el cambio propuesto.

---

## 📝 Licencia

Propietario — Aguitech / SxxySecret © 2026.
