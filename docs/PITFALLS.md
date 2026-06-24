# ⚠️ Pitfalls

Bugs reales que encontramos construyendo esta app y cómo se arreglaron. **Lee esto antes de mergear cambios** — la mayoría de estos bugs son silenciosos y vuelven si los reproduces sin querer.

> Formato: síntoma → causa raíz → fix definitivo.

---

## 1. Decoding de fechas flexibles

### Síntoma
```
"Error de decodificación: The data couldn't be read because it is missing."
```
O más vago: el array de proyectos está vacío en el dashboard.

### Causa raíz
El backend manda fechas con **dos formatos diferentes** según el endpoint:

```
"createdAt": "2026-06-16T18:20:20.587Z"      ← sin fracciones
"startDate": "2026-06-16T21:46:43.251Z"     ← con fracciones (milisegundos)
```

`ISO8601DateFormatter` por default rechaza el formato con fracciones. Pero `.withInternetDateTime` solo acepta sin fracciones.

### Fix
**Archivo:** `Models/User.swift` (y replicado en `APIClient.swift`)

```swift
extension ISO8601DateFormatter {
    static let flexStrict: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let flexFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
```

Y en `APIClient.request<T>`:
```swift
decoder.dateDecodingStrategy = .custom { dec in
    let raw = try dec.singleValueContainer().decode(String.self)
    if let d = APIClient.iso8601Strict.date(from: raw) { return d }
    if let d = APIClient.iso8601Fractional.date(from: raw) { return d }
    throw DecodingError.dataCorruptedError(...)
}
```

> ⚠️ Si el backend cambia el formato de fecha, este decoder se cae silenciosamente. **Si ves array vacío sin error**, lo primero que hay que checar es este decoder.

---

## 2. Chat decoding — `sender` viene como String o UserRef

### Síntoma
El tab de Chat abre pero **todas las conversaciones aparecen vacías** o tiran error de decoding.

### Causa raíz
El backend usa el mismo key `sender` con dos shapes distintos:

```json
// GET /chat/conversations (listing)
{ "_id": "...", "sender": "6a3193e4...", ... }

// GET /chat/conversations/:id/messages (detail)
{ "_id": "...", "sender": { "_id": "6a3193e4...", "name": "Memo", ... }, ... }
```

Mi modelo Swift original tenía `sender: UserRef` (solo objeto), que solo matchea el segundo caso. En el listing, el decoder **falla silenciosamente por campo desconocido** (o tira error si es strict).

### Fix
**Archivo:** `Models/Client.swift`

```swift
enum ChatSender: Codable, Hashable {
    case userId(String)
    case user(UserRef)

    var id: String { ... }
    var user: UserRef? { ... }
    var name: String? { ... }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .userId(s); return }
        if let u = try? c.decode(UserRef.self) { self = .user(u); return }
        self = .userId("")
    }
}
```

Y `ChatMessage.sender: ChatSender` (antes era `senderUser: UserRef`).

### Patrón a seguir
Si agregas cualquier otro campo polimórfico (donde el backend puede mandar ID o poblar el objeto), **usa el patrón de enum con custom decoder**. Aplicado en:
- `ProjectOwner` (en Project)
- `ProjectLite` (en Project)
- `ClientOwner` (en Client)
- `ChatSender` (en Client)

---

## 3. Projects — `clientId` no `client`, y miembros por email

### Síntoma
Al crear o editar un proyecto desde la app:
```
400 Bad Request — "Cliente requerido"
```
O al agregar miembro:
```
400 — "Email requerido"
```

### Causa raíz
El backend `aguitechcore` espera nombres de campos **diferentes** al REST genérico:

| Concepto | Yo mandaba | Backend espera |
|---|---|---|
| Cliente | `client: "abc123"` | `clientId: "abc123"` |
| Miembro | `{user: userId, role: "colaborador"}` | `{email: "memo@...", role: "colaborador"}` |

Esto está **explícito en el código del backend** (`server/src/controllers/dashboard.controller.js`).

### Fix
**Archivo:** `Services/APIClient.swift`

```swift
// createProject
var body: [String: Any] = [
    "title": title,
    "clientId": clientId,    // ← no "client"
    ...
]

// updateProject
if let v = clientId { body["clientId"] = v }  // ← no "client"

// addProjectMember
func addProjectMember(projectId: String, email: String, role: String = "colaborador") async throws {
    try await requestNoBody("POST", "/dashboard/projects/\(projectId)/members",
        body: ["email": email, "role": role])  // ← no "user"
}
```

