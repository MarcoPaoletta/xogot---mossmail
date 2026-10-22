# UI pack de arte: paneles en una imagen, escalados sin estirar

Cómo se arma y se usa el UI de un juego 2D con arte generado (Makko u otro generador de imágenes), para que el HUD y los menús se vean de producto y no de prototipo. Sale de Reedway Ferry Ep 1 (Makko juego 4, 2026-09-24): Marco revisó el build, pidió el pack, rechazó dos piezas y corrigió tres pantallas. Esas correcciones son las reglas de abajo, y valen para los próximos juegos y episodios.

## 1. El pack se genera en UNA sola imagen

- ⛔ **Una imagen con todas las piezas, no un prompt por panel.** Salidas del mismo lote comparten el grosor del borde, el radio de las esquinas y la paleta. Pedidas por separado, cada una vuelve con otro borde, que es exactamente lo que rompió los sentados de Reedway.
- **Máxima resolución que dé el generador** (Makko: `2K` = 2560x1440 en 16:9, no hay 4K), sobre chroma, y con el marco que ya use el juego como referencia única, así el pack es de la misma familia que el HUD existente.
- **Las piezas que sirven (las seis aprobadas):** cuadrado chico, cuadrado mediano, panel grande (ventanas y modales), panel alto (listas), barra ancha (headers, contadores, botones anchos), barra mediana (tags de precio). Todas vacías por dentro, crema plana, sin veta, sin íconos, sin texto.
- ⛔ **Nada de barras enanas ni tiras finas.** Marco rechazó `bar_small` y `strip_thin` de Reedway ("decile que no las use"): a ese tamaño el borde come el interior y no entra nada legible. Un contador chico usa el cuadrado chico o la barra mediana escalados.
- **Borde FINO.** El primer pack salió con un borde naranja de unos 80 px sobre paneles de 400 a 650 px y Marco pidió afinarlo; quedó en unos 55 px con un `Iterate` de Makko ("make the orange wood border of every panel much thinner, about half"). Default para los próximos: pedir el borde fino desde el primer prompt.
- Se keyea local (`Letta/Skills/Skill 22 - Background Removal/chroma_key.py`, `35 25`), se corta por componentes conexas con 4 px de margen, y se escribe un manifest con el tamaño de cada pieza y sus márgenes de nine patch.

## 2. Cómo se usa en Godot (la regla de Marco)

- ⛔ **Cada hueco usa la pieza cuya forma NATIVA se parece más, escalada UNIFORME** (TextureRect con `STRETCH_KEEP_ASPECT_CENTERED`, o escalada a la altura del hueco). Estirar un solo marco a todos los tamaños con los márgenes del nine patch "queda todo roto" (Marco); por eso el pack trae formas distintas.
- **Nine patch solo si un hueco de verdad necesita otro aspecto**, y con márgenes que cubran el **radio de la esquina exterior** (medido: 56 a 79 px en el pack de Reedway), no solo el grosor del borde. Si el margen es menor que el radio, la esquina se deforma. Los márgenes van multiplicados por el mismo factor de escala de la pieza.
- Mapeo que quedó en Reedway (commit `8f11959`): ventanas = panel grande; tarjetas de barco = cuadrado mediano; diálogos, pills del HUD y botones anchos = barra ancha; botones cuadrados y slots de asiento = cuadrado chico; tag de precio del edificio = barra mediana.

## 3. Padding y contenido (las tres correcciones de Marco)

- ⛔ **Padding generoso adentro de cada pill del HUD.** El ícono, el número y la barra no tocan el borde: en Reedway quedaron unos 28 px de aire adentro y la barra de vida termina 32 px antes del borde derecho. Marco lo marcó en rojo sobre la captura: "more padding".
- ⛔ **Un slot muestra UNA cosa, centrada con el mismo aire en los cuatro lados.** Los asientos del HUD tenían la cara del animal más un iconito de isla encima; Marco: "remove the island icons and center with padding the animal icons". Nada de íconos superpuestos en un slot chico.
- ⛔ **El contenido de una tarjeta entra con aire abajo.** Si el botón de una tarjeta queda pegado al borde inferior, se achica el contenido (Reedway: todo un 15 por ciento, título 42 a 36 px, sprite 202 a 172, botón 400x96 a 340x82), nunca se agranda la tarjeta sobre el menú. El piso de texto de 28 px del proyecto no se rompe: lo que ya está en el piso queda igual.
- ⛔ **Las barras de progreso adentro de un panel son rectángulos de esquinas rectas**, no pills redondeadas (Marco, sobre el hold to build del tag de precio). El redondeo lo pone el marco, no la barra.
- **Un tag o cartel que crece se revisa contra lo que tiene abajo.** Al agrandar el tag de precio, el texto "Hold to build" quedó encima del arte de la isla: cada cambio de tamaño se verifica con captura del juego en la zona más cargada. **Cómo quedó (Marco, ronda 4):** el tag a mitad de tamaño, sobre el borde superior del edificio, y sin el texto "Hold to build". La UI pegada a un objeto del mundo nunca lo tapa (`character-anchors-handover/` §1).

