# 🖼️ Views

Catálogo de las 16 vistas de la app, con qué hace cada una y cómo navegan entre sí.

> **Convención:** todas las vistas usan `Theme.bgPrimary.ignoresSafeArea()` como background. Tema oscuro con acentos dorados.

---

## 🗺️ Mapa de navegación

```
SxxySecretApp (@main)
├── [si NO authed] LoginView
└── [si authed] MainTabView
    ├── tab 0: DashboardView
    ├── tab 1: ProjectsView
    │   └── → ProjectDetailView (NavigationLink)
    │       ├── → ProjectEditView (sheet, ⋯ menu)
    │       └── → ClientDetailView (si click en cliente del header)
    ├── tab 2: ClientsView
    │   └── → ClientDetailView
    │       └── → ClientEditView (sheet, ⋯ menu)
    │       └── → ProjectDetailView (si click en proyecto del cliente)
    ├── tab 3: UsersView (admin-only)
    │   └── → UserDetailView
    │       └── → UserEditView (sheet, ⋯ menu)
    ├── tab 4: ChatListView (en ChatView.swift)
    │   └── → ChatDetailView (NavigationLink)
    ├── tab 5: TasksView
    │   └── → TaskDetailView
    │       └── → TaskEditView (sheet, ⋯ menu)
    └── tab 6: ProfileView
```

---

## 🔐 Auth

### `LoginView` — `LoginView.swift`

Pantalla de inicio de sesión.

- **Inputs:** email, password
- **Acción:** `AuthService.shared.login(email:, password:)`
- **Demo:** No tiene (puedes ver el credential en pantalla)
- **Credenciales seed:** `admin@aguittech.com` / `admin123`

### `MainTabView` — `MainTabView.swift`

Tab bar raíz. Se muestra cuando `AuthService.shared.isAuthenticated`.

```swift
TabView {
    DashboardView()    // tag 0
    ProjectsView()     // tag 1
    ClientsView()      // tag 2
    if isAdmin { UsersView() }  // tag 3 — solo admin
    ChatListView()     // tag 4 (en ChatView.swift)
    TasksView()        // tag 5
    ProfileView()      // tag 6
}
.tint(Theme.gold)
```

**Adaptatividad por rol:**
- **Admin:** 7 tabs visibles
- **No-admin:** 6 tabs (sin Usuarios)

> Si el iPhone no cabe, SwiftUI mete los últimos tabs en "More" automáticamente.

---

## 📊 `DashboardView` — `DashboardView.swift`

**Tag:** 0 | **Path:** `/`

Pantalla de inicio post-login.

- Hero card con saludo "Hola, [nombre] 👋"
- 4 stat tiles: Total · Activos · Completados · Progreso
- Lista de últimos 5 proyectos
- Lista de últimas tareas

**Datos:**
- `/dashboard/stats` (KPIs)
- `/dashboard/projects` (top 5)
- `/tasks` (top 5)

**Navegación:** cada proyecto → `ProjectDetailView(projectId:)`

---

## 📁 Proyectos

### `ProjectsView` — `ProjectsView.swift`

**Tag:** 1

Lista de todos los proyectos con búsqueda + chips de filtro por status.

- **Búsqueda:** por título o nombre del cliente (en memoria)
- **Filtros:** `Todos` · `Activo` · `Pausado` · `Completado`
- **FAB:** `+` dorado arriba a la derecha → abre `ProjectEditView(mode: .create)`
- **Tap en proyecto:** → `ProjectDetailView(projectId:)`

### `ProjectDetailView` — `ProjectDetailView.swift`

**Entrada:** recibe `projectId: String` y carga por su cuenta

Pantalla rica con:
- **Header:** título, cliente, status pill, descripción, progress bar, presupuesto, fechas
- **Stats grid:** Tareas / Progreso / Vencidas / Miembros + breakdown por status
- **Miembros:** lista con avatar, nombre, email, **rol** (chip dorado), tareas hechas/total
- **Tareas:** agrupadas por status (Pendientes / En curso / Hechas)
- **Comentarios recientes:** top 5

**Menu `⋯` (toolbar top-right):**
- ✏️ Editar → abre `ProjectEditView(mode: .edit(project))`
- 🗑️ Eliminar → confirmation dialog

### `ProjectEditView` — `ProjectEditView.swift`

**Modal:** sheet desde `ProjectsView` (create) o `ProjectDetailView` (edit)

Formulario con secciones:
1. **Datos básicos:** título, cliente (picker), descripción
2. **Estado y avance:** status (segmented), progress slider 0-100%
3. **Presupuesto y fechas:** toggles + inputs opcionales
4. **Equipo:** lista editable de miembros con roles (chips)
5. **Botón:** "Crear proyecto" o "Guardar cambios"

