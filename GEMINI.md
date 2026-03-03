# GEMINI.md - Kit IA para eXeLearning

Este proyecto es un conjunto de herramientas y recursos diseñado para facilitar la generación y modificación de paquetes educativos de eXeLearning (`.elpx`) mediante Inteligencia Artificial.

## 🎯 Objetivo del Proyecto
Proporcionar una estructura de referencia sólida, plantillas validadas y herramientas de automatización para que una IA pueda crear contenidos educativos compatibles con eXeLearning 4+ sin necesidad de la interfaz gráfica, asegurando que el resultado sea tanto funcional (reproducible en navegador) como reimportable por la herramienta original.

## 🛠️ Tecnologías y Estructura
El proyecto se basa en la manipulación de archivos ZIP (formato `.elpx`), XML (`content.xml`) y HTML/JS/CSS.

### Directorios Clave
- **`scripts/`**: Herramientas en Bash para la gestión del ciclo de vida de un proyecto `.elpx`.
- **`plantillas/`**: Proyectos base (`base`, `avanzada`, `todos_idevices`) en formato de directorio y empaquetados.
- **`referencias/ode_components/`**: Biblioteca de fragmentos XML (`odeComponent`) para insertar diferentes iDevices.
- **`referencias/ode_components_curated/`**: Referencias refinadas manualmente para mayor fiabilidad.
- **Documentación técnica**: Guías específicas (`guia_elpx_ia.md`, `guia_componentes_ode_por_idevice.md`, `guia_juegos_elpx.md`) que dictan las reglas de construcción.

## 🚀 Comandos y Uso

### Gestión de Proyectos (`elpx-tool.sh`)
- **Crear un nuevo proyecto**:
  ```bash
  ./scripts/elpx-tool.sh create ./mi_proyecto "Título del Proyecto"
  ```
- **Empaquetar un directorio a .elpx**:
  ```bash
  ./scripts/elpx-tool.sh pack ./mi_proyecto ./mi_proyecto.elpx
  ```
- **Descomprimir un .elpx para edición**:
  ```bash
  ./scripts/elpx-tool.sh unpack ./material.elpx ./directorio_destino
  ```

### Edición e Inserción de Contenido
- **Insertar un iDevice en un proyecto**:
  ```bash
  ./scripts/insert-ode-component.sh ./mi_proyecto <tipo_idevice>
  ```
- **Instanciar un componente ODE (snippet XML)**:
  ```bash
  ./scripts/instantiate-ode-component.sh <tipo_idevice> [archivo_salida.xml]
  ```

### Validación y Enriquecimiento
- **Validar estructura y placeholders**:
  ```bash
  ./scripts/validate-elpx.sh ./mi_proyecto
  ```
- **Añadir recursos de iDevices (ej. juegos)**:
  ```bash
  ./scripts/add-idevice-assets.sh add ./mi_proyecto guess crossword word-search
  ```
- **Añadir un preset completo**:
  ```bash
  ./scripts/add-idevice-assets.sh add-preset ./mi_proyecto aula
  ```

### Mantenimiento y Sincronización
- **Sincronizar el kit con eXeLearning**: `./scripts/sync-with-exe.sh`
- **Regenerar catálogo de iDevices**: `./scripts/generate-idevice-catalog.sh`
- **Regenerar ejemplos de componentes ODE**: `./scripts/generate-ode-component-examples.sh`

## 📋 Convenciones para la IA
0. **Preflight Obligatorio de Entorno**: Antes de trabajar, ejecutar `./scripts/preflight-kit.sh`. Si faltan dependencias, intentar `--install` cuando sea posible; si no, informar al usuario con lista concreta.
1. **Prioridad de Referencias**: Usar primero `curated`, luego `real` y finalmente `generated`.
2. **Política de Temas**: Mantener el tema de la plantilla original o usar `base` por defecto.
3. **Estructura Interna**: Respetar estrictamente la ruta `content/resources/` para assets y `idevices/<tipo>/` para motores de juego/actividades.
4. **Validación Obligatoria**: Siempre ejecutar `validate-elpx.sh` tras modificar `content.xml` o `index.html`. Usar `checklist_validacion_elpx.md` como guía técnica y `checklist_rea_calidad.md` como guía de calidad pedagógica REA.
5. **Trabajo por Fases (Preferente)**: Primero fase de esqueleto (indice/paginas/iDevices base), mostrar ese indice al usuario, y despues completar en bloques incrementales; no rellenar todo de golpe salvo encargo simple.
6. **Paginación Docente**: La estructura multipágina es preferente, pero se admite recurso de una sola página si el docente lo solicita y se mantiene calidad didáctica.

## 📂 Archivos Importantes
- `README.md`: Resumen rápido de comandos.
- `guia_elpx_ia.md`: Manual técnico fundamental para entender la anatomía de un `.elpx`.
- `guia_componentes_ode_por_idevice.md`: Instrucciones sobre cómo usar los fragmentos de la carpeta `referencias/`.
- `guia_juegos_elpx.md`: Guía específica para iDevices de juegos interactivos.
- `catalogo_idevices.md`: Inventario de todos los componentes soportados.
- `catalogo_componentes_ode.md`: Catálogo de ejemplos ODE por iDevice.
- `checklist_validacion_elpx.md`: Criterios mínimos de calidad para un paquete `.elpx`.
- `checklist_rea_calidad.md`: Lista de comprobación de calidad pedagógica REA.
- `mapa_recursos_ia.md`: Mapa de dónde obtener cada recurso para la generación.
