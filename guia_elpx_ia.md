# Guía Técnica: Generación de Archivos `.elpx` mediante IA (eXe 4+)

## Objetivo real

Un archivo `.elpx` moderno es un ZIP que combina:

- Un **export HTML autónomo** que puede abrirse localmente con `index.html`.
- Un **proyecto reimportable** gracias a `content.xml` (y, en los formatos modernos, `content.dtd`).

La IA no debe tratarlo como "un XML con algunos recursos", sino como un **sitio exportado completo** más un **modelo ODE** reutilizable.

## Preflight de entorno (paso 0)

Antes de ejecutar el flujo tecnico, la IA debe verificar dependencias del sistema:

```bash
./scripts/preflight-kit.sh
```

Si faltan herramientas y el entorno lo permite, puede intentar:

```bash
./scripts/preflight-kit.sh --install
```

Si no puede instalar, debe detener el flujo y reportar al usuario:

- comandos faltantes
- impacto concreto en el proceso (crear, empaquetar, validar, etc.)
- accion manual recomendada por sistema operativo

## Principio clave

Para eXe 4 o superior, la estrategia más fiable no es "inventar un `.elpx` desde cero", sino:

1. Partir de una **plantilla `.elpx` vacía o mínima** exportada por la **misma versión de eXe** objetivo.
2. Sustituir o regenerar contenido, páginas y recursos.
3. Validar el resultado reimportándolo o comparándolo con una exportación real.

Esto es importante porque la estructura interna y algunos metadatos pueden cambiar entre versiones.

## Política de tema por defecto

La IA debe aplicar esta política, sin ambigüedades:

1. Si parte de un `.elpx` modelo o plantilla, debe **heredar el tema de esa plantilla**.
2. Si no hay plantilla y el usuario no especifica un tema, debe usar **`base`** por defecto.
3. Solo debe usar otro tema si:
   - el usuario lo pide explícitamente, o
   - existe una plantilla válida que ya lo use.

Tema predeterminado recomendado:

- `base`

Motivo:

- Es la opción más estable para compatibilidad.
- Evita depender de temas que pueden no existir en otra revisión del repo.
- Reduce diferencias visuales inesperadas entre versiones.

## Estructura mínima operativa

La estructura real de un `.elpx` funcional en eXe 4+ debe contemplar, como mínimo:

```text
/
├── content.xml
├── content.dtd
├── index.html
├── html/
├── content/
│   ├── css/
│   │   └── base.css
│   ├── img/
│   │   └── exe_powered_logo.png        (habitual; puede faltar si no se usa)
│   └── resources/                      (archivos del proyecto)
├── libs/
├── idevices/
└── theme/
```

Además, pueden aparecer:

- `search_index.js` si el proyecto activa buscador.
- `libs/elpx-manifest.js` si se usa el iDevice de descarga del propio `.elpx`.

## Qué NO debe asumirse

- `metadata.json` **no es un requisito del `.elpx` exportado**.
- `resources/` en raíz **no es la ruta correcta** para assets de proyecto en el export HTML moderno.
- No basta con copiar solo `jQuery`, `common.js` y un `.js` del juego.

## Librerías y recursos

### Librerías base habituales

La IA debe esperar y, si genera el paquete manualmente, incluir estas piezas:

- `libs/jquery/jquery.min.js`
- `libs/bootstrap/bootstrap.bundle.min.js`
- `libs/bootstrap/bootstrap.min.css`
- `libs/common.js`
- `libs/common_i18n.js`
- `libs/exe_export.js`
- `libs/favicon.ico`

Notas:

- `common_i18n.js` depende del idioma del proyecto y conviene **generarlo o copiarlo desde una exportación equivalente**.
- Los `.map` de Bootstrap no son imprescindibles para funcionar, pero sí son habituales en exportaciones reales.

### Librerías condicionales

Se incluyen solo si el contenido las necesita:

