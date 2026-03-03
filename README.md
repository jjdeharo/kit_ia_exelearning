# Kit IA para eXeLearning

Este repo ya incluye:

- guias corregidas para entender `.elpx`
- una plantilla minima reutilizable con tema `base`
- una plantilla avanzada con recursos de varios iDevices frecuentes
- una herramienta sencilla para crear, abrir y volver a empaquetar proyectos
- un validador rapido para comprobar si un `.elpx` esta bien formado a nivel practico
- una utilidad para añadir recursos de mas iDevices a un proyecto
- un catalogo generado de todos los iDevices detectados en el clon local de eXe
- un catalogo de ejemplos reales de `odeComponent` para los iDevices que ya aparecen en los fixtures
- una capa de referencias `curated` para los iDevices prioritarios mas usados
- una biblioteca de snippets `odeComponent` para todos los iDevices (reales o generados)
- un generador para instanciar snippets `odeComponent` listos para insertar
- una herramienta para insertar esos bloques en `content.xml` e `index.html`
- una carpeta fija `trabajos/` para centralizar los `.elpx` reales de cada sesion

## Carpeta de trabajo

La carpeta recomendada para los materiales reales esta en:

- `trabajos/`

Su objetivo es centralizar:

- los `.elpx` originales que entregue el docente
- los `.elpx` modificados o generados por la IA
- los directorios temporales descomprimidos para editar

Conviene que cualquier IA que entre en este repo use `trabajos/` como ubicacion por defecto para el flujo real de trabajo.
Ademas, para evitar mezclar proyectos de sesiones distintas, cada proyecto debe vivir en su propia subcarpeta directa dentro de `trabajos/`.

Ejemplo:

```bash
mkdir -p ./trabajos/biologia_endosimbiosis_2026-03-02/entrega
cp /ruta/externa/material.elpx ./trabajos/biologia_endosimbiosis_2026-03-02/entrega/material_original.elpx
./scripts/elpx-tool.sh unpack \
  ./trabajos/biologia_endosimbiosis_2026-03-02/entrega/material_original.elpx \
  ./trabajos/biologia_endosimbiosis_2026-03-02/editable
./scripts/validate-elpx.sh ./trabajos/biologia_endosimbiosis_2026-03-02/editable
./scripts/elpx-tool.sh pack \
  ./trabajos/biologia_endosimbiosis_2026-03-02/editable \
  ./trabajos/biologia_endosimbiosis_2026-03-02/entrega/material_modificado.elpx
```

## Flujo recomendado

### Preflight de entorno (primer paso recomendado)

Antes de crear o modificar cualquier `.elpx`, la IA debe inspeccionar el entorno:

```bash
./scripts/preflight-kit.sh
```

Si faltan dependencias y el entorno lo permite, puede intentar instalarlas:

```bash
./scripts/preflight-kit.sh --install
```

Si no puede instalarlas automaticamente, debe informar al usuario de lo que falta y detener el flujo hasta corregir el entorno.

Nota Windows:

- Si el usuario trabaja en Windows sin Bash, la IA debe recomendar `WSL` (preferente) o `Git Bash`.
- El preflight incluye guia de instalacion manual (incluyendo comandos orientativos para `winget`/`choco`).

### Criterio docente minimo

Para generar productos docentes utiles (no demos tecnicas), cualquier IA que trabaje en este repo debe cumplir:

- no entregar proyectos reducidos a un unico iDevice
- organizar el material por paginas didacticas; multipagina es preferente pero no obligatorio
- incluir siempre una pagina de creditos/licencias/fuentes
- redactar contenido util para profesorado y alumnado (objetivos, desarrollo, actividades y repaso/evaluacion)

### Crear un proyecto nuevo

```bash
./scripts/elpx-tool.sh create ./mi_proyecto "Mi titulo"
```

Si quieres crearlo y empaquetarlo en un solo paso:

```bash
./scripts/elpx-tool.sh create ./mi_proyecto "Mi titulo" ./mi_proyecto.elpx
```

### Modificar un `.elpx` existente

Descomprime:

```bash
./scripts/elpx-tool.sh unpack ./material.elpx ./material_editable
```

Edita `content.xml`, `index.html`, `html/` o los recursos necesarios.

Vuelve a empaquetar:

```bash
./scripts/elpx-tool.sh pack ./material_editable ./material_modificado.elpx
```

Nota de compatibilidad eXe:

- `pack` normaliza automaticamente los HTML exportados para que las rutas de recursos queden como en eXe (`content/resources/...` en `index.html` y `../content/resources/...` en `html/*.html`).
- `content.xml` mantiene `{{context_path}}/...` para compatibilidad de edicion/reimportacion.

### Validar un `.elpx`

Validar un paquete ya empaquetado:

```bash
./scripts/validate-elpx.sh ./material_modificado.elpx
```

Validar un directorio ya descomprimido:

```bash
./scripts/validate-elpx.sh ./material_editable
```

El validador comprueba tambien que no queden placeholders sin sustituir como `__IDEVICE_ID__`, `__PAGE_ID__`, `__DATA_GAME__` o `__EVALUATION_ID__`.
Ademas lanza avisos si detecta valores de ejemplo tipicos (`https://example.org`, `recurso.ggb`, `imagen-1.jpg`, `video.mp4`, textos de muestra, etc.).
Tambien valida que en iDevices `text` no haya desajuste entre `htmlView` y `jsonProperties.textTextarea` (para evitar que el editor muestre menos contenido que la vista previa).
Tambien valida que `jsonProperties.textTextarea` mantenga HTML en iDevices `text` para evitar que el editor muestre todo sin formato.
Tambien valida que las imagenes presentes en `htmlView` aparezcan tambien en `textTextarea` para que se vean tanto en editor como en vista previa.
Tambien fuerza compatibilidad de editor en iDevices `text`: evita imagenes `SVG` y exige formatos raster (`PNG/JPG/WebP`) en `textTextarea`.
Tambien fuerza rutas de imagen compatibles con editor en iDevices `text`: en `textTextarea` exige `{{context_path}}/<carpeta>/<archivo>` en lugar de `content/resources/...` directo.
Tambien valida formato de atribucion en imagenes (estructura eXe con `figcaption` y campos `author`, `title` con URL de origen y `license` con enlace).
Tambien aplica una validacion didactica minima para evitar entregables construidos como un unico iDevice.
Si detecta una sola pagina, lo trata como recomendacion pedagogica (aviso), no como rechazo tecnico.

### Trabajo por fases (preferente, no absoluto)

La IA debe preferir este metodo para materiales medianos o largos:

1. fase de esqueleto: proponer e implementar indice inicial (paginas + iDevices base)
2. validar estructura tecnica minima
3. mostrar al usuario ese indice antes de pasar a la fase de contenido
4. fase de relleno incremental: completar por partes (pagina a pagina o bloque a bloque), no todo de golpe
5. validar al final de cada bloque importante y en la entrega final

### Validacion pedagogica REA (obligatoria para entrega docente)

Despues de la validacion tecnica, la IA debe revisar el material con:

- `checklist_rea_calidad.md`

Esta lista amplia la validacion didactica minima y cubre:

- portada y motivacion
- metodologia activa
- calidad y variedad de contenidos
- tareas, evaluacion y guia didactica
- accesibilidad, inclusion y licencias

### Ampliar un proyecto con mas iDevices

Ver los iDevices disponibles en el clon local de eXe:

```bash
./scripts/add-idevice-assets.sh list
```

Ver los perfiles predefinidos:

```bash
./scripts/add-idevice-assets.sh list-presets
```

Añadir recursos de varios iDevices a un proyecto ya creado o descomprimido:

```bash
./scripts/add-idevice-assets.sh add ./material_editable guess crossword word-search
```

Añadir un conjunto amplio de iDevices con un solo comando:

```bash
./scripts/add-idevice-assets.sh add-preset ./material_editable juegos aula
```

Esto copia las carpetas de exportacion a `idevices/<tipo>/`, listas para que la IA use esos iDevices en `content.xml` e `index.html`.

Perfiles disponibles:

- `juegos`: actividades y juegos interactivos
- `aula`: bloques frecuentes para materiales didacticos generales
- `evaluacion`: iDevices centrados en comprobacion y rubricas
- `medios`: iDevices centrados en recursos visuales y multimedia
- `all`: todos los iDevices disponibles en el clon local de eXe

## Plantilla base

La plantilla reutilizable esta en:

- `plantillas/plantilla_base_minima/`
- `plantillas/plantilla_base_minima.elpx`
- `plantillas/plantilla_avanzada_aula/`
- `plantillas/plantilla_avanzada_aula.elpx`
- `plantillas/plantilla_todos_idevices/`
- `plantillas/plantilla_todos_idevices.elpx`

La plantilla avanzada deja ya preparados los recursos de:

