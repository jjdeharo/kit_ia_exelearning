# Mapa de Recursos para Generación de `.elpx` (eXe 4+)

Este documento indica de dónde debe obtener la IA los recursos necesarios para construir un `.elpx` funcional y qué nivel de obligatoriedad tiene cada bloque.

## Regla de versionado

No uses este mapa contra una rama flotante sin control. Para automatizar con garantías:

1. Usa el **mismo tag, commit o release** del repo de eXe que corresponda al objetivo.
2. Si trabajas desde GitHub, fija SHA o tag.
3. Si trabajas desde un clon local, documenta la revisión exacta.

Si no se fija versión, la automatización puede romperse cuando cambie el exportador.

## 1. Fuentes de recursos

### A. Librerías generales

Salen de dos sitios:

- `public/libs/`
- `public/app/common/`

### B. iDevices exportables

Salen de:

- `public/files/perm/idevices/base/<tipo>/export/`

### C. Temas

Salen de:

- `public/files/perm/themes/base/<tema>/`

### D. CSS base del contenido

Sale de:

- `public/style/workarea/base.css`

Su destino en el `.elpx` es:

- `content/css/base.css`

## 2. Librerías base habituales

Estas son las más comunes en un `.elpx` exportado moderno:

| Recurso | Origen | Destino |
| :--- | :--- | :--- |
| jQuery | `public/libs/jquery/jquery.min.js` | `libs/jquery/jquery.min.js` |
| Bootstrap JS | `public/libs/bootstrap/bootstrap.bundle.min.js` | `libs/bootstrap/bootstrap.bundle.min.js` |
| Bootstrap CSS | `public/libs/bootstrap/bootstrap.min.css` | `libs/bootstrap/bootstrap.min.css` |
| Common JS | `public/app/common/common.js` | `libs/common.js` |
| Export runtime | `public/app/common/exe_export.js` | `libs/exe_export.js` |
| Favicon | `public/favicon.ico` | `libs/favicon.ico` |
| CSS base | `public/style/workarea/base.css` | `content/css/base.css` |

Notas:

- `libs/common_i18n.js` no debe considerarse un archivo estático universal: depende del idioma y conviene generarlo o copiarlo desde una exportación de la misma versión.
- Los `.map` de Bootstrap son opcionales para funcionamiento, pero pueden copiarse si se quiere imitar el export oficial.

## 3. Librerías condicionales

La IA debe incluirlas solo cuando el contenido las necesite.

| Recurso | Origen base | Destino |
| :--- | :--- | :--- |
| Accesibilidad | `public/app/common/exe_atools/` o `public/libs/exe_atools/` según la revisión | `libs/exe_atools/` |
| Descarga `.elpx` desde HTML | `public/libs/fflate/` | `libs/fflate/` |
| Descarga `.elpx` desde HTML | `public/libs/exe_elpx_download/` | `libs/exe_elpx_download/` |
| Tooltips, lightbox, effects, etc. | `public/app/common/<lib>/` o `public/libs/<lib>/` | `libs/<lib>/` |

Regla:

- No adivinar estas librerías a mano si puedes evitarlo.
- Mejor detectarlas a partir del contenido o reutilizarlas desde una plantilla ya exportada.

## 4. Motores de iDevices

Para cada iDevice usado, copiar **la carpeta `export` completa**, no solo el `.js`.

| iDevice | Origen | Destino |
| :--- | :--- | :--- |
| Rosco | `public/files/perm/idevices/base/az-quiz-game/export/` | `idevices/az-quiz-game/` |
| Sopa de letras | `public/files/perm/idevices/base/word-search/export/` | `idevices/word-search/` |
| Crucigrama | `public/files/perm/idevices/base/crossword/export/` | `idevices/crossword/` |
| Trivial | `public/files/perm/idevices/base/trivial/export/` | `idevices/trivial/` |
| Adivina | `public/files/perm/idevices/base/guess/export/` | `idevices/guess/` |
| Vídeo interactivo | `public/files/perm/idevices/base/interactive-video/export/` | `idevices/interactive-video/` |
| Texto | `public/files/perm/idevices/base/text/export/` | `idevices/text/` |

También se deben filtrar:

- `*.test.js`
- `*.spec.js`

## 5. Temas

Para el tema elegido, copiar la carpeta completa:

| Tema | Origen | Destino |
| :--- | :--- | :--- |
| Base | `public/files/perm/themes/base/base/` | `theme/` |
| Intef | `public/files/perm/themes/base/intef/` | `theme/` |
| Cualquier otro tema disponible | `public/files/perm/themes/base/<tema>/` | `theme/` |

No copies solo `style.css`. Un tema real puede necesitar:

- `style.css`
- `style.js`
- `config.xml`
- `icons/`
- `img/`
- `fonts/`

## 5.1 Política de selección de tema

La IA debe seguir esta prioridad:

1. Heredar el tema del `.elpx` modelo o plantilla.
2. Si no hay modelo y el usuario no indica nada, usar `base`.
3. Si el usuario pide un tema concreto, usarlo solo si existe en la revisión objetivo.

Tema por defecto recomendado:

- `base`

Regla práctica:

- No uses nombres de temas antiguos o ausentes como predeterminado.
- Antes de fijar un tema distinto de `base`, comprueba que su carpeta existe en `public/files/perm/themes/base/<tema>/`.

## 6. Recursos del proyecto

Los archivos propios del material deben ir en:

```text
content/resources/
```

Ejemplos:

- imágenes subidas por el usuario
- audios
- PDFs
- recursos de actividades

Regla práctica:

- Si partes de un modelo, conserva la convención de rutas ya usada en ese modelo.
- Si generas desde cero, no coloques los recursos en `resources/` en raíz.

## 7. Cabecera HTML mínima realista

Una página exportada moderna suele necesitar algo cercano a esto:

```html
<head>
  <meta charset="utf-8" />
  <script src="libs/jquery/jquery.min.js"></script>
  <script src="libs/common_i18n.js"></script>
  <script src="libs/common.js"></script>
  <script src="libs/exe_export.js"></script>
  <script src="libs/bootstrap/bootstrap.bundle.min.js"></script>
  <link rel="stylesheet" href="libs/bootstrap/bootstrap.min.css" />
  <link rel="stylesheet" href="content/css/base.css" />
  <script src="theme/style.js"></script>
  <link rel="stylesheet" href="theme/style.css" />
  <link rel="icon" href="libs/favicon.ico" />
</head>
```

Además:

- Cada iDevice añade sus propios `<script>` y `<link>` a `idevices/<tipo>/`.
- Algunas páginas necesitarán librerías adicionales según el contenido.

## 8. Recomendación fuerte

Si la IA trabaja desde GitHub y necesita máxima robustez:

1. Clonar o consultar el repo de eXe en la revisión objetivo.
2. Exportar un `.elpx` mínimo con esa versión.
3. Usar ese `.elpx` como plantilla estructural.
4. Reemplazar solo contenido, assets y páginas.

Esto es más fiable que reconstruir el árbol completo a mano.
