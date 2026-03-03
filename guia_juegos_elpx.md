# Guía de iDevices de Juegos para IA (eXe 4+)

## Alcance

Esta guía describe los iDevices de juego más comunes y cómo integrarlos en un `.elpx`.

## Regla crítica

Los JSON de esta guía son **orientativos**. Para automatización robusta:

1. Toma siempre como referencia un `jsonProperties` real exportado por la **misma versión de eXe**.
2. Conserva claves que no entiendas si proceden de un modelo válido.
3. No asumas que un esquema simplificado seguirá siendo válido en futuras revisiones.

Un iDevice funcional necesita siempre las dos capas:

- `htmlView`: HTML ya renderizado.
- `jsonProperties`: estado editable.

Y además sus recursos en:

- `idevices/<tipo>/`

## Inserción correcta en `content.xml`

El patrón correcto es:

```xml
<odeComponent>
  <odePageId>...</odePageId>
  <odeBlockId>...</odeBlockId>
  <odeIdeviceId>...</odeIdeviceId>
  <odeIdeviceTypeName>az-quiz-game</odeIdeviceTypeName>
  <htmlView><![CDATA[...HTML renderizado del juego...]]></htmlView>
  <jsonProperties><![CDATA[{ ... JSON ... }]]></jsonProperties>
  <odeComponentsOrder>1</odeComponentsOrder>
  <odeComponentsProperties>
    <odeComponentsProperty>
      <key>visibility</key>
      <value>true</value>
    </odeComponentsProperty>
  </odeComponentsProperties>
</odeComponent>
```

### Consecuencias prácticas

- Si solo rellenas `jsonProperties`, el juego puede seguir sin mostrarse bien.
- Si solo rellenas `htmlView`, el proyecto puede verse pero perder editabilidad.
- Si falta `idevices/<tipo>/`, el HTML puede cargarse sin comportamiento o con errores.

## 1. Rosco (A-Z Quiz)

**Tipo:** `az-quiz-game`

### JSON orientativo

```json
{
  "typeGame": "Rosco",
  "instructions": "<p>Instrucciones del juego...</p>",
  "wordsGame": [
    {
      "letter": "A",
      "word": "ALGORITMO",
      "definition": "Conjunto ordenado de operaciones...",
      "type": 0,
      "url": "",
      "audio": ""
    }
  ],
  "durationGame": 240,
  "showSolution": true,
  "timeShowSolution": 3,
  "numberTurns": 1,
  "caseSensitive": false,
  "letters": "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"
}
```

Nota:

- `type: 0` suele equivaler a "empieza por".
- `type: 1` suele equivaler a "contiene".

## 2. Sopa de Letras

**Tipo:** `word-search`

### JSON orientativo

```json
{
  "typeGame": "Sopa",
  "instructions": "Encuentra las palabras ocultas.",
  "wordsGame": [
    {"word": "EXELEARNING", "definition": "Herramienta de autor"},
    {"word": "CODIGO", "definition": "Texto de programación"}
  ],
  "diagonals": true,
  "reverses": false,
  "time": 0,
  "showResolve": true
}
```

## 3. Crucigrama

**Tipo:** `crossword`

### JSON orientativo

```json
{
  "typeGame": "Crucigrama",
  "wordsGame": [
    {
      "word": "IA",
      "definition": "Inteligencia Artificial",
      "url": "",
      "audio": ""
    }
  ],
  "time": 0,
  "difficulty": 100,
  "showSolution": true,
  "caseSensitive": false
}
```

## 4. Trivial

**Tipo:** `trivial`

### JSON orientativo

```json
{
  "typeGame": "Trivial",
  "temas": [
    [
      {
        "quextion": "¿Cuál es el lenguaje de eXe?",
        "options": [
          {"option": "JavaScript", "isCorrect": true},
          {"option": "Python", "isCorrect": false}
        ],
        "type": 0
      }
    ]
  ],
  "numeroTemas": 1,
  "nombresTemas": ["General"],
  "globalTime": 0
}
```

## 5. Adivina

**Tipo:** `guess`

### JSON orientativo

```json
{
  "typeGame": "Adivina",
  "wordsGame": [
    {
      "word": "ELEFANTE",
      "definition": "Animal de gran tamaño con trompa",
      "url": "content/resources/elefante.jpg"
    }
  ],
  "showSolution": true,
  "timeShowSolution": 5,
  "useLives": true,
  "numberLives": 3
}
```

Importante:

- Los recursos del proyecto deben apuntar a una ruta coherente con el paquete exportado.
- Si partes de una plantilla, respeta la convención de rutas ya usada por esa plantilla.

## 6. Vídeo interactivo

**Tipo:** `interactive-video`

### JSON orientativo simplificado

```json
{
  "videoUrl": "https://www.youtube.com/watch?v=...",
  "points": [
    {
      "time": 15,
      "type": "multichoice",
      "question": "¿Qué acabas de ver?",
      "options": ["Opción A", "Opción B"],
      "correct": 0
    }
  ]
}
```

Advertencia:

- Este iDevice es especialmente sensible a cambios de estructura.
- En exportaciones reales puede almacenar un JSON más complejo embebido en `htmlView` o en `jsonProperties`.
- Para este caso, usar un ejemplo real del mismo eXe no es opcional: es lo recomendable.

## Flujo recomendado para juegos

1. Exportar o tomar un ejemplo real del mismo iDevice.
2. Copiar su `htmlView`.
3. Copiar su `jsonProperties`.
4. Sustituir solo los datos de contenido.
5. Copiar la carpeta completa `idevices/<tipo>/`.
6. Validar en navegador y en reimportación.

## Señal de que el paquete está mal

Si ocurre cualquiera de estos casos, el `.elpx` no debe darse por válido:

- El juego se ve como HTML estático pero no responde.
- El proyecto reimporta, pero el iDevice aparece roto o vacío.
- Faltan imágenes, iconos o audios del juego.
- El tipo de `odeIdeviceTypeName` no coincide con la carpeta en `idevices/`.
