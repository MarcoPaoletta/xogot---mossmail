# UI mobile, touch y tutorial guiado en Godot 2D

Referencia destilada de Idle Acres, Godot 4.7, renderer Mobile, un farm builder top down probado en
desktop y en un Xiaomi real. Aplica cuando una UI 2D tiene HUD persistente, catálogo horizontal,
placement por grilla, tutorial con spotlight, personajes 2D por expresiones o export Android.

## 1. El teléfono real es el canvas de revisión

El error más caro fue revisar demasiado tiempo en un 16:9 genérico. El shop podía verse aceptable en
desktop y salir cortado en el Xiaomi. El contrato correcto:

1. Medir la resolución y el aspect del device real.
2. Usar ese aspect también en el desktop preview.
3. Anclar cada bloque del HUD a su propio borde, no a una caja centrada.
4. Validar cada cambio de layout con captura runtime en ese viewport.
5. Validar touch, gesture bar y entrega sobre el teléfono físico.

El screenshot de una UI aislada no alcanza. Tomar además una captura sobre la zona más cargada del
mundo y con cada panel grande abierto. Ahí aparecen recortes, oclusión, márgenes falsos y advisor
escalado de más.

## 2. Geometría de arte y tipografía

### 2a. La imagen manda su aspect

Íconos y portraits conservan aspect. Las cápsulas conservan el aspect de la fuente y derivan height
desde width. Si el rect coincide con el aspect de la fuente, una escala uniforme preserva mejor el
outline que dividir el arte en nueve bandas. Reservar 9-patch para panels que realmente cambian de
forma.

La zona clara interior es el content rect real. Título, descripción, arte y costo se miden contra esa
zona, no contra el bounding box exterior. El arte puede superponerse de forma controlada con otro
elemento. El texto y el precio no pueden meterse en el borde.

### 2b. Best fit, no texto cortado

No truncar ni tapar copy para hacerlo entrar. Darle al Label el width correcto y activar un rango de
font size con mínimo explícito. Ajustar también la altura del Label para que su baseline quede dentro
de la zona clara. Verificar el texto más largo real, no un placeholder corto.

Marco prefiere UI grande y legible. Cuando una card no lee, primero agrandar tipografía, íconos y la
card levemente. Resolver overlap con estructura y fit. Achicar toda la interfaz es el último recurso.

### 2c. Medir grupos, no nodos sueltos

Un wallet compacto tiene ícono más valor como un solo grupo visual. El valor va cerca del ícono y
alineado a izquierda, no pegado al borde derecho de una cápsula ancha. Lo mismo aplica a costos,
recompensas offline y storage: medir el ancho total del grupo y centrar el grupo completo.

Para storage, `Wheat: 21` comunica mejor que un ícono y un 21 separados por media pantalla. Los
botones inferiores necesitan padding real respecto del frame y respecto de cualquier tray que suba
desde abajo.

## 3. Catálogos horizontales sin huecos

Una lista data driven sigue siendo UI authorable. Cada card existe en la escena y referencia su data
desde inspector. El código sólo bindea datos, ordena, filtra y reacciona a cambios.

Contrato del catálogo:

1. Cards desbloqueadas primero.
2. Después, máximo una card bloqueada por product id.
3. Cards con data nula se ocultan.
4. Duplicados se ocultan.
5. Variantes authoradas pero omitidas llevan un flag semántico, por ejemplo `show_in_catalog`.
6. Todo lo omitido se pone invisible antes de pedir sort y reflow al Container.

El bug medido fue un `WellCard` authorado entre un pond y el primer locked product. Su contenido no
debía aparecer, pero el slot seguía visible y creó un hueco enorme. Ocultarlo confirmó la causa. La
fix durable fue `show_in_catalog = false` más filtrado antes del sort, no depender del ojo del editor.

La card necesita suficiente width y height para title, rate, thumbnail, unlock caption y costos. El
coin y su precio son una pareja compacta. Si hay previews de animales, quedan detrás del texto y el
costo. Un frame idle comunica el pen sin robar la jerarquía.

### Reactividad mientras está abierto

Actualizar sólo al abrir y cerrar deja precios o estados stale. La lista escucha todos los inputs de
affordability: coins, goods, unlock progression y cualquier grant de debug. El refresh ocurre con el
shop abierto y preserva el scroll cuando sea posible.

