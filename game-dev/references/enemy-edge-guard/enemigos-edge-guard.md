# Edge-guard: enemigos de plataforma que NO se tiran al vacío

Cómo hacer que un enemigo que persigue al jugador sobre plataformas
flotantes se frene en el borde en vez de suicidarse, sin navmesh y con un
solo raycast.

Referencia viva: `scripts/enemies/paint_slime.gd` (`_floor_ahead()`),
lab de regresión: `tests/respawn_lab.tscn` + `tests/respawn_lab.gd`.

---

## 1. El problema

Un chaser ingenuo hace `dir = player.pos - self.pos` y avanza. En un mundo
de islas flotantes eso significa que el enemigo se tira del borde apenas el
jugador cruza un hueco. Gracioso una vez; después el nivel se queda sin
enemigos y el loop de juego muere.

## 2. La idea: chequear el punto de ATERRIZAJE, no "adelante mío"

El clásico ray-hacia-abajo-a-distancia-fija falla con enemigos que SALTAN:
el salto cubre una distancia discreta que depende de su velocidad. Lo
correcto es predecir dónde termina el movimiento y preguntar si AHÍ hay piso:

```gdscript
func _floor_ahead(dir: Vector3, speed: float) -> bool:
	# Arco del salto: vy 4.6 contra g 22 -> ~0.42 s de vuelo.
	# Distancia horizontal = velocidad_horizontal * tiempo_de_vuelo.
	var land: Vector3 = global_position + dir * speed * 1.6 * 0.42
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		land + Vector3.UP * 0.6, land + Vector3.DOWN * 3.0, 1)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()
```

Y en el tick de decisión, ANTES de comprometer el salto:

```gdscript
if not _floor_ahead(dir, speed):
	_hop_cooldown = 0.35   # reintenta pronto; NO salta
else:
	velocity = dir * speed * 1.6
	velocity.y = 4.6
	...
```

Detalles que importan:

- **`land` sale de la MISMA fórmula que el movimiento real.** Acá el salto
  aplica `velocity = dir * speed * 1.6` y el airtime es `2·vy/g = 2·4.6/22
  ≈ 0.42 s`. Si cambiás vy o la gravedad del enemigo, recalculá el 0.42 o
  el guard miente.
- **Ray desde +0.6 hasta −3.0 del punto de aterrizaje.** El margen superior
  tolera bordes con lip; los 3 m hacia abajo aceptan aterrizar en una
  plataforma algo más baja (drop chico intencional) pero rechazan el vacío.
- **Máscara = capa 1 (mundo).** Cuenta plataformas Y los colliders de props
  (`decoracion-props.md`) como piso. NO cuenta a otros enemigos ni al player
  como "piso" — correcto: no queremos que salte sobre la cabeza de otro
  slime que se va a mover.
- **`exclude = [get_rid()]`** por higiene (con land adelantado casi nunca se
  auto-golpea, pero un enemigo gordo sí).

## 3. Qué hacer cuando NO hay piso (decisión de diseño)

Cuatro opciones, elegí la que pidió el diseño, no la más cómoda:

1. **Defender el borde** (este proyecto): cooldown corto (0.35 s) y
   re-chequear. El enemigo queda amenazante en el borde, mirando al jugador.
   Si el jugador vuelve a la plataforma, retoma la persecución al instante.
2. **Flipear y patrullar**: invertir la dirección y caminar para el otro
   lado. Mejor para enemigos "tontos" tipo goomba sin aggro. La receta
   concreta que pidió Starling (el Gloamling, un caminante que patrulla la
   plataforma) fue esta secuencia atómica cuando el lookahead no encuentra
   piso adelante:
   1. Marcar `edge_hold` (un flag de estado, no un movimiento).
   2. Invertir `_patrol_direction`.
   3. Actualizar el facing EN EL ACTO, no en el próximo frame. Si el facing
      se difiere, el enemigo camina un instante mirando para el lado
      equivocado y se lee como bug.
   4. Bloquear otra decisión de borde durante un lock de `0.42 s`. Sin el
      lock, el enemigo puede re-decidir el mismo frame y quedar oscilando
      contra el borde.
   5. Caminar hacia atrás SÓLO si también hay piso ahí. Flipear no garantiza
      piso del otro lado: el mismo chequeo de landing vale para la nueva
      dirección (una plataforma de un solo bloque tiene vacío a ambos lados).
3. **Replegarse (retreat)**: alejarse del jugador manteniéndose sobre piso,
   como conducta distinta de patrullar. Patrullar es indiferente al jugador
   (va y viene); replegarse es una reacción AL jugador (retroceder cuando se
   acerca, aguantar la distancia). Son criterios de aceptación distintos: un
   test de patrulla no valida un repliegue.
4. **Rodear (reroute)**: probar direcciones alternativas (±45°, ±90° del dir
   al player) y tomar la primera con piso. Más listo, más caro; hacerlo solo
   si el nivel tiene puentes que valga la pena encontrar.

Para enemigos CAMINANTES (sin salto), mismo patrón con lookahead temporal:
`land = pos + dir * speed * t_lookahead` (t ≈ 0.3–0.5 s). Chequear cada
tick es barato: es UN raycast.