- `text`
- `guess`
- `crossword`
- `word-search`
- `az-quiz-game`
- `trivial`
- `interactive-video`

La plantilla total deja preparados los recursos de todos los iDevices disponibles en el clon local de eXe.

## Catalogo completo de iDevices

El inventario generado automaticamente esta en:

- `catalogo_idevices.md`
- `catalogo_idevices.json`

Se puede regenerar con:

```bash
./scripts/generate-idevice-catalog.sh
```

## Resincronizar tras actualizar eXe

Cuando cambie el clon local de eXe, el flujo recomendado es:

```bash
./scripts/sync-with-exe.sh
```

Ese script:

- regenera `catalogo_idevices.md` y `catalogo_idevices.json`
- regenera `catalogo_componentes_ode.md` y `referencias/ode_components/`
- valida las carpetas fuente de `plantillas/`
- valida los `.elpx` de referencia
- resume cuantas referencias ODE quedan como `curated`, `real` o `generated`

Si el repo de eXe esta en otra ruta:

```bash
EXE_REPO_DIR=/ruta/al/repo ./scripts/sync-with-exe.sh
```

## Referencias ODE por iDevice

Este paso es la base para que la IA aprenda a insertar iDevices en `content.xml`.

Se generan:

- `catalogo_componentes_ode.md`
- `referencias/ode_components/`

Con:

```bash
./scripts/generate-ode-component-examples.sh
```

Cuando existe un ejemplo real en los fixtures de eXe, se extrae un `odeComponent` completo para ese iDevice.

Ademas:

- si existe una referencia afinada en el propio kit, queda marcada como `curated` y tiene prioridad
- si existe ejemplo real, el snippet queda marcado como `real`
- si no existe, se genera un esqueleto minimo a partir de `config.xml` y queda marcado como `generated`

La prioridad correcta para la IA es:

- `curated`
- `real`
- `generated`

En el estado actual de este repo, el catalogo generado ya cubre todos los iDevices detectados con referencias `curated` o `real`, sin entradas `generated`.

Documentos clave:

- `catalogo_componentes_ode.md`
- `guia_componentes_ode_por_idevice.md`
- `referencias/ode_components/`
- `checklist_validacion_elpx.md`
- `checklist_rea_calidad.md`

## Generar un `odeComponent` listo para insertar

Para convertir una referencia en un bloque usable:

```bash
./scripts/instantiate-ode-component.sh text
./scripts/instantiate-ode-component.sh crossword ./tmp/crossword.xml
```

El script sustituye automaticamente:

- `__PAGE_ID__`
- `__BLOCK_ID__`
- `__IDEVICE_ID__`
- `__EVALUATION_ID__`
- `__DATA_GAME__`

Si necesitas fijar valores concretos:

```bash
PAGE_ID=20260101010101PAGE01 \
BLOCK_ID=20260101010101BLK001 \
IDEVICE_ID=20260101010101IDEV01 \
EVALUATION_ID=20260101010101EVAL01 \
DATA_GAME='{\"mode\":\"study\"}' \
./scripts/instantiate-ode-component.sh periodic-table ./tmp/periodic-table.xml
```

## Insertar el bloque en un proyecto

Para anadir un iDevice ya preparado dentro de un proyecto:

```bash
./scripts/insert-ode-component.sh ./mi_proyecto periodic-table
./scripts/insert-ode-component.sh ./material_editable crossword
```

Si el proyecto tiene varias paginas, hay que indicar la pagina destino:

```bash
./scripts/insert-ode-component.sh --page-title "Ponte a prueba" ./material_editable guess
./scripts/insert-ode-component.sh --page-id page-mm8ub2df-uddvjkrkr ./material_editable guess
```

El script:

- genera el `odeComponent`
- anade un nuevo `odePagStructure` a la `odeNavStructure` correcta dentro de `content.xml`
- localiza el HTML real de la pagina destino (`index.html` o `html/*.html`)
- anade un nuevo `<article>` en esa pagina
- inserta las referencias JS/CSS del iDevice si faltan

Requisito:

- antes deben existir los assets del iDevice en `idevices/<tipo>/`
- si hacen falta, anadelos antes con `./scripts/add-idevice-assets.sh add ...`

Nota importante:

- si el proyecto tiene varias paginas y no se indica `--page-id` o `--page-title`, el script falla por seguridad para evitar insertar el bloque en la pagina equivocada

## Politica de tema

- Si se parte de un `.elpx` existente, se conserva su tema.
- Si se crea desde cero, el tema por defecto es `base`.
