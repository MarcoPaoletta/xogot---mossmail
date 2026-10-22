# Motores y MCPs en la PC de Marco: instalación, transportes y trampas medidas

Referencia de setup, no de gameplay. Junta todo lo que hay que saber para que un agente conecte con Godot, Unreal, Blender y Codex desde una sesión sin perder horas redescubriéndolo. Cada dato tiene fecha: los que dependen de una versión caducan, verificar antes de apoyarse en ellos. Aplica a cualquier IA que abra Marco's Hub (Claude, Codex, MiniMax Code), no solo a Claude.

---

## 1. Godot en la PC (medido el 2026-09-18)

Marco pidió *"fijate si tengo la última stable de Godot"* y esto es lo que hay:

- **Dónde están:** exes sueltos en la raíz de `C:\` (`Godot_v4.5.1`, `4.6.2`, `4.6.3`, `4.7`, `4.7.1`, `4.7.2-stable_win64.exe`), no en Program Files. Hay copias viejas en la raíz de `D:\` (4.2.1, 4.2.2, 4.3, 4.7.2) y una carpeta `D:\Godot 4.7.2\` con `_sc_` (modo self contained, `editor_data` adentro). `_sandbox/godot-4.7.2/` del Hub es otra copia para pruebas.
- **La que usa Marco:** la anclada en la barra de tareas, `Godot Engine (2).lnk` → `C:\Godot_v4.7.2-stable_win64.exe` (4.7.2.stable.official, SHA256 igual a la copia de D:). Queda un pin muerto `Godot Engine.lnk` → `C:\Godot_v4.4.1-stable_win64.exe` que ya no existe (Marco no pidió sacarlo).
- **Cómo se chequea la última stable:** `https://api.github.com/repos/godotengine/godot/releases/latest` (tag `4.7.2-stable` al 18-sep-2026; 4.8 estaba en dev6 sin beta). Los zips oficiales están en las releases de `godotengine/godot-builds` (`Godot_vX.Y.Z-stable_win64.exe.zip` + `SHA512-SUMS.txt`).
- **Cómo se actualiza:** bajar el zip, extraer el exe a `C:\Godot_vX.Y.Z-stable_win64.exe` (mismo patrón, al lado de las anteriores), verificar con `--version` (sin abrir ventana, para no robar el foco), y anclarlo a la barra **desde afuera del contenedor MSIX** (tarea programada; la sesión de Claude corre adentro del contenedor de la app y no puede tocar la barra). Los pines se leen en `%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\` (la lectura desde la sesión sí refleja los reales).

---

## 2. Godot AI (hi-godot/godot-ai): el attach bridge por stdio, envuelto en `pythonw`

Desde **godot-ai v3.1.0** (2026-08-03) el transporte oficial de todos los clientes MCP es el **attach bridge por stdio**, no la URL HTTP. El cliente arranca o adopta el server compartido él mismo.

**Por qué importa al grabar:** con la URL remota, si Godot no está abierto cuando arranca el cliente, no conecta. Con attach **el orden de arranque deja de importar y la sesión sobrevive a que Godot se cierre en el medio**. En una jornada de grabación larga eso es la diferencia entre una reconexión y una retoma.

La forma FLAT del entry, que es la que aceptan Claude Code, VS Code y el `mcp.json` de MiniMax Code (§3):

```json
{ "type": "stdio",
  "command": "C:\\Python314/pythonw.exe",
  "args": ["-c", "import subprocess,sys; raise SystemExit(subprocess.call(sys.argv[1:], stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr, creationflags=0x08000000))",
           "C:\\Users\\Usuario/.local/bin/uvx.exe", "--link-mode", "copy",
           "--from", "godot-ai==<version>", "godot-ai", "attach",
           "--port", "<http>", "--ws-port", "<ws>"] }
