# Menú principal con cortes de cámara sobre el mundo vivo

El menú de Paintfall no es una pantalla estática: es EL MUNDO REAL del juego
con la UI encima, filmado por una cámara que recorre el nivel en planos que se
cortan en seco, como un tráiler en loop. Dos scripts chicos, cero timelines,
todo editable desde el árbol de escena. Portable a cualquier juego Godot 4.x.

---

## La idea

- El menú carga la MISMA escena del juego (`main.tscn`), no una escena aparte:
  las plataformas gotean, los slimes patrullan, los orbes flotan. El jugador ve
  el juego de verdad antes de tocar PLAY.
- Una cámara dedicada (del director) recorre el mundo en una secuencia de
  planos ("shots"). Entre plano y plano hay **corte duro** — sin blend, sin
  fade. El corte es lenguaje de cine: se siente editado, no "una cámara
  volando".
- **Dentro** de cada plano la cámara SIEMPRE se mueve (dolly u órbita, suave).
  Regla del proyecto: nada queda quieto nunca.
- Al tocar PLAY, el director se apaga y la cámara del player toma `current`.

## Arquitectura (2 scripts)

| Pieza | Archivo | Rol |
|---|---|---|
| `MenuCameraDirector` | `scripts/ui/menu_camera_director.gd` | `@tool Node3D` con una `Camera3D` hija; reproduce los shots hijos en orden de árbol, en loop |
| `MenuCameraShot` | `scripts/ui/menu_camera_shot.gd` | `@tool Node3D`: SU PROPIO transform es el encuadre inicial; exports definen el movimiento |

### Jerarquía en la escena

```
Main
└── MenuCameraDirector (menu_camera_director.gd)
    ├── Camera3D              ← la única cámara del menú
    ├── ShotHubOrbit  (MenuCameraShot)
    ├── ShotShallows  (MenuCameraShot)
    ├── ShotDripDolly (MenuCameraShot)
    └── ShotWellPush  (MenuCameraShot)
```

**El orden del árbol ES la secuencia.** Reordenás nodos = reordenás el montaje.
`enabled = false` en un shot lo saca del loop sin borrarlo.

## Anatomía de un shot

Cada `MenuCameraShot` es un Node3D: lo posicionás en el editor MIRANDO lo que
quieras encuadrar (su transform es el frame inicial del plano). Después:

- `duration` — segundos del plano (3–4 s va bien; más corto = más nervio).
- `fov` — focal por plano (FOV bajo ≈ teleobjetivo, comprime; alto ≈ angular).
- `movement`:
  - **STATIC** — se queda en el transform (usalo poco: rompe la regla de que
    nada esté quieto).
  - **MOVE** — dolly: `end_offset` (a dónde llega, relativo al inicio) y
    opcional `end_rotation_offset_degrees` (paneo durante el viaje).
  - **ORBIT** — orbita `orbit_degrees` grados alrededor de `orbit_target`
    (punto en mundo), manteniendo la distancia inicial.
- `look_at_target` + `look_target` — fuerza a mirar un punto fijo durante todo
  el plano (para órbitas alrededor de un héroe: el pozo, el personaje…).
- `ease_ends` — smoothstep (`t·t·(3−2t)`): el movimiento arranca y termina
  suave DENTRO del plano; el corte entre planos sigue siendo seco.

### El corte

`_advance()` simplemente asigna el siguiente shot y setea el `fov`. El próximo
`_process` samplea el shot nuevo en `t=0` → **teleport de cámara en un frame**.
Eso es todo: no hay tween que "viaje" entre planos. Si un corte se siente mal,
el problema es de MONTAJE (dos planos muy parecidos): cortá a un encuadre bien
distinto (otro ángulo, otra distancia, otra zona).

## Preview en el editor (sin correr el juego)

El director es `@tool` y expone:

- `preview_shot` — índice del plano a previsualizar.
- `preview_t` — slider 0→1 que scrubea el plano completo (con su ease).

Seleccionás el director, movés el slider y ves EXACTAMENTE el encuadre en el
viewport. Iterar el montaje toma segundos y no hay que tocar código.

## Integración con el flujo de juego

```gdscript
# Al entrar al estado MENU:
_menu_director.active = true          # resetea a shot 0 y arranca el loop
_menu_director.make_current()

# Al tocar PLAY (estado PLAYING):
_menu_director.active = false         # el loop se congela
_player.camera_rig().camera().current = true   # handoff a la cámara de juego
```

`active` es un setter: al encender resetea `_shot_index = -1` y avanza — el
menú siempre arranca con el mismo primer plano (montaje determinista).

## Recetas de planos que funcionan

- **Órbita lenta al héroe**: ORBIT 30–45° con `look_at_target` al punto de
  interés. El plano clásico de menú.
- **Dolly descendente**: MOVE con `end_offset = (0, −2, 0)` bajando hacia la
  acción, FOV 55–65.
- **Paneo revelador**: MOVE con offset lateral + `end_rotation_offset` en Y:
  la cámara viaja y gira descubriendo el nivel.
- **Tele comprimido**: STATIC o MOVE mínimo con FOV 35–45 desde lejos: capas
  de plataformas apiladas en profundidad.
- Alterná distancia y dirección entre planos consecutivos: primer plano →
  general → medio. Nunca dos planos gemelos seguidos.

## Checklist para portar

1. Copiá `menu_camera_director.gd` y `menu_camera_shot.gd`.
2. En tu escena de mundo: `MenuCameraDirector` + `Camera3D` hija + 3–5 shots
   hijos posicionados con el editor.
3. Estado MENU: `active = true` + `make_current()`. Estado PLAYING:
   `active = false` + tu cámara de gameplay a `current`.
4. La UI del menú va en un `CanvasLayer` encima; el mundo debe VIVIR detrás
   (animaciones ambientales, NPCs, partículas) — un mundo congelado mata el
   efecto.
