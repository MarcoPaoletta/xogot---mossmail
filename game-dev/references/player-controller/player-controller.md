# Player controller tercera persona: facing correcto + free look

Cómo lograr el comportamiento estándar de shooter en tercera persona:

- **W** = el personaje corre alejándose de cámara → se le ve la **espalda**
- **S** = corre hacia cámara → se le ve el **frente**
- **A / D** = strafe → se le ve el **perfil**
- Mouse libre en ambos ejes (estilo Fortnite), mismo feel horizontal/vertical
- Apuntando, el cuerpo gira para alinear el CAÑÓN con el retículo

Parece trivial. Nos costó TRES bugs no obvios que acá quedan documentados con
sus fixes, porque cualquiera que arme esto desde cero se los va a comer igual.
Referencia: `scripts/player/player.gd` + `scripts/player/player_camera.gd`.

---

## 1. Movimiento relativo a cámara

El stick/WASD se interpreta en el espacio de LA CÁMARA, no del mundo:

```gdscript
func _wish_dir() -> Vector3:
	var cam_basis: Basis = _camera.yaw_basis()   # Basis(Vector3.UP, yaw) — SOLO yaw
	var dir: Vector3 = cam_basis * Vector3(move_input.x, 0.0, move_input.y)
	dir.y = 0.0
	return dir.normalized() * minf(1.0, move_input.length())
```

Clave: `yaw_basis()` usa SOLO el yaw de la cámara (nunca el pitch — si no,
mirar al suelo frenaría el avance). W siempre empuja hacia donde mira la
cámara, proyectado al plano horizontal.

## 2. Facing: el modelo mira hacia el INPUT (no la velocidad)

```gdscript
# Estado guardado del último wish:
_last_wish = wish   # cada tick de física

# En _face_movement():
target_yaw = atan2(_last_wish.x, _last_wish.z)   # espacio MUNDO
var k: float = 1.0 - exp(-16.0 * dt)             # respuesta del giro
_model_yaw = lerp_angle(_model_yaw, target_yaw, k)
_model.rotation = Vector3(0.0, _model_yaw, 0.0)  # triple completo, SIEMPRE
```

Tres decisiones acá, cada una arregla un bug real:

### Bug A — mirar la velocidad se ve "corriendo de costado"

La velocidad persigue al stick con toda la rampa de aceleración (~0.2 s). Si
el modelo mira la VELOCIDAD, en cada cambio de dirección corre torcido mientras
la velocidad converge. **Fix: mirar el INPUT (`_last_wish`)** — la intención,
no el estado físico. La velocidad solo se usa de fallback cuando no hay input
(knockback, hielo).

### Bug B — leer la rotación del basis se estabiliza 90° corrido

El clásico `model.rotation.y = lerp_angle(model.rotation.y, target, k)` es un
read-modify-write sobre el basis. La descomposición euler de Godot cambia de
representación según el cuadrante → el loop de feedback se estabiliza en
valores CORRIDOS (nos pasó: 90° exactos). **Fix: el yaw vive en una variable
propia (`_model_yaw`)** que se interpola y se ESCRIBE como triple euler
completo. Nunca se lee de vuelta del nodo.

### Bug C — el cuerpo físico rotado desplaza todo el sistema

`reset_for_run()` copiaba el `Transform3D` completo del SpawnPoint (que tenía
rotY(+90) para "mirar hacia el nivel") al CharacterBody3D. Nuestro facing se
calcula en MUNDO pero se aplica en espacio LOCAL del body → error constante de
+90° en todo el juego (W mostraba el perfil), que además NO se reproducía en la
escena de pruebas (que no llama a reset). **Fix: el body de física NUNCA
rota** (`rotation = Vector3.ZERO` siempre); del spawn se toma solo la posición,
y su basis solo alimenta el yaw inicial del MODELO y de la cámara:

```gdscript
global_position = spawn.origin
rotation = Vector3.ZERO
_model_yaw = spawn.basis.get_euler().y
_model.rotation = Vector3(0.0, _model_yaw, 0.0)
```