### Lección
**Antes de escribir el cliente de un endpoint, lee el controller del backend.** La doc de OpenAPI no siempre refleja el campo real.

---

## 4. Projects — no acepta members inline en create

### Síntoma
Al crear un proyecto con miembros desde la app, los miembros no aparecen. La llamada devuelve 201 pero `members: []`.

### Causa raíz
El backend **`createProject`** llama a `buildProjectPayload(body)` que sí lee `members` del body, **pero `Project.create()` no procesa los members** — solo guarda el resto del payload.

Ver `aguitechcore/server/src/controllers/dashboard.controller.js` línea ~80:

```js
export async function createProject(req, res, next) {
    // ...
    const project = await Project.create({ ...payload, owner: req.user._id });
    // ← NO hay lógica para insertar members desde body
}
```

### Fix
**Archivo:** `Views/ProjectEditView.swift`

Después de crear el proyecto, agregar miembros en calls separadas:

```swift
case .create:
    let created = try await APIClient.shared.createProject(...)
    // Backend doesn't accept inline members on create — add them after.
    for m in members {
        _ = try? await APIClient.shared.addProjectMember(
            projectId: created.id, email: m.email, role: m.role.rawValue
        )
    }
```

> **Frágil:** si la creación del proyecto succeed pero algún `addProjectMember` falla, el proyecto queda creado sin todos los miembros. Para producción habría que hacer un rollback o usar una transacción.

---

## 5. Login "decoding error" en el primer arranque

### Síntoma
Al hacer login por primera vez, la app dice "Error de decodificación" y no entra.

### Causa raíz
Múltiple:

1. **El backend manda `_id` no `id`** → mi modelo esperaba `id` directo
2. **`createdAt` con fracciones** → ver Pitfall #1
3. **Campos opcionales que el backend NO manda** → `decode` (no `decodeIfPresent`) los marca como faltantes

### Fix
**Archivo:** `Models/User.swift`

```swift
enum CodingKeys: String, CodingKey {
    case id = "_id"  // ← mapping
    ...
}

init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try c.decode(String.self, forKey: .id)
    // ... required
    self.phone = try c.decodeIfPresent(String.self, forKey: .phone)  // ← decodeIfPresent
    self.active = try c.decodeIfPresent(Bool.self, forKey: .active)
    self.lastLogin = User.flexDate(c, key: .lastLogin)
    // ...
}
```

> **Regla:** en Swift, **todo lo que el backend pueda omitir va con `decodeIfPresent`**. Si dudas, hazlo opcional.

---

## 6. ATS bloqueando HTTP en simulator

### Síntoma
En simulator la app hace requests a `https://...` y todo bien. Pero si apuntas a `http://localhost:4000` (backend local), la app muere con:
```
Error de red: ...
```

### Causa raíz
iOS App Transport Security (ATS) **bloquea HTTP plano por default**. Solo HTTPS.

### Fix
**Archivo:** `sxxysecret/Info.plist`

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

> ⚠️ **Solo para development.** En producción el backend siempre debe ser HTTPS.

---

## 7. ProjectDetailView sin recargar tras edit

### Síntoma
Editas un proyecto desde el menu `⋯` → `Editar`, cambias el título, guardas. **Pero el detail sigue mostrando el título viejo.**

### Causa raíz
`ProjectDetailView` original recibía `let project: Project` (un valor inmutable). Después de editar, el valor en memoria seguía siendo el viejo.

### Fix
Cambiar la signature para que cargue por sí mismo:

```swift
struct ProjectDetailView: View {
    let projectId: String              // ← ahora ID, no Project
    @State private var project: Project?

    var body: some View {
        // ... usa `project?.title` en lugar de `project.title`
    }

    .sheet(isPresented: $showEdit, onDismiss: { Task { await reload() } }) {
        ProjectEditView(mode: .edit(p)) { showEdit = false }
    }

    private func reload() async {
        async let p = APIClient.shared.getProject(id: projectId)
        async let d = APIClient.shared.getProjectDetail(id: projectId)
        self.project = try await p
        self.detail = try await d
    }
}
```

> **Lección:** cuando una vista puede mutar su contenido desde un sheet hijo, **que la vista cargue por ID, no por valor**. El callback `onChange: () -> Void` en el padre es un parche frágil.

---

## 8. `Chip` struct redeclarado

### Síntoma
Build falla con:
```
error: invalid redeclaration of 'Chip'
```

### Causa raíz
Dos structs `Chip` definidos en archivos distintos (uno en `TasksView.swift`, otro en `UsersView.swift`) con **firmas diferentes** (uno usaba `text:`/`isSelected:`, otro `label:`/`isOn:`). Swift NO soporta overloading de struct names.

