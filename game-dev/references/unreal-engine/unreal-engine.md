# Unreal Engine en game-dev (UE 5.8, MCP primero, probar sin robar el foco)

Salió de dos builds reales de StudioTwin en UE 5.8: **Coldhearth / Sugarwing Courier** (MCP nativo mas StudioTwin) y **Gravelight Vanguard** (StudioTwin MCP 2, build del 2026-10-08, iteraciones hasta el 2026-10-21). Todo lo de abajo se midió corriendo el juego, no leyendo la doc. Las lecciones completas de Gravelight viven en su repo (`D:\_Programming\Game Development\Games - Letta Collaborations\StudioTwin\GravelightVanguard\docs\build\LESSONS.md` y `HEADLESS_PLAYTEST.md`); acá queda lo que sirve para cualquier juego de Unreal.

Setup del MCP y de los motores (puertos, `.mcp.json`, GLB por Interchange, toolsets): `../engines-and-mcp-setup/` §4. Este doc es el **cómo se construye y se prueba**.

---

## 1. ⛔ La regla clave: PROBAR SIN ROBARLE EL FOCO A MARCO (2026-10-21, "super importante")

**Todo agente valida el juego SIN tomar el foco, el mouse ni el teclado de la PC de Marco.** Nada de la ventana flotante de Play In Editor que salta al frente, nada de clicks de foco, nada de teclas del sistema, nada de bots de input. Marco sigue trabajando mientras el agente prueba. Esto es el mismo principio de "nunca robarle el foco" del Hub, aplicado al playtest de Unreal.

Por qué importa: un bot de input real espera 60 segundos sin que Marco toque nada antes de abrir su ventana, así que mientras él trabaja puede esperar un cuarto de hora, y cuando corre le toma la pantalla. El método de abajo corre **al instante, en segundo plano, y da la misma evidencia**.

### Cómo funciona

Play In Editor corre **adentro del viewport del propio editor** (`PlayMode_InViewPort`): no abre ventana nueva y no cambia el foco. Todo lo demás entra por **Python Remote Execution** (`tools/ue_py.py`) y por el **servidor MCP del editor**, nunca por input del sistema operativo.

Las herramientas están en `references/unreal-engine/tools/` (en el juego: `skills/game-dev/references/unreal-engine/tools/`). Se corren **desde la raíz del proyecto** (donde está el `.uproject`); encuentran solas el proyecto, la instalación del engine y el puerto del MCP (`UE_PROJECT_ROOT`, `UE_ENGINE_ROOT` y `UE_MCP_URL` los pisan si hace falta).

| Necesidad | Comando | Qué hace |
|---|---|---|
| Arrancar y parar Play | `python tools/pie.py start` / `stop` | `StartPIE` en el viewport por MCP |
| Descubrir clases reales | `python tools/pie.py actors [texto]` | clase, nombre y posición de cada actor del mundo PIE |
| Leer el estado del juego | `python tools/pie.py props BP_Hero_C Health State` | propiedades de un actor |
| "Apretar un botón" | `python tools/pie.py call BP_Manager_C PlayerChoose 0` | llama la **misma función de Blueprint** que llama el botón del HUD o la tecla. Es el input de un playtest headless |
| Ir a un lugar / disparar un encuentro | `python tools/pie.py tp BP_Hero_C X Y [Z] [YAW]` | mueve el actor en el mundo PIE |
| Frame limpio del juego (sin HUD) | `python tools/pie.py shot NOMBRE 1920 1080` | `HighResShot` del viewport, a `docs/evidence/ue-shots/NOMBRE.png` |
| Frame CON el HUD | `python tools/pie.py shotui NOMBRE` | el comando `shot showui`: la ventana del editor con el viewport adentro (se recorta el viewport) |
| Cámara lenta para efectos de un solo frame | `python tools/pie.py dilate 0.2` (y `1.0` al terminar) | dilatación global de tiempo, así la latencia de un segundo del screenshot agarra el golpe |
| Cualquier consola | `python tools/pie.py console "stat fps"` | comandos de consola en el mundo PIE |
| Script propio | `python tools/pie.py py mi_script.py args` | cualquier `tools/ue/*.py` dentro del mundo PIE |
| Bloqueo del editor | `python -I tools/editor_lock.py acquire NOMBRE --ttl 7200` / `release NOMBRE` / `status` | exclusión entre agentes paralelos (nivel, viewport, PIE, cámara, capturas) |

