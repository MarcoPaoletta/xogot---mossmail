# Revisión visual a partir del feedback

Leer cuando Marco manda capturas con círculos, corrige escala, luz, cámara o composición, o pide revisar todo el juego con imágenes. Complementa [concept match](../concept-match/concept-match.md) y [UI 2D](../ui-polish-2d/ui-polish-2d.md). Para pisos, paredes, alfombras y navegación en vista isométrica, leer también [isométrico 2D](../isometric-2d/isometric-2d.md).

## Convertir cada corrección en evidencia

1. Guardar la captura original y registrar cada círculo o frase como una entrada en `docs/BUILD_NOTES.md`: problema visible, escena dueña, cambio y evidencia necesaria. Los mensajes nuevos se suman a la ronda activa.
2. Inspeccionar la escena y sus propiedades antes de elegir la causa. Un hueco junto a un mueble puede ser un contorno roto; agrandar el sprite o pintar encima no prueba que el piso exista.
3. Cambiar dimensiones, posiciones y recursos permanentes mediante las herramientas del editor del proyecto. Guardar, reabrir la escena dueña y confirmar persistencia. En builds que adoptan Rule 1c, conservar cada elemento como una escena fuente modular; ningún constructor o override de arranque reemplaza la edición.
4. Capturar antes y después con la misma pose, resolución, zoom y estado. Identificar qué cambió en el mundo y qué cambió en el encuadre. Abrir los PNG a tamaño real, incluyendo los bordes del frame.
5. Revisar las otras instancias del mismo sistema. Una corrección local no cierra la ronda si otro piso, puerta o estado repite el defecto.

## Qué revisar según la corrección

| Feedback | Revisión que decide si está resuelto |
|---|---|
| Botones más altos o texto poco legible | Altura real del control, padding superior e inferior, texto y área clickeable. Mirar menú, pausa y opciones en la ventana real, con focus, hover y press. Conservar bordes y proporciones del arte. |
| La luz no debe afectar una burbuja | Revisar el fondo, número, icono y borde bajo la luz más intensa y fuera de ella. Inspeccionar materiales y efectos heredados de todo el componente. Usar el tratamiento de UI sin iluminación que corresponda al proyecto y comprobar que la luz y el glow no lavan sus píxeles. |
| Cámara más cercana al abrir una puerta | Capturar el instante de apertura y la llegada, registrar el zoom efectivo y comprobar el foco en actor y puerta. Expresar un porcentaje relativo al zoom existente. Evitar que el follow o la transición lo reemplacen al siguiente frame. |
| Zoom y paneo manual en cualquier momento | Probar rueda y arrastre con clic izquierdo en gameplay, pausa y durante la transición aplicable. Comprobar ambos extremos y el regreso al actor. Un clic de UI conserva su acción; el arrastre de cámara no dispara una interacción accidental. |
| Pisos más grandes y menos apretados | Comparar altura de pared, profundidad de piso, separación entre niveles y claros de paso manteniendo la escala aprobada de personajes y muebles. Revisar también con el zoom anterior: alejar la cámara no amplía el espacio. |
| Alfombras incorrectas o lejos de puertas | Revisar alineación con umbrales, ejes del piso, extremos, recortes, muebles y soporte debajo. La alfombra queda dentro del piso real; no tapa geometría inválida ni define navegación. |

Los tamaños y porcentajes elegidos se registran por proyecto. Los valores de una ronda no se convierten en defaults para todos los juegos.

## Cobertura de capturas y movimiento

Capturar cada piso o zona en vista general y en primeros planos de esquinas, encuentros de pared con piso, puertas, alfombras y bases de muebles. En una vista fija isométrica, variar encuadre y zoom; si la cámara permite cambiar ángulo, revisar también esos ángulos. Incluir la escena más ocupada, las luces más fuertes y los estados de UI con más texto.

Capturar secuencias cortas de puerta, recorrido, giro y animación. Una pose idle no revela pies que saltan, equipaje que cambia de mano, oclusión incorrecta o un frame gigante. Probar cámara cercana y lejana, paneo a los bordes, pausa y regreso. Guardar capturas numeradas en `docs/evidence/` y relacionarlas con cada entrada del log. Mostrar las imágenes relevantes en el chat.

## Cierre de la ronda

Hay tres comprobaciones distintas: geometría y propiedades guardadas, funcionamiento mediante input real, y lectura visual mediante imágenes. Registrar resultados por separado. Una suite verde no acredita composición, y una foto correcta no acredita que el actor llegue a su puerta.

Precedente: Last Floor Hotel, 7 de octubre de 2026. Tras una suite verde, Marco encontró tiles sobre el zócalo, piso faltante junto a una cómoda y alfombras mal ubicadas. La revisión detectó contornos cruzados y parches de soporte sobre planos de pared. Una auditoría estática de 57 contornos guardados sin cruces ni solapamientos con paredes tampoco cerró por sí sola la verificación de rutas. El aprendizaje es ampliar la evidencia, y no declarar terminado un cambio por una sola captura o un único tipo de check.
