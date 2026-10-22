# Ambientación con props: decorar niveles con colisión real

Cómo vestir un nivel con props (latas, tambores, rocas, carteles, baldes…)
para que el mundo se sienta habitado, SIN que el jugador los atraviese como
hologramas y sin ensuciar los assets visuales con física.

Referencia viva: `scenes/world/main.tscn` (Hub / Shallows / Drip / DeepEnd),
sub_resources `prop_col_*`.

---

## 1. El problema

- Un nivel de plataformas "pelado" (solo plataformas + enemigos) se siente
  a test map, no a lugar.
- Props solo-visuales se atraviesan → rompen la ilusión al primer roce.
- Meter colliders DENTRO de cada escena de prop (GLB importado) es frágil:
  el import se regenera, las escalas varían por instancia, y un mesh collider
  por prop es caro y granuloso.

## 2. Arquitectura: visual y colisión SEPARADOS

El prop visual es una instancia común (`instance=ExtResource(...)`) con el
transform que quieras (rotado, escalado, medio hundido). La colisión es un
**StaticBody3D hermano**, con un **shape primitivo compartido** vía
`sub_resource`:

```text
[sub_resource type="CylinderShape3D" id="prop_col_can"]
radius = 0.42
height = 0.85

[node name="PaintCanHubB" parent="Hub" instance=ExtResource("29_can")]
transform = ...            # visual: rotado/escalado libre

[node name="CanHubBBody" type="StaticBody3D" parent="Hub"]
transform = Transform3D(1,0,0, 0,1,0, 0,0,1, -2, 0, -7.5)   # base del prop

[node name="Shape" type="CollisionShape3D" parent="Hub/CanHubBBody"]
transform = Transform3D(1,0,0, 0,1,0, 0,0,1, 0, 0.45, 0)    # y = height/2
shape = SubResource("prop_col_can")
```

Por qué así:

- **Un shape por FAMILIA de prop, no por instancia.** Seis sub_resources
  cubren todo el juego: `can`, `drum`, `bucket` (cilindros), `post`
  (cilindro finito para carteles), `easel`, `rock` (cajas).
- **El body va en la BASE del prop** (y = piso), y el CollisionShape3D hijo
  se offsetea `height/2` hacia arriba. Así el mismo shape sirve en cualquier
  plataforma sin recalcular centros.
- **Capa de colisión = 1 (mundo).** El player ya colisiona con la capa 1;
  cero configuración extra. Bonus: el raycast anti-caída de los enemigos
  (ver `enemigos-edge-guard.md`) también los ve como piso — un slime arriba
  de un tambor es válido.
- El visual puede ser reemplazado/re-escalado sin tocar física.

### Paleta de shapes de este proyecto

| Shape           | Tipo     | Medidas            | Para                    |
|-----------------|----------|--------------------|-------------------------|
| `prop_col_can`  | Cylinder | r 0.42 × h 0.85    | latas de pintura        |
| `prop_col_drum` | Cylinder | r 0.95 × h 1.7     | tambores 200 L          |
| `prop_col_bucket`| Cylinder| r 0.8 × h 1.5      | pilas de baldes         |
| `prop_col_post` | Cylinder | r 0.15 × h 2.2     | POSTE del cartel (solo) |
| `prop_col_easel`| Box      | 1.7 × 1.8 × 0.6    | caballete (rotar body)  |
| `prop_col_rock` | Box      | 2.3 × 1.5 × 2.3    | rocas medianas          |

Regla: el collider es SIEMPRE un poco más chico que el visual. Rozar y pasar
se siente bien; chocar con aire invisible alrededor de un prop, horrible.

## 3. Reglas de composición (lo que hace que "ambiente")

1. **Agrupar, no espolvorear.** Tres props juntos (tambor + lata + roca)
   cuentan una historia; los mismos tres equiespaciados parecen random.
   El Hub usa clusters en los bordes, centro despejado para jugar.
2. **Variar rotación y escala SIEMPRE.** Dos instancias del mismo prop nunca
   con el mismo yaw ni la misma escala (0.7–1.6 en este proyecto). El basis
   rotado se escribe directo en el `transform` del visual.
3. **Nunca sobre la línea de salto.** Antes de ubicar un prop en una
   plataforma chica, mirar desde dónde salta y aterriza el player. Props al
   borde de la ruta, no en el medio. (Nos pasó: el cartel del Hub quedó
   EXACTO en la línea recta spawn→Shallows; jugable porque se esquiva, pero
   el playtest automático chocaba de frente. Ver §5.)
4. **Altura correcta = base del prop en el TOP de la plataforma.** En este
   proyecto el top de cada plataforma ≈ su `y` de nodo, así que un prop con
   origen en su centro va a `y_plataforma + alto/2` (latas +0.28, tambores
   +0.55). Si el prop queda flotando 5 cm se nota SIEMPRE.
5. **Decoración fuera de alcance NO lleva collider.** Rocas flotantes
   lejanas, props tumbados muy bajos (la brocha del Hub): collider ahí es
   gasto y molestia (trip hazards invisibles).
6. **Carteles: collider solo en el poste.** El cartel entero como caja
   bloquea saltos; el poste finito (r 0.15) se rodea natural.

## 4. Props hijos de plataformas MÓVILES

Si el prop visual es hijo de una plataforma (p. ej. tambor sobre D8), su
body estático NO puede ser hermano en coordenadas mundo… salvo que la
plataforma no se mueva. En este proyecto los props solo decoran plataformas
estáticas, así que el body hermano en mundo alcanza. Si la plataforma se
mueve: el body debe ser HIJO de la plataforma (AnimatableBody3D la arrastra)
— y ojo con `[editable]` si la plataforma es una instancia (ver abajo).

## 5. Verificación (numérica, no a ojo)

Playtest: caminar de frente contra el prop y leer telemetría:

```text
pos=(8.2, -0.1, 1.5)  speed=0.00      # W sostenida contra el poste (x=9)
```

Player FRENADO con input sostenido = collider funciona. Antes del fix
atravesaba el prop y `pos.x` seguía creciendo. No confiar en el screenshot:
la cámara en tercera persona esconde interpenetraciones chicas.

## 6. Trampas de serialización (.tscn a mano)

- Los `sub_resource` van ANTES del primer `[node]`; si un nodo referencia un
  shape no declarado, Godot **revierte el archivo entero** al validar.
- Si editás una escena que está ABIERTA en el editor, el editor puede
  re-guardar su copia en memoria y PISAR tus ediciones de disco. Estacionar
  el editor en otra escena antes de editar, recargar después.
- Overrides sobre hijos de instancias necesitan tag `[editable path="..."]`
  o el editor los descarta en silencio al guardar.

## 7. Checklist de porteo

- [ ] Definir la paleta de shapes (4–6 primitivas compartidas máximo).
- [ ] Patrón visual + StaticBody3D hermano; body en la base, shape a h/2.
- [ ] Capa de colisión = la misma que el suelo del mundo.
- [ ] Clusters en bordes, rutas de salto despejadas, rotación/escala variada.
- [ ] Sin collider: decoración lejana y props bajos tumbados.
- [ ] Verificar caminando CONTRA cada prop nuevo: speed debe caer a 0.
