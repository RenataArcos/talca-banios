# TalcaToilet 🚽 Mapeo Colaborativo de Baños en Talca

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Licencia](https://img.shields.io/badge/Licencia-MIT-green?style=for-the-badge)

Proyecto de mapeo colaborativo para encontrar y calificar baños públicos en la ciudad de Talca. Esta aplicación permite a los usuarios localizar baños cercanos, filtrar por características clave (como accesibilidad y costo) y, en futuras versiones, contribuir con reseñas y nuevos lugares.

Este proyecto es parte del curso de Desarrollo de Software (Prof. Sebastián Ortega).

##  Características (Hito 1 / Entregable 25%)

El estado actual del proyecto (Entregable 1) incluye las siguientes funcionalidades:

* **Mapa Interactivo:** Visualización de la ciudad de Talca usando `flutter_map` con un mapa base limpio de CARTO.
* **Datos de Origen (OSM):** Carga inicial de baños existentes desde la API Overpass (basada en OpenStreetMap).
* **Búsqueda y Filtros (HU1, HU2):** Una barra de búsqueda y filtros flotante (UI en `Stack`) que permite filtrar los marcadores del mapa en tiempo real por:
    * Nombre (Búsqueda textual).
    * Gratis (`fee=no`).
    * Accesible (`toilets:wheelchair=yes`).
* **Datos de Prueba (Mocks):** Inyección de datos de prueba para demostrar el funcionamiento de los filtros y la búsqueda.

---

## 🏗️ Arquitectura del Proyecto

El proyecto sigue una estructura inspirada en **Arquitectura Limpia (Clean Architecture)** para cumplir con los requisitos de mantenibilidad (RNF-03) y separar las responsabilidades en tres capas principales:



* `lib/presentation`: Contiene la UI (Widgets, Pantallas) y la lógica de estado.
* `lib/domain`: Contiene la lógica de negocio pura (Entidades, Casos de Uso) y las definiciones de los repositorios.
* `lib/data`: Contiene la implementación de los repositorios y las fuentes de datos (ej. `OsmDataSource` para la API Overpass).

---

## 📦 Dependencias Principales

El archivo `pubspec.yaml` define todas las dependencias. Las más importantes para este hito son:

* `flutter_map`: El widget principal para mostrar el mapa (alternativa a Google Maps).
* `http`: Para realizar las peticiones HTTP a la API de Overpass.
* `latlong2`: Paquete de utilidades para `flutter_map` (manejo de LatLng).

---

## 🚀 Guía de Ejecución

Sigue estos pasos para clonar y ejecutar el proyecto en un entorno Ubuntu/Linux con VS Code.

### Requisitos Previos

* [SDK de Flutter](https://flutter.dev/docs/get-started/install/linux)
* [Git](https://git-scm.com/downloads)
* [Visual Studio Code](https://code.visualstudio.com/) (con la extensión de Flutter)

### Pasos

1.  **Clonar el repositorio:**
    ```bash
    git clone git@github.com:RenataArcos/talca-banios.git
    cd talca-banios
    ```

2.  **Abrir en VS Code:**
    

3.  **Obtener dependencias:**
    Abre una terminal dentro de VS Code y ejecuta:
    ```bash
    flutter pub get
    ```

4.  **Ejecutar la aplicación:**
    *  Ejecuta:
    ```bash
    flutter run
    ```

---


## 📝 Licencia

Este proyecto está bajo la Licencia MIT.