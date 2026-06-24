# 🏗️ Architecture

Cómo está estructurada la app — capas, responsabilidades, patrones. **Lee esto antes de tocar nada.**

---

## 📐 Capas

```
┌─────────────────────────────────────────────────────────┐
│  Views (SwiftUI)        ← pantallas, navigation, state  │
├─────────────────────────────────────────────────────────┤
│  Services (APIClient, AuthService) ← networking, auth   │
├─────────────────────────────────────────────────────────┤
│  Models (Codable)       ← DTOs del backend              │
├─────────────────────────────────────────────────────────┤
│  Utils (Theme, Keychain)← cross-cutting                 │
└─────────────────────────────────────────────────────────┘
```

### Reglas de oro

1. **Views nunca hablan HTTP directamente.** Siempre van por `APIClient.shared`.
2. **Models nunca importan SwiftUI** (excepto `Project.swift` que necesita `Color` para `ProjectMemberRole.color`). Mantenerlos planos y `Codable`.
3. **APIClient es un `actor`.** Es thread-safe por diseño — todas las llamadas son `async` y se serializan automáticamente.
4. **AuthService es un `ObservableObject`** que vive en `@State` del root view. Lee `.user` y `.token` desde ahí.

---

## 📂 Carpetas

### `Models/`
DTOs `Codable` que mapean 1:1 con la respuesta del backend. **MongoDB-shaped**: `_id`, `createdAt`, `updatedAt`, etc.

- **`User.swift`** — `User`, `UserRef`, `AuthResponse`, `MeResponse`, `LoginRequest`, `ISO8601DateFormatter.flexX` (extensión)
- **`Project.swift`** — `Project`, `UserRef`, `ClientRef`, `ProjectMember`, `ProjectOwner` enum (String|UserRef), `ProjectLite` enum (String|populated), `DashboardStats`, `ProjectDetail`, `ProjectStats`, `Comment`, `MemberStat`, **`ProjectMemberRole` enum** (colaborador/revisor/observador)
- **`Client.swift`** — `Client`, **`ClientOwner` enum** (String|UserRef), `TaskAttachment`, `ChatAttachment`, `ProjectTask`, `TaskLink`, `TaskComment`, `Conversation`, **`ChatSender` enum** (String|UserRef), `ChatMessage`, `MessagePage`, `SendMessageRequest`

> **Patrón clave: enums polimórficos.** El backend alterna entre mandar IDs como `String` o populateados como objeto. Modelamos esto con enums + custom decoder. Ver `docs/MODELS.md` para el detalle.

### `Services/`
- **`APIClient.swift`** — `actor` con ~30 métodos (uno por endpoint). Métodos privados `request<T>` y `uploadMultipart<T>` para JSON y multipart respectivamente. Helper `requestNoBody` para POST/PUT/DELETE sin respuesta esperada.
- **`AuthService.swift`** — `ObservableObject` con `@Published user: User?`, `@Published token: String?`. Persiste token en Keychain. `login(email:password:)`, `logout()`, `currentToken()` (nonisolated para usar desde actor).

### `Utils/`
- **`Theme.swift`** — colores (`gold #d4af37`, `accent`, `success`, etc.), helper `Theme.gold`, `Theme.bgPrimary`, etc.
- **`Keychain.swift`** — wrapper genérico sobre `SecItem*` con `Keychain.shared.set(key:value:)` y `.get(key:)`.

### `Views/`
Cada vista es su propio `.swift`. Patrón típico:

```swift
struct XView: View {
    @State private var items: [Item] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let error = error {
                    // error view
                } else if items.isEmpty {
                    EmptyStateCard(...)
                } else {
                    // list / content
                }
            }
            .navigationTitle("...")
            // toolbar / search / sheets
        }
        .task { await load() }
    }

    private func load() async { ... }
}
```

Catálogo completo de las 16 vistas en [`docs/VIEWS.md`](./VIEWS.md).

---

## 🔌 Networking

### `APIClient` API

Todos los métodos son `async throws`. Devuelven el tipo Swift decodificado directamente:

```swift
let clients = try await APIClient.shared.listClients()
let created = try await APIClient.shared.createClient(name: "...", ...)
let updated = try await APIClient.shared.updateClient(id: "...", name: "...", ...)
try await APIClient.shared.deleteClient(id: "...")
```

Para endpoints con query strings: parámetro opcional (`q: String? = nil`).

### Fechas: el truco del backend

El backend manda fechas con **fracciones de segundo**:
```
"createdAt": "2026-06-17T16:42:06.214Z"
"startDate": "2026-06-16T21:46:43.251Z"
```

Y a veces **sin fracciones**:
```
"publishedAt": "2026-06-23T00:00:00.000Z"
```

El decoder usa **dos `ISO8601DateFormatter`** y prueba ambos:

```swift
decoder.dateDecodingStrategy = .custom { dec in
    let raw = try dec.singleValueContainer().decode(String.self)
    if let d = APIClient.iso8601Strict.date(from: raw) { return d }
    if let d = APIClient.iso8601Fractional.date(from: raw) { return d }
    throw DecodingError.dataCorruptedError(...)
}
```

