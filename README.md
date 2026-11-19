# SurveysApp — Aplicación Móvil de Campo (SurveySaaS)

*Aplicación móvil Android para operadores de campo de **SurveySaaS** (producto de Desesoft S.R.L.), diseñada con enfoque **Offline-First** para recolección de respuestas en zonas rurales o sin cobertura, digitalización de formularios físicos con OCR y captura de respuestas por voz en formato WAV con transcripción IA.*

---

## 📋 Índice

1. [Arquitectura y Stack Técnico](#arquitectura-y-stack-t%C3%A9cnico)
2. [Capacidades Clave](#capacidades-clave)
3. [Estructura del Proyecto](#estructura-del-proyecto)
4. [Configuración de Firma Release (Keystore Propio)](#configuraci%C3%B3n-de-firma-release-keystore-propio)
5. [Variables de Entorno y Configuración](#variables-de-entorno-y-configuraci%C3%B3n)
6. [Pipeline CI/CD (GitHub Actions)](#pipeline-cicd-github-actions)
7. [Pruebas Automatizadas y Calidad](#pruebas-automatizadas-y-calidad)

---

## 🏛️ Arquitectura y Stack Técnico

| Componente | Tecnología / Paquetes | Propósito |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3 / Dart 3** | Plataforma móvil Android (API 24+) |
| **Estado** | `provider` | Gestión de estado reactiva y desacoplada |
| **Base Local** | `sqflite` (SQLite) | Cola outbox transaccional, caché de campañas y `sync_log` |
| **Seguridad** | `flutter_secure_storage` | Tokens JWT almacenados en Android Keystore seguro |
| **Identificadores** | `uuid` (UUID v4) | Generación de identificador único de respuesta en el cliente |
| **Monitoreo** | `sentry_flutter` | Reporte centralizado de errores no controlados |
| **Multimedia** | `record` (WAV 44.1 kHz), `image_picker` | Grabación de voz y captura de formularios en papel |
| **Conectividad** | `connectivity_plus` | Detección reactiva de conexión para sincronización automática |

---

## ✨ Capacidades Clave

* **Offline-First & Modo Avión:** Descarga de campañas y encuestas asignadas en SQLite local. Permite responder encuestas completas sin conexión a internet y guardarlas de forma segura.
* **Cola Outbox con UUID Estable:** Cada respuesta se crea con un UUID v4 generado en el teléfono que se preserva en todos los reintentos.
* **Sincronización por Lotes y Backoff:** Al recuperar la red, las respuestas se envían en segundo plano por lotes con espera creciente (backoff exponencial).
* **Idempotencia Garantizada:** El backend rechaza duplicados (`400: Esta encuesta ya ha sido respondida`) y la app marca la entrega como sincronizada sin duplicar registros.
* **Bitácora Local `sync_log`:** Registro histórico con fecha, cantidad enviada, aceptada, rechazada y cálculo del % de efectividad de sincronización.
* **Indicador en Dashboard:** Contador visual de respuestas pendientes, botón "Sincronizar ahora" y alerta destacada si existen respuestas con más de 7 días sin sincronizar.
* **Verificación de Versión Silenciosa:** Consulta `version.json` una vez al día; si hay actualización disponible, notifica con novedades y enlace al APK.

---

## 🔐 Configuración de Firma Release (Keystore Propio)

Por seguridad, el keystore de producción y el archivo `key.properties` **se almacenan fuera del repositorio** y están excluidos en `.gitignore`.

### 1. Generación del Keystore de Lanzamiento (Una sola vez)

Ejecuta el siguiente comando en PowerShell o Bash (reemplazando las contraseñas por valores seguros):

```powershell
keytool -genkeypair -v `
  -keystore "C:\Users\<TU_USUARIO>\.android\surveysapp-release-keystore.jks" `
  -storetype JKS `
  -alias upload `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -storepass "<TU_STORE_PASSWORD>" `
  -keypass "<TU_KEY_PASSWORD>" `
  -dname "CN=SurveysApp, OU=Mobile, O=SurveysApp, L=LaPaz, ST=LaPaz, C=BO"
```

### 2. Configuración de `android/key.properties`

Copia la plantilla `android/key.properties.example` a `android/key.properties`:

```properties
keyAlias=upload
keyPassword=<TU_KEY_PASSWORD>
storeFile=C:/Users/<TU_USUARIO>/.android/surveysapp-release-keystore.jks
storePassword=<TU_STORE_PASSWORD>
```

> **Nota para CI/CD:** Si `android/key.properties` no existe (por ejemplo, en runners remotos de GitHub Actions sin secretos configurados), `android/app/build.gradle.kts` hace fallback automático a la firma `debug` para garantizar que la compilación no se rompa.

---

## ⚙️ Variables de Entorno y Configuración

La URL base del backend y el DSN de Sentry pueden configurarse en tiempo de compilación con `--dart-define` o modificarse desde la propia app en la pantalla de ajustes:

| Variable | Valor por Defecto | Descripción |
| :--- | :--- | :--- |
| `BACKEND_URL` | `http://32.197.191.95:8000` | URL base del backend FastAPI en AWS EC2 |
| `VERSION_JSON_URL` | `http://32.197.191.95:8000/downloads/version.json` | Endpoint de metadatos de versión |
| `SENTRY_DSN` | *(Vacío)* | DSN para reporte de errores en Sentry |

Ejemplo de compilación release:

```bash
flutter build apk --release `
  --dart-define=BACKEND_URL=http://32.197.191.95:8000 `
  --dart-define=SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0
```

---

## 🚀 Pipeline CI/CD (GitHub Actions)

El flujo automatizado está definido en `.github/workflows/ci.yml`:

* **En cada Push / Pull Request:**
  1. Instala el SDK de Flutter (versión estable).
  2. Ejecuta `flutter pub get`.
  3. Ejecuta análisis estático con `flutter analyze`.
  4. Ejecuta la suite de pruebas unitarias con `flutter test`.
* **En la rama `main`:**
  1. Compila el instalador final `app-release.apk`.
  2. Sube el binario como artefacto de compilación descargable (`app-release`, retención de 30 días).

---

## 🧪 Pruebas Automatizadas y Calidad

Para verificar la integridad del código:

```bash
# Analizador de código sin advertencias
flutter analyze

# Suite de pruebas unitarias y de simulación offline
flutter test
```

Las 5 pruebas oficiales en `test/offline_sync_and_models_test.dart` cubren:
1. Guardado local de una respuesta en SQLite y serialización de `SyncQueueItem`.
2. Generación y estabilidad de UUID v4 de cliente a través de reintentos con backoff.
3. Cola de sincronización: procesamiento de lotes con aceptación y rechazo parcial.
4. Serialización y deserialización bidireccional del modelo `Campaign` (`fromJson` y `toJson`).
5. Corte de red emulado: encolado offline sin pérdida y sincronización idempotente sin duplicados.