Un juego real agrega sus propios scripts `tools/ue/pie_*.py` (estado del manager, posiciones, timers, logger por frame). Los de Gravelight son el modelo: `pie_state.py` (un JSON con todo lo que un bot necesita), `pie_action_timer.py` y `pie_logger.py` (log por frame con un callback de Slate post tick, solo lectura), `pie_pos_log.py`.

### Reglas que vienen con el método

* **Se toma el editor lock** mientras una corrida headless usa el viewport, y se suelta al terminar. El lock **expira** (900 s por defecto): para sesiones largas `--ttl 7200`, o otro agente puede abrir otro nivel debajo tuyo.
* **El Python del editor es ciego durante PIE.** `get_all_level_actors` devuelve el mundo del editor, vacío mientras PIE corre en el viewport, y los imports de assets fallan (`load_asset` devuelve `None`). Se **para PIE antes** de importar, cargar niveles o editar niveles. El mundo PIE se lee con `unreal.GameplayStatics` (como los `ue/pie_*.py`).
* **`HighResShot` deja afuera los widgets.** Para chequear el HUD se usa `shotui`, y se mira un frame real después de la primera regeneración de un look de UI compartido.
* **`CaptureViewport` del MCP renderiza el mundo del EDITOR, no el de PIE.** Los frames del juego vienen de `HighResShot` / `shot showui`.
* **Nunca dejar Play corriendo ni la dilatación de tiempo por debajo de 1.0** al terminar. Nunca dejar un modo de test (HP recortado para peleas cortas) encendido al commitear.
* **Lo que SÍ necesita input real** y se pide a Marco antes: el camino real de un click en un botón de menú, la caminata real con WASD. Un bot que mueve el mouse, toma el foreground o manda teclas es el ÚLTIMO recurso, solo con su OK.
* **Un modal de Windows** (por ejemplo la pregunta del Firewall la primera vez que el juego empaquetado abre un socket) atenúa la pantalla, bloquea los clicks y se queda con el teclado. La respuesta es decisión de Marco.
* **Simulate In Editor** (`LevelEditorSubsystem.editor_play_simulate`) tampoco abre ventana ni toma foco, y sirve para probar poses y animaciones cuando el mesh se renderiza (ver §5).

### Dos mundos de Python (el error que cuelga el editor)

* `tools/ue_py.py file X.py` ejecuta X **adentro del editor, en el game thread**. Solo para scripts que usan el módulo `unreal` (`tools/ue/*.py`).
* Un script que le habla al servidor MCP (`tools/mcp_client.py` y todo lo construido encima) **corre desde el shell**, nunca por `ue_py.py`: mandaría un request HTTP al mismo editor, que solo puede atender el game thread que está bloqueado esperándolo. El editor queda en "Not Responding" hasta que vence el timeout del cliente (900 s).
* El proceso Python del editor **cachea módulos**: `import mi_lib` conserva la primera versión, usar `importlib.reload`. El entorno del shell no es el del editor: los parámetros van como argumentos del script (`name=value`).
* Las herramientas de editor usan `python -I`. Las de playtest con captura (Pillow) van sin `-I`, que esconde el user site.

---

## 2. Arrancar un proyecto de Unreal para esta skill

