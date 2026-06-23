# 🔥 SxxySecret iOS

App iOS nativa para **SxxySecret / Aguitech Core** — la agencia de marketing digital.

## ✨ Features

- 🔐 **Login con JWT** — autenticación contra `https://sxxysecret.com/api/auth/login`
- 🔑 **Keychain storage** — el token JWT se guarda de forma segura
- 📊 **Dashboard** — KPIs en tiempo real (Total, Activos, Completados, Progreso)
- 📁 **Proyectos** — lista con status, progreso, cliente
- 👥 **Clientes** — listado completo con búsqueda visual
- ✅ **Tareas** — filtradas por status (Todas/Pendientes/En curso/Hechas)
- 👤 **Perfil** — info del usuario, rol, logout
- 🎨 **UI premium** — tema oscuro con acentos dorados

## 🛠️ Stack

- **SwiftUI** puro (iOS 17+)
- **Async/Await** para networking
- **Actor pattern** para APIClient (thread-safe)
- **Codable** para JSON
- **Keychain Services** para tokens
- **NavigationStack** + **TabView**

## 📁 Estructura

```
ios-sxxysecret/
└── sxxysecret/
    ├── SxxySecretApp.swift       # Entry point
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Models/                   # User, Project, Client, Task
    ├── Services/                 # APIClient, AuthService
    ├── Utils/                    # Keychain helper, Theme
    └── Views/                    # Login, Dashboard, Projects, etc.
```

## 🚀 Build

```bash
cd ~/projects/ios-sxxysecret
open sxxysecret.xcodeproj
# Click ▶️ Run
```

O desde terminal:
```bash
xcodebuild -project sxxysecret.xcodeproj -scheme sxxysecret \
  -sdk iphonesimulator -configuration Debug build
```

## 🔌 API Endpoints usados

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/auth/login` | Login → JWT |
| GET | `/auth/me` | Usuario actual |
| GET | `/dashboard/stats` | KPIs |
| GET | `/dashboard/projects` | Lista de proyectos |
| GET | `/dashboard/projects/:id` | Detalle de proyecto |
| GET | `/clients` | Lista de clientes |
| GET | `/tasks` | Lista de tareas |

## 🔑 Credenciales seed

- **Email:** `admin@aguittech.com`
- **Password:** `admin123`

---

Hecho con ❤️ por [Héctor Aguilar](https://github.com/aguitech) · Powered by Aguitech
