# 🛠️ Setup

Cómo clonar, abrir, compilar, instalar y correr la app. **Empieza aquí si es tu primera vez.**

---

## 📋 Requisitos

- **macOS 14+** (probado en 26.5.1)
- **Xcode 26.5+** (incluye iOS 26.5 SDK)
- **Git** con SSH key configurada para `github.com/aguitech`
- **iPhone simulator** (Xcode incluye iPhone 17 Pro por default)
- **Conexión a internet** para llamar a `sxxysecret.com`

> ⚠️ **No necesitas cuenta de Apple Developer** para correr en simulator. Solo para device físico o TestFlight.

---

## 🚀 Instalación

### 1. Clonar el repo

```bash
git clone git@github.com:aguitech/ios-sxxysecret.git
cd ios-sxxysecret
```

Si SSH no está configurado:
```bash
# HTTPS (no recomendado, pero funciona)
git clone https://github.com/aguitech/ios-sxxysecret.git
```

### 2. Abrir en Xcode

```bash
open sxxysecret.xcodeproj
```

**O** desde Xcode:
1. File → Open...
2. Navegar a la carpeta clonada
3. Seleccionar `sxxysecret.xcodeproj`

### 3. Configurar signing (solo device físico)

Xcode debería auto-seleccionar tu personal team. Si no:

1. Click en el proyecto `sxxysecret` (en el navigator izquierdo)
2. Selecciona el target `sxxysecret`
3. Pestaña **Signing & Capabilities**
4. **Team:** selecciona tu Apple ID
5. Si no aparece, agrega uno en Xcode → Settings → Accounts

> **No requerido para simulator.** Solo afecta builds para device físico.

---

## 🏗️ Build

### Desde Xcode
1. Selecciona el scheme `sxxysecret` (arriba a la izquierda)
2. Selecciona destination: **iPhone 17 Pro** (o el que tengas)
3. `Cmd + R` para build & run

### Desde CLI

```bash
# Build para simulator
xcodebuild \
  -project sxxysecret.xcodeproj \
  -scheme sxxysecret \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  build
```

El `.app` queda en:
```
~/Library/Developer/Xcode/DerivedData/sxxysecret-<hash>/Build/Products/Debug-iphonesimulator/sxxysecret.app
```

---

## 📱 Instalar en simulator

### Paso 1: Bootea un simulator

```bash
# Listar devices disponibles
xcrun simctl list devices available

# Bootea uno (iPhone 17 Pro es el default moderno)
xcrun simctl boot "iPhone 17 Pro"
# Si el ID cambia, usa el UUID directamente
xcrun simctl boot 1E7FA890-EE82-4109-B1A2-53A62A4EA4E2
```

### Paso 2: Instala la app

```bash
APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/sxxysecret-*/Build/Products/Debug-iphonesimulator/sxxysecret.app"
xcrun simctl install booted $APP_PATH
```

### Paso 3: Abre la app

```bash
xcrun simctl launch booted com.aguitech.sxxysecret
```

### All-in-one script

```bash
#!/bin/bash
set -e
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcodebuild -project sxxysecret.xcodeproj -scheme sxxysecret \
  -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  build 2>&1 | tail -5
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "sxxysecret.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.aguitech.sxxysecret
```

Guardar como `run.sh`, `chmod +x run.sh`, `./run.sh`.

---

## 🔑 Credenciales seed

Para login en la app:

```
Email:    admin@aguittech.com
Password: admin123
```

⚠️ Esto es el admin del backend de desarrollo. **No usar en producción.** Si necesitas un user nuevo, créalo desde la sección Usuarios de la app.

---

## 🧹 Reset

Si quieres empezar de cero:

```bash
# Borrar app del simulator
xcrun simctl uninstall booted com.aguitech.sxxysecret

# Reset completo del simulator (borra todo)
xcrun simctl erase "iPhone 17 Pro"
xcrun simctl boot "iPhone 17 Pro"
```