### 3b. Telegraph y lunge: revalidar soporte DESPUÉS del telegraph

Un atacante que se abalanza (lunge) no se mueve a `speed` normal: cubre una
distancia real de `speed × multiplier × ventana_activa`. Ese alcance hay que
calcularlo con los valores reales del ataque, no con la velocidad de patrulla.

Y el punto clave: **re-chequear el piso DESPUÉS del telegraph, justo antes de
comprometer el lunge.** El resultado del chequeo previo al telegraph puede
quedar obsoleto: entre que el enemigo telegrafía y que se lanza pasan cientos
de milisegundos, y en ese lapso el jugador se movió, la plataforma pudo
correrse o el propio enemigo ya no está donde estaba. Un lunge que validó
soporte al empezar el telegraph y no re-valida al lanzarse se tira al vacío
con un resultado viejo.

Ojo también con un `edge_probe_down` demasiado profundo. En Starling, el
Fogmite tenía un override de `edge_probe_down = 1000` que se eliminó: un probe
hacia abajo tan generoso trata una plataforma MUY por debajo como destino
seguro y acepta el vacío como piso. El alcance del probe hacia abajo tiene que
tolerar un drop chico intencional y rechazar la caída larga, no barrer medio
nivel hacia abajo.

## 4. Limitaciones conocidas

- **Plataformas móviles:** el ray ve el piso de AHORA; si la plataforma se
  corre durante el vuelo, el enemigo puede caer igual. Aceptable (raro y
  hasta divertido). Fix real si molesta: predecir con la velocidad de la
  AnimatableBody3D.
- El guard corre solo `if is_on_floor()`: un enemigo empujado en el aire
  (knockback) no se protege — intencional, el knockback al vacío ES la
  mecánica del juego.

## 5. Verificación numérica: el patrón diferencial

**Meta-regla: la aceptación tiene que COINCIDIR con la conducta pedida, no
basta con "no se cayó".** Defender el borde y flipear son criterios de
aceptación DISTINTOS. En Starling el patrón de referencia defendía el borde,
pero el usuario pidió que el enemigo flipeara y caminara para el otro lado:
un test que sólo verifica "no cayó al vacío" da verde con el enemigo
defendiendo (que NO era lo pedido), o peor, con un enemigo congelado o
bugueado. El test tiene que nombrar la conducta requerida y verificar ESA.

Para la variante flip, el test diferencial además de "con hueco no cae" tiene
que verificar que **el facing cambió** y que **caminó al lado opuesto**
(facing distinto + desplazamiento en la dirección contraria), y sobre piso
continuo que igual avanza. Y tiene que **esperar MÁS que el lock de borde
(0,42 s)**: si el assert corre antes de que venza el lock, mide al enemigo
todavía bloqueado y el resultado no dice nada.

Ojo con el falso verde: "no se movió" también pasa si el enemigo está
dormido/bugueado. El lab prueba EL MISMO enemigo en ambas condiciones:

```text
LAB EDGE  drift=0.00 y0=0.48 y1=0.48 fell=false -> PASS  # con hueco: se queda
LAB CHASE drift=4.31                            -> PASS  # con piso: persigue
```

Setup (`tests/respawn_lab.tscn`): dos plataformas 3×3 separadas, slime en
una, player real en la otra (aggro 12 m cubre el hueco). Fase 1 mide drift
XZ y caída durante 2.5 s (debe ser ~0). Fase 1b teletransporta el slime a
piso continuo y exige drift > 0.4 en 1.2 s. Sin la fase diferencial, un
enemigo sin aggro daría PASS falso en la fase 1.

## 6. Checklist de porteo

- [ ] Derivar `land` de la fórmula REAL de movimiento (salto: v_h · t_vuelo;
      caminata: v · t_lookahead).
- [ ] Ray de `land+0.6` a `land−3.0`, máscara = solo capas de mundo/piso.
- [ ] Decidir y NOMBRAR el comportamiento sin piso: defender borde / flipear
      y patrullar / replegarse / rodear. La aceptación verifica ESE, no "no
      se cayó".
- [ ] Cooldown corto al bloquear (no spamear el ray cada frame si es caro).
- [ ] Variante flip: `edge_hold`, invertir dirección, facing en el acto,
      lock (0,42 s), caminar atrás sólo si hay piso ahí.
- [ ] Lunge: alcance real = speed × multiplier × ventana activa, y re-chequear
      soporte DESPUÉS del telegraph (el resultado previo queda obsoleto).
- [ ] Probe hacia abajo acotado: rechazar el vacío, no aceptar una plataforma
      muy baja como destino seguro (nada de `edge_probe_down = 1000`).
- [ ] Sincronizar constantes si cambia la física del enemigo (vy, gravedad).
- [ ] Test diferencial: mismo enemigo, con hueco (drift ≈ 0) y con piso
      (drift > umbral). Nunca solo el caso negativo. Para la variante flip,
      el test verifica cambio de facing + desplazamiento contrario y espera
      más que el lock de borde (0,42 s).
