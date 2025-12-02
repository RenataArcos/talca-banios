# TalcaToilet 🚽 Mapeo Colaborativo de Baños en Talca

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Licencia](https://img.shields.io/badge/Licencia-MIT-green?style=for-the-badge)

Proyecto de mapeo colaborativo para encontrar y calificar baños públicos en la ciudad de Talca. Esta aplicación permite a los usuarios localizar baños cercanos, filtrar por características clave (como accesibilidad y costo) y, en futuras versiones, contribuir con reseñas y nuevos lugares.

Este proyecto es parte del curso de Desarrollo de Software (Prof. Sebastián Ortega).

---

## ✅ Estado del Proyecto (Hito 1 – Entregable 25%)

### Funcionalidades clave por Historia de Usuario

**HU1 – Ver mapa y centrado en mi ubicación**
- Mapa interactivo con `flutter_map` (CARTO light).
- Centrado **automático** al abrir:
  - Si hay permisos y GPS activos → centra en mi ubicación (zoom 16).
  - Si no → **fallback** a centro de Talca (−35.427, −71.655; zoom 15) con SnackBar informativo.
- Botón **“Mi ubicación”** (FAB) que reintenta permisos y centra el mapa.
- Manejo robusto de permisos:
  - `denied` → solicita permiso.
  - `deniedForever` → diálogo para abrir **Configuración** de la app.
  - GPS apagado → diálogo para abrir **Ajustes de ubicación**.

**HU2 – Buscar y filtrar resultados**
- Barra de búsqueda por nombre (filtrado en tiempo real).
- Filtros combinables:
  - **Gratis** (`fee=no`)
  - **Accesible** (`toilets:wheelchair=yes`)

**HU3 – Ver distancia y acciones sobre un baño**
- Al tocar un pin se abre ficha con:
  - **Distancia** desde mi posición (m / km).
  - Indicadores **Gratis** / **Accesible**.
  - Botones: **Detalle**, **Reseñar**, **Reportar** (placeholders).
- Capa visual para **mi posición** (círculo azul).

**HU4 – Autenticación (email/Google)**
- Botón **Cuenta** en la esquina superior derecha (AppBar).
- Popup (bottom sheet) para:
  - **Google Sign-In** (botón principal).
  - **Email/Password** (login/registro).
  - Mostrar **errores** (p. ej., “Correo o contraseña incorrectos.”, “Ese correo ya está registrado.”).
  - Ver **perfil básico** y **cerrar sesión** cuando hay sesión activa.
- **Gate de autenticación**: si el usuario toca **Reseñar** o **Reportar** sin sesión, se abre el popup de login/registro; tras autenticarse, se continúa.

> Además, se inyectan **datos de prueba (mocks)** para que búsqueda/filtros/fichas sean demostrables incluso si la API de Overpass no retorna datos.

---

## 🏗️ Arquitectura (inspirada en Clean Architecture)

- `lib/presentation/` → Pantallas y widgets (UI y lógica de estado ligera).
  - `screens/map_screen.dart` (mapa, permisos, auth popup, fichas)
- `lib/domain/` → Entidades y casos de uso.
  - `entities/bathroom.dart`
  - `use_cases/get_bathrooms_usecase.dart`
- `lib/data/` → Repositorios y fuentes de datos.
  - `data_sources/osm_data_source.dart` (Overpass/OSM)
  - `repositories/bathroom_repository_impl.dart`

> Próximo paso (Hito siguiente): mover **Auth/User** a repositorios/UC (actualmente la UI orquesta FirebaseAuth directamente para simplificar la demo de HU4).

---

## 🧩 Dependencias principales

```yaml
# pubspec.yaml (extracto)
dependencies:
  flutter_map: ^7.x
  latlong2: ^0.9.x
  http: ^1.x
  geolocator: ^13.x
  firebase_core: ^3.x
  firebase_auth: ^5.x
  google_sign_in: ^6.x
  cloud_firestore: ^5.x   # (cuando habilites Firestore)