- `libs/exe_atools/` si se activa la barra de accesibilidad.
- Otras librerías detectadas por el contenido (`exe_lightbox`, `exe_tooltips`, `exe_effects`, `mermaid`, etc.).
- `libs/fflate/fflate.umd.js` y `libs/exe_elpx_download/exe_elpx_download.js` si hay descarga del paquete fuente desde la web exportada.

### Motores de iDevice

Cada iDevice usado en el proyecto debe tener su carpeta en:

```text
idevices/<tipo-normalizado>/
```

Ejemplos:

- `idevices/text/`
- `idevices/guess/`
- `idevices/interactive-video/`
- `idevices/az-quiz-game/`

No basta con copiar un único `.js`: hay iDevices que necesitan también `.css`, imágenes, SVG, GIF o HTML auxiliares.

### Tema

El tema exportado debe ir en:

```text
theme/
```

Y normalmente contiene:

- `theme/style.css`
- `theme/style.js`
- `theme/config.xml`
- imágenes, iconos y fuentes del tema

## Flujo recomendado: desde plantilla

Este es el flujo recomendado para que la IA sea realmente fiable:

1. Crear o usar una **plantilla mínima exportada por la misma versión de eXe**.
2. Mantener intactas las carpetas `libs/`, `theme/`, `idevices/` y la base de `content/`.
3. Regenerar:
   - `content.xml`
   - `index.html`
   - `html/*.html`
   - `content/resources/*`
4. Ajustar referencias internas a recursos.
5. Validar.
6. Revisar calidad pedagogica REA con `checklist_rea_calidad.md`.

### Ventajas

- Reduce roturas por cambios internos de eXe.
- Conserva librerías exactas de la versión objetivo.
- Evita tener que reconstruir manualmente dependencias condicionales.

## Flujo alternativo: desde cero

Solo debe usarse si no hay plantilla disponible.

En ese caso, la IA debe:

1. Generar `content.xml` válido.
2. Incluir `content.dtd`.
3. Renderizar `index.html` y páginas hijas en `html/`.
4. Añadir `content/css/base.css`.
5. Incluir todos los recursos de `theme/`, `libs/` e `idevices/` necesarios.
6. Copiar los assets del proyecto a `content/resources/`.
7. Verificar que todos los enlaces locales resuelven.

## Reglas para `content.xml`

### Formato general

- Debe existir una raíz `ode`.
- Debe incluir `userPreferences`, `odeResources`, `odeProperties` y `odeNavStructures`.
- Cada página se representa como `odeNavStructure`.
- Cada bloque dentro de la página se representa como `odePagStructure`.
- Cada iDevice se representa como `odeComponent`.

### Reglas prácticas

- `htmlView` debe contener el HTML ya renderizado del iDevice.
- `jsonProperties` debe contener el estado editable del iDevice.
- En formatos modernos conviene usar **CDATA** en `htmlView` y `jsonProperties` cuando el contenido contiene HTML o JSON complejo.
- `odeIdeviceTypeName` debe coincidir con el tipo usado por el iDevice exportado (`text`, `guess`, `interactive-video`, etc.).

### Regla obligatoria de renderizado LaTeX con MathJax

Para que eXeLearning renderice fórmulas matemáticas escritas directamente por la IA dentro del contenido:

- La IA debe escribir el LaTeX como **texto normal dentro del contenido del iDevice**.
- Debe usar exclusivamente estos delimitadores:
  - `\(...\)` para fórmulas en línea.
  - `\[...\]` para fórmulas en bloque.
- No debe usar `$...$` ni `$$...$$`, aunque otros motores los admitan.
- No debe envolver las fórmulas en HTML especial (`<span>`, `<math>`, `<script>`, etc.).
- No debe dejar fórmulas sin delimitadores, porque eXe no lanzará el renderizado correctamente.
- No debe partir los delimitadores ni el contenido matemático con etiquetas HTML intermedias.
- No debe colocar fórmulas dentro de bloques de código o zonas literales (`<code>`, `<pre>`, `<textarea>`), porque eso puede impedir su procesado.

Regla operativa para la IA:

- Si la fórmula va integrada en una frase, usar `\(...\)`.
- Si la fórmula debe mostrarse destacada en una línea aparte, usar `\[...\]`.

Ejemplos válidos:

- `La aceleración es \(a=\frac{\Delta v}{\Delta t}\).`
- `\[\frac{-b\pm\sqrt{b^2-4ac}}{2a}\]`

Ejemplos no válidos:

- `$a=\frac{\Delta v}{\Delta t}$`
- `$$\frac{-b\pm\sqrt{b^2-4ac}}{2a}$$`
- `<code>\(x^2\)</code>`
- `x^2+1`

### Regla obligatoria de sincronización (iDevice `text`)

Para evitar discrepancias entre el editor de eXe y la vista previa/exportación:

- En iDevices `text`, el contenido semántico de `htmlView` y `jsonProperties.textTextarea` debe ser el mismo.
- No está permitido dejar en `textTextarea` un resumen corto mientras `htmlView` contiene el desarrollo completo.
- `textTextarea` debe conservar HTML rico (párrafos, encabezados, listas, imágenes, etc. cuando aplique); no se admite convertirlo a texto plano.
- Si `htmlView` contiene imágenes (`<img src="...">`), esas mismas rutas deben existir también en `textTextarea`.
- Para maximizar compatibilidad del editor de eXe, en iDevices `text` usar imágenes raster (`.png`, `.jpg`, `.webp`) en lugar de `.svg`.
- En `textTextarea` de iDevices `text`, usar rutas de imagen tipo `{{context_path}}/<carpeta>/<archivo>` y guardar los ficheros en `content/resources/<carpeta>/<archivo>`.
- Si se edita uno, se debe regenerar el otro en el mismo cambio.

Consecuencia práctica:

- Si no están sincronizados, el paquete debe considerarse inválido para uso docente, aunque renderice en `index.html`.
- Si `textTextarea` queda en texto plano, el paquete debe considerarse inválido para edición en eXe aunque la vista previa se vea bien.

Regla de fidelidad de exportacion (clave):

- En `content.xml`, mantener `{{context_path}}/...` en iDevices `text`.
- En HTML exportado (`index.html` y `html/*.html`), no dejar `{{context_path}}`: resolver a rutas reales `content/resources/...` o `../content/resources/...` segun profundidad.

### Regla obligatoria de estructura docente (producto util)

Para materiales destinados a docencia real (profesorado + alumnado), no se admite un proyecto de iDevice único.

- El proyecto debe tener una estructura por paginas didacticas.
- La estructura multipagina es preferente para materiales amplios, pero no obligatoria en todos los casos.
- Si el docente lo decide, se admite una sola pagina siempre que el contenido no quede reducido a un unico iDevice.
- Cada pagina debe contener uno o mas iDevices.
- El proyecto completo debe incluir al menos 2 iDevices en total.
- Debe incluir siempre una pagina especifica de creditos/licencias/fuentes.
- Recomendacion fuerte: separar en varias paginas (introduccion, desarrollo, actividades, repaso/evaluacion).

Ademas del formato tecnico, el contenido debe tener profundidad didactica:

- Objetivos de aprendizaje explicitos.
- Temporalizacion realista de sesion(es).
- Desarrollo conceptual con explicaciones completas, no texto telegráfico.
- Actividades y propuesta de evaluacion o repaso.
- Material util tanto para explicar en clase como para estudio autonomo.

## Como escribir un REA (Recurso Educativo Abierto)

La IA debe redactar el contenido como REA completo, no como borrador tecnico.

### Flujo por fases (preferente)

Este modo de trabajo no es absoluto, pero debe ser la opcion por defecto en la mayoria de encargos:

1. Definir fase 1 (esqueleto): indice inicial, paginas y iDevices base.
2. Materializar ese esqueleto en `content.xml` + `index.html`/`html/*.html`.
3. Validar estructura tecnica minima.
4. Presentar al usuario el indice inicial antes de iniciar la fase 2.
5. Ejecutar fase 2 de forma incremental: completar por partes (secciones/paginas), no todo de golpe.
6. Revalidar tras cada bloque relevante y al cierre final.

