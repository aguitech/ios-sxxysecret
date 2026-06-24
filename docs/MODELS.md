# 📦 Models

Los modelos Swift son `Codable` DTOs que mapean 1:1 con la respuesta JSON del backend. Viven en `sxxysecret/Models/`.

> **Convención clave:** el backend usa MongoDB shapes (`_id`, `createdAt`, `updatedAt`). Mapeamos `_id` → `id` con `CodingKeys`. Todos los timestamps son opcionales excepto los que son requeridos por la app.

---

## 🎯 User

**File:** `Models/User.swift`

```swift
struct User: Codable, Identifiable, Hashable {
    let id: String           // ← maps from _id
    let name: String
    let email: String
    let role: String         // admin | manager | member | client
    let phone: String?
    let active: Bool?
    let lastLogin: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, role, phone, active, lastLogin, createdAt, updatedAt
    }
}
```

### Custom init

`User` tiene un `init(from:)` custom que:
1. Usa `decodeIfPresent` para todos los opcionales
2. Usa el helper `flexDate` para fechas con/sin fracciones

```swift
init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try c.decode(String.self, forKey: .id)
    self.name = try c.decode(String.self, forKey: .name)
    self.email = try c.decode(String.self, forKey: .email)
    // ... etc
    self.lastLogin = User.flexDate(c, key: .lastLogin)
    // ...
}
```

### `flexDate` helper

```swift
private static func flexDate(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
    guard container.contains(key),
          let raw = try? container.decode(String.self, forKey: key) else { return nil }
    if let d = ISO8601DateFormatter.flexStrict.date(from: raw) { return d }
    return ISO8601DateFormatter.flexFractional.date(from: raw)
}
```