⚠️ **No tocar esto sin verificar que el backend sigue mandando estos formatos.**

### Polymorphic fields

El backend alterna entre:
- `String` ID (en listings)
- Objeto poblado `{ _id, name, email, role }` (en details)

Lo manejamos con **enums + custom decoder**. Ejemplo `ChatSender`:

```swift
enum ChatSender: Codable, Hashable {
    case userId(String)
    case user(UserRef)

    var id: String {
        switch self { case .userId(let s): return s; case .user(let u): return u.id }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .userId(s); return }
        if let u = try? c.decode(UserRef.self) { self = .user(u); return }
        self = .userId("")
    }
}
```

Aplicado en: `ProjectOwner`, `ProjectLite`, `ClientOwner`, `ChatSender`.

---

## 🔐 Auth flow

```
┌─────────────────────────────────────────────────────┐
│  LoginView                                          │
│  └─→ AuthService.shared.login(email, password)      │
│        └─→ POST /api/auth/login                     │
│        └─→ store {token, user}                      │
│             └─→ token → Keychain (persistido)       │
│             └─→ user → @Published (memoria)         │
│        └─→ @Published change → re-render root view  │
└─────────────────────────────────────────────────────┘
         ↓ authed
┌─────────────────────────────────────────────────────┐
│  SxxySecretApp                                      │
│  └─→ @StateObject auth = AuthService.shared         │
│        └─→ if auth.isAuthenticated → MainTabView    │
│        └─→ else → LoginView                         │
└─────────────────────────────────────────────────────┘
```

Al **arrancar la app**, `AuthService` carga el token del Keychain. Si existe, hace `me()` para obtener el user. Si falla (401) → logout y vuelve a LoginView.

---

## 🎨 UI / Theme

Tema oscuro (`bgPrimary: #0d0d14`, `bgCard: #21212e`) con dorado (`gold: #d4af37`) como accent.

```swift
Theme.bgPrimary       // background principal
Theme.bgCard          // tarjetas
Theme.gold            // accent / CTAs
Theme.gold.opacity(0.2)  // fondos sutiles
Theme.textPrimary     // blanco
Theme.textSecondary   // gris claro
Theme.success         // verde (status activo)
Theme.warning         // naranja (pendiente)
Theme.error           // rojo
Theme.info            // azul
Theme.accent          // magenta (admin)
```

Todas las vistas usan estos colores consistentemente. **No hardcodear colores.**

---

## 🚦 Adaptatividad por rol

`MainTabView` adapta los tabs según el rol del usuario:

```swift
private var isAdmin: Bool { me?.role == "admin" }

TabView {
    DashboardView()
    ProjectsView()
    ClientsView()
    if isAdmin { UsersView() }   // ← solo admins
    ChatListView()
    TasksView()
    ProfileView()
}
```

- **Admin:** Inicio · Proyectos · Clientes · **Usuarios** · Chat · Tareas · Perfil (7 tabs)
- **No-admin:** Inicio · Proyectos · Clientes · Chat · Tareas · Perfil (6 tabs)

`UsersView` además muestra un **access-denied card** si alguien navega directamente sin ser admin (defensa en profundidad).

---

## 🧪 Patrones recurrentes

### Search bar
Todas las listas usan `.searchable(text:)`. Las queries se ejecutan **en memoria** (SwiftUI filter sobre el array cargado). Para listas grandes esto es OK porque siempre paginamos implícitamente desde el backend.

### Chips de filtro
`struct Chip(label: String, isOn: Bool, action: () -> Void)` — un solo definition en `TasksView.swift`, usado por Projects/Tasks/Users.

### FAB (Floating Action Button)
Toolbar item con `Image(systemName: "plus.circle.fill").foregroundStyle(Theme.gold)`. Abre un sheet con el EditView en `.create` mode.

### Sheet pattern (crear/editar)
```swift
.sheet(isPresented: $showEdit) {
    EditView(mode: .edit(item), onSaved: {
        showEdit = false
        Task { await load() }
    })
}
```

`EditView` recibe un enum `Mode { case create, case edit(Item) }` y un `onSaved: () -> Void` callback.

### Pull-to-refresh
```swift
.refreshable { await load() }
```

### Delete confirmation
```swift
.confirmationDialog("¿Eliminar X?", isPresented: $showDeleteConfirm) {
    Button("Eliminar", role: .destructive) { Task { await delete() } }
    Button("Cancelar", role: .cancel) {}
}
```

---

## 📦 Dependencias

**Cero dependencias externas.** Solo frameworks de Apple:
- SwiftUI
- Foundation
- Security (Keychain)
- PhotosUI (chat — selección de imágenes)

No usamos Swift Package Manager, no CocoaPods, no Carthage. Esto simplifica enormemente el build y reduce la superficie de ataque de supply chain.

---

## 🔧 Build configuration

- **Deployment target:** iOS 17.0
- **Swift:** 5.0
- **Bundle ID:** `com.aguitech.sxxysecret`
- **Signing:** Automático (Development team: tu Apple ID)

Ver `docs/SETUP.md` para correr / instalar / troubleshoot.
