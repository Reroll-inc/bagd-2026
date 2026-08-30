class_name DirtSpawner

extends Node2D

##Reparte los parches de mugre entre sus puntos de aparición: distinto en cada partida.
##
##Los Marker2D son HIJOS de este nodo, así que no hay nada que exportar ni cablear, y
##en el editor los ves todos juntos como un solo grupo. Los parches, en cambio, los busca
##entre sus HERMANOS y por tipo — igual que Main busca el RunState: renombrar un nodo no
##rompe nada, un string mágico sí.
##
##No crea ni destruye parches: los MUEVE. Por eso la magia total del nivel es idéntica en
##todas las partidas y el balance de magic_goal se sostiene solo. Un spawner que
##instanciara mugre tendría que además garantizar que la cuenta cierre.

@export var print_events: bool = false


func _ready() -> void:
	_place_dirt()


#Corre en _ready() y NO diferido, a propósito. Los nodos hermanos ya EXISTEN apenas se
#instancia la escena, aunque su propio _ready() no haya corrido todavía: por eso alcanza
#con recorrerlos por tipo y el orden del panel Scene deja de importar. Buscarlos por el
#grupo "dirt" habría obligado a diferir, porque cada Dirt se anota recién en su _ready().
func _place_dirt() -> void:
	var points: Array[Marker2D] = _collect_points()
	var patches: Array[Dirt] = _collect_patches()

	if points.is_empty():
		push_warning("DirtSpawner: no tiene ningún Marker2D hijo. Los parches quedan donde estaban.")
		return

	if points.size() < patches.size():
		push_warning("DirtSpawner: %d puntos para %d parches. Los que sobren no se mueven." % [points.size(), patches.size()])

	#shuffle() baraja el array en el lugar. Barajar los PUNTOS y repartirlos en orden es
	#lo mismo que sortear sin reposición: ningún parche puede caer sobre otro.
	points.shuffle()

	var moved: int = mini(points.size(), patches.size())

	for i: int in moved:
		patches[i].global_position = points[i].global_position

	if print_events:
		print("[DirtSpawner] %d parches repartidos entre %d puntos" % [moved, points.size()])


func _collect_points() -> Array[Marker2D]:
	var points: Array[Marker2D] = []

	for child: Node in get_children():
		var marker: Marker2D = child as Marker2D

		if marker != null:
			points.append(marker)

	return points


#Solo encuentra parches que sean hijos DIRECTOS del mismo nodo que este spawner. Si
#algún día los parches se agrupan dentro de un contenedor, esto deja de verlos —y no da
#error: simplemente no mueve nada. El print_events es la forma de darse cuenta.
func _collect_patches() -> Array[Dirt]:
	var patches: Array[Dirt] = []
	var level: Node = get_parent()

	if level == null:
		return patches

	for child: Node in level.get_children():
		var patch: Dirt = child as Dirt

		if patch != null:
			patches.append(patch)

	return patches