```

⚠️ **El wrapper de `pythonw.exe` con `creationflags=0x08000000` NO es adorno.** El addon **se niega a escribir una entrada attach en Windows si no encuentra un intérprete sin consola** (falla cerrado, `_finalize_attach_launch`), justamente para que no parpadee una ventana negra. A Marco eso le importa literal: una consola que aparece sola cae adentro de la grabación, igual que pasó con la tarea de backup a Drive.

**No inventar el comando: sacarlo del que el addon ya resolvió.** Vive en `~/.claude.json` bajo `mcpServers`, y trae los puertos reales, la versión pineada y la ruta de uvx verificadas. El addon lo genera en `client_configurator.gd` → `resolve_attach_launch`, con tres tiers en orden: dev venv → uvx con versión exacta → install de sistema. Nunca escribe un `uvx` pelado a propósito.

Doc oficial de las formas por cliente: `docs/client-configuration.md` del repo. Agregar un cliente nuevo al addon es tirar un archivo en `clients/` y sumar una línea a `_registry.gd`, o sea que pedirle al dev (**dlight** en el Asset Store y en Discord) que agregue uno es un pedido chico de verdad.

**La versión siempre es la última 4.x** (Regla 1b del `SKILL.md`): 3.x y 4.x no interoperan, y un scaffold copiado de un proyecto viejo arrastra el pin viejo en silencio. Emberhold y Gravegarden quedaron en 3.2.4 una semana antes de que saliera 4.x. Se chequea `api.github.com/repos/hi-godot/godot-ai/releases/latest` y `pypi.org/pypi/godot-ai/json` en cada starter nuevo.

---

## 3. MiniMax Code: los MCP se leen de `~/.minimax/mcp.json`, NO del `config.yaml`

MiniMax Code (el agente de escritorio de MiniMax, fork de OpenCode) **NO lee sus MCP servers del `config.yaml`**, aunque ese archivo sea de OpenCode y acepte la clave `mcp`. Los lee de un archivo aparte:

`C:\Users\Usuario\.minimax\mcp.json` (y también `~/.minimax/mcp/mcp.json`), con la forma estándar `{"mcpServers": {"<nombre>": {...}}}`.

El parser es `@mavis/local-runtime/dist/mcp/config-file.js` + `mcp/config.js`, adentro del `app.asar`. Acepta `stdio` (con `command`, `args`, `env`), `sse`, y `http` / `streamable-http` (con `url`, `headers`). Las claves `enabled` y `configured` son true por defecto.

**Tres cosas que no se deducen y cuestan horas:**

1. **El `config.yaml` es un callejón sin salida.** Poner un bloque `mcp:` ahí en formato OpenCode no hace absolutamente nada, y no da ningún error.
2. **El runtime relee `mcp.json` en cada turno, así que no hace falta reiniciar la app. Pero el set de tools se fija cuando arranca la sesión**, o sea que hay que **abrir una tarea NUEVA**. Si probás en la misma conversación va a decir que no tiene las tools aunque esté todo bien, y parece que falló cuando funcionó.
3. **Los tools de un MCP no aparecen con su nombre pelado.** Entran por progressive disclosure: el agente los descubre con `tool_search` y los llama con `mcp_invoke(server=..., tool=..., args=...)`. Pedirle "llamá a `editor_state`" con semántica de Claude Code da un falso negativo. Hay una vía nativa (`buildNativeToolName`, prefijo `mcp_<server>_<tool>`) que se activa listando tools en el config, es la feature "Native MCP Tool Exposure" del changelog.

⛔ **Nada de esto está en la doc oficial.** Al 2026-08-05, las 28 páginas de `agent.minimax.io/docs` no tienen **una sola** página de MCP: verificado por `llms.txt`, por `sitemap.xml` y por 8 rutas candidatas probadas a mano, 404 en las 8. MCP solo aparece en el changelog. Sale de leer el bundle de la app o no sale.

Para Godot AI conviene la entrada **stdio con el attach bridge** (§2), no la URL remota. Contexto del video en el Deal State de MiniMax.

---

## 4. Unreal Engine 5.8: MCP nativo, gratis, y SÍ importa GLB

Unreal Engine 5.8 (jun-2026) trae un **servidor MCP nativo y gratis adentro del editor** (plugin `ModelContextProtocol` + Toolset Registry + AllToolsets; `Auto Start Server` en `127.0.0.1:8000/mcp`; `ModelContextProtocol.GenerateClientConfig ClaudeCode` escribe el `.mcp.json`).

✅ **VERIFICADO EN UN PROYECTO REAL (2026-07-26): el nativo IMPORTA GLB.** En Coldhearth (StudioTwin, UE 5.8) entraron **10 GLB de Tripo3D con el nativo manejando Interchange**, sin UI y sin VibeUE: 50 assets con material y las tres texturas (Color, NormalGL, ORM) asignadas. No hay un tool dedicado de import de GLB, pero **Interchange lee GLB y el nativo lo puede disparar**. Esto **pisa** la nota anterior de que "solo importa FBX y OBJ", que era la razón principal para instalar VibeUE.

**Lo que sigue en pie del nativo:** no corre Python arbitrario y es flojo en fine tuning de materiales. VibeUE (rama `5-8`, MIT) sigue valiendo como **fallback** por el `execute_python_code` y el fine tuning, con la regla dura de **tools nativos primero**, porque es más potente y puede crashear el editor. Lo que ya no es cierto es que sea imprescindible para el pipeline de assets.

**Por qué importa:** el pipeline de Letta vive en GLB (Tripo, Meshy, Rodin), y creer que el nativo no lo importaba hacía a VibeUE obligatorio y sumaba riesgo de crash al gratis. Es un caso de la Regla #2 de Skill 17: la ausencia en la doc no prueba la ausencia en el producto.

**Cómo se construye y se PRUEBA un juego de Unreal (playtest headless sin robar el foco, trampas medidas, tools portables): `../unreal-engine/unreal-engine.md`.**

**El archivo completo** (síntesis, doc oficial de Epic mirroreada, los drop-in `CLAUDE.md` y `AGENTS.md` para la raíz de un proyecto UE, y los 145 md de skills de VibeUE) está en `Letta/Knowledge/Game Development/Unreal Engine MCP/`, ya con la corrección marcada. El proyecto de StudioTwin ya está en 5.8 y corre el nativo (ubicación en `docs/context/game-projects.md`, SugarwingCourier).

**El server no arranca solo** salvo que esté el Auto Start (`Editor Preferences → General → Model Context Protocol`), que es una preferencia **por usuario**, no por proyecto: por eso ya estaba prendido desde Coldhearth.

### 4b. El MCP de Unreal es un REGISTRO de toolsets: 3 meta-tools, no las tools sueltas

El `ModelContextProtocol` de Epic (UE 5.8, plugin del engine, `Engine/Plugins/Experimental/`) **no expone las tools directamente**. Un `tools/list` devuelve **exactamente 3**: `list_toolsets`, `describe_toolset` y `call_tool`. Todo lo demás vive detrás de ese registro.

⚠️ **Un agente que lista tools y ve 3 CONECTÓ BIEN, no está roto.** Tiene que llamar `list_toolsets` para ver la superficie real. Es el falso negativo obvio de este server.

**StudioTwin y Unreal comparten el MISMO endpoint.** No hay dos servers ni dos configs: el plugin de StudioTwin registra sus toolsets adentro del MCP de Epic, así que una sola conexión a `http://127.0.0.1:8000/mcp` da las tools de generación **y** toda la superficie de edición de Unreal. (Ojo: el plugin de StudioTwin anterior a la 3 no tiene MCP.)