## 4. Verificación

Captura del juego a la resolución de diseño de cada pantalla tocada (`docs/evidence/ui-*.png`, mismos nombres para que se comparen ronda contra ronda), antes del commit. Marco revisa las capturas y corrige marcando en rojo: cada corrección suya que valga para otros juegos se agrega a este archivo.

## 5. Saffron Shift (SpriteCook 6, GPT 6.1 Sol, 2026-09-30): lo que hizo bien la UI y cómo se verifica

Marco revisó el build ("everything broken") y la ronda de arreglo quedó como referencia de una UI bien resuelta con un kit de SpriteCook. Fuente completa: `SpriteCook\6 - Saffron Shift\docs\UI_RULES.md` (contiene además los scripts `tools/author_ui_rebuild.py`, `ui_padding_pass.py`, `patch_kitchen_ui.py`, re-ejecutables).

- ⛔ **Una pantalla modal nunca se dibuja debajo del HUD.** Capas fijas: HUD `z_index` 0 a 3, Screens 10, Tutorial 20, panel de grabación 30, toast global 40. El primer hijo de Screens es un `Scrim` que oscurece el juego detrás de todo modal menos el título vivo. Un modal bajo texto del HUD fue el bug más visible de la primera pasada.
- ⛔ **Un label que necesita marco dibuja su PROPIO pill** (`theme_override_styles/normal` con un StyleBox de pill, con variante para cuando hay ícono a la izquierda). Texto y marco son un solo nodo, no pueden desfasarse. Los paneles "Frame" separados detrás de labels eran la causa del texto cortado ("Reputation 5 / 5" partido al medio): se borran, no se ocultan.
- ⛔ **Una sola fuente en todo el UI, sin overrides por nodo.** Va en `gui/theme/custom_font` y en cada clase del theme; se verifica caminando las escenas. Claro sobre madera es crema con outline oscuro; oscuro sobre pergamino. Medir contraste: el marrón oscuro sobre madera oscura dio 1,4 a 1.
- ⛔ **Los nombres internos no llegan al jugador.** `Oven0` es "Oven 1", `Boil` es "Cauldron", las etapas de una orden son verbos ("Prepping", "Dish ready"). El botón contextual solo ofrece una acción que el juego va a aceptar y dice por qué si no ("Wrong dish for guest 2", "Burnt food: discard it"). Los hints y toasts aparecen solo cuando hay algo que decir: nada permanente sobre el área de juego.
- **Cada bloque del HUD anclado a su propio borde** (arriba izquierda, arriba centro, etc.), `HUD` y `Screens` en full rect; tamaño de diseño con stretch `viewport` y aspect `expand` más una `Camera2D` centrada. Los taps pasan por la inversa del canvas transform, así el mundo responde con cualquier aspecto.
- **Verificación que funcionó:** playtest independiente por el MCP con eventos reales de teclado y mouse, captura del viewport a la resolución de diseño (`game_eval` guardando la textura) y LEER el texto de la imagen, sobre el frame más cargado (tres órdenes, dos hornos, toast y plato cargado a la vez). Las pruebas funcionales pasaban y el gate perceptual fallaba: los tests verdes no prueban que el UI se vea bien.

Trampas del MCP en esta ronda:
- Editar scripts con el juego detenido y `autosave` apagado en `project_run`; con el juego corriendo las escrituras fallan con `EDITOR_PLAYING`, y un `scene_save` posterior puede pisar un script editado por fuera del buffer. Orden que funciona: theme y resources, batch de escena más `scene_save`, parches de script al final, verificar en disco con grep.
- `set_anchor_preset` mueve el control a esa esquina: primero los anchors, después `position` y `size`. Además rechaza un `Sprite2D` (poner el ícono como hijo de un Label anclado).
- `filesystem_manage remove` rechaza archivos de más de 256 KB: borrar el archivo y su `.import` desde disco y hacer `scan`.
