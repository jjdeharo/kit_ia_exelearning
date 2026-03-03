# Plantilla ELPX Base Minima

Esta carpeta es la plantilla fuente que usa el script para generar proyectos `.elpx` con:

- tema `base`
- una sola pagina
- un iDevice de texto

## Uso recomendado

1. Ejecutar `../../scripts/elpx-tool.sh create ...` desde la raiz del repo.
2. Sustituir `content.xml`.
3. Sustituir `index.html`.
4. Mantener `libs/`, `theme/`, `idevices/` y `content/css/` salvo que cambie la version objetivo de eXe.
5. Anadir archivos propios del material en `content/resources/`.
6. Volver a comprimir el contenido como `.elpx`.

Nota:

- Esta carpeta contiene marcadores internos para que el script pueda reemplazar IDs y titulo.
- Si quieres una plantilla ya empaquetada y lista para importar, usa `plantilla_base_minima.elpx`.

## Politica de tema

- Esta plantilla fija `theme = base`.
- Si se usa como modelo, la IA debe heredar ese tema salvo instruccion contraria del usuario.
