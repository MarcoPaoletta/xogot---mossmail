# Fade de pantalla global con ownership explícito

Cómo hacer que los cambios de escena y los respawns dejen de verse a
prototipo (corte instantáneo), con un solo fade global que ninguna otra
parte del juego puede pisar.

Referencia viva: `scripts/screen_transition.gd` (`class_name
ScreenFadeTransition`), portada verbatim del proyecto Starling
(`scenes/ui/screen_transition.gd`, Godot 4.7).

Segunda referencia: `scripts/travel_fade.gd`, el `fade.gd` de Reedway Ferry
(Godot 4.7.2, 2026-09-24), con la precarga en thread y la transición de viaje
de las secciones 5 y 6.

---

## 1. El problema

Un cambio de escena hecho a lo directo llama `change_scene_to_file()` y ya:
la pantalla salta de golpe. Un respawn hace lo mismo, teletransporta al
player en un frame. Los dos se leen como bug o como demo sin terminar, no
como un juego shippeable. Y apenas el juego crece aparece el problema real:
varias partes quieren atenuar la pantalla a la vez (el SceneLoader durante un
cambio de mundo, el respawn del mundo, un boss intro), cada una arma su
propio fade, y los fades se pelean entre sí. Overlays que quedan a medio
camino, una pantalla que queda negra para siempre, el mouse que sigue
clickeando debajo del negro.

La solución no es "poné un tween de alpha". Es una CAPA global con un dueño
claro, con fases que se pueden observar, que se limpia sola si la escena se
destruye a mitad de la transición.

## 2. La arquitectura

`ScreenFadeTransition` es un `CanvasLayer` autoload (`/root/ScreenTransition`)
con un `ColorRect` negro adentro. Piezas obligatorias:

- **`CanvasLayer` global con `process_mode = PROCESS_MODE_ALWAYS`.** El fade
  tiene que seguir corriendo aunque el árbol esté pausado (`get_tree().paused
  = true`), porque muchas transiciones pausan el gameplay mientras la pantalla
  está en negro. El tween además se setea con `set_pause_mode(Tween.
  TWEEN_PAUSE_PROCESS)` para que avance con el nodo, no con el árbol.
- **Serial de cancelación (token).** `_tween_serial` es un entero que sube en
  cada pedido. Cada corrida de `_tween_alpha` captura su `serial` local, mata
  el tween anterior con `kill()`, y al terminar sólo se considera válida si
  `serial == _tween_serial`. Así una segunda petición que llega en el medio
  cancela la primera de forma limpia: la vieja await termina y devuelve
  `false` en vez de pelear por el mismo `modulate.a`. Sin esto, dos fades
  concurrentes dejan el alpha en un valor indefinido.
- **Fases observables.** El estado se puede leer desde afuera: `is_
  transitioning()` y `get_fade_alpha()` en la capa, y el SceneLoader que la
  usa expone `get_transition_phase()`. Sirve para que los callers y, sobre
  todo, los tests sepan en qué punto está la transición sin adivinar por
  frames. La máquina de fases del SceneLoader es: `hold` (espera corta antes
  de arrancar), `fade_out` (a negro), `scene_change` (`change_scene_to_file`),
  `fade_in` (de negro a la escena nueva), `idle` (en reposo).
- **Bloqueo de mouse en negro.** Durante el fade el `ColorRect` pasa a
  `MOUSE_FILTER_STOP` para que ningún click se cuele a lo que está debajo del
  overlay; vuelve a `MOUSE_FILTER_IGNORE` recién cuando termina el fade in.
- **Reversión ante error.** Si `change_scene_to_file()` devuelve distinto de
  `OK`, el sistema NO se queda en negro: hace `fade_in`, libera el guard de
  transición, vuelve a `idle` y emite una señal de error
  (`transition_failed`). El juego queda jugable en la escena vieja en vez de
  trabado en pantalla negra.
- **Cleanup en `_exit_tree()`.** En el sistema de respawn, la secuencia
  adquiere un input lock (`respawn`) y lo libera al final. `_exit_tree()`
  libera ese lock si la escena se destruye a mitad del proceso. Sin esa
  guarda, una escena que se descarga justo durante un respawn deja el juego
  permanentemente bloqueado (el lock nunca se suelta).
- **Un solo owner.** El fade global es UNO. El mundo coordina su respawn
  usando la MISMA capa global (`_get_screen_transition()` resuelve
  `/root/ScreenTransition`), no cada sistema levantando su propio fade. Dos
  owners simultáneos del fade es exactamente lo que el serial de cancelación
  y esta disciplina evitan. La regla: los sistemas piden fade a la capa
  global, no fabrican fades.

## 3. La máquina de fases del SceneLoader

El SceneLoader (autoload que también corre `PROCESS_MODE_ALWAYS`) es el
caller canónico. Su `_change_scene_after_hold()` recorre las fases en orden y
las publica en `_transition_phase`:

1. `hold`: espera un tiempo corto (`create_timer` que corre en pausa) para
   que el frame previo se lea antes de cortar.
2. `fade_out`: `await screen_transition.fade_out()` lleva el overlay a negro.
3. `scene_change`: `change_scene_to_file(scene_path)`. Si falla, salta a
   `fade_in`, libera el guard y emite `transition_failed`.
