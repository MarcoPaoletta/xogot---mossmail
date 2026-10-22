# Isométrico 2D: superficies, anclas y recorridos

Leer antes de construir o corregir habitaciones, pisos apilados, corredores, alfombras o navegación en un juego 2D con arte isométrico. Esta referencia trata `Camera2D` y sprites; las reglas de proyección de `Camera3D` se aplican a juegos 3D. Para la ronda de capturas, usar [revisión visual](../visual-feedback-review/visual-feedback-review.md).

## Una topología coherente

Definir una referencia común de suelo: sus dos ejes isométricos, origen, contorno transitable y umbrales. Piso visible, pie de paredes, frentes de losa, colisiones, navegación y markers se alinean con esa referencia. Son elementos distintos y pueden tener márgenes distintos, pero ninguno debe inventar un espacio incompatible con los demás.

Las posiciones, dimensiones y contornos permanentes se editan y guardan mediante las herramientas del editor. En builds que adoptan Rule 1c, cada elemento conserva su escena fuente, el nivel compone instancias y los scripts solo coordinan comportamiento sobre esa estructura. Un generador, builder temporal o parche en `_ready()` no reemplaza el authoring.

1. Recorrer el perímetro en un único sentido y sin saltar entre esquinas. Cada tramo de una pared o borde avanza de forma monotónica sobre su eje previsto. Los entrantes reales se representan como entrantes, sin unir puntos distantes con una diagonal que atraviesa la habitación.
2. El contorno es simple: no hay cruces entre aristas no adyacentes, segmentos de longitud cero ni vértices duplicados innecesarios. Controles de área o winding no bastan para detectar un polígono que se cruza a sí mismo.
3. Derivar los encuentros de pared y los frentes de losa de los bordes reales que les corresponden. Un plano de suelo no puede ocupar el zócalo, y un frente de losa no cuenta como soporte para pies o muebles.
4. Confirmar superficie visible bajo cada base de mueble y sobre cada recorrido. Si falta suelo, corregir el límite real y sus elementos relacionados mediante el editor. No agregar un parche dibujado sobre una pared para esconder el hueco.
5. Mantener navegación y colisiones sobre suelo verdadero. Medir la forma del collider y su transform local respecto del punto que consulta la ruta. Un radio correcto con el centro desplazado todavía permite rutas que chocan con muebles. Expresar suelo, obstáculos y footprint del actor en la misma referencia antes de aplicar márgenes; no agrandar el radio a ciegas. Un parche visual o una alfombra nunca amplía el área caminable ni justifica una ruta horneada debajo de geometría incorrecta.

La validación de cruces se hace sobre todos los contornos guardados afectados, no solo sobre la definición fuente que se esperaba guardar. Revisar además las intersecciones entre superficies del mismo piso y los planos de pared. Excluir de esa comparación la superposición en pantalla entre niveles distintos cuando su separación y oclusión son intencionales.

## Alfombras y umbrales

La silueta y textura de una alfombra mantienen la perspectiva de la superficie que la sostiene. Para un runner de pasillo, medir la dirección efectiva del corredor y de los umbrales visibles. No imponer la pendiente isométrica global si ese tramo del escenario tiene otra dirección. Un rectángulo horizontal de pantalla o un triángulo para rellenar un hueco se descubre en cuanto se acerca la cámara.

Cuando Marco pide una línea recta, usar una única dirección larga de extremo a extremo, con dos bordes largos rectos y paralelos. Evitar codos, escalones y cambios de pendiente entre puertas. Ubicar la franja completa dentro del suelo y comprobar ambos extremos en la misma captura. En Last Floor Hotel, la línea entre los umbrales 402 y 403 tenía pendiente aproximada 0.254, mientras el valor global era 0.38; usar ese valor global dejó el extremo del runner desalineado con las puertas.

Ubicarla desde el umbral real de la puerta y comprobar la distancia visible hasta él. Cuando el pedido es acercarla, mover el extremo correspondiente y revisar la alfombra completa. No extenderla fuera del piso para alcanzar una puerta mal alineada. Sus puntas permanecen sobre suelo verdadero, no sobre frentes de losa, huecos, zócalos o footprints de props. Los tramos de un corredor se conectan sin cortes diagonales ajenos al plano.

Revisar extremos, esquinas y encuentros bajo luz real con una captura cercana de cada alfombra. Probar el acceso a la puerta por ambos sentidos; el rug no cambia colisión ni navegación.

## Escala, claridad y anclas

Para reducir densidad, ampliar profundidad y claros de paso, altura de paredes o separación de niveles según el concepto. Mantener el tamaño aprobado del personaje, su equipaje y los muebles. Medir las relaciones en el encuadre del concepto y también a zoom constante, porque alejar la cámara puede disimular el mismo espacio apretado.

Cada puerta tiene un marker de umbral y una llegada válida para los pies del actor. Comprobar el claro con el collider completo, el equipaje visible, ambos sentidos de entrada y las poses más anchas. Los props decorativos no ocupan ese paso. El orden de dibujo se decide por contacto con el suelo y oclusión prevista; aumentar `z_index` globalmente no corrige un plano mal construido.

Si el contrato entrega ocho vistas reales, usar sus ocho direcciones. Un espejo horizontal cambia de mano una maleta o un arma y rompe el motivo de tener vistas distintas. Verificar cada dirección en movimiento, sin confiar solo en el nombre del clip. Mantener un ancla estable en los pies entre direcciones y estados; los offsets se miden sobre los sprites entregados. Ver [importación de animación](../sprite-animation-import/sprite-animation-import.md) y [anclas](../character-anchors-handover/character-anchors-handover.md).

## Verificación de fuente, guardado y runtime

Inspeccionar la escena fuente, guardar y reabrir para confirmar contornos, markers, transforms y ownership. Lanzar una instancia nueva y recorrer los mismos puntos. Esta cadena separa una definición correcta, una escena que realmente persistió y un estado que el runtime usa.

La evidencia mínima de una corrección incluye una vista general por piso, primeros planos de encuentros y alfombras, y movimiento real por puertas, esquinas y pasajes modificados. El actor recorre la ruta con su collider real; una consulta de path válida no acredita que complete el trayecto. Revisar los extremos de zoom y paneo, pausa y transiciones de cámara. Si la vista admite varios ángulos, capturarlos; si es fija, desplazar el encuadre para descubrir bordes ocultos por UI o props. Mantener pares de antes y después con la misma pose.

Last Floor Hotel, 7 de octubre de 2026: el contorno de floor 4 se cruzaba, había parches de pasaje sobre paredes y floor 2 también tenía un contorno cruzado. Marco los detectó como tiles cortando el zócalo y falta de piso junto a un mueble. Una auditoría de contornos no prueba que las rutas sigan funcionando: después de cualquier corrección de superficie, probar recorrido, llegada, entrega y retorno con los actores reales antes de cerrar el cambio.
