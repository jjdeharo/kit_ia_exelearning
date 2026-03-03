# Guia de Componentes ODE por iDevice

## Objetivo

Esta guia explica como debe usar la IA las referencias de:

- `referencias/ode_components/`
- `catalogo_componentes_ode.md`

para insertar iDevices dentro de `content.xml`.

## Regla principal

La IA debe trabajar asi:

1. Buscar el snippet del iDevice en `referencias/ode_components/<tipo>.xml`
2. Si el catalogo lo marca como `curated`, usarlo como referencia prioritaria
3. Si el catalogo lo marca como `real`, usarlo como segunda mejor referencia
4. Si el catalogo lo marca como `generated`, usarlo solo como base estructural
5. Reemplazar identificadores y contenido
6. Mantener intacta la estructura general del `odeComponent`

## Tipos de referencia

### `curated`

Significa:

- el snippet ha sido preparado manualmente dentro de este kit
- no siempre procede de un `content.xml` exportado, pero esta afinado para ser un modelo practico
- se usa para los iDevices prioritarios cuando aun no hay fixture real o cuando el stub generico se queda corto

En estos casos, la IA debe:

- tomarlo como referencia principal
- completar `__DATA_GAME__` y los campos internos que queden como ejemplo
- mantener sus clases y estructura base

### `real`

Significa:

- el snippet se ha extraido de un `content.xml` real de eXe
- es la mejor referencia disponible
- conviene conservar su forma lo maximo posible

En estos casos, la IA debe:

- copiar el bloque como modelo
- sustituir solo IDs, textos, recursos y los campos necesarios de `jsonProperties`
- no simplificar el XML salvo que entienda exactamente lo que hace

### `generated`

Significa:

- no se encontro aun un ejemplo real en los fixtures
- el snippet se ha generado a partir del `config.xml` del iDevice
- sirve para no partir de cero, pero no garantiza fidelidad completa

En estos casos, la IA debe:

- usar el snippet como esqueleto
- comprobar si hay informacion adicional en la documentacion del repo
- intentar conseguir un ejemplo real antes de usar ese iDevice en escenarios exigentes

## Campos que la IA puede modificar siempre

En cualquier `odeComponent`, la IA puede cambiar:

- `odePageId`
- `odeBlockId`
- `odeIdeviceId`
- `odeComponentsOrder`
- el contenido de `htmlView`
- el contenido de `jsonProperties`
- propiedades como `visibility`, si el caso lo requiere

## Campos que no debe cambiar a la ligera

La IA no debe cambiar sin motivo:

- `odeIdeviceTypeName`
- la estructura general interna del `odeComponent`
- nombres de claves internas de `jsonProperties` cuando proceden de un ejemplo real

## Flujo recomendado por iDevice

1. Identificar el tipo exacto del iDevice
2. Abrir `referencias/ode_components/<tipo>.xml`
3. Consultar `catalogo_componentes_ode.md` para saber si la referencia es `real` o `generated`
4. Si es `curated`, trabajar primero sobre ese bloque
5. Si es `real`, usarlo como referencia fuerte
6. Si es `generated`, usarlo solo como base y buscar mejorar la referencia en futuras iteraciones
7. Validar el proyecto final con `scripts/validate-elpx.sh`

## Prioridad de mejora del repo

La prioridad de trabajo pendiente sigue siendo:

1. Reemplazar los snippets `generated` mas importantes por snippets `curated` o `real`
2. Empezar por juegos y iDevices de evaluacion
3. Mantener `referencias/ode_components/` como biblioteca central de ejemplos

## Resumen

La carpeta `referencias/ode_components/` ya permite a la IA trabajar con todos los iDevices:

- con referencia `curated` cuando existe
- con referencia `real` cuando existe
- con esqueleto `generated` cuando aun no existe ejemplo real

El objetivo futuro es que cada vez mas entradas pasen de `generated` a `curated` o `real`.
