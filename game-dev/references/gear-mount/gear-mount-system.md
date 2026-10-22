# Sistema de montaje de equipamiento (GearMount)

Cómo montar props (armas, mochilas, sombreros…) sobre un esqueleto animado,
ajustarlos visualmente en el editor y persistir la calibración en un recurso —
sin que se rompa con animaciones, escalas de rig raras ni re-guardados del
editor. Diseñado en Paintfall para el cañón de pintura y el tanque; portable a
cualquier juego Godot 4.x.

---

## 1. El problema

1. **Los rigs importados no miden en metros.** Los GLB de Meshy (y muchos de
   Mixamo) traen el `Armature` a escala `0.01` (rig en centímetros). Si colgás
   un prop de un hueso, hereda esa escala: o se ve microscópico o tenés que
   escribir números ×100 sin sentido.
2. **El hueso se mueve todo el tiempo.** El prop debe quedar RÍGIDO a la mano
   durante cualquier animación → el offset tiene que vivir en espacio LOCAL del
   hueso… pero los ejes locales de un hueso de mano apuntan a cualquier lado, y
   tunear "X local del hueso" a mano es tortura.
3. **La calibración se pierde.** Si el transform calibrado vive horneado en la
   escena, cualquier guardado del editor en mal momento (o un `@tool` que corre
   antes de tiempo) lo pisa. Nos pasó tres veces antes de blindarlo.

## 2. Arquitectura

Tres piezas (copiar estos archivos para portar):

| Pieza | Archivo | Rol |
|---|---|---|
| `GearMount` | `scripts/player/gear_mount.gd` | `@tool BoneAttachment3D`: aplica el perfil al prop, compensa escala, captura desde el gizmo, preview de poses |
| `WeaponMountProfile` | `scripts/resources/weapon_mount_profile.gd` | Resource con `position_offset` (m), `rotation_degrees_offset`, `scale_factor` — **la única fuente de verdad** |
| `MuzzleTip` | `scripts/player/muzzle_tip.gd` | (opcional) bola visible solo en editor que marca el punto de spawn de proyectiles |

### Jerarquía de nodos (ejemplo del cañón)

```
Player (CharacterBody3D)
├── PainterModel (instancia del GLB)
│   └── Armature (scale 0.01)  ←  el rig en cm
│       └── Skeleton3D
├── BlasterMount (BoneAttachment3D + gear_mount.gd)
│   │     bone_name = "RightHand", use_external_skeleton = ON,
│   │     external_skeleton = ../PainterModel/Armature/Skeleton3D
│   │     mount_profile = blaster_mount.tres
│   └── Blaster (instancia del GLB del arma)  ←  el "gear" (primer hijo)
│       └── Muzzle (MeshInstance3D + muzzle_tip.gd)  ←  spawn de proyectiles
└── TankMount (ídem, bone "Spine", tank_mount.tres)
```

Clave: el mount NO es hijo del esqueleto — usa `use_external_skeleton` para
poder vivir ordenado bajo el Player y sobrevivir a swaps de modelo (cambiamos
el personaje entero por otro con el mismo rig y los mounts ni se enteraron).

## 3. La matemática (compensación de escala)

`_apply()` corre al cargar (editor y juego) y cada vez que cambia un offset:

```gdscript
# La escala se lee del SKELETON, no del propio global_basis del mount:
# el basis del BoneAttachment recién es válido cuando resuelve el bind del
# hueso, y leerlo antes de tiempo horneaba basura en la escena.
var parent_scale: Vector3 = skeleton.global_basis.get_scale()   # p.ej. 0.01
var inv: Vector3 = 1.0 / parent_scale                            # p.ej. 100

gear.position = offset_position * inv        # perfil en METROS → local del hueso
gear.rotation_degrees = offset_rotation_degrees
gear.scale = offset_scale * inv              # perfil en escala MUNDO → local
```

Así el perfil se lee en unidades humanas (`scale_factor = 0.26` = 26 cm en el
mundo) y el prop rendea correcto aunque el rig esté en cm. Si tu rig está en
metros (`parent_scale = 1`), funciona igual sin tocar nada.

## 4. Flujos de calibración

### A. Gizmo del viewport + Capture (recomendado)

1. Seleccioná el **prop hijo** (Blaster/Tank) en el árbol.
2. Movelo/rotalo/escalalo con el gizmo normal de Godot. Con "Use Local Space"
   APAGADO (tecla `T`) las flechas son ejes de MUNDO — lo intuitivo.