## 4. Placement repetido y movimiento directo

Después de colocar un item, mantenerlo seleccionado permite tocar otra celda y construir otra copia.
Cada drop válido vuelve a comprobar affordability y cobra. Cancelar, cerrar el shop o elegir otra card
desarma la selección.

El dirt path es una operación de terreno y se pinta en muchas celdas consecutivas. Si el diseño lo
declara gratis, no mostrar ni cobrar un costo falso. Debe producir el mismo terreno visual que el dirt
authorado de base.

La grilla construible sigue lo que el jugador ve. Si un área parece pasto libre y no acepta placement,
la affordance miente. Expandir bounds hasta cubrir el terreno visible y conservar sólo blockers con
una razón visual clara.

Todo prop colocado y todo prop de arranque usa el mismo contrato de move. Esto incluye decoraciones,
pozos, pens, productores y edificios especiales si el diseño lo permite. Un long press entra directo
en move y no abre antes el panel Move/Sell. El botón Move queda como ruta alternativa para un tap
normal.

## 5. Tutorial tipo spotlight

La secuencia se siente limpia cuando cada fase tiene owner:

1. El advisor habla.
2. El jugador toca para reconocer la instrucción.
3. El advisor sale con tween.
4. El overlay oscuro hace fade in.
5. La máscara revela sólo el target.
6. La mano aparece animada y apunta con la punta real del dedo.
7. Sólo el target recibe input.

La mano es decorativa: `mouse_filter = IGNORE` o equivalente, sin raycast target. La posición se
calibra desde el fingertip, no desde el centro del PNG. Un offset en espacio local se conserva cuando
la mano rota; un offset global hace que algunos pasos queden arriba del target y la mano desaparezca
fuera de pantalla.

Antes de pedir un gesto espacial, cerrar cualquier panel que lo tape. En el caso medido, el tutorial
debía obligar a cerrar el shop antes de pedir mover una flor. El trigo se enseña con una colocación
exitosa. Pedir dos repite la lección y dejó el state machine trabado.

Cada transición escucha un evento de dominio: shop closed, item selected, placement completed, move
started, move committed. No avanzar por timers ciegos ni por la mera visibilidad de un panel.

## 6. Advisor, animales y sprites por estado

Makko genera expresiones y animaciones en canvases distintos. Un scale global produce un personaje
que crece o encoge entre estados. Calibrar cada clip o expresión contra dos referencias:

1. Altura aparente objetivo.
2. Línea de piso compartida.

Primero ajustar scale. Después ajustar Y para que los pies vuelvan a la misma coordenada. Verificar
frame cero, el clip completo y las transiciones idle, walk y vuelta a idle. El bubble también puede
necesitar offset por expresión, pero el advisor no debe cambiar su Y base al abrir el shop.

Anclar el personaje a su propio piso no alcanza si el LUGAR donde se para cambia: cada muelle, isla o
asiento lleva su propio anchor medido sobre su arte, y el pase de un sprite a otro (parado a sentado)
se hace sin salto visible. Receta en `character-anchors-handover/`.

Y sorting usa el contacto con el suelo o front edge. Un barril puede tapar un árbol si ordena por el
centro del canvas. Definir pivot en la base o calcular el sort origin desde los pies.

## 7. Luz y lectura del mundo

No convertir cada edificio en emisor de luz. Las lámparas son la affordance de iluminación. Su pool
aparece después del dusk y el glow se dibuja detrás o alrededor del poste. Un punto brillante adelante
del sprite, mal posicionado y sin área iluminada, se lee como bug.

Los edificios quedan estáticos. La vida visual viene de animales, cultivos, labels de ready,
partículas y luz. El menú puede mostrar el mismo mundo vestido con granja, pens, animales, paths y
decoraciones, pero su composición respeta Y sorting y no usa props como collage plano.

## 8. Seams de tiles en PC