---

## 🐛 Troubleshooting

### "The simulator is not booted"
```bash
xcrun simctl boot "iPhone 17 Pro"
# O lista los booted:
xcrun simctl list devices booted
```

### "Bundle identifier mismatch"
Verifica `Info.plist` → `CFBundleIdentifier`. Debe ser `com.aguitech.sxxysecret`. Si lo cambiaste, ajusta el comando de launch:
```bash
xcrun simctl launch booted com.YOUR.bundle.id
```

### "Build failed: 'X' is ambiguous"
Probablemente dos structs con el mismo nombre. Ver [PITFALLS.md#8-chip-redeclared](./PITFALLS.md#8-chip-struct-redeclarado).

### "Cannot find 'Color' in scope" en Project.swift
Falta `import SwiftUI` arriba. Es el único modelo que lo necesita (para `ProjectMemberRole.color: Color`).

### "Build takes forever"
Xcode cache puede estar corrupto. Reset:
```bash
xcrun simctl shutdown all
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild ... build  # rebuild everything
```

### App abre y cierra inmediatamente
Probablemente crash en algún modelo o vista. Ver el log:
```bash
# Stream logs del simulator
xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "sxxysecret"' --level=debug

# O abre Console.app y filtra por "sxxysecret"
```

### "Error de decodificación" en alguna vista
Lee [PITFALLS.md](./PITFALLS.md) — hay 5+ bugs resueltos con explicación completa.

### Login falla con 401
El token puede estar expirado (7 días). Reset:
```bash
xcrun simctl uninstall booted com.aguitech.sxxysecret
xcrun simctl install booted $APP_PATH
xcrun simctl launch booted com.aguitech.sxxysecret
```

O desde la app: Profile → Cerrar sesión.

---

## 🔌 Configurar backend local (opcional)

Si quieres apuntar a un backend local en vez de `sxxysecret.com`:

1. Clona `aguitechcore`
   ```bash
   git clone git@github.com:aguitech/aguitechcore.git ~/projects/aguitechcore
   cd ~/projects/aguitechcore
   # sigue su README para correr Mongo + Express
   ```

2. Edita `sxxysecret/Services/APIClient.swift`:
   ```swift
   private let baseURL = "http://localhost:4000/api"  // ← cambiar
   ```

3. **Importante:** iOS ATS bloquea HTTP por default. Agrega una excepción en `Info.plist`:
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

   O desactiva ATS completamente (NO recomendado):
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
       <key>NSAllowsArbitraryLoads</key>
       <true/>
   </dict>
   ```

---

## 🔨 Estructura del .xcodeproj

El proyecto Xcode NO usa Swift Package Manager ni Cocoapods. Es un proyecto "vainilla" con:
- 1 target (`sxxysecret`)
- 17 archivos `.swift` en `sxxysecret/Views/`
- 3 archivos en `sxxysecret/Models/`
- 2 archivos en `sxxysecret/Services/`
- 2 archivos en `sxxysecret/Utils/`
- `Info.plist` con ATS hardened
- `Assets.xcassets` (vacío, sin íconos custom por ahora)

Si agregas un archivo `.swift` nuevo, **debes** registrarlo en `project.pbxproj` en 4 secciones:
1. `PBXBuildFile` section
2. `PBXFileReference` section
3. `Views` group children
4. `PBXSourcesBuildPhase` files

Usa IDs únicos de 24 chars hex.

> **Tip:** usa Xcode (no edición manual del `.pbxproj`). Click derecho en el grupo "Views" → "Add Files to sxxysecret...". Es más seguro.

---

## 📊 Métricas

- **Tamaño:** ~14 MB compilado
- **Build time:** ~25s desde limpio (M1/M2/M3/M4)
- **Test target:** No hay (no escribimos tests todavía — TODO futuro)
- **Dependencies externas:** 0 (zero. solo frameworks de Apple)