### Fix
**Archivo:** `Views/UsersView.swift`

Eliminar el `struct Chip` duplicado. El de `TasksView.swift` es el canónico:

```swift
struct Chip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void
    // ...
}
```

Y renombrar todas las llamadas a `Chip(text:isSelected:)` → `Chip(label:isOn:)`.

> **Lección:** Antes de definir un struct "compartido", busca si ya existe. Si existe, reusa. Si no, defínelo en **un solo lugar** (idealmente un archivo `Components.swift` aparte).

---

## 9. `InfoRow` con label `label:` vs `title:`

### Síntoma
Build falla con:
```
error: incorrect argument label in call (have 'icon:label:value:', expected 'icon:title:value:')
```

### Causa raíz
`ProfileView.swift` ya tenía un `struct InfoRow(icon:, title:, value:)`. Yo agregué otro `InfoRow(icon:, label:, value:)` en `ClientDetailView.swift`. Conflicto de redeclaración.

### Fix
**Renombrar mi versión** a `InfoField` (más específico) y actualizar todas las llamadas.

```swift
struct InfoField: View {
    let icon: String
    let label: String
    let value: String
    // ...
}
```

> **Mismo principio que #8:** cuando un struct ya existe con una firma, **reusar o renombrar el mío**. Nunca redefinir.

---

## 10. `MetaRow` también redeclarado

Mismo problema que #9. Mi `MetaRow` chocaba con el de `TasksView.swift`/`ProjectDetailView.swift`. **Renombrado a** `InfoField` (unificado).

---

## 11. `ProjectMemberRole.color: String` vs `Color`

### Síntoma
Build falla con:
```
error: value of type 'String' has no member 'opacity'
error: instance method 'foregroundStyle' requires that 'String' conform to 'ShapeStyle'
```

### Causa raíz
Originalmente `ProjectMemberRole.color: String` para hacerlo simple (azul, morado, gris como nombre). Pero en SwiftUI necesitas `Color` para `.opacity()` y `.foregroundStyle()`.

### Fix
**Archivo:** `Models/Project.swift`

```swift
var color: Color {
    switch self {
    case .colaborador: return Theme.info
    case .revisor: return Theme.accent
    case .observador: return Theme.textTertiary
    }
}
```

