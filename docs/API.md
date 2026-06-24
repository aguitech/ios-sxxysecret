# 🌐 API Contract

Todos los endpoints del backend **Aguitech Core / SxxySecret** que consume la app iOS.

**Base URL:** `https://sxxysecret.com/api/`
**Auth:** Bearer JWT (header `Authorization: Bearer <token>`)
**Content-Type:** `application/json` (multipart para uploads)

> Source: `aguitech/aguitechcore` repo. Backend is MERN stack con MongoDB.
> Esta doc refleja lo que la app **usa** — para el contrato completo ver `aguitechcore/docs/`.

---

## 🔐 Auth (`/auth`)

### `POST /auth/login` — público

```json
// Request
{ "email": "admin@aguittech.com", "password": "admin123" }

// Response 200
{
  "token": "eyJhbGc...",
  "user": { "_id": "...", "name": "...", "email": "...", "role": "admin", ... }
}
```

### `GET /auth/me` — auth

Devuelve `{ user: {...} }`. La app lo llama al startup si hay token persistido.

---

## 👤 Users (`/users`) — admin-only

### Roles
`admin` | `manager` | `member` | `client`

### Endpoints

| Method | Path | Permisos | Notas |
|---|---|---|---|
| GET | `/users` | admin | Lista todos. Soporta `?q=`, `?role=` |
| GET | `/users/:id` | admin, manager | Detalle |
| POST | `/users` | admin | Crear. Body: `name, email, password, role, phone?` |
| PUT | `/users/:id` | admin | Editar. Body parcial |
| DELETE | `/users/:id` | admin | Borrar |

### Shape `User`

```json
{
  "_id": "6a3c02f7559de78a86e06b4c",
  "name": "Memo",
  "email": "memo@codimexa.com",
  "role": "admin",
  "phone": "5577483822",
  "active": true,
  "lastLogin": "2026-06-24T16:16:55.321Z",
  "createdAt": "2026-06-24T16:16:55.321Z",
  "updatedAt": "2026-06-24T16:16:55.321Z"
}
```

---

## 👥 Clients (`/clients`)

### Status enum
`activo` | `pausado` | `baja`

### Endpoints

| Method | Path | Notas |
|---|---|---|
| GET | `/clients` | Lista. Soporta `?q=`, `?status=` |
| POST | `/clients` | Crear. Body: `name*`, `company?`, `email?`, `phone?`, `notes?`, `status?` |
| PUT | `/clients/:id` | Editar |
| DELETE | `/clients/:id` | Borrar (falla si tiene proyectos/tareas) |

### Shape `Client`

```json
{
  "_id": "6a3193e4b6627b79a7507ecf",
  "name": "Sofía Castillo",
  "company": "Café Raíz",
  "email": "sofio@caferaiz.mx",
  "phone": "+52 81 7777 8888",
  "notes": "Cliente VIP",
  "status": "activo",
  "owner": "6a3193e4b6627b79a7507ec7",
  "createdAt": "2026-06-16T18:20:20.894Z",
  "updatedAt": "2026-06-16T18:20:20.894Z"
}
```

⚠️ `owner` puede venir como `String` (ID) o `UserRef` populado. Modelado como `ClientOwner` enum.

---

## 📁 Projects (`/dashboard/projects`)

> ⚠️ Las rutas de projects están **dentro de `/dashboard`**, no en `/projects` root.

### Status enum
`activo` | `pausado` | `completado`

### Endpoints

| Method | Path | Notas |
|---|---|---|
| GET | `/dashboard/projects` | Lista. Soporta `?q=`, `?status=`, `?client=` |
| GET | `/dashboard/projects/:id` | Detalle básico |
| GET | `/dashboard/projects/:id/detail` | Detalle con tasks, stats, comments |
| POST | `/dashboard/projects` | Crear. **Usa `clientId`**, NO `client` |
| PUT | `/dashboard/projects/:id` | Editar. Acepta `clientId` |
| DELETE | `/dashboard/projects/:id` | Borrar |
| POST | `/dashboard/projects/:id/members` | **Agregar por EMAIL** + role |
| DELETE | `/dashboard/projects/:id/members/:userId` | Quitar por userId |

### ⚠️ Diferencias clave vs. otros endpoints

| Concepto | Backend espera | NO hagas |
|---|---|---|
| Cliente | `clientId: "abc123"` | NO `client: "abc123"` |
| Crear con miembros | No soportado inline | NO `members: [userIds]` en POST /projects |
| Agregar miembro | `{email, role}` | NO `{user: userId, role}` |
| Solo owner puede editar | `findOneAndUpdate({_id, owner})` | No funciona para otros users |

### Shape `Project`

```json
{
  "_id": "6a31b50cee6b35a4e85ebc6d",
  "title": "Hector",
  "client": {
    "_id": "6a3193e4b6627b79a7507ecf",
    "name": "Sofía Castillo",
    "company": "Café Raíz",
    "email": "sofio@caferaiz.mx",
    "status": "activo"
  },
  "status": "activo",
  "progress": 10,
  "description": "",
  "budget": 10000,
  "startDate": "1989-04-12T00:00:00.000Z",
  "endDate": "2026-09-12T00:00:00.000Z",
  "owner": "6a3193e4b6627b79a7507ec7",
  "members": [
    {
      "user": {
        "_id": "6a3186e95a4c64b1e7754a88",
        "name": "Memo",
        "email": "memo@codimexa.com",
        "role": "admin"
      },
      "role": "colaborador",
      "addedAt": "2026-06-16T21:46:43.251Z"
    }
  ],
  "createdAt": "2026-06-16T21:46:43.251Z",
  "updatedAt": "2026-06-16T21:46:43.251Z"
}
```