4. `fade_in`: tras un `process_frame` para que la escena nueva se instancie,
   `await screen_transition.fade_in()` saca el negro.
5. `idle`: baja `_transitioning`, deja `_transition_phase = &"idle"` y emite
   `transition_finished`.

Un guard `_transitioning` al frente de cada entrada pública
(`start_new_run`, `continue_run`, `go_to_title`, `load_world`, etc.) rechaza
transiciones concurrentes: si ya hay una en curso, la nueva no arranca.

## 4. Las dos trampas

- **ColorRect con alpha base 1, no un color base con alpha 0.** El overlay
  mantiene su color negro con alpha base en 1 y lo que anima el tween es
  `modulate.a` (arranca en 0.0 en `_ready`). Si en cambio el color base del
  ColorRect tuviera alpha 0 y animaras `modulate.a`, el resultado sería
  invisible: modular un color que ya es transparente por multiplicación sigue
  dando transparente. El overlay nunca se ve. Base alpha 1 en el color,
  animación sobre `modulate.a`.
- **Los tests esperan una CONDICIÓN observable con timeout, no un número fijo
  de frames.** Las pruebas viejas asumían cambios de escena instantáneos y
  medían justo después. Con fades, esa suposición es falsa: la transición
  tarda. El test tiene que esperar una condición que el sistema expone (`not
  is_transitioning() and not visible`, o `get_transition_phase() == &"idle"`,
  o la señal `transition_finished`), con un timeout de guarda, NUNCA
  `await` de N frames fijos. Un conteo fijo de frames o pasa de casualidad o
  falla intermitente según la máquina.

## 5. Una transición lenta casi siempre es CARGA, no animación (medido)

En Reedway Ferry el viaje mar a pueblo era fade a negro, 0,3 s de hold y un
`change_scene_to_file` bloqueante, y Marco lo sintió roto. El tiempo se iba en
cargar la escena, no en el tween. Arreglo:

- **Cada escena precarga en un thread su próxima escena probable apenas
  arranca**: `ResourceLoader.load_threaded_request(path)`, se sondea con
  `load_threaded_get_status` y el `PackedScene` cargado **se guarda
  referenciado** (un diccionario en el autoload de transición) hasta que el
  viaje lo usa. Sin la referencia, el recurso se libera y la carga se repite.
- El viaje toma la escena precargada y hace `change_scene_to_packed`; si la
  precarga todavía corre, espera a que termine en vez de lanzar un `load`
  bloqueante encima.
- **Medir antes y después** con `Time.get_ticks_msec()` alrededor del evento, y
  reportar los números. Mar a pueblo pasó de unos 1,3 s a 0,65 s.

## 6. Transición de viaje: zoom al destino, captura y crossfade (Marco)

⛔ **Las transiciones entre lugares del mundo escalan HACIA el destino y
después cambian de escena**, no cortan a negro (Marco, Reedway Ferry). Receta:

1. La cámara que se va hace un dive hacia el destino (zoom más pan).
2. El último frame se guarda como captura en un `TextureRect` por encima de
   todo (`get_viewport().get_texture().get_image()`).
3. La escena nueva carga DEBAJO de la captura (precargada, sección 5).
4. La captura hace crossfade hacia afuera mientras la cámara que llega entra
   desde el zoom equivalente al suyo con ease.
5. El viaje inverso hace pull back en lugar de dive.

El zoom del dive lo calibra Marco sobre capturas y se mueve en pasos: en
Reedway 2,6x fue "way too much" y quedó 1,3x.

## 7. Checklist de porteo

- [ ] `CanvasLayer` autoload en `/root`, `process_mode = PROCESS_MODE_ALWAYS`.
- [ ] `ColorRect` negro adentro, **color con alpha base 1**, `modulate.a`
      arranca en 0.0 y es lo que anima el tween.
- [ ] Serial entero (`_tween_serial`): subir por pedido, capturar local,
      `kill()` del tween previo, validar `serial == _tween_serial` al cerrar.
- [ ] Tween con `set_pause_mode(TWEEN_PAUSE_PROCESS)` para avanzar en pausa.
- [ ] `mouse_filter = STOP` mientras hay negro, `IGNORE` al terminar.
- [ ] Fases observables: `is_transitioning()`, `get_fade_alpha()` en la capa;
      `get_transition_phase()` en el caller (`hold`, `fade_out`,
      `scene_change`, `fade_in`, `idle`).
- [ ] Reversión ante error: si `change_scene_to_file()` != `OK`, fade in,
      soltar guard, emitir señal de fallo. No quedarse en negro.
- [ ] `_exit_tree()` libera cualquier lock adquirido (input lock del respawn),
      para que una escena destruida a mitad de transición no trabe el juego.
- [ ] Un solo owner: sistemas piden fade a la capa global, no arman el suyo.
- [ ] Tests que esperan condición observable con timeout, no frames fijos.
- [ ] Cada escena precarga su próxima escena probable en thread y guarda la
      referencia del `PackedScene`; el viaje no hace `load` bloqueante.
- [ ] Tiempo del viaje medido antes y después del arreglo, con números.
- [ ] Viajes entre lugares: dive al destino, captura encima, escena nueva
      debajo, crossfade de la captura y zoom de llegada con ease.