**Medido el 2026-09-05** en `SugarwingCourier`, plugin StudioTwin 3.1.1:

| Superficie | Toolsets | Funciones |
| :-- | --: | --: |
| StudioTwin | 6 | 18 |
| Unreal (Epic) | 51 | 784 |
| **Total** | **57** | **802** |

Los 6 de StudioTwin: `StMesh` (1), `StMaterial` (3), `StEnvironment` (6), `StMotion` (6), `StAudio` (1), `StMcpJob` (1). **17 de las 18 se auto-declaran** *"uses paid tokens from the user's StudioTwin account"*; solo `PollStudioTwinMcpJob` es gratis. Los más grandes de Unreal: `SequencerTools` 140, `SequencerControlRigTools` 72, `BlueprintTools` 53, `ControlRigTools` 44, `UMGToolSet` 23, `MaterialTools` 22, `EditorAppToolset` 21 (cámara de viewport, screenshots, Play In Editor).

**Detalles que cuestan tiempo:**
- El parámetro de `describe_toolset` es **`toolset_name`**, no `toolset`.
- El transporte es streamable HTTP: hay que mandar `Accept: application/json, text/event-stream` y guardar el header `Mcp-Session-Id` del `initialize`. Un GET pelado al endpoint devuelve **405**, que es lo correcto, no una señal de que esté caído.
- ⛔ **`NiagaraToolsets.NiagaraToolset_System` devuelve un body VACÍO (0 bytes) en `describe_toolset`.** No es un error JSON-RPC, es nada, así que el cliente ve un fallo de parseo. Los otros Niagara (`_Component`, `_Blueprint`, `_Assets`, `_Info`) andan bien. Ese es justo el de **autoría de sistemas Niagara**, o sea confetti, shards y trails. Workaround: `_Component` + `_Blueprint`, o a mano en el editor como pase de polish.