### Miembros — roles válidos
`colaborador` (default) | `revisor` | `observador`

### Crear proyecto con miembros

```swift
// 1. Crear el proyecto
let project = try await APIClient.shared.createProject(
    title: "Mi proyecto",
    clientId: "...",           // ← clientId, no client
    status: "activo",
    progress: 0,
    budget: nil,
    startDate: nil,
    endDate: nil
)

// 2. Después, agregar miembros uno por uno (backend resuelve por email)
for member in membersToAdd {
    try await APIClient.shared.addProjectMember(
        projectId: project.id,
        email: member.email,    // ← email, no userId
        role: member.role.rawValue
    )
}
```

---

## ✅ Tasks (`/tasks`)

### Status enum
`pendiente` | `en_curso` | `hecho`

### Priority enum
`baja` | `media` | `alta`

> ⚠️ NO usar `urgent`, `low`, `medium`, `high`, `in_progress`, `done` — esos NO existen.

### Endpoints

| Method | Path | Notas |
|---|---|---|
| GET | `/tasks` | Lista. Soporta `?status=`, `?assignee=`, `?project=`, `?priority=` |
| POST | `/tasks` | Crear |
| PUT | `/tasks/:id` | Editar |
| DELETE | `/tasks/:id` | Borrar |
| POST | `/tasks/:id/images` | Multipart upload imagen |
| POST | `/tasks/:id/videos` | Multipart upload video |
| POST | `/tasks/:id/documents` | Multipart upload doc |
| POST | `/tasks/:id/comments` | Agregar comentario |

### Shape `ProjectTask`

```json
{
  "_id": "6a32ce5e87e6269f8379b8de",
  "title": "PDF Export Test Task",
  "description": "...",
  "status": "en_curso",
  "priority": "alta",
  "project": { "_id": "...", "title": "Hector", "status": "activo" },
  "client": { "_id": "...", "name": "...", "status": "activo" },
  "owner": { "_id": "...", "name": "Héctor Admin", "email": "admin@aguittech.com" },
  "assignee": null,
  "images": [{ "url": "/api/uploads/...", "filename": "...", "mimetype": "...", "size": 238, ... }],
  "videos": [],
  "documents": [],
  "comments": [],
  "dueDate": null,
  "createdAt": "2026-06-17T16:42:06.214Z",
  "updatedAt": "2026-06-17T16:42:34.249Z"
}
```

⚠️ `project` puede venir como objeto poblado (en `GET /tasks`) o como String ID (en otros contexts). Modelado como `ProjectLite` enum.

---

## 💬 Chat (`/chat`)

### Endpoints

| Method | Path | Notas |
|---|---|---|
| GET | `/chat/users/search?q=` | Buscar users |
| GET | `/chat/conversations` | Lista de conversaciones |
| POST | `/chat/conversations` | Abrir conversación. Body: `{email}` |
| GET | `/chat/conversations/:id/messages?cursor=&since=` | Mensajes paginados |
| POST | `/chat/conversations/:id/messages` | Enviar (multipart para adjuntos) |
| POST | `/chat/conversations/:id/attachments` | Subir adjuntos sin mensaje |
| POST | `/chat/conversations/:id/read` | Marcar leído |

### Paginación de mensajes

```json
// GET /chat/conversations/:id/messages
{
  "messages": [...],
  "hasMore": true,
  "nextCursor": "..."
}
```

### Adjuntos en mensajes

Multipart `multipart/form-data` con field `files` (puede ser múltiple, hasta 20). El texto va en field `text`.

```bash
curl -X POST https://sxxysecret.com/api/chat/conversations/<id>/messages \
  -H "Authorization: Bearer <token>" \
  -F "text=Hola con adjunto" \
  -F "files=@/path/to/image.png"
```

Los archivos se guardan en `uploads/` y se sirven en `/api/uploads/`.

---

## 📊 Dashboard (`/dashboard`)

| Method | Path | Notas |
|---|---|---|
| GET | `/dashboard/stats` | KPIs globales `{total, activos, completados, promedio}` |
| GET | `/dashboard/projects/member-roles` | `{roles, labels, descriptions}` — UI para roles |

---

## 📝 Otras secciones del backend (no usadas aún por la app)

- `notifications`, `appointments`, `posts` (blog), `mcp`, `apikeys`, `audit`, `calendar`, `profile`

Ver `aguitechcore/docs/` para detalle.

---

## ⚠️ Notas operacionales

### Errores

```json
// 400/404/etc
{ "message": "Cliente requerido" }

// 401
{ "message": "Token inválido o expirado" }

// 409
{ "message": "Ese usuario ya es miembro del proyecto" }
```

La app usa `APIError` enum (en `APIClient.swift`):
- `.unauthorized` → logout automático (vuelve a LoginView)
- `.server(code, message)` → muestra `message` en UI
- `.decoding(error)` → "Error de decodificación: ..."

### CORS / HTTPS
ATS en `Info.plist` está hardened a HTTPS-only para `sxxysecret.com`. No HTTP.

### Rate limits
El backend no tiene rate limits formales. Si abusas, sufres.