> ⚠️ Esto **requiere `import SwiftUI` en `Project.swift`**, que es el único modelo que no es Foundation puro. Está documentado en [MODELS.md](./MODELS.md#projectmemberrolecolor-color-requiere-import-swiftui).

---

## 12. `AuthService.shared.currentUser` no existe

### Síntoma
Build falla con:
```
error: value of type 'AuthService' has no member 'currentUser'
```

### Causa raíz
El accessor se llama `user`, no `currentUser` (el método `currentToken()` sí existe para thread-safety desde actor).

### Fix
```swift
@State private var me: User? = AuthService.shared.user  // ← "user", no "currentUser"
```

---

## 13. ProjectEditView — el type-checker no puede inferir

### Síntoma
Build falla con:
```
error: the compiler is unable to type-check this expression in reasonable time
```

### Causa raíz
`ProjectEditView.body` tenía un `ForEach` con un `HStack` complejo (Menu dentro de Button dentro de ForEach). Swift type-checker se atora en expresiones anidadas con muchos closures.

### Fix
**Extraer la fila a un sub-view.**

```swift
// En el body:
Section {
    ForEach(members) { m in
        MemberRowEditable(member: m) { newRole in ... } onRemove: { ... }
    }
}

// Sub-view aparte:
private struct MemberRowEditable: View {
    let member: ProjectEditView.MemberEntry
    let onRoleChange: (ProjectMemberRole) -> Void
    let onRemove: () -> Void
    var body: some View { ... }
}
```

> **Regla empírica:** si el body tiene más de ~3 niveles de anidación con closures, extrae.

---

## 14. TasksView.swift — chip conflict con UsersView

### Síntoma
Build OK, pero `UsersView` no muestra los chips de filtro correctamente.

### Causa raíz
`UsersView.swift` definía su propio `Chip` además del de `TasksView.swift`. Aunque después eliminamos el duplicado, la confusión quedó.

### Fix
**Un solo `struct Chip`** en `TasksView.swift` (es el archivo que originalmente lo introdujo). Las otras vistas lo importan implícitamente por estar en el mismo módulo.

---

## 15. SwiftUI recrea el tab bar entero al cambiar admin

### Síntoma
Si el user es despromovido de admin a member durante la sesión, el tab de Usuarios sigue ahí (debería desaparecer).

### Causa raíz
`MainTabView` solo lee `me.role` en `onAppear`. No hay observer.

### Fix (TODO — no implementado)
Suscribirse a `AuthService.shared.$user`:
```swift
@StateObject private var auth = AuthService.shared

var body: some View {
    let isAdmin = auth.user?.role == "admin"
    TabView { ... }
}
```

> Por ahora, los cambios de role requieren **logout/login** para reflejarse en el tab bar.

---

## 16. Subir PDF/imágenes grandes sin progress UI

### Síntoma
Subir un PDF de 50 MB en el chat parece que la app se congeló.

### Causa raíz
No hay progress UI en `ChatDetailView` mientras se hace el multipart upload.

### Fix (TODO)
- Mostrar un `ProgressView` overlay durante el upload
- O deshabilitar el botón de enviar y mostrar "Subiendo..."

Por ahora, los archivos pequeños suben rápido y no es problema.

---

## 17. `Calendar` no implementado en app

### Síntoma
El backend tiene `/calendar/events` pero la app no lo usa.

### Causa raíz
**No lo construimos aún.** Es el siguiente feature obvio después del CRUD.

### Fix (TODO)
Agregar un nuevo tab entre Tareas y Perfil:
```swift
CalendarView()
    .tabItem { Image(systemName: "calendar"); Text("Calendario") }
```

Conectar a `/calendar/events`.

---

## 18. Search en memoria, no en backend

### Síntoma
Si la lista tiene 5000 proyectos, la búsqueda es lenta.

### Causa raíz
Los Views filtran en memoria con `arr.filter { ... }`. Para datasets grandes esto no escala.

### Fix (parcial)
El backend soporta `?q=` en `/dashboard/projects`, `/clients`, `/users`. Pero la app actualmente **ignora el `q` del backend** y solo filtra en memoria.

**Para mejorar:** cambiar el `.task { await load() }` para que reaccione al query con `.onChange(of: query)` y haga llamadas con `q=` al backend.

```swift
.onChange(of: query) { _, newQuery in
    Task {
        items = try await APIClient.shared.listProjects(q: newQuery)
    }
}
```

> Es bajo prioridad por ahora — los datasets son pequeños (< 100 items).

---

## 🧰 Debugging tools

### Logs del simulator
```bash
xcrun simctl spawn booted log stream --predicate 'processImagePath CONTAINS "sxxysecret"' --level=debug
```

### Ver archivos subidos
Los archivos que subes desde el chat van a `uploads/` en el backend. Si tienes acceso al server:
```bash
ls /path/to/aguitechcore/server/uploads/
```

### Decodificar un JSON específico
Si una vista no carga y sospechas del decoder, agrega un print en el `init(from:)` del modelo:
```swift
init(from decoder: Decoder) throws {
    let raw = try JSONSerialization.data(...).base64EncodedString()
    print("DEBUG User decode: \(raw)")
    ...
}
```

### Test endpoint directo con curl
```bash
# Login
curl -X POST https://sxxysecret.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@aguittech.com","password":"admin123"}'

# Listar proyectos
curl https://sxxysecret.com/api/dashboard/projects \
  -H "Authorization: Bearer ***"
```

---

## 📋 Checklist para agregar un nuevo endpoint

1. ✅ Verifica el controller en `aguitechcore/server/src/controllers/`
2. ✅ Define el shape de respuesta (especialmente `_id` y fechas con fracciones)
3. ✅ Si tiene campos polimórficos, usa el patrón de enum
4. ✅ Agrega el método en `APIClient.swift`
5. ✅ Llama desde la vista
6. ✅ Prueba con curl primero
7. ✅ Compila, instala, prueba en simulator
8. ✅ Verifica que no se rompe el caso viejo (cliente/users CRUD existente)

---

## 🚨 Si todo se rompe

```bash
# 1. Pull lo más reciente
git pull origin main

# 2. Clean build
xcodebuild clean -project sxxysecret.xcodeproj -scheme sxxysecret

# 3. Borrar DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/sxxysecret-*

# 4. Rebuild desde cero
xcodebuild -project sxxysecret.xcodeproj -scheme sxxysecret \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  build

# 5. Reinstalar
xcrun simctl uninstall booted com.aguitech.sxxysecret
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "sxxysecret.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.aguitech.sxxysecret
```

Si después de eso sigue roto, abrir un issue con:
- Output de los logs (`xcrun simctl spawn booted log stream ...`)
- JSON exacto que devuelve el backend (con `curl`)
- Stack trace si hay crash
