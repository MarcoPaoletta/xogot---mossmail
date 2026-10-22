# Plataformas, dirección y revisión visual

Medido en Shrine Keeper el 7 de octubre de 2026, después del playtest de Marco.

Un HUD diseñado para teléfono no se muestra entero en PC. Se decide con las features `android` o `ios`. El renderer Mobile puede usarse en PC y su nombre no decide la interfaz. Un override para revisar touch vive en F1, arranca desactivado y no se serializa en escenas de PC. Sacar el panel de sonido del HUD exige conservar un control de audio dentro de pausa para el teléfono que arranca muteado. Ver [las capturas reales de antes y después](examples/shrine-keeper-ui-review.md).

Si Marco pide sacar energía, se quitan también agotamiento, límites de carrera, descripciones de consumibles y tutoriales relacionados. En Shrine Keeper, Shift mantuvo aproximadamente 640 px/s durante 6,6 segundos y recorrió 4091 px. Un flag de sprint en true mientras la velocidad es cero contra una pared no prueba carrera continua.

Las etiquetas de dirección de un generador no prueban hacia dónde mira el personaje. Se inspeccionan todos los frames y las ocho vistas idle. En Shrine Keeper las cuatro diagonales estaban espejadas y las cardinales eran correctas. `flip_h` por clip corrigió todas las diagonales conservando los PNG, los hashes y el contacto de los pies.

Una grilla con nombres que pueden ocupar dos líneas necesita incluir ambas líneas en la altura de cada fila. Los tests de texto comparan ancho real del font y ancho real del Label, porque un mínimo automático puede expandir el Label y esconder el problema. Una captura detectó nombres sobre la segunda fila aunque el texto entraba en su propio control. La solución final usó nombres completos en una línea y más margen lateral en el pergamino.

La navegación se hornea con geometría física real y la misma referencia del actor. En Shrine Keeper, un rock tenía su borde inferior en 3020,8 y la ruta permitía pies en 3050,8. El círculo del ranger estaba 18 px más arriba y todavía tocaba el rock. Se desplazaron todos los outlines y traversal 18 px hacia abajo, con radio de navegación 32 para un cuerpo 30. El chequeo muestreó rutas cada 6 px contra las formas reales y el recorrido completo de la quest volvió a pasar. Guiado y probes esperan estar a 12 px de una esquina antes de avanzar: con 45 px pueden cortar una esquina válida del navmesh.

Un recorte de una flecha del joystick todavía puede contener su fondo cuadrado. Se revisa sobre el mundo. La extracción de alpha de la silueta conserva el RGB original de Holopix y evita dibujar otro icono. Para nivelar un puente pintado en diagonal, se mide la pendiente de sus dos barandas y se aplica un shear vertical al sprite. Rotarlo también inclina los postes. La colisión y la navegación se verifican cruzándolo con teclas reales.

Después de `set_deferred("disabled", true)`, el signal `physics_frame` no garantiza que la cola diferida ya se aplicó. Un probe espera la condición física observable con timeout y registra cuánto tardó. El combate se prueba por entrada real: golpe, cooldown, esquive, invulnerabilidad, pausa, diálogo, curación y reinicio.

Un fixture de aspect con scripts desactivados copia la visibilidad, offsets, texto y pose actuales del juego antes de renderizar. Si no lo hace, puede mostrar de nuevo el HUD táctil por defaults de la escena y producir evidencia de otro estado.

En authoring se evita reemplazar profundamente los recursos compartidos de una escena abierta. `CACHE_MODE_REPLACE_DEEP` invalidó handles del font y produjo errores `fd is null` en el editor. Se corrigió cargando la escena de authoring con `CACHE_MODE_IGNORE` y reiniciando el editor antes de validar. Si una operación larga pierde transporte, primero se inspeccionan sus archivos y estado. Puede haber guardado correctamente.

La evidencia está en `docs/evidence/new-user-review.json`, `probe-slime_probe.json`, `bridge-playtest.json` y las capturas `revision-*` del repo `MarcoPaoletta/holopix-shrine-keeper`. La prueba del teléfono físico sigue siendo una verificación aparte.
