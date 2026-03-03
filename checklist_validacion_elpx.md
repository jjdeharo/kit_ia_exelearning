# Checklist de Validación de un `.elpx` generado por IA

Este checklist define el mínimo exigible antes de considerar válido un `.elpx` para eXe 4 o superior.

## 1. Validación estructural del ZIP

Comprobar que el paquete contiene, como mínimo:

- `content.xml`
- `content.dtd`
- `index.html`
- `content/css/base.css`
- `libs/`
- `theme/`
- `idevices/`

Si el proyecto tiene más de una página:

- Debe existir `html/` con sus páginas hijas.

Si hay recursos del usuario:

- Debe existir `content/resources/`.

## 2. Validación de coherencia de archivos

Comprobar que:

- Todo `<script src="...">` apunta a un archivo existente.
- Todo `<link rel="stylesheet" href="...">` apunta a un archivo existente.
- Toda referencia a imágenes, audio o PDFs usados por el contenido existe realmente en el ZIP.
- En `index.html` y `html/*.html`, no quedan placeholders `{{context_path}}` sin resolver.
- Cada `odeIdeviceTypeName` usado en `content.xml` tiene su carpeta correspondiente en `idevices/` si ese iDevice exporta recursos.

## 3. Validación de `content.xml`

Comprobar que:

- El XML es parseable.
- La raíz es `ode`.
- Existe `odeNavStructures`.
- Cada página contiene sus bloques.
- Cada bloque contiene sus componentes.
- Cada `odeComponent` incluye `odeIdeviceTypeName`.
- `htmlView` y `jsonProperties` existen, aunque alguno esté vacío.
- En iDevices `text`, `htmlView` y `jsonProperties.textTextarea` deben estar sincronizados en contenido real (no resumen en uno y contenido completo en otro).
- En iDevices `text`, `jsonProperties.textTextarea` debe contener HTML (no texto plano) para que el editor preserve formato.
- Si hay imágenes en `htmlView`, las mismas rutas `<img src>` deben estar también en `textTextarea`.
- En iDevices `text`, evitar `SVG` en imágenes del editor; usar `PNG/JPG/WebP` para compatibilidad.
- En iDevices `text`, las imágenes de `textTextarea` deben usar `{{context_path}}/<carpeta>/<archivo>` (no `content/resources/...` directo).
- Si hay imágenes de terceros, deben ir en `figure` con `figcaption` y contener autor, URL de origen y licencia con enlace (`rel="license"`).

Regla práctica:

- Si `jsonProperties` contiene JSON, debe poder parsearse tras extraer su texto.
- Si el iDevice es `text`, discrepancias entre `htmlView` y `textTextarea` se consideran error de consistencia de edición.
- Si el iDevice es `text` y `textTextarea` no contiene etiquetas HTML, se considera error.
- Si el iDevice es `text` y faltan imágenes en `textTextarea` que sí existen en `htmlView`, se considera error.
- Si el iDevice es `text` y usa `SVG` en `textTextarea`, se considera riesgo de no visualización en editor.
- Si el iDevice es `text` y usa `content/resources/...` en `textTextarea`, se considera riesgo de no visualización en editor.
- Si hay imágenes sin bloque de atribución eXe (`figcaption` con `author`, `title`, `license`), se considera error de calidad REA.

## 4. Validación visual mínima

Descomprimir y abrir `index.html`.

Comprobar que:

- La página principal carga.
- El CSS del tema se aplica.
- Los iDevices se ven.
- No faltan iconos ni estilos.
- La navegación entre páginas funciona.

Si hay juegos:

- Deben responder, no solo mostrarse.

## 5. Validación didáctica mínima (producto docente útil)

Comprobar que:

- El proyecto no se reduce a un único iDevice.
- Hay estructura por páginas didácticas y cada página tiene al menos un bloque con contenido.
- Si hay varias páginas, la secuencia didáctica está bien distribuida entre ellas.
- Si hay una sola página, está justificado didácticamente y no se reduce a contenido mínimo.
- Existe una página de créditos/licencias/fuentes.
- El material incluye objetivos, desarrollo y actividades/repaso.
- El texto está redactado para uso real de profesorado y alumnado (no esquema superficial).
- La secuencia temporal es viable para el tiempo de clase objetivo.

Nota editorial REA:

- La comprobación de la página de créditos/licencias se valida por revisión humana del contenido, no por detección automática del idioma del título.

## 6. Validación de reimportación

El paquete debe poder reimportarse en eXe sin errores graves.

Comprobar que:

- Las páginas aparecen.
- Los bloques aparecen.
- Los iDevices conservan su contenido.
- Los juegos siguen editables.

## 7. Criterio de rechazo

El `.elpx` debe rechazarse si:

- Falta `content.xml`.
- Falta un recurso cargado por HTML.
- El HTML abre pero los iDevices no inicializan.
- El paquete se ve, pero no se reimporta.
- El contenido se reimporta, pero se ha perdido el estado editable del iDevice.
- El editor de eXe muestra menos contenido que la vista previa por desincronización `htmlView`/`jsonProperties`.
- El editor de eXe muestra el contenido sin formato por `textTextarea` en texto plano.
- El proyecto entregable está construido como un único iDevice sin estructura docente por páginas.
- El proyecto no incluye página de créditos/licencias/fuentes.

## 8. Estrategia de recuperación

Si falla alguna comprobación:

1. Volver a una plantilla `.elpx` válida de la misma versión.
2. Reaplicar solo los cambios de contenido.
3. Mantener `libs/`, `theme/` e `idevices/` del modelo.
4. Revalidar.
