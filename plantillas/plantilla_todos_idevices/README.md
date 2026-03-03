# Plantilla ELPX Total

Esta carpeta es la plantilla fuente con cobertura maxima de iDevices.

## Alcance

- tema `base`
- una pagina inicial minima
- recursos preinstalados para todos los iDevices disponibles en el clon local de eXe en el momento de generarla

## Uso recomendado

Es la mejor opcion cuando la IA debe poder insertar cualquier iDevice sin tener que preparar antes los assets.

Flujo:

1. Crear un proyecto con `./scripts/elpx-tool.sh create ...`
2. O partir directamente de `plantilla_todos_idevices.elpx`
3. Editar `content.xml` e `index.html`
4. Validar con `./scripts/validate-elpx.sh`

## Regla operativa para formulas

Si la IA escribe formulas matematicas directamente en el contenido:

- usar `\(...\)` para formulas en linea
- usar `\[...\]` para formulas en bloque
- no usar `$...$` ni `$$...$$`
- no envolver las formulas en HTML especial
- no meter formulas en `<code>`, `<pre>` o `<textarea>`

Esta regla es necesaria para que eXe detecte el patron y renderice la formula con MathJax.

## Nota

- Esta carpeta hereda los marcadores internos de la plantilla base para que pueda servir como plantilla fuente.
- El archivo listo para importar es `plantilla_todos_idevices.elpx`.