> Ver [PITFALLS.md#1-encoding-fechas-flexibles](./PITFALLS.md#1-encoding-de-fechas-flexibles) por qué esto es necesario.

### Helpers de UI

```swift
var roleLabel: String {  // → "Administrador", "Manager", "Miembro", "Cliente"
    switch role { ... }
}

var initials: String {  // → "MH" para "Memo Hernández"
    let parts = name.split(separator: " ")
    let first = parts.first?.first.map(String.init) ?? ""
    let last = parts.dropFirst().first?.first.map(String.init) ?? ""
    return (first + last).uppercased()
}
```

---

## 👤 UserRef (sub-ref)

Representación mínima de un User cuando viene **populado dentro de otro documento**.

```swift
struct UserRef: Codable, Hashable {
    let id: String
    let name: String
    let email: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, role
    }
}
```

Aparece en: `ProjectMember.user`, `ClientRef` (parcialmente), `Task.owner`, `Task.assignee`, `Conversation.other`, `Conversation.participants[]`, `MemberStat.user`, `Comment.author`.

---

## 👥 Client

**File:** `Models/Client.swift`

```swift
struct Client: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let company: String?
    let email: String?
    let phone: String?
    let notes: String?
    let status: String?         // activo | pausado | baja
    let owner: ClientOwner?     // String | UserRef — enum
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, company, email, phone, notes, status, owner, createdAt, updatedAt
    }
}
```

### `ClientOwner` — enum polimórfico

⚠️ El backend alterna entre `String` (en listing) y `UserRef` poblado (en detail). Lo modelamos como enum:

```swift
enum ClientOwner: Codable, Hashable {
    case userId(String)
    case user(UserRef)

    var id: String {
        switch self {
        case .userId(let s): return s
        case .user(let u): return u.id
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .userId(s); return }
        if let u = try? c.decode(UserRef.self) { self = .user(u); return }
        self = .userId("")  // fallback
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .userId(let s): try c.encode(s)
        case .user(let u): try c.encode(u)
        }
    }
}
```

---

## 📁 Project

**File:** `Models/Project.swift`

```swift
struct Project: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let status: String           // activo | pausado | completado
    let progress: Int            // 0-100
    let description: String?
    let budget: Double?
    let startDate: Date?
    let endDate: Date?
    let owner: ProjectOwner?     // String | UserRef
    let client: ClientRef?       // poblado o null
    let members: [ProjectMember]?
    let createdAt: Date?
    let updatedAt: Date?
}
```

### `ProjectOwner` — enum polimórfico

Igual patrón que `ClientOwner`. Usado en:
- `Project.owner` (String en list, UserRef en detail)

### `ProjectLite` — enum polimórfico

Usado en **`ProjectTask.project`**:

```swift
enum ProjectLite: Codable, Hashable {
    case projectId(String)
    case populated(_id: String, title: String, status: String?)

    var id: String { ... }
    var title: String? { ... }
    // custom decoder igual que los demás
}
```

### `ProjectMember` y `ProjectMemberRole`

```swift
struct ProjectMember: Codable, Hashable {
    let user: UserRef
    let role: String
    let addedAt: Date?
}

enum ProjectMemberRole: String, CaseIterable, Codable, Identifiable {
    case colaborador
    case revisor
    case observador

    var id: String { rawValue }
    var label: String { ... }        // "Colaborador", "Revisor", "Observador"
    var description: String { ... }  // "Puede editar tareas", etc.
    var colorName: String { ... }    // para debug
    var color: Color { ... }         // ← ESTE necesita import SwiftUI
}
```

> ⚠️ `ProjectMemberRole.color: Color` requiere `import SwiftUI` en `Project.swift`. Por eso es el único modelo que no es Foundation puro.

### Otros modelos auxiliares en Project.swift

- **`DashboardStats`**: `{total, activos, completados, promedio}` (de `/dashboard/stats`)
- **`ProjectDetail`**: response de `/dashboard/projects/:id/detail` (incluye `project, stats, tasks, memberStats, recentComments`)
- **`ProjectStats`**: contadores de tareas por status/priority, progress, etc.
- **`MemberStat`**: `{user, role, addedAt, tasksOwned, tasksCompleted}`

---

## ✅ ProjectTask (Task)

**File:** `Models/Client.swift` (sí, vive ahí por motivos históricos)

```swift
struct ProjectTask: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let status: String          // pendiente | en_curso | hecho
    let priority: String        // baja | media | alta
    let dueDate: Date?
    let project: ProjectLite?   // String | poblado
    let client: ClientRef?
    let owner: UserRef?
    let assignee: UserRef?
    let images: [TaskAttachment]?
    let videos: [TaskAttachment]?
    let documents: [TaskAttachment]?
    let links: [TaskLink]?
    let comments: [TaskComment]?
    let createdAt: Date?
    let updatedAt: Date?
}
```

> ⚠️ Status y priority son los enums **del backend** (3 valores cada uno), NO los de la documentación vieja (que mencionaba 5 y 4).

### Adjuntos

```swift
struct TaskAttachment: Codable, Hashable, Identifiable {
    var id: String { url + filename }
    let url: String
    let filename: String
    let mimetype: String?
    let size: Int?
}
```

`url` viene como path relativo: `/api/uploads/12345_image.png`. La app lo concatena con el host cuando necesita mostrarlo.

---

## 💬 Chat models

Todos viven en `Models/Client.swift` también.

### `ChatSender` — enum polimórfico

```swift
enum ChatSender: Codable, Hashable {
    case userId(String)         // listing
    case user(UserRef)          // detail

    var id: String { ... }
    var user: UserRef? { ... }
    var name: String? { user?.name }
}
```

⚠️ **ESTE es el bug más reciente que arreglamos.** El backend usa el mismo key `sender` para ambas formas. Sin este enum, el chat fallaba con "Error de decodificación". Ver [PITFALLS.md#2-chat-decoding](./PITFALLS.md#2-chat-decoding).

### `ChatMessage`

```swift
struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String?
    let conversation: String?
    let sender: ChatSender
    let text: String
    let attachments: [ChatAttachment]?
    let readBy: [String]?
    let editedAt: Date?
    let deleted: Bool?
    let createdAt: Date
    let updatedAt: Date?
}
```

### `MessagePage` (paginación)

```swift
struct MessagePage: Codable {
    let messages: [ChatMessage]
    let hasMore: Bool
    let nextCursor: String?
}
```

### `Conversation`

```swift
struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let type: String?            // "direct" | "group"
    let name: String?
    let other: UserRef?          // for direct chats
    let participants: [UserRef]?
    let lastMessageAt: Date?
    let lastMessage: ChatMessage?
    let unreadCount: Int?
}
```

---

## 📐 Patrones recurrentes

### Custom Codable para enums polimórficos

El patrón se repite 4 veces (`ClientOwner`, `ProjectOwner`, `ProjectLite`, `ChatSender`):

```swift
enum X: Codable, Hashable {
    case variantA(...)
    case variantB(...)

    var usefulAccessor: T {
        switch self {
        case .variantA(let x): return x.transform()
        case .variantB(let x): return x.transform()
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let x = try? c.decode(TypeA.self) { self = .variantA(x); return }
        if let x = try? c.decode(TypeB.self) { self = .variantB(x); return }
        self = .variantA(.default)  // fallback seguro
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .variantA(let x): try c.encode(x)
        case .variantB(let x): try c.encode(x)
        }
    }
}
```

> **Si agregas un nuevo enum polimórfico, sigue este patrón exacto.**

### Hashable conformance

Todos los modelos son `Hashable` para que SwiftUI pueda usarlos en `ForEach`, `NavigationLink(value:)`, etc. Los enums polimórficos también.

### Identifiable

Todos los modelos principales son `Identifiable` (conforman `var id: String`). Esto permite `ForEach(model) { ... }` sin necesidad de `id:`.

---

## ⚠️ Errores comunes

### "Cannot decode. The data couldn't be read because it is missing."

Causa más probable: un enum polimórfico no maneja una nueva forma que el backend está mandando. Solución: agregar el case que falta o extender el `init(from:)`.

### "Invalid date: ..."

El backend mandó una fecha que ni `flexStrict` ni `flexFractional` pueden parsear. Solución: revisar el formato exacto en la respuesta del backend y agregar un parser.

### "The data couldn't be decoded because it contains a nil value"

Campo opcional del backend que en Swift está marcado como no-opcional. Solución: marcarlo `Optional` o usar `decodeIfPresent`.