**Por qué está escrito:** sin esto un agente concluye que el MCP no funciona (ve 3 tools), o pierde la sesión debuggeando su propio cliente contra un toolset que el server devuelve vacío. Vale para cualquier proyecto de UE 5.8 con MCP, no solo StudioTwin.

---

## 5. Codex como MCP de Claude Code (y la vía de imágenes)

Marco quiere disparar Codex desde adentro de una conversación de Claude en vez de abrir la app de escritorio de Codex (2026-07-15). La solución limpia: **Codex CLI está registrado como MCP server en Claude Code**, en scope de usuario, así que el tool `codex` (típicamente `mcp__codex__codex`) está disponible en todos los proyectos.

- Registrado con: `claude mcp add --scope user codex -- codex mcp-server -c approval_policy=never -c sandbox_mode=workspace-write` (config en `C:\Users\Usuario\.claude.json`; se saca con `claude mcp remove codex -s user`).
- Los overrides `-c approval_policy=never -c sandbox_mode=workspace-write` evitan que Codex headless se cuelgue en prompts de aprobación, y siguen sandboxeando las escrituras al directorio de trabajo.
- Codex CLI: `codex` (v0.144.0), autenticado vía `~/.codex/auth.json`, modelo `gpt-6.1-sol`. Su feature flag `image_generation` es **stable/true**, así que el tool de imagen funciona headless (MCP / `codex exec`), no solo en la app de escritorio.
- Alternativa sin setup: `codex exec "<prompt>"` desde la carpeta del proyecto (headless, one-off).
- **Regla ALWAYS-GPT-Image (2026-07-15):** una regla global en `~/.codex/AGENTS.md` obliga a Codex a usar su tool nativo `image_generation` / `image_gen` para CUALQUIER pedido de imagen o arte y a NUNCA dibujarla con código (System.Drawing, PIL, SVG, canvas, etc.). Sin esa regla, Codex dibuja las imágenes triviales (una forma, un ícono) con código en vez de GPT Image, y eso mata el propósito. Verificado: el mismo prompt de un círculo rojo pasó de un PNG de 5,6 KB dibujado por código a un render de GPT Image de 193 KB con la regla puesta. La skill de imagen de Codex vive en `~/.codex/skills/.system/imagegen/` y trae un helper de chroma key para fondos transparentes (útil para sprites).

