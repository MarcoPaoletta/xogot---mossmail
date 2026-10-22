# Godot AI 4.2.3: verificación de escrituras y juego real

Medido en Saffron Shift, 30 de septiembre de 2026. Aplica a cualquier agente que invoque el mismo MCP. El cliente puede ser la integración nativa o un cliente Python del protocolo stdio. No necesita herramientas exclusivas de un agente.

## Las escrituras se prueban desde disco

`batch_execute` puede devolver `is_error: false` aunque `data.error` y `data.stopped_at` indiquen una suboperación fallida. Revisar esos campos y `rolled_back`, no solo el envelope. En el primer intento de piso, un recurso faltante revirtió el batch; continuar como si hubiese aplicado dejó el piso plano en ejecución. Ante fallo, arreglar la dependencia y repetir solo la parte que falta. Comprobar nodos, referencias y recursos guardados antes de Play.

Los buffers del editor de scripts pueden guardar una versión anterior durante `project_run(autosave=true)` y pisar un `script_create` externo. Usar tabs consistentes para GDScript. Después de una actualización externa, verificar el archivo guardado y su indentación, además de los diagnostics. Si el buffer conserva código viejo, cerrar y reabrir el editor propio del proyecto después de escribir, sin guardar ese buffer viejo. No cerrar otros editores. También se puede ejecutar con autosave false cuando todas las escenas ya están guardadas. No arreglarlo escribiendo escenas o recursos como texto.

`script_create` valida el archivo que recibe. Una validación verde no prueba que el próximo autosave conservará esos bytes, ni que un Array construido por una expresión condicional será compatible con Array[String] en ejecución. Probar las rutas reales.

## Evaluaciones acotadas

`game_eval` inserta la fuente dentro de una función indentada con tabs. Normalizar la indentación del código enviado. El timeout observado es ocho segundos. Mantener las evaluaciones debajo de seis segundos. Una evaluación abortada que sigue esperando un timer puede encontrarse fuera del árbol y fallar si llama get_tree de su nodo temporal.

Para playtests largos, crear por MCP un script de prueba y agregar un nodo efímero a la ejecución. Ese nodo manda InputEvent o acciones normales, lee estados semánticos y guarda reportes. No teletransporta al chef, no altera timers ni usa F1 para simular una campaña válida. El nodo no se guarda en la cocina y se excluye del export. Las lecturas del MCP permanecen cortas.

## Recursos nativos y recuperación

Cuando faltan operaciones especializadas de SpriteFrames o TileSet, un worker temporal escrito y lanzado por MCP puede crear recursos nativos y serializarlos con ResourceSaver. Forzar el scan, esperar que estén importadas las fuentes y comprobar los archivos resultantes antes de asignarlos. Reabrir y guardar la escena después de cambios externos de UID para que las referencias queden sincronizadas.

Registrar las variantes de Theme con set_type_variation. Escribir slots para un nombre sin declarar su base puede dejar activo el estilo de Panel o Button que se intentaba reemplazar.

Para un save corrupto esperado, JSON.new().parse devuelve un error que se puede manejar. JSON.parse_string imprime un error del motor ante JSON dañado, aunque luego la aplicación recupere el backup. Mantener el aviso de recuperación y preservar el archivo corrupto.

No indexar en git un JSON mientras el playtest lo reescribe. Guardar un snapshot inmutable o excluir el archivo vivo del staging hasta que termine la prueba.