### Validacion final REA en el flujo

La comprobacion REA debe ejecutarse siempre al final, despues de la validacion tecnica (`validate-elpx.sh` + `checklist_validacion_elpx.md`).

Referencia obligatoria:

- `checklist_rea_calidad.md`

### Estructura minima de un REA

- Portada o introduccion con titulo, nivel, materia y contexto de uso.
- Desarrollo por temas (preferentemente en varias paginas).
- Actividades de aplicacion y seccion de repaso/evaluacion.
- Pagina dedicada a creditos, fuentes y licencias de recursos usados.

### Criterios de redaccion

- Lenguaje claro y academico adecuado al nivel educativo objetivo.
- Explicaciones completas: conceptos, relaciones causales y ejemplos.
- Instrucciones accionables para el profesorado (temporalizacion, dinamica de aula, evaluacion).
- Material de estudio util para alumnado (resumenes, preguntas, pautas de repaso).

### Criterios de apertura (OER)

- Identificar y mostrar la licencia del propio recurso educativo.
- Incluir atribuciones de terceros (autor, fuente, licencia, enlace).
- Evitar contenidos sin permiso de reutilizacion.
- Facilitar reutilizacion y adaptacion por otros docentes.

### Formato eXe para atribucion de imagenes

Cuando una imagen sea de terceros, la IA debe usar el formato de eXe con `figure` + `figcaption`.

Campos obligatorios en la atribucion:

- Autor (si es conocido; si no, indicar claramente `Autor desconocido`).
- URL de origen.
- Licencia y enlace de licencia.

Patron recomendado:

```html
<figure class="exe-figure exe-image position-center license-CC-BY-SA" style="width: 640px;">
  <img src="{{context_path}}/ID_ASSET/imagen.png" alt="Descripcion" width="640" height="360" />
  <figcaption class="figcaption">
    <span class="author">Nombre del autor</span>.
    <a href="https://origen.example/recurso" target="_blank" class="title" rel="noopener"><em>Titulo del recurso</em></a>
    <span class="license"><span class="sep">(</span><a href="https://creativecommons.org/licenses/by-sa/4.0/" rel="license nofollow noopener" target="_blank" title="Creative Commons BY-SA 4.0">CC BY-SA 4.0</a><span class="sep">)</span></span>
  </figcaption>
</figure>
```

### Criterios tecnicos para eXe

- La informacion de creditos/licencias debe estar en una pagina propia del proyecto.
- No depender del idioma del titulo de esa pagina para su existencia: debe ser una decision de diseno instruccional, no de deteccion automatica.

### Importante sobre metadatos variables

Algunos metadatos han cambiado entre implementaciones y fixtures:

- En unas versiones aparecen claves como `eXeVersion`.
- En otras aparece `exe_version`.

Por tanto:

- **No hardcodees una sola variante** como verdad universal.
- Si trabajas desde plantilla o modelo, **conserva la forma exacta** usada por esa versión.
- Si trabajas desde el código del repo de eXe, usa como referencia el exportador de esa revisión concreta.

## Regla de compatibilidad

Para eXe 4+, la IA debe seguir esta prioridad:

1. **Primero**: reutilizar un `.elpx` modelo del mismo eXe.
2. **Segundo**: reutilizar una exportación de prueba del mismo tipo de iDevices.
3. **Tercero**: construir desde cero solo si puede validar el resultado.

## Requisito mínimo para considerar el paquete "funcional"

Un `.elpx` solo debe darse por bueno si cumple las tres condiciones:

1. Al descomprimirlo, `index.html` carga sin errores por falta de archivos locales.
2. El contenido visible coincide con lo esperado.
3. eXe puede reimportarlo a partir de `content.xml`.

## Conclusión operativa

La IA debe tratar el `.elpx` como un **artefacto versionado de exportación**, no como un formato fijo e inmutable. Para que el proceso sea robusto con eXe 4 o superiores, la plantilla de la misma versión y la validación final son obligatorias en la práctica.