Esto **reemplazó** la vieja skill `gpt-image-via-chatgpt`, que Marco borró el 2026-07-15 como slop (*"skill pedorra, es falopa"*). Su MCP dedicado `playwright-chatgpt` también se sacó. Para concept art e imágenes de juegos, la vía es Codex. SpriteCook MCP sigue cubriendo sprites y tilesets game-ready.

⛔ **IMÁGENES: nunca astra, usar sol en medium (Marco, 2026-09-13).** El default de Codex en `~/.codex/config.toml` es `gpt-6-astra` con `model_reasoning_effort = "high"`; para generar imágenes se pasa `model: "gpt-6.1-sol"` y `config: {"model_reasoning_effort": "medium"}` en la llamada a `mcp__codex__codex` (*"con codex no uses astra para las imgs... usa medium effort o algo así. Quizás con sol"*). La imagen la hace `image_gen`; el modelo que conduce solo escribe el prompt y mueve el archivo, así que el modelo caro ahí es plata tirada.

---

## 6. Blender y su MCP (wired 2026-08-21)

Blender vive en **`D:\Blender`** (5.2 LTS), NO en `C:\Program Files\Blender Foundation`, y no está en el PATH: todo lo que llame a `blender` necesita la ruta completa.

El Blender MCP (la extensión oficial de Blender Lab `ant.dir.gh.blender.blender-mcp`) tiene dos modos:

- **Modo live** (`execute_blender_code`, screenshots, renders de viewport): necesita Blender abierto con el add-on `lab_blender_org.mcp` corriendo un bridge en `localhost:9876`. El add-on está instalado y `use_autostart` está ON con 1 s de delay, así que el puerto sube ~6 s después de que Blender arranca. No hay nada que clickear.
- **Modo CLI** (los tools `*_for_cli`, que abren un `.blend` en Blender background): leen la variable de entorno `BLENDER_PATH`, seteada a nivel usuario en `D:\Blender\blender.exe`.

**Trampas:**
- El proceso del MCP server captura el entorno al spawnear, así que un `BLENDER_PATH` nuevo necesita reiniciar la sesión de Claude antes de que los tools CLI lo vean. El modo live no necesita reinicio, solo Blender corriendo.
- Blender 5.2 tiene add-ons rotos que escupen tracebacks en modo `-b` background (PolyQuilt `GPUShader`, Rokoko `boto3` / LZ4). Es ruido inofensivo: filtrarlo del output del CLI.
- Instalar add-ons headless: `blender --command extension install <repo_id>.<pkg> --enable` (el repo es un prefijo del id del paquete, no hay flag `--repo`).
- Blender headless para merges de animación y renders de comparación de assets: `D:\Blender\blender.exe --background --python script.py` (los warnings de "GPU not available in background" son inofensivos, igual rendea con Workbench o EEVEE).

## 7. Un starter nuevo sin interferir con otros bridges (Inkbound, 2026-09-29)

Si hay otros editores/sesiones escuchando en los puertos compartidos, no se cierran ni se reconfiguran. En Inkbound se preparo un editor Godot 4.7.2 self-contained: copia oficial del exe bajo `.local-editor/` con `_sc_` y `.gdignore`, ignorado por git. Su EditorSettings propio guarda `godot_ai/v4_endpoint_ports = { http_port: 8021, ws_port: 9521 }`, configurado por la API de Godot en headless. Las configs de cliente usan los mismos puertos, attach por pythonw y server pineado a 4.2.3, version de addon y PyPI verificadas al 29-sep. El ejemplo reproducible vive en `Zenva/3 - Inkbound/tools/setup-local.ps1` y `configure_profile.gd`; los clientes de otro agente usan la misma entrada stdio con su formato nativo. Otro OS usa el editor oficial de su plataforma y un perfil/config equivalentes.