1. Proyecto vacío de UE 5.8 con `ModelContextProtocol` y `AllToolsets` habilitados (vienen con el engine) y **Python Editor Script Plugin** activo.
2. Con el editor **cerrado**: `python skills/game-dev/references/unreal-engine/tools/setup_project.py` (idempotente; `--check` solo reporta). Prende Python Remote Execution **solo en loopback** (`bRemoteExecution=True`, `RemoteExecutionMulticastBindAddress=127.0.0.1`, `RemoteExecutionMulticastTtl=0`).
3. **Abrir el editor con las flags del MCP**: `UnrealEditor.exe "<proyecto>.uproject" -ModelContextProtocolStartServer -ModelContextProtocolPort=<puerto>`. Un arranque pelado abre bien pero **nunca abre el puerto**. Recuperación sin reiniciar, por Remote Execution: `python -I tools/ue_py.py stmt "import unreal; unreal.SystemLibrary.execute_console_command(None, 'ModelContextProtocol.StartServer 8070')"`. Para trabajo desatendido sumar `-NoSound`: un dispositivo de audio colgado (hay uno virtual en esta PC) mató un editor una vez.
4. Si el puerto lo ocupa otro MCP (un Godot AI en 8070 devuelve 401), `StartServer` en otro puerto y `UE_MCP_URL=http://127.0.0.1:<puerto>/mcp`. `ModelContextProtocol.GenerateClientConfig ClaudeCode` escribe el `.mcp.json` y las herramientas lo leen.
5. Verificar que conecta: `python -I tools/mcp_client.py list-toolsets` y `python -I tools/ue_py.py nodes` (el nodo tiene que ser el del proyecto). **Un cliente que lista tools y ve 3 CONECTÓ BIEN**: la superficie real está en `list_toolsets`, `describe_toolset` y `call_tool`.

Verificado el 2026-10-21 contra el editor abierto de Gravelight Vanguard (solo lectura): detección de proyecto, engine y puerto por `.mcp.json`, `list-toolsets` por MCP y una sentencia de Python por Remote Execution, sin ventana ni foco.

---

## 3. Las reglas de la skill, traducidas a Unreal

La tesis no cambia: el producto es el **juice** más el **post proceso**; la mecánica da el minuto a minuto. Lo que cambia es el vehículo.

| Godot | Unreal |
|---|---|
| Regla 1: Godot MCP primero | **Toolsets del MCP primero** (el nativo de Epic, 51 toolsets / 784 funciones, más los de StudioTwin en el MISMO endpoint). Python Remote Execution solo para lo que no tiene tool estructurado (niveles nuevos, consola, import de audio y fuentes, anim notifies, retarget, lectura del mundo PIE). VibeUE queda de fallback, con tools nativos primero |
| Una `.tscn` guardada por elemento del juego | **Un Blueprint por elemento** (personaje, enemigo, prop, manager, director, widget), con nombre propio y seleccionable. Nada de lógica suelta en el level blueprint |
| Valores de tuning en recursos | **`CurveTable` / `DataTable` de balance** y variables de Blueprint. Una sola tabla (`CT_Balance`), todo número ahí |
| GDScript tipado | Blueprints con DSL (`write_graph_dsl`) o C++ solo si el proyecto ya compila código. Un proyecto con plugin de código o un plugin deshabilitado en el `.uproject` obliga a compilador y Windows SDK al empaquetar |
| `WorldEnvironment` con glow, grading, vignette | **Post Process Volume** con exposición fijada (`auto_exposure_min_brightness = auto_exposure_max_brightness = EV100`) y la cine camera con `exposure_method` en `DO_NOT_OVERRIDE`, si no manda la exposición física de la cámara. Lumen, bloom y color grading deliberados |
| `GPUParticles` | **Niagara**. `NiagaraToolset_System` devuelve body vacío en `describe_toolset`: usar `_Component` y `_Blueprint`, o pase manual |
| `stretch aspect=expand` | **`UIScaleRule` (ShortestSide) + anclas y contenedores**, y verificar en runtime a resolución de diseño, una ventana menor, un aspecto más ancho y uno más alto. Un juego empaquetado es DPI unaware por defecto (`bAllowHighDPIInGameMode=False`): con escala de Windows al 125 % un "1080p" salió en realidad en 1280 x 720. Setearlo en True para empaquetado y medir la captura |
| Evidencia en `docs/evidence/` | Igual: las capturas del §1 caen en `docs/evidence/ue-shots/` con dimensiones y hallazgos en `docs/BUILD_NOTES.md` |