**Pickers como sheets:**
- `ClientPickerSheet` — lista buscable de clientes
- `AddMemberSheet` — lista buscable de users + picker de rol inicial

**Lógica de miembros:**
- En **create**: crea el proyecto primero, después hace POST /members por cada uno
- En **edit**: diff entre members originales y actuales; agrega nuevos y borra quitados

> Ver [PITFALLS.md#3-projects-member-api](./PITFALLS.md#3-projects-member-api) por qué se hace así.

---

## 👥 Clientes

### `ClientsView` — `ClientsView.swift`

**Tag:** 2

Lista de clientes con búsqueda + FAB.

- **Búsqueda:** por nombre, empresa o email
- **Tap en cliente:** → `ClientDetailView(client:onChange:)`
- **FAB `+`:** → `ClientEditView(mode: .create)`

### `ClientDetailView` — `ClientDetailView.swift`

**Entrada:** recibe `Client` directamente (no fetch por ID)

- **Hero card:** avatar con iniciales, nombre, empresa, status pill
- **Info:** email, teléfono, notas
- **Proyectos asociados:** lista de proyectos del cliente (llama `listProjects(clientId:)`)

**Menu `⋯`:**
- ✏️ Editar → `ClientEditView(mode: .edit(client))`
- 🗑️ Eliminar → confirmation dialog (falla si tiene proyectos/tareas)

**Tap en proyecto:** → `ProjectDetailView(projectId:)`

### `ClientEditView` — `ClientEditView.swift`

**Modal:** sheet desde `ClientsView` (create) o `ClientDetailView` (edit)

Formulario con:
1. **Datos básicos:** nombre*, empresa, email, teléfono
2. **Estado:** segmented `Activo` / `Pausado` / `Baja`
3. **Notas:** multiline textfield
4. **Botón:** "Crear cliente" o "Guardar cambios"

---

## ✅ Tareas

### `TasksView` — `TasksView.swift`

**Tag:** 5

Lista de tareas con filtros + FAB.

- **Filtros chips:** `Todas` · `Pendientes` · `En curso` · `Hechas`
- **Tap en tarea:** → `TaskDetailView(task:onChange:)`
- **FAB `+`:** → `TaskEditView(mode: .create)`

Incluye `TaskRow` (card) y `TaskDetailView`.

### `TaskDetailView` — en `TasksView.swift`

Pantalla rica con:
- Header: título, status pill, priority pill, project pill
- Descripción
- Meta info: owner, asignado, fecha de vencimiento
- Adjuntos: imágenes (scroll horizontal), documentos (lista)

**Menu `⋯`:**
- ✏️ Editar → `TaskEditView(mode: .edit(task))`
- 🗑️ Eliminar → confirmation dialog

### `TaskEditView` — `TaskEditView.swift`

**Modal:** sheet desde `TasksView` (create/edit) o `TaskDetailView` (edit)

Formulario:
1. **Datos básicos:** título*, descripción
2. **Estado y prioridad:** segmented para ambos
3. **Asignación:** pickers de proyecto y asignado (con opción "sin X")
4. **Fecha límite:** toggle + datepicker
5. **Botón:** crear/guardar

**Pickers como sheets:**
- `ProjectPickerSheet`
- `AssigneePickerSheet`

---

## 👤 Usuarios

### `UsersView` — `UsersView.swift`

**Tag:** 3 | **Permisos:** solo admin

**Si NO eres admin:**
- EmptyStateCard "Acceso restringido"

**Si eres admin:**
- Lista de usuarios con búsqueda
- **Filtros chips:** `Todos` · `Admins` · `Managers` · `Miembros` · `Clientes`
- **FAB `+`:** → `UserEditView(mode: .create)`
- **Tap en user:** → `UserDetailView(user:onChange:)`

### `UserDetailView` — `UserDetailView.swift`

- Hero: avatar, nombre, email, role pill (color-coded)
- Info: teléfono, último login, fecha de creación
- Indicator "Usuario desactivado" si `active == false`

**Menu `⋯`:**
- ✏️ Editar
- 🗑️ Eliminar

### `UserEditView` — `UserEditView.swift`

**Modal:** sheet desde `UsersView` o `UserDetailView`

Formulario:
1. **Datos básicos:** nombre*, email*, teléfono
2. **Credenciales (solo create):** password*
3. **Rol y estado:** picker de rol, toggle "activo" (solo edit)
4. **Botón:** crear/guardar

---

## 💬 Chat

**File:** `ChatView.swift` (todo el chat está aquí, son 2 vistas grandes)

### `ChatListView`

**Tag:** 4

Lista de conversaciones (estilo inbox):
- Avatar del otro user + última preview + timestamp relativo + badge unread
- **FAB `+`:** abre sheet para escribir un email → `openConversationByEmail`
- **Tap:** → `ChatDetailView(conversationId:, otherName:)`

### `ChatDetailView`

Pantalla de chat estilo iMessage:
- Header: nombre del otro + back button
- Mensajes mezclados izquierda (ellos) / derecha (yo) con bubble colors (gris/dorado)
- Timestamps en cada mensaje
- Image attachments con AsyncImage + document icons
- **Composer:** textfield + 📎 (PhotosPicker o fileImporter) + enviar
- **Paginación:** scroll arriba carga más mensajes (cursor-based)
- **Polling implícito:** cada 5 segundos se refrescan mensajes nuevos

---

## 👤 `ProfileView` — `ProfileView.swift`

**Tag:** 6

- Avatar grande con iniciales
- Info: nombre, email, rol (chip color-coded), teléfono
- Botón "Cerrar sesión" rojo al final
- Tap logout → `AuthService.shared.logout()` → vuelve a `LoginView`

---

## 🎨 Componentes reutilizables

Viven dentro de cada archivo de vista donde se usan (no hay carpeta `Components/` separada por ahora).

### `EmptyStateCard`
```swift
EmptyStateCard(icon: "person.3.fill", title: "Sin usuarios", message: "...")
```
Mostrado cuando una lista está vacía. Centrado, icono grande, texto secundario.

### `Chip`
```swift
Chip(label: "Activos", isOn: filter == .active) { filter = .active }
```
Filtro pill. **Un solo struct compartido** (en `TasksView.swift`). Cambia color de fondo entre `Theme.gold` (selected) y `Theme.bgCard` (unselected).

### `InfoField` (antes `InfoRow`)
```swift
InfoField(icon: "envelope", label: "Email", value: email)
```
Fila de info con icono + label pequeño + value. Usado en ClientDetailView y UserDetailView.

> ⚠️ No usar `InfoRow` — colisiona con el de `ProfileView.swift` que usa `title:` en vez de `label:`.

### `Pill`
```swift
Pill(text: "Activo", color: Theme.success)
```
Tag/chip pequeño de status. Usado para status de proyecto, task, user, etc.

### `MetaRow`
```swift
MetaRow(icon: "calendar", label: "Inicio", value: "12 jun 2026")
```
Igual concepto que `InfoField` pero con estilo diferente (más compacto, gris). Usado en `TasksView.swift` y `ProjectDetailView.swift`.

### `StatCard`
```swift
StatCard(title: "Tareas", value: "12", icon: "checklist", color: Theme.info)
```
Cuadrícula KPI usada en `ProjectDetailView`.

### `StatusCountPill`
Contador compacto con label + número + color. Usado en el breakdown de tareas.

---

## 🧭 Patrones de navegación

### Sheet para crear/editar
```swift
@State private var showCreate = false

Button { showCreate = true } label: { Image(systemName: "plus.circle.fill") }
.sheet(isPresented: $showCreate) {
    EditView(mode: .create) { showCreate = false; Task { await reload() } }
}
```

### NavigationLink en listas
```swift
ForEach(items) { item in
    NavigationLink {
        DetailView(item: item, onChange: { Task { await reload() } })
    } label: {
        ItemCard(item: item)
    }
    .buttonStyle(.plain)
}
```

### Confirmation dialog para delete
```swift
@State private var showDelete = false
.confirmationDialog("¿Eliminar X?", isPresented: $showDelete, titleVisibility: .visible) {
    Button("Eliminar", role: .destructive) { Task { await delete() } }
    Button("Cancelar", role: .cancel) {}
}
```

### Recargar después de editar
El `onChange: () -> Void` callback que cada Detail recibe se llama desde el EditView al guardar. Típicamente:
```swift
.sheet(isPresented: $showEdit, onDismiss: { onChange() }) {
    EditView(...) { showEdit = false }
}
```

---

## ⚠️ Cosas a recordar

- **Tap en lista vs navigation:** los `NavigationLink` con `.buttonStyle(.plain)` son los que funcionan bien con cards/tiles custom.
- **Sheet dentro de NavigationStack:** los sheets viven dentro de la `NavigationStack` del padre. Si navegas y abres un sheet, al cerrar vuelves al root, NO al detail. Por eso `dismiss()` debe estar disponible con `@Environment(\.dismiss)`.
- **Toolbar theme:** siempre poner `.toolbarBackground(Theme.bgPrimary, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)` en cada `NavigationStack`.