Codex no lee `.mcp.json` como config de proyecto: usa `.codex/config.toml` y requiere que el proyecto sea trusted para cargarla. El chequeo real es `codex mcp get godot-ai --json` DESDE la raiz del juego: antes del trust mostraba el global 4.1.0 en 8005/8006; despues de registrar SOLO esa carpeta muestra 4.2.3 en 8021/9521. Para otros agentes se comprueba la config efectiva equivalente, no se asume que guardar el JSON conecta. No se cambia el MCP global para arreglar un solo repo. Un import headless limpio no prueba handshake vivo; la sesion del build debe leer editor_state y confirmar ruta exacta antes de editar.

Las trampas verificadas de batches, buffers de scripts, evaluaciones, recursos y pruebas de Saffron Shift están en [godot-ai-4.2.3-verification.md](godot-ai-4.2.3-verification.md). Se aplican igual desde una integración nativa y desde un cliente MCP portátil.

## 8. El banco de descargas necesita `.gdignore` antes de abrir Godot

Medido en WorldOS, 13 de octubre de 2026: un banco de packs completos bajo `tmp/source_bank/` estaba ignorado por Git, pero Godot importó también esos archivos y sus formatos alternativos. El primer escaneo produjo más de 5300 entradas en `.godot/imported/`, aunque la selección final tenía solo 30 GLB. El MCP rechazaba las escrituras mientras el editor seguía en `importing`.

`.gitignore` no controla el FileSystem de Godot. Antes del primer import o apertura, el directorio que guarda ZIPs, stock sin seleccionar y formatos alternativos lleva su propio `.gdignore`. El directorio de assets seleccionados permanece importable. Preparar ese marcador como parte de la adquisición, antes de iniciar el editor; si el editor ya está conectado y listo, escribirlo con su herramienta de filesystem y volver a escanear. Si el import ya comenzó y la herramienta rechaza cambios, esperar su finalización y no reintentar en un loop ni tocar otro editor.

No ocultar la carpeta `skills/` completa: Marco pidió verla en Godot. El instalador ya ignora solamente los scripts de referencia que podrían duplicar clases del juego.

## 9. Imported child overrides require a save and reopen check

Measured with Godot AI 4.3.0 in WorldOS on 13 October 2026: assigning `material_override` to a mesh inside an imported GLB instance returned success, but the override was absent after saving and reopening. An in-memory inspector result alone did not prove persistence.

Use editable source ownership for durable changes. Where editable child ownership is unavailable through the installed tools, move the original native mesh into its reusable prop scene through editor node tools, remove its empty import wrapper, and assign a saved material. Record the original composed transform before moving. The MCP reparent operation did not preserve the wrapper's transform in this case. Restore the measured transform through editor properties, then save, reopen and inspect the runtime instance. Preserve the GLB, original mesh arrays, atlas, filtering and material values.

The Kenney office doorway pairs contained exact opposed triangles with different atlas coordinates and double-sided materials. Saved back-face culling overrides removed the competing face without modifying the licensed originals. Native bracket intersections and crane joins required actual geometry corrections. Changing camera clipping alone would not repair either case.

## 10. Fading controls still block input until their transition completes

WorldOS recording round advance initially closed a modal and immediately called the normal turn coordinator. The closing panel remained visible during its fade, so the coordinator's blocking-dialog guard rejected the turn. Wait for the authored fade to complete, guard the campaign generation, then call the normal coordinator. Verify the round number through actual UI input. Also clear stale previews before debug state changes and preserve a pending event, pause or result when closing the debug panel.

For Control scene instances, verify the instance anchors and offsets in the composed parent. Native instancing reset several root layouts in this build, even though the source Control scene was correct. Save explicit instance layout overrides and inspect every supported window aspect.
