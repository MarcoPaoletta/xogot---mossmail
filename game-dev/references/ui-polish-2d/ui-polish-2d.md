# UI placeholder a sistema visual: pulir la UI de un plataformero 2D

Cómo convertir la UI de blockout de un juego 2D funcional (Labels flotantes,
ColorRect sueltos, colores fuera de paleta, barras con style default) en un
sistema visual coherente, sin romper los tests y sin dejar placeholders en
cámara.

Para corregir padding, exceso de HUD o controles móviles mostrados en PC, leer [los ejemplos visuales de Shrine Keeper](examples/shrine-keeper-ui-review.md). Incluyen capturas reales de antes y después, pedidos de Marco y los cambios que deben verse. Sacar bloques redundantes conserva texto grande y devuelve espacio al mundo; no se resuelve reduciendo toda la UI.

Proyecto observado: Starling, Episode 1 (Gloomlands), Godot 4.7. Fuente viva:
`docs/godot-polish-learnings.md`. Getters de UI en `scenes/ui/hud.gd`,
`scenes/ui/dialogue_box.gd`. Prompt de interacción en la escena dueña
`scenes/npcs/npc_interaction.tscn`.

---

## 1. El problema

Un build puede tener el loop completo, las colisiones bien y la economía
cerrada, y aun así leerse como prototipo. La causa casi nunca es falta de
sistemas: es la UI. Labels flotantes, rectángulos de blockout, colores sin
sistema (azul oscuro, amarillo, celeste), barras con el style default de Godot
y slots de portrait vacíos. Si el entregable se evalúa en una captura o un
video, el criterio visual pesa igual que la lógica. Una mecánica no está
terminada cuando funciona: lo está cuando comunica estado, intención e impacto.

La aceptación se parte en dos puertas: la funcional (estados, colisiones,
economía, guardado) y la perceptual (escala, jerarquía, legibilidad, ausencia
de placeholders). No cerrar un feature con la primera puerta si se va a grabar.

## 2. Paleta y tokens

El pedido de Starling fue negro, gris y blanco, con la barra de vida roja como
única excepción funcional. Los VFX de gameplay pueden conservar color si la
restricción es sólo sobre la UI.

**Un Theme NO alcanza.** Centralizar el theme (`starling_theme.tres`) y armar
StyleBoxes reutilizables es el primer paso, no el último:

1. `panel_glass.tres`
2. `objective_chip.tres`
3. `dialogue_panel.tres`
4. `bar_background.tres`
5. `dash_fill.tres`
6. `boss_fill.tres`
7. `health_fill.tres`
8. `interact_prompt.tres`

Después de centralizar, Title, Options, Pause, World Selector, cards, prompts y
scripts seguían teniendo colores propios. **Un theme sólo controla nodos que no
sobrescriben el valor localmente.** Los overrides locales y los colores escritos
desde código se escapan del theme y hay que cazarlos uno por uno.

Auditoría obligatoria, sobre escenas, resources Y código:

- `theme_override_colors`
- `modulate`
- `self_modulate`
- colores escritos desde scripts (`Color(...)`, tints, `.color =`)

Regla de tokens: definir los colores en un solo lugar y **nombrar las
excepciones** de forma explícita (la vida roja es funcional, no decorativa). Un
color fuera de paleta sin una excepción declarada es un bug.

## 3. Auditoría de placeholders

No todo rectángulo es placeholder. Un panel UI intencional tiene style,
margins, jerarquía y función. Un placeholder es un rectángulo sin intención
visual que sobrevivió al blockout. Cazar y eliminar:

1. `ColorRect` world space sin intención visual (ej. el marcador celeste del
   checkpoint: se elimina el ColorRect, el trigger `Area2D` sigue invisible).
2. Labels flotantes que describen gates (`7 CORES REQUIRED`): se reconstruyen
   con arte real, en Starling con recortes del sheet de plataformas.
3. Sprites de spawn o checkpoint (marcadores que no comunican gameplay no
   necesitan representación).
4. Portrait slots vacíos (`PortraitSlot`, `PortraitLabel` del diálogo se
   eliminaron: si no aporta función, se borra, no se oculta, porque ocultar
   deja layout residual).
5. Texto de debug en el HUD.
6. Barras con style default de Godot (el porcentaje visible se oculta).
7. Colores celeste, amarillo o azul fuera de la paleta aprobada.

Ocultar un placeholder suele dejar el layout corrido. Eliminarlo de verdad, no
`visible = false`.

## 4. Densidad de UI: se calibra contra el viewport, no se minimiza

El primer rediseño del diálogo bajó el panel al borde y sacó el portrait, y
todavía tapaba medio nivel, así que un pase lo achicó a `1040 x 126`. Una
captura POSTERIOR mostró el error opuesto: a ese tamaño el texto quedaba chico y
sobraba espacio horizontal y vertical sin usar. El ajuste final lo AGRANDÓ a
`1180 x 166`, con tipografías mayores, y recuperó ese espacio sin tapar al player
ni las plataformas.