Una línea negra fina entre filas de tiles, visible sólo en PC/editor, no implica arte roto. El caso
medido usaba canvas de diseño `2460x1080` y ventana desktop `1640x720`, una escala fraccionaria
`2/3`. Con `canvas_items`, Godot rasterizaba CanvasItems ya escalados y pixel snap no alcanzaba para
evitar una fila subpíxel. La solución fue componer el frame completo a la resolución de diseño con
`viewport` y recién después reducirlo. Configuración final:

```text
display/window/stretch/mode = "viewport"
rendering/2d/snap/snap_2d_vertices_to_pixel = true
rendering/2d/snap/snap_2d_transforms_to_pixel = true
```

Las tres son parte del arreglo cuando el preview desktop usa una escala fraccionaria. En el teléfono
1:1, `viewport` no agrega una segunda escala. No cambiar HD painted art a nearest como workaround.
Verificar en el framebuffer exacto donde aparecía la línea.

## 9. Shipping Android

Exportar el APK no cierra la tarea. El gate mínimo es:

1. Instalar el APK exacto con ADB.
2. Limpiar logcat y lanzar la activity.
3. Esperar y confirmar PID vivo.
4. Confirmar activity resumed y ventana focused.
5. Leer el crash buffer.
6. Hacer screencap en el device y mirarlo.

Regla de Marco (2026-10-10, ampliada el 2026-10-13 a todo juego final en PC y móvil):
**todo APK se exporta con `display/window/stretch/aspect="expand"`** para
que no haya barras negras en el teléfono (`keep` las deja en cualquier pantalla que no sea la
proporción de diseño). Se verifica ANTES de exportar leyendo `project.godot`, y en el paso 6 del gate
se mira la captura: sin barras negras, HUD pegado a los bordes con sus anchors, nada cortado ni
descentrado por la safe area (notch), y la cámara del mundo cubriendo el ancho/alto extra. Si el HUD
estaba pensado para `keep`, se arregla el anclaje antes de entregar, no se vuelve a `keep`.
También se revisan menús, diálogos, pausa, resultados, legibilidad del texto,
controles y gameplay completo en distintos tamaños, con evidencia runtime.
Matriz y criterio común: `../launch-settings/launch-settings.md`.

El APK exacto se deja SIEMPRE en `<proyecto>/build/` (un solo APK, el de la versión final, regenerado en cada cambio
mientras Marco lo tenga pedido; desde 2026-10-21 ya no va a Downloads: SKILL.md, "Builds (APK / EXE)" y `../build-exports/`). Si el dispositivo no aparece, decir
con claridad que todavía no fue instalado. No confundir `export succeeded` con `app opens`.

## 10. Controles, anillos y HUD de un juego de vehículo (Reedway Ferry, 2026-09-24)

Reedway Ferry (Makko, Godot 4.7.2) es un ferry top down que se maneja solo con joystick. Estas son
las decisiones de Marco a lo largo de siete rondas de feedback; las reglas finales del proyecto están
en su `docs/UI_RULES.md`.

### 10a. Joystick: fijo, respuesta final

- Historial: flotante fue "awful", fijo abajo a la izquierda estaba bien, "se mueve a donde apretás"
  se probó y se revirtió. ⛔ **Final: fijo, abajo al centro en PC y abajo a la izquierda en teléfono**
  (`OS.has_feature("mobile")`). Lo agarra un press sobre él o a menos de ~1,9 radios de la base; un
  press en otro lado no hace nada. El knob se clampa en el borde y vuelve con resorte.
- **La distancia del empuje es el acelerador:** medio empuje, media velocidad; aflojar baja la
  velocidad de a poco. Zona muerta 12 %, pleno al 90 %. Se muestra con un anillo dorado que se llena
  alrededor del borde.
- **Solo joystick, sin teclado para dirigir.** Cuando el joystick es el único control del juego,
  también se ve en PC: es la excepción a la regla de esconder el touch en desktop (SKILL.md, Cameras).

### 10b. Interacción por anillo: un segundo, a cualquier velocidad

- ⛔ **Un segundo en cualquier punto adentro del anillo, a cualquier velocidad**, con un arco de
  progreso que se llena. Exigir además frenar se sintió como tres segundos.
- **Los anillos se esconden salvo donde hay que dejar a alguien que va a bordo.** En un pickup solo
  se ve el arco de progreso.