El facing es 100% del modelo visual; la cápsula es simétrica y no necesita
girar jamás.

## 3. Facing mientras se apunta (cañón al retículo)

Apuntando, el cuerpo no mira "adelante": mira lo necesario para que el CAÑÓN
(que la pose de apuntado tuerce respecto de la cadera) quede alineado con la
cámara:

```gdscript
@export var aim_yaw_offset_deg: float = -102.6   # medido, no adivinado
target_yaw = _camera.yaw + PI + deg_to_rad(aim_yaw_offset_deg)
```

El `-102.6` es el twist de columna de la pose de aim: se MIDE con FK sobre el
clip (yaw del vector mano-a-mano MENOS yaw de las piernas) y el offset es su
negativo. El generador de animaciones lo imprime en cada corrida
(`tools/generate_painter2_anims.gd` → "aim pose: ... aim_yaw_offset_deg=X").
Si cambiás de personaje/pose, re-medí; no lo tunees a ojo.

## 4. Free look (mouse y gamepad, ambos ejes)

En `player_camera.gd` (`_unhandled_input` / `_process`):

```gdscript
# Mouse: MISMA tasa angular en X e Y — la trampa clásica es un multiplicador
# extra en pitch que deja el eje vertical 10x más lento y "trabado".
var sens_deg: float = 0.1375 * SettingsManager.mouse_sensitivity   # deg/pixel
yaw   -= deg_to_rad(motion.relative.x * sens_deg)
pitch  = clampf(pitch - motion.relative.y * sens_deg * invert, pitch_min, pitch_max)
```

- `0.1375 °/px` es el estándar de la industria a sensibilidad 1.0 (Fortnite,
  CS). Un solo número para ambos ejes; el slider del usuario lo multiplica.
- `pitch` clampeado (aquí −60°..+45°) e `invert_y` como opción.
- Gamepad: mismas variables, tasa en °/s escalada por `delta`, en `_process`.
- El yaw/pitch se APLICAN como `rotation = Vector3(pitch, yaw, 0)` desde las
  variables propias — misma regla que el modelo: nunca leer el basis de vuelta.
- La cámara sigue al cuerpo en forma rígida y con física interpolada — eso
  tiene su propio documento: `third-person-camera.md`.

## 5. Cómo verificarlo con números

El error de facing NO se juzga a ojo (nos falló varias veces con el escorzo).
Métrica en un label de debug:

```gdscript
# Yaw real del esqueleto vía vector de piernas:
var l: Vector3 = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("LeftUpLeg"))).origin
var r: Vector3 = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("RightUpLeg"))).origin
var legs_yaw: float = rad_to_deg(atan2(Vector3.UP.cross(r - l).x, Vector3.UP.cross(r - l).z))
# vs el yaw comandado:
var delta: float = wrapf(legs_yaw - rad_to_deg(model.rotation.y), -180.0, 180.0)
```

- `delta` debe ser ~0° en todo momento (±5° por el sway del idle es normal).
- Probá la matriz completa CON LA CÁMARA GIRADA a un ángulo arbitrario (no
  solo desde el spawn): W→espalda, S→frente, A/D→perfiles. El Bug C solo
  aparecía con la cámara rotada.
- Para el aim: yaw del vector mano-a-mano vs `camera.yaw + 180` — deben
  coincidir (±5°).

## Checklist para portar

1. Input → `_wish_dir()` con el yaw de la cámara (solo yaw).
2. Modelo visual separado del body; el body con `rotation = ZERO` para
   siempre; spawn aporta posición + yaw inicial del modelo.
3. `_model_yaw` como variable propia, `lerp_angle` con `k = 1-exp(-16·dt)`,
   escritura como triple euler.
4. Facing = input; velocidad solo como fallback sin input.
5. Aim = `cam.yaw + PI + offset_medido` (medí el twist de TU pose).
6. Sensibilidad única en °/px para ambos ejes del mouse; pitch clampeado.
7. Label de debug con `delta(legs-cmd)` y probar con cámara girada.
