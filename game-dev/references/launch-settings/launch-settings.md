# Configuración de lanzamiento del juego (ventana, escala, stretch)

Regla de Marco (2026-10-13): el juego final usa **Expand en PC y móvil**, con
UI legible y todo el juego bien encuadrado al cambiar el tamaño de pantalla.
Este bloque usa canvas base 1920×1080, ventana centrada y escalado proporcional.
Todo vive
en `project.godot` (viaja con el repo), más un par de preferencias del editor
para que el Play embebido se vea igual. Copiá este bloque en cualquier
proyecto nuevo.

---

## El bloque completo (`project.godot`)

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=0
window/size/initial_position_type=1
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

Regla: **pineá también los valores que hoy son default** (mode, aspect,
initial_position_type). Los defaults pueden cambiar entre versiones de Godot o
por un click accidental — explícito en el archivo = determinista para siempre.

## Qué hace cada uno y por qué este combo

| Setting | Valor | Por qué |
|---|---|---|
| `viewport_width/height` | 1920×1080 | El canvas de DISEÑO. Toda la UI (HUD, menús, shop) se maqueta contra 1080p con números enteros. No es la resolución final: es la referencia que después se escala. |
| `size/mode` | `0` (Windowed) | El juego arranca en ventana. Fullscreen es una ELECCIÓN del usuario (checkbox en Options), no una imposición del primer arranque. |
| `initial_position_type` | `1` (Center of Primary Screen) | La ventana aparece centrada en el monitor principal. Sin sorpresas multi-monitor. |
| `resizable` | `true` | El usuario puede estirar la ventana a gusto; el stretch se encarga de que nada se rompa. |
| `stretch/mode` | `"canvas_items"` | La MAGIA del combo. El mundo 3D rendea a la resolución real de la ventana (nítido siempre), y los Control/CanvasItems se escalan desde el canvas 1080p. UI diseñada una vez, perfecta en 720p, 1440p, 4K y ultrawide. |
| `stretch/aspect` | `"expand"` | Conserva las proporciones y amplía el área visible para llenar la ventana sin letterboxing. Obligatorio en el juego final, PC y móvil. La UI se ancla al viewport real y la cámara, fondos y efectos cubren el área extra. Reemplaza el antiguo default `keep` de PC. |

### Por qué `canvas_items` y no las alternativas

- `disabled`: la UI queda en píxeles absolutos — en 4K se ve diminuta, en
  720p se corta. Nunca para un juego shippeable.
- `viewport`: escala TODO el render (3D incluido) desde 1080p — en monitores
  4K el juego se ve borroso. Solo tiene sentido para pixel-art.
- `canvas_items`: 3D nativo nítido + UI escalada. El estándar para juegos 3D
  con HUD.

## Interacción con las Options del juego

El runtime tiene un `SettingsManager` (autoload) con Fullscreen como opción
persistida en el save del usuario:

- **Primer arranque** (sin save): manda `project.godot` → ventana 1080p
  centrada. Esta es la experiencia "de fábrica" que define este documento.
- **Arranques siguientes**: si el usuario activó Fullscreen en Options, el
  SettingsManager lo re-aplica al bootear. Su elección gana — el project
  setting es el DEFAULT, no una cárcel.

Si un tester quiere volver al estado de fábrica: borrar el archivo de save de
settings (en este proyecto, `user://paintfall_save.json`).

## Preferencias del editor (para que el Play se vea igual)

Estas NO van en `project.godot` (son por máquina, panel desplegable arriba a
la derecha del Game workspace):

- **Embed Game on Next Play: ON** — el juego corre embebido en el editor.
- **Embedded Window Sizing: Stretch to Fit** — el embed usa todo el panel;
  combinado con `stretch/aspect = expand`, conserva proporciones y amplía el
  área visible al aspecto del panel, sin barras de letterboxing.

Así lo que ves al apretar Play en el editor es proporcionalmente lo mismo que
verá el jugador en la build.

## Checklist para portar

1. Pegá el bloque `[display]` de arriba en el `project.godot` nuevo (o seteá
   los 7 valores por Project Settings → Display → Window).
2. Diseñá TODA la UI contra el canvas de diseño con anchors y containers que
   respondan al viewport real. Fondos y overlays en full rect, HUD anclado a
   sus bordes, diálogos y menús con márgenes y espacio para texto legible.
3. Si tu juego tiene opción de fullscreen, aplicala en un autoload al bootear
   LEYENDO el save — nunca la hardcodees en project.godot.
4. Probá en runtime el tamaño de diseño, una ventana chica, un aspecto más
   ancho y otro más alto soportados por el target. Para PC con base 1920×1080:
   1920×1080, 1280×720, 2560×1080 y 1280×1024. Para móvil, incluir el aspecto
   real del dispositivo y su safe area. Revisar redimensionado y fullscreen
   cuando estén disponibles.
5. Capturá menú, gameplay con HUD, diálogo o panel, pausa y resultados.
   Texto grande y legible, controles accesibles, nada cortado, solapado ni
   deformado. Revisá también cámara, personajes, bordes del nivel, fondos y
   efectos: sin barras negras involuntarias, áreas sin cubrir, escenarios
   incompletos expuestos ni gameplay esencial oculto por la UI. Ampliar la
   vista no implica mostrar el nivel entero de una vez.
6. Guardá capturas y dimensiones en `docs/evidence/` y el resultado en
   `docs/BUILD_NOTES.md`. Corregí y volvé a capturar cada fallo antes de declarar
   terminado. Si hay exports pedidos, verificá esos builds también.

Configurar `expand` solo no alcanza: el criterio de entrega es que la UI y el
juego completo se vean bien durante el uso real. La base 1920×1080 de este
bloque es para PC; conservar la resolución y orientación de diseño aprobadas
del target móvil, usando el mismo aspect `expand`.

Semántica del escalado: [documentación oficial de Godot](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).