- ⚠️ Trampa: un muelle que además es el puerto (su anillo está siempre "activo") no puede quedar
  afuera del timer de entrega. El timer se habilita por "hay alguien para dejar o levantar", nunca
  por el estado visual del anillo.

### 10c. HUD mínimo

Se sacó el panel de asientos (los pasajeros ya se ven en el barco) y la vida del casco pasó arriba a
la derecha. Flecha guía a mitad de tamaño, 65 % de opacidad, sin la imagen del destino. Si el mundo
ya muestra un dato, el HUD no lo repite.

### 10d. Pantalla de título

- Sin overlay oscuro, sin HUD ni joystick detrás, el agua del mundo de fondo, el panel a la derecha,
  y a la izquierda un **showcase que hace crossfade** entre pares isla y pasajero cada 2,5 s.
- ⛔ **Un crossfade es que los dos se desvanecen A LA VEZ**, no uno después del otro. Cada par va
  adentro de un `CanvasGroup`, así el personaje no se vuelve transparente encima de su isla a mitad
  del fade.

### 10e. Constructor de pueblo y monedas

- Los edificios arrancan **100 % negros** (base incluida) y el color sube de abajo hacia arriba a
  medida que se pagan monedas.
- ⛔ **El orden de desbloqueo es lineal, cada edificio vecino del anterior.** Marco dibujó el orden
  exacto con números sobre una captura: cuando da un orden, se usa literal.
- ⛔ **Cada edificio tiene que hacer algo visible:** un bonus por tipo (casco, velocidad, giro,
  aceleración, tarifas, daño por choque) que se muestra en un popup cuando se completa.
- **Juice de monedas:** muchas (70 por desbloqueo, dos por lanzamiento a hasta 80 lanzamientos por
  segundo), volando en un `CanvasLayer` por encima de toda la UI, re-apuntadas al edificio en cada
  frame, achicándose y desvaneciéndose al llegar.
- **Tag de precio:** mitad de tamaño, sobre el borde superior del edificio, sin texto "Hold to
  build". La UI pegada a un objeto nunca lo tapa (`character-anchors-handover/` §1).

### 10f. Escala y velocidad

- **Más grande se lee mejor** (la vista de Marco): el barco pasó a 1,5x porque los pasajeros
  sentados se veían chiquitos al lado de los del muelle. **La colisión escala con el arte**, no solo
  el sprite.
- **La velocidad máxima del barco se cortó un 40 %** después del primer jugable. Contar con que la
  velocidad sale alta de más en los primeros builds.

## 11. Checklist reusable

- [ ] Preview y screenshot usan el aspect real del teléfono.
- [ ] HUD anclado a bordes, sin controles cortados por gesture area.
- [ ] Imágenes conservan aspect y los frames respetan su content rect.
- [ ] Texto largo usa best fit y no clipping.
- [ ] Ícono más valor y costos están centrados como grupo.
- [ ] Catálogo tiene unlocked primero, un locked por id y cero slots vacíos.
- [ ] Shop abierto reacciona a coins y goods.
- [ ] Placement repetido cobra cada drop y tiene salida clara.
- [ ] Long press mueve sin abrir Move/Sell.
- [ ] Todo pasto visible que promete placement lo acepta.
- [ ] Spotlight bloquea todo menos el target y la mano no consume input.
- [ ] Advisor y animales conservan tamaño aparente y pies por estado.
- [ ] Y sorting usa pies o front edge.
- [ ] Sólo las fuentes de luz intencionales iluminan.
- [ ] `viewport` más las dos opciones de pixel snap están activos si el preview fraccionario abre seams 2D.
- [ ] APK instalado, lanzado, sin crash y verificado por captura real.
- [ ] Joystick fijo (centro en PC, izquierda en teléfono), empuje = acelerador con anillo visible.
- [ ] Interacción de un segundo adentro del anillo sin exigir frenar; timer gateado por "hay alguien
      para dejar o levantar", no por el anillo.
- [ ] HUD sin datos que el mundo ya muestra; crossfades simultáneos con `CanvasGroup` por par.
- [ ] Cada edificio desbloqueable da un bonus visible; orden de desbloqueo lineal o el que dibujó Marco.
- [ ] Colisiones escaladas junto con el arte; velocidad del primer build revisada a la baja.