Lo que vale igual que en Godot, sin traducir: concept match, revisión de feedback visual, aceptación funcional y perceptual, tag `setup-finished`, versiones `vN`, builds solo cuando Marco los pide, la skill privada y fuera de Git.

---

## 4. Trampas medidas del MCP y del editor

* **Play In Editor rompe las asset tools.** Con PIE corriendo, `AssetTools.exists` devuelve False para todo y `save_assets` falla. Un `create` que sigue a un `exists` falso abre el modal **Overwrite Existing Object** y **congela el game thread por minutos**. Nunca correr asset tools ni scripts que crean assets durante PIE; preguntarle al propio Blueprint (`BlueprintTools.get_default_object`) y **parar PIE primero**. Para cargar un asset durante PIE: `unreal.load_object(None, "/Game/.../Name.Name")`.
* **Nunca crear un Blueprint Function Library con `BlueprintTools.create`** (modal "Message" y MCP congelado). Duplicar el helper chico en cada Blueprint.
* **Un modal en el editor congela todo el MCP.** Hay que encontrar la ventana (puede estar detrás de otras, sin parpadeo en la barra) y contestarla. Un `StartPIE` que no vuelve suele ser el modal "Blueprint Asset Compilation Errors: are you sure you want to Play in Editor?"; regenerar un widget UMG deja punteros de clase viejos en cada Blueprint que lo referencia: recargar los paquetes guardados y compilar antes de PIE.
* **Recompilar un material padre puede congelar el editor 10 minutos o más** (un shader worker, muchas permutaciones). No dispararlo mientras hay otro trabajo en vuelo.
* **Un material que no compila es silencioso**: el piso quedó con el material de grilla del engine. Buscar `Failed to compile` en `Saved/Logs/<Proyecto>.log` después del último paso.
* **`write_graph_dsl` agrega, no reemplaza.** Cada reescritura suma una copia completa de los nodos. Limpiar y reescribir una vez; comparar nodos contra tamaño del DSL.
* **Una llamada impura (con pines de exec) no puede ir anidada en una expresión pura**: el compilador la poda ("was pruned because its Exec pin is not connected") y su valor se lee como 0. Statement o `(bind x (call))`.
* **Un `bind` de expresión pura no es un snapshot**: se recalcula con el estado nuevo. Decidir antes de guardar.
* **Los defaults de un componente no llegan a los actores ya colocados** en un nivel guardado: reconstruir el nivel (los builders deben ser idempotentes).
* **Un default de clase cambiado desde Python necesita compilar el Blueprint** antes de que las instancias nuevas lo vean. Y las ediciones de `CurveTable` por MCP **no ensucian el paquete**: guardar con `EditorAssetLibrary.save_asset(path, only_if_is_dirty=False)`.
* **Sin `gameInstanceClass` en Project Settings, todo cast al game instance falla en silencio.** Se setea con `ConfigSettingsToolset.SetSectionProperties`.
* **`ObjectTools.set_properties` toma `values` como string JSON**, nombres camelCase (`castShadows`, `overrideMaterials`), structs anidados con JSON parcial.
* **Forzar kill del editor deja el diálogo "Restore Packages"** y el servidor MCP nunca arranca hasta contestarlo. Respaldar `Saved/Autosaves` y elegir **Skip Restore**. Los scripts idempotentes reconstruyen la capa de Blueprints.
* **`F1` en PIE es del editor (wireframe), `Escape` para PIE.** La pantalla violeta de un video de Marco fue el wireframe. En PIE se llama a la función de Blueprint, no a la tecla.

## 5. Trampas medidas de gameplay y animación