**⚠️ No existe una regla absoluta de "achicar la UI". Más compacto no es siempre
mejor.** La densidad se calibra contra la escena completa, a resolución de
gameplay, sobre el fondo más cargado, comparando tres cosas: legibilidad,
espacio disponible y cobertura del gameplay. En Starling el barrido final fue
hacia ARRIBA en casi todo:

| Elemento | Antes | Final |
|---|---:|---:|
| Panel del HUD | `370 x 166` | `460 x 200` |
| Contador de Cores | `28` | `34` |
| Objetivo | `16` | `20` |
| Panel de diálogo | `1040 x 126` | `1180 x 166` |
| Speaker | `19` | `23` |
| Texto de diálogo | `18` | `24` |
| Hint de avance | `13` | `16` |

Esto engancha con la preferencia de Marco: UI grande y legible, texto y números
clave que aprovechen el espacio. Ante la duda, más grande. Achicar es una
respuesta válida sólo cuando la captura muestra oclusión real, no por default.

**Regla: después de CUALQUIER cambio de tamaño de UI, dos screenshots.**

1. La UI aislada, para evaluar legibilidad a resolución de gameplay.
2. La UI sobre la zona MÁS densa del nivel, para evaluar oclusión y jerarquía.

Una UI que se ve perfecta en un fondo vacío puede tapar la traversal donde el
nivel se aprieta, y una que se achicó "para no tapar" puede quedar ilegible. La
captura runtime detecta las dos cosas, que ni los scripts ni los probes ven: el
diálogo demasiado alto Y el diálogo demasiado chico se encontraron mirando el
framebuffer, no leyendo el árbol.

## 5. Barras world space del player

La barra de vida (`110 x 12`, sobre la cabeza) y la de dash viven en
`StatusBars`. **`StatusBars` es SIBLING de `AnimatedSprite2D`, nunca hijo.** Si
la barra cuelga del sprite, el `flip_h` del personaje espeja también la UI y la
barra salta de lado al girar.

La ubicación se verifica contra TODOS los clips grandes, no sólo idle. Attack y
air_dash usan canvases más grandes y pueden invadir el espacio de la barra
aunque en idle se vea perfecto. Calibrar mirando el clip más invasivo.

## 6. Ownership de UI anidada

El prompt de interacción (`E TALK`) se intentó estilizar desde las escenas de
NPC concretas (Ember, Old Cobb). El cambio no se serializó: el Label vive en la
escena compartida anidada `npc_interaction.tscn`, no en la escena de NPC que
estaba abierta.

**Regla: nunca asumir que un nodo visible pertenece a la escena abierta.**
Inspeccionar ownership e instancias, abrir la escena DUEÑA del nodo, editar
ahí, guardar y verificar el archivo. Editar la instancia no persiste al padre.

El prompt final: `220 x 58`, fuente `24`, outline `3`, z index `8`, fondo gris
`0.17` alpha `0.95`, borde gris `0.66`, radio `12`, copy `E   TALK` o binding
dinámico. El texto fijo hardcodeado es deuda: un binding o un idioma largo
desborda el ancho fijo. Preferir binding dinámico o NinePatch con margins.

**El prompt necesita AIRE sobre la silueta.** La pastilla estaba pegada al
sprite del NPC, así que subió `50 px`, de `Y = -235` a `Y = -285`. Un prompt
world space quiere separación respecto de la silueta y contraste, no colgar
encima de la cabeza.

**Colocar un NPC es una validación en contexto, no una coordenada.** Old Cobb se
movió de `(5200, 900)` a `(5600, 908)` porque su posición coincidía con una
plataforma alta y parecía flotar. Mover un NPC exige tres comprobaciones en una
misma prueba:

1. La silueta no invade la geometría cercana (separación horizontal real).
2. Los pies coinciden visualmente con el piso.
3. Existe colisión de soporte debajo del actor (raycast a la colisión del mundo).

El probe combina la posición exacta con el raycast hacia el suelo, y una captura
runtime cierra la validación: una coordenada correcta puede seguir viéndose mal
por el offset del sprite.

## 6b. Diálogo: typewriter con dos acciones

El diálogo revela el texto con efecto typewriter, `42` caracteres por segundo,
usando `Label.visible_characters`. El progreso se acumula como `float` y se
redondea hacia abajo para mostrar caracteres completos, así la velocidad es
estable aunque cambie el frame rate (nunca un carácter por frame).

El contrato de input tiene DOS acciones distintas sobre el mismo botón, y
mezclarlas produce saltos de contenido:

1. Si la línea todavía se está revelando, la interacción la COMPLETA y no cambia
   el índice de línea.
2. Si la línea ya está completa, la interacción AVANZA a la siguiente.
3. Al cerrar o liberar el nodo (`_exit_tree`), se reinician progreso, total y
   estado activo.

La regla es no permitir que un mismo input "acelere y avance" en un solo gesto:
el primer input completa, el segundo avanza. Si no se separan, el jugador que
aprieta rápido para leer se saltea líneas sin querer.

La UI expone getters semánticos para probar el typewriter (ver sección 7):
`is_typewriting()`, `get_revealed_character_count()`,
`get_current_line_character_count()`. El probe valida progreso parcial,
completar la línea a mano, avanzar y reset.

