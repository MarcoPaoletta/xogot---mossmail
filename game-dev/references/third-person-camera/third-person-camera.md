# Cámara tercera persona sin lag ni jitter (playbook)

El "lag de cámara" nos apareció TRES veces en este proyecto, cada vez por una
causa distinta. Este documento junta las tres causas, cómo se diagnostican con
números (no a ojo) y la arquitectura final que las elimina. Portable a
cualquier juego Godot 4.x con CharacterBody3D + cámara que sigue.

---

## Síntomas típicos

- El personaje "flota" descentrado mientras corre y la cámara lo alcanza al
  frenar (banda elástica).
- Micro-tirones (jitter) al moverse, peor en monitores de alta frecuencia.
- Durante saltos o caídas el personaje se corre del centro o la cámara parece
  venir "un paso atrás".

Todos se reportan igual ("hay lag"), pero son tres bugs distintos.

## Causa 1 — Física a 60 Hz vs render a N Hz (jitter)

El `CharacterBody3D` se mueve en `_physics_process` (60 pasos/s). El render va
a 150/500 fps. Si la cámara lee `player.global_position` en `_process`, entre
dos ticks de física el cuerpo NO se movió → la cámara ve una posición
escalonada → jitter.

**Fix (los tres juntos, no alcanza con uno):**

1. Project Settings → `physics/common/physics_interpolation = true`
   (y `physics_jitter_fix = 0.0`, que pelea con la interpolación).
2. La cámara sigue el transform INTERPOLADO, no el crudo:
   ```gdscript
   var body_pos: Vector3 = _player.get_global_transform_interpolated().origin
   ```
3. En CADA teleport (spawn, respawn, reset de run, pooling de proyectiles):
   ```gdscript
   global_position = destino
   reset_physics_interpolation()   # si no, un frame "viaja" desde la pos vieja
   ```
   Esto aplica a TODO lo que se teletransporta, no solo al player: pools de
   proyectiles, plataformas que respawnean, orbes, etc.

## Causa 2 — Lerp exponencial en la POSICIÓN del follow (banda elástica)

El clásico `position = position.lerp(target, 1 - exp(-k*dt))` parece "suave"
pero tiene un error estacionario: siguiendo un objetivo que se mueve a
velocidad `v`, la cámara queda SIEMPRE a `v/k` metros atrás.

Números reales de este juego (`k = 12`):

| Situación | v | Arrastre v/k |
|---|---|---|
| Corriendo | 6 m/s | **0.50 m** |
| Cayendo (terminal) | 24 m/s | **2.0 m** |

Medio metro constante corriendo = el personaje viaja descentrado y "te
alcanza" al frenar. Eso ES el lag que se siente, y ningún ajuste de `k`
razonable lo elimina (k=40 todavía deja 15 cm y se pone nervioso).

**Fix: el follow de posición es RÍGIDO. Sin lerp. Punto.**

```gdscript
global_position = body_pos + Vector3(0.0, follow_height, 0.0)
```

Como `body_pos` ya viene interpolado (Causa 1), el resultado es perfectamente
suave. Fortnite, Mario, Zelda: todos rígidos en posición.

## Causa 3 — Suavizado "solo vertical" con clamp (lag en caídas)

Intento intermedio que también falló: posición horizontal rígida + Y con lerp
clampeado a ±0.8 m ("para suavizar aterrizajes"). Problema: cayendo a 24 m/s
el lerp queda saturado en el borde del clamp → la cámara viaja clavada 0.8 m
ARRIBA del cuerpo toda la caída, y al aterrizar "baja". Se siente como lag
vertical + encuadre raro en el fall.

**Fix: también rígido en Y.** Los aterrizajes no necesitan amortiguación de
posición: la venden el shake (trauma), el squash del personaje y el SFX.

## Dónde SÍ va suavidad

La suavidad exponencial es correcta donde no desplaza el encuadre respecto del
cuerpo:

- **Rotación** de cámara por input (yaw/pitch directos del mouse, sin lerp) y
  sesgos automáticos (mirar abajo al caer) — estos sí con `1-exp(-k*dt)`.
- **FOV y largo del SpringArm** (zoom de apuntado).
- **Shake por trauma** (`shake = trauma²` con ruido) y **punch** de retroceso.
- Cámaras cinemáticas desacopladas (nuestro "detach" al caer al vacío mira al
  jugador con slerp — ahí el desfase es intencional).

## Arquitectura del rig (la que quedó)

```
Player (CharacterBody3D)
└── CameraPivot (Node3D, top_level = true, script de cámara)
    └── SpringArm3D (spring_length, margin; colisiona con paredes)
        └── ArmEnd (Node3D)                ← ¡intermediario obligatorio!
            └── Camera3D (offset de hombro + punch en position)
```

- `top_level` en el pivot: el yaw/pitch de la cámara no hereda nada del body.
- **`ArmEnd` intermedio**: `SpringArm3D` posiciona a TODOS sus hijos directos;
  si ponés el offset de hombro/punch directamente en la `Camera3D` hija del
  spring, el spring te lo pisa. El offset vive en la cámara hija de `ArmEnd`.
- El pivot setea `global_position` rígido en `_process` (Causas 1–3) y
  `rotation = (pitch, yaw, 0)` desde variables propias — nunca lee su rotación
  de vuelta del basis (la descomposición euler cambia de representación por
  cuadrante y un read-modify-write se estabiliza en valores corridos).

## Cómo verificarlo con números (no a ojo)

El "se ve bien" nos falló varias veces. Métrica en pantalla (label de debug):

```gdscript
var body_i: Vector3 = player.get_global_transform_interpolated().origin
var trail_xz: float = Vector2(pivot.global_position.x - body_i.x,
		pivot.global_position.z - body_i.z).length()
var trail_y: float = pivot.global_position.y - body_i.y  # debe = follow_height
```

- Corriendo a velocidad máxima: `trail_xz` debe ser **0.000**.
- Cayendo a velocidad terminal: `trail_y` debe ser exactamente
  `follow_height`, constante.
- Cualquier valor que crece con la velocidad = hay un lerp escondido.

## Checklist para portar

1. `physics_interpolation = ON`, `physics_jitter_fix = 0`.
2. Cámara lee `get_global_transform_interpolated()`.
3. Follow de posición 100% rígido (los 3 ejes).
4. `reset_physics_interpolation()` después de todo teleport (player, pools,
   plataformas, pickups).
5. Rig: pivot `top_level` → SpringArm → ArmEnd → Camera (offsets en la
   cámara, no en hijos directos del spring).
6. Suavidad solo en rotación/FOV/shake/punch.
7. Label de debug con `trail_xz` / `trail_y` y verificar a velocidad máxima.

## Nota relacionada: animación que "se congela" en el aire

Si el salto se ve raro arriba, chequeá que el clip de ascenso dure lo mismo
que `jump_ascent_time` del perfil de movimiento: un clip más corto se congela
en su último frame hasta el apex. Acá el slice de `jump_rise` se hornea
retimeado a 0.58 s exactamente por eso (`tools/generate_painter2_anims.gd`).