* **`bUseControllerRotationYaw` es true por defecto y gana sobre todo**: cada `SetActorRotation` se pisaba. Apagarlo en el Blueprint base y en cada hijo si el código maneja el yaw.
* **Un Blueprint hijo con su propio `EventTick` reemplaza el del padre por completo** (no hay llamada implícita al padre). Poner el cuerpo en una función y llamarla desde ambos.
* **Un hijo pierde un NoCollision heredado**: cada plantilla hija re-aplica su perfil. Un plano de target de 260 cm con `BlockAllDynamic` lanzó soldados 2 a 5 m en los primeros frames. Setear el perfil en cada hijo y verificarlo con un tracker frame a frame en los PRIMEROS frames, no a los segundos. Un helper mesh que se mueve sobre un personaje lleva `NoCollision`.
* **Los meshes importados traen UN convex hull automático**: un arco hueco es un bloque sólido. Apagar colisión de la instancia y armar lo caminable con cajas ocultas.
* **Animation Blueprint de un solo slot muestra T pose** cuando no hay montage activo. Alimentar el slot con un Sequence Player en loop (idle) que sale al Output Pose, y que cada montage vuelva al idle, nunca a la T pose. Se arregla en el grafo, no con timing.
* **Los huesos no se actualizan en el mundo del editor ni en Simulate In Editor si el mesh no se renderizó**: `visibility_based_anim_tick_option = ALWAYS_TICK_POSE_AND_REFRESH_BONES`. `AnimPoseExtensions.get_anim_pose_at_time` lee un clip sin tickear nada.
* **El orden de BeginPlay entre actores es indefinido**: un director que aplica estado en su BeginPlay puede ser pisado por los actores que configura. Aplicar una vez desde los primeros ticks (`Age > 0.1`).
* **Un `DefaultPawn` del engine** aparece si el game mode no define pawn (la "esfera oscura" del menú). Usar la clase `Pawn` pelada, que no dibuja nada.
* **Un frame de 50 a 90 ms al primer texto nuevo** no era un compile de pipeline state: el game thread gastaba 12 ms en UI (primer dibujo de texto, atlas de glifos). Calentar efectos Niagara no lo toca. Contar las líneas `PSOPrecacheState: Missed` del log por corrida antes de culpar a los shaders.
* **Una cámara lateral de combate** necesita más distancia que la exploración: con un HUD de 520 px a la izquierda, la cámara de batalla fue 1,4 veces la distancia de exploración. Comparar contra la concept, no contra los números del GDD.
* **Centrar texto en una celda**: las mayúsculas quedan 0,075 x tamaño de fuente POR ENCIMA del medio (el line box reserva descendentes) y un padding mueve el texto su valor COMPLETO, no la mitad. Medir con una captura antes y después de cualquier cambio de padding.

## 6. Empaquetado (solo cuando Marco lo pide, regla de `../build-exports/`)

* UAT trata un proyecto como basado en código (y pide compilador y Windows SDK) si un plugin está deshabilitado en el `.uproject` o si hay un plugin de código (StudioTwin). Se arma una **copia solo de contenido** del proyecto para cocinar.
* Un cook más stage, pak y archive tomó **14 a 21 minutos** en un Ryzen 5 5600X.
* El `.exe` empaquetado es un launcher de 172 KB que arranca `UnrealGame.exe`: la ventana es del hijo. Buscarla por título y por nombre de imagen, no por el pid lanzado.
* La primera ejecución de un build nuevo es lenta (36 s de frame 0 con la caché de DirectX fría): esperar la línea `LogLoad: LoadMap:` del log, no la ventana. Nunca caer a una captura de pantalla completa cuando la captura de ventana sale negra: termina otra aplicación en la evidencia.
* Una medida de FPS vale lo que vale la máquina alrededor: un backup programado bajó el menú de 80 a 30 fps. Medir solo con la PC libre, y revisar la carga de CPU.
* **Una corrida del juego empaquetado con input scripteado SÍ toma el monitor y el mouse.** No se hace con Marco usando la PC; con la PC ocupada alcanza un smoke test de ventana chica sin input.

## 7. Evidencia antes de decir "listo"

1. Corrida headless del §1 (frames limpios, frames con HUD, cámara lenta para efectos, el log de estado).
2. `Saved/Logs/<Proyecto>.log` sin `Failed to compile`, sin errores nuevos de compilación de Blueprint (`compile_report`).
3. Aceptación funcional y perceptual de la skill sobre los frames reales, no sobre el editor.
4. PIE parado, dilatación de tiempo en 1.0, lock liberado, modo de test apagado.
