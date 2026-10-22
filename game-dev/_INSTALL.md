# game-dev: cómo llega a cada juego

Esta carpeta es la **única copia canónica** de la skill, y es markdown plano: la lee Claude, Codex o cualquier IA.

**Ya no es una skill de Claude** (regla de Marco, 2026-09-24: *"no quiero usar skills específicas de Claude, todo tiene que ser reusable en Codex y en cualquier lugar"*). El junction que había en `~/.claude/skills/game-dev` (2026-07-20) se sacó ese día: solo le servía a Claude, y encima solo cargaba el `SKILL.md`, no las `references/`.

## Cómo la ve el agente que construye un juego

Los juegos viven fuera del Hub (`D:\_Programming\Game Development\...`), así que cada proyecto de Godot lleva **su copia local, ignorada por Git** en `skills/game-dev/`:

```
py -3 "C:\_Marco Paoletta\Work\Marco's Hub\Letta\Skills\game-dev\install_to_project.py" "<raíz del proyecto de Godot>"
```

**Funciona con cualquier motor (Marco, 2026-10-20).** El script detecta Godot (`project.godot`), Unity (`ProjectSettings/ProjectVersion.txt` con `Assets/`) y Unreal (`.uproject`); para otro motor se pasa `--engine other`, y `--engine godot|unity|unreal` fuerza uno. En proyectos que no son de Godot no se crean los `.gdignore` y `skills/README.md` lleva una nota del motor. La skill sigue escrita sobre todo para Godot: la seccion "Engine applicability" de `SKILL.md` dice que partes valen para cualquier motor (primer caso: Meadow Mechs de Aura, Unity).

El script copia la carpeta, escribe `skills/README.md` con el commit del Hub del que salió y un `.gdignore` SOLO en las carpetas de scripts de referencia (`references/*/scripts/`). La carpeta `skills/` con sus `.md` se ve en el FileSystem de Godot a propósito (Marco, 2026-09-24: *"I want the skills to appear in Godot"*); los `.gd` de referencia quedan ocultos porque traen `class_name` y chocarían con las clases del juego (hay un `paint_slime.gd`). Y el `AGENTS.md` / `CLAUDE.md` del juego dicen "leé `skills/game-dev/SKILL.md` antes de tocar nada" (plantillas en Skill 30 `templates/agent-docs.md`). Lo corre Skill 30 en el Paso 4, en todo starter nuevo.

## Privacidad y distribución (Marco, 2026-10-07)

La skill es trabajo propio que Marco puede monetizar en el futuro. **No se regala con el código del juego ni hereda su licencia MIT.** En repos públicos o compartidos con terceros nunca se commitea, pushea ni entrega en ZIP, export o paquete de fuentes. El juego no depende de ella para ejecutar. Por default, todos los juegos llevan copia local ignorada para evitar filtrarla si después se hacen públicos o se comparten.

El instalador agrega `/skills/game-dev/`, `/skills/godot-game-dev/` y `/skills/README.md` al `.gitignore`, sin ignorar skills públicas de terceros. No usar `git add -f` sobre esas rutas. Antes de publicar/compartir, verificar con `git check-ignore` que se ignoran y con `git ls-files` que no están trackeadas. Solo se versiona la canónica en el Hub privado y el espejo privado `MarcoPaoletta/game-dev-skill`; no cambiar su visibilidad ni compartirlos.

Si una copia ya está trackeada, el instalador frena sin modificar el proyecto: `.gitignore` no la protege. Conservar primero la skill local y un respaldo privado del repo, inventariar todas las ramas/tags y rutas actuales/anteriores, retirar esas rutas de todo el historial expuesto y verificar las refs remotas después. Un commit de borrado o `git rm --cached` solamente no alcanza. Registrar por separado forks o copias ajenas, porque reescribir el repo de Marco no borra repos de otras personas. Los docs públicos pueden explicar que se usó una metodología privada, sin pegar la skill completa ni requerirla para correr el juego.

**Excepción resuelta (2026-10-07, noche):** Marco levantó la restricción sobre el shooter de Xogot del long 5 (twin-stick). `MarcoPaoletta/twin-stick-shooter-starter-kit` (público) traía la skill commiteada en `skills/game-dev/` (57 archivos más `skills/README.md`). Se retiró de todas las ramas y tags, se borró el tag `game-dev-skill` y se agregaron las rutas al `.gitignore`. Hay respaldo previo y detalle en `docs/context/game-dev-distribution.md`. `MarcoPaoletta/xogot---twin-stick-shooter` es privado y no se tocó.

**Alcance de v1.8.0:** la regla de escenas modulares se instala en builds futuros. Actualizar la skill canónica y su espejo no implica modificar juegos ya hechos o en construcción, ni refrescar sus copias. La eventual limpieza de una skill publicada es una tarea de privacidad separada; nunca se aprovecha para refactorizar esos juegos.

## Dónde se escribe lo aprendido

Siempre **acá**, en el Hub, nunca en la copia del juego. Para que un juego viejo tenga lo nuevo, Marco tiene que pedir esa actualización y entonces se vuelve a correr el script sobre ese proyecto. No refrescar juegos existentes por haber cambiado la canónica.

## Qué significa "bajale las skills de Godot"

Cuando Marco dice *"bajale las skills"*, *"metele las skills actualizadas de godot game dev"* o parecido, habla **siempre de esta carpeta del Hub** (Marco, 2026-09-28). Correr el script de arriba sobre el proyecto (pisa la copia local vieja con la del Hub y deja en `skills/README.md` el commit de origen), confirmar que el `AGENTS.md` y el `CLAUDE.md` del juego tienen `skills/game-dev/SKILL.md` primero en la lista de lectura, y commitear solamente el `.gitignore` y los docs de proyecto que cambiaron. **Nunca commitear `skills/game-dev/` ni su README local.** No se buscan otras skills ni se baja nada de internet.

## Espejo y Mac (Marco, 2026-10-05)

La skill se llama **`game-dev`** (antes `godot-game-dev`). Está espejada en el repo privado `MarcoPaoletta/game-dev-skill` con `sync_mirror.py` (corre solo desde el hook post-commit del Hub cuando un commit toca esta carpeta). La Mac tiene un clon en `~/Skills/game-dev` con SOLO esta skill; se actualiza con `git -C ~/Skills/game-dev pull` y se instala en un proyecto con `python3 ~/Skills/game-dev/install_to_project.py "<proyecto>"`. Vale para los juegos de Xogot también (el instalador borra la copia vieja `skills/godot-game-dev/` si existe).