3. Seleccioná el **mount** → Inspector → tildá **`Capture From Gear`**.
4. `Ctrl+S`. Listo: quedó en el `.tres`.

Por qué funciona: el gizmo ya convierte tu manipulación mundial al transform
local del hueso; `_capture()` es el inverso exacto de `_apply()` (round-trip
verificado con error 0.000000) y lo guarda en metros/grados.

**Regla de oro: gizmo → Capture → guardar.** Si movés el prop y no capturás,
el perfil lo pisa en la próxima carga (by design: perfil manda).

### B. Números en el inspector

Los tres `offset_*` del mount se editan en vivo y escriben el perfil al
guardar. Útil para retoques finos (+0.01 m); para posicionar de cero usá el
gizmo, porque estos campos están en espacio del hueso.

### C. Preview de poses mientras calibrás

Campos `preview_animation` / `preview_time` en el mount: escribí el nombre de
un clip (`aim`, `run`, `idle`…) y arrastrá el slider — el esqueleto posa y el
prop te sigue. Así calibrás el agarre EN la pose que importa (apuntando), no en
T-pose.

Implementación: muestrea las pistas del `Animation` directamente
(`rotation_track_interpolate` + `set_bone_pose_rotation` hueso por hueso).
**No** usa `AnimationPlayer.play()+seek()`: dentro del editor eso no evalúa la
pose de forma confiable. La pose de preview es cosmética — en runtime el
AnimationTree pisa todo.

### D. Punto de disparo (MuzzleTip)

Bola brillante hija del arma, visible SOLO en editor (`visible =
Engine.is_editor_hint()`). La agarrás con el gizmo y la metés en la boca del
cañón; los proyectiles y el fogonazo spawnean de `muzzle.global_position`.
Como es hija del prop, sigue cualquier recalibración del arma gratis.

## 5. Blindajes (las tres formas en que esto se rompió antes)

Estas guardas están en el código y NO hay que quitarlas:

1. **`_write_profile()` exige `is_node_ready()`.** Al cargar una escena, los
   setters exportados disparan UNO POR UNO antes de `_ready`. Sin la guarda, el
   primer setter escribía el perfil con los otros campos aún en default →
   perfil a medias (así perdimos la escala del tanque: quedó en 1.0 = gigante).
2. **`_write_profile()` exige `Engine.is_editor_hint()`.** El juego jamás
   escribe el perfil (un run no puede romper tu calibración).
3. **`_apply()` lee la escala del skeleton, no del propio basis, y hace
   early-out si no está en el árbol.** El basis del BoneAttachment es basura
   hasta que el bind del hueso resuelve; leerlo antes horneaba transforms
   rotos. Además `_ready` re-aplica en `call_deferred` por si el bind llega
   tarde.
4. **Los transforms del prop en la escena son descartables.** `_apply()` los
   pisa SIEMPRE desde el perfil al cargar. El editor puede re-guardarlos
   horneados — no importa: son deterministas y el perfil manda. Nunca edites el
   transform del prop a mano esperando que persista: usá Capture.

## 6. Checklist para portar a otro juego

1. Copiá `gear_mount.gd`, `weapon_mount_profile.gd` y (opcional)
   `muzzle_tip.gd`.
2. Creá un `WeaponMountProfile` (.tres) por prop:
   click derecho en FileSystem → New Resource → WeaponMountProfile.
3. En tu escena de personaje: agregá un `BoneAttachment3D`, ponele el script
   `gear_mount.gd`, elegí `bone_name`, activá `use_external_skeleton` y
   apuntalo al `Skeleton3D` del modelo.
4. Asignale el `.tres` en `mount_profile` e instanciá el prop como PRIMER hijo
   del mount.
5. (Preview) Asigná `preview_player_path` a un AnimationPlayer que tenga la
   librería de clips — con la librería asignada EN la escena, no en runtime,
   para que el editor la vea.
6. Calibrá con el flujo A y guardá. El `.tres` viaja con el juego; la escena
   puede re-guardarse mil veces sin riesgo.

## 7. Referencias en este proyecto

- Perfiles: `resources/mounts/blaster_mount.tres`, `tank_mount.tres`
- Uso runtime del muzzle: `scripts/player/blaster.gd` (`_fire()` spawnea del
  `Muzzle.global_position`, apuntado al raycast de cámara para que el retículo
  sea honesto)
- Escena de referencia: `scenes/player/player.tscn` (BlasterMount + TankMount)
- Rig de pruebas con gizmos de ejes: `scenes/world/mount_tune.tscn`