## 7. Getters semánticos para tests

El rediseño cambió paths de Labels y jerarquías. Los tests acoplados al árbol
fallaron aunque la UI funcionaba perfecto. La UI es lo que MÁS se reordena en un
pase de polish, así que un probe atado a `$Panel/VBox/Label3` es un test que se
va a romper solo.

**Regla: los probes prueban estado público semántico, no decoración ni paths
internos.** La UI expone getters con nombre de dominio, y el relayout no toca
el contrato:

```gdscript
func get_core_count() -> int:
	return _core_count

func is_boss_health_visible() -> bool:
	return boss_panel.visible
```

Getters de referencia expuestos por `hud.gd` y `dialogue_box.gd`:

1. `get_core_count()`
2. `get_core_punch_count()`
3. `get_boss_health_value()`
4. `is_boss_health_visible()`
5. `is_transitioning()`
6. `get_visual_alpha()`
7. `is_typewriting()`
8. `get_revealed_character_count()`
9. `get_current_line_character_count()`

Corolario asincrónico: después del polish, cierre de diálogo, barrera, respawn
y scene load dejaron de ser instantáneos. Un assert de un frame da falso rojo.
Los tests esperan una condición observable con timeout (`not visible and not
transitioning`, phase `idle`, señal terminada), no un número fijo de frames. El
test conoce el contrato temporal por el getter, no por contar frames.

## 8. Trampas de resources y gradientes

Dos trampas que aparecen apenas la UI usa glow o luz, cada una vale su propia
nota.

### 8a. Caché de resources

Sobrescribir un `.tres` puede no actualizar la instancia ya cargada: el editor
conserva la anterior en caché. Sobrescribir `star_core_glow.tres` no cambió su
`fill_from` en memoria.

Corrección: crear el resource con un path NUEVO, reasignarlo, guardar la escena
y recargar. Cuando disco y memoria difieren, force reload o path nuevo, y
después retirar el asset viejo para que nadie lo agarre.

### 8b. Gradiente radial y luz con borde

Un `GradientTexture2D` con `fill_from = (0, 0)` centra el gradiente en la
esquina y renderiza un RECTÁNGULO en vez de un halo. Se veía un bloque detrás de
la moneda.

Corrección: `fill_from = (0.5, 0.5)`, `fill_to = (1, 0.5)`, y verificar centro,
stops, RGB del borde y alpha del borde.

Y la trampa apareada, la luz con borde transparente: **la textura del
`PointLight2D` debe terminar en NEGRO OPACO, mientras el halo VISUAL termina en
alpha cero.** Son dos texturas distintas. Una textura transparente puede
conservar RGB en el borde, y el `PointLight2D` ilumina ese RGB residual y revela
un cuadrado, aunque el Sprite2D visual parezca perfectamente transparente.
Revisar: centro, RGB del borde, alpha del borde y uso final de cada textura.

## 9. Checklist de porteo

- [ ] Existe una paleta aprobada, con las excepciones funcionales nombradas
      (ej. vida roja).
- [ ] Theme + StyleBoxes centralizados, y auditoría de `theme_override_colors`,
      `modulate`, `self_modulate` y colores escritos desde scripts, sobre
      escenas, resources Y código.
- [ ] No quedan placeholders world space: ColorRect sin intención, Labels de
      gate, marcadores de spawn/checkpoint, portrait slots vacíos, debug text,
      barras con style default, colores fuera de paleta. Eliminados, no ocultos.
- [ ] HUD con anchors de viewport, no safe area fija.
- [ ] Barras world space SIBLING del `AnimatedSprite2D`, verificadas contra los
      clips grandes (attack, air_dash), no sólo idle.
- [ ] Densidad calibrada contra el viewport final, a resolución de gameplay,
      sobre el fondo más cargado: dos screenshots (UI aislada + UI sobre la zona
      más densa). Más chico NO es el default; ante la duda, más grande y legible.
- [ ] Diálogo con typewriter de dos acciones: el primer input completa la línea,
      el segundo avanza; reset en `_exit_tree`. Velocidad estable por acumulación
      en `float`, no por frame.
- [ ] Prompt de interacción editado en su escena DUEÑA (inspeccionar ownership
      antes de mutar), con binding dinámico, no texto fijo, y con aire sobre la
      silueta del NPC.
- [ ] Colocar un NPC se valida en contexto: separación horizontal, pies sobre el
      piso y colisión de soporte debajo (posición + raycast + captura runtime).
- [ ] Tests consumen getters semánticos, no node paths, y esperan condiciones
      observables con timeout, no un número fijo de frames.
- [ ] Resources: path nuevo o force reload cuando disco y memoria difieren;
      retirar el asset viejo.
- [ ] Gradiente radial con `fill_from = (0.5, 0.5)`; textura de `PointLight2D`
      termina en negro opaco, halo visual en alpha cero.

## Plataformas y revisión de dirección

Ver [plataformas, dirección y revisión visual](platform-and-direction-review.md) para separar HUD de PC y móvil, verificar sprites mal etiquetados, medir texto y filas, extraer una flecha sin fondo, nivelar un puente y esperar colisiones diferidas con evidencia real.
