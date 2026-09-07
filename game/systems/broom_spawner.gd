class_name BroomSpawner

extends Node2D

##Pone en el nivel las escobas que el jugador compró en la tienda.
##
##Gemelo del DirtSpawner y con las mismas reglas: los Marker2D son HIJOS de este nodo, así
##que no hay nada que exportar ni cablear, y en el editor se ven todos juntos como un
##grupo. Las escobas nacen como HERMANAS, colgando del nivel, igual que la que ya venía
##puesta a mano.
##
##A diferencia del DirtSpawner, este sí INSTANCIA: las escobas compradas no existen hasta
##que alguien las paga. Eso está bien acá porque una escoba de más no cambia la magia total
##del nivel — cambia la velocidad a la que se junta.
##
##Los puntos se usan EN ORDEN, sin barajar. Es deliberado y al revés que el DirtSpawner:
##de la mugre se quiere variedad, de una compra se quiere previsibilidad. El primer marker
##es el mejor lugar, el segundo el siguiente, y el jugador aprende dónde aparecen.
##
##Cada Marker2D tiene que estar sobre PISO FIRME. Este nodo no lo verifica: una escoba
##en el aire cae, y si cae fuera del nivel se pierde sin ningún error. Esa validación es
##el trabajo manual que este spawner existe para hacer posible.

##La escena que se instancia. Va broom.tscn, que ya viene con su ToolData, su capa de
##física y su collider: no hay nada que configurar después de instanciarla.
@export var broom_scene: PackedScene

@export var print_events: bool = false


func _ready() -> void:
	#DIFERIDO Y NO DIRECTO, al revés que el DirtSpawner. La diferencia es que aquel
	#solo MUEVE nodos que ya existen y este AGREGA: cuando este _ready() corre, el nivel
	#todavía está en medio de armar su lista de hijos, y Godot rechaza el add_child()
	#con "Parent node is busy setting up children". Un llamado diferido corre cuando el
	#árbol ya terminó de armarse. Mismo patrón que RunState._connect_to_dirt().
	_spawn_purchased_brooms.call_deferred()


#La escoba nueva corre su _ready() al entrar al árbol, y ahí se anota sola en el grupo
#"tools". Aparece un frame después de que el nivel se carga, que a ojo no se nota.
func _spawn_purchased_brooms() -> void:
	#La automática ocupa un punto más, después de las normales. Se cuenta acá para que
	#todas las validaciones de abajo la incluyan y no aparezca encimada con otra.
	var auto: int = 1 if PlayerProgress.has_auto_broom() else 0
	var wanted: int = PlayerProgress.get_extra_brooms() + auto

	if wanted <= 0:
		return

	if broom_scene == null:
		push_error("BroomSpawner sin broom_scene asignado: las %d escobas compradas no van a aparecer." % wanted)
		return

	var points: Array[Marker2D] = _collect_points()

	if points.is_empty():
		push_warning("BroomSpawner: no tiene ningún Marker2D hijo. Las %d escobas compradas no aparecen." % wanted)
		return

	#Un punto por escoba y sin repetir: dos escobas en la misma posición se ven como una
	#sola y el jugador cree que la compra no funcionó.
	if points.size() < wanted:
		push_warning("BroomSpawner: %d puntos para %d escobas compradas. Solo aparecen %d." % [
			points.size(), wanted, points.size()
		])

	var level: Node = get_parent()

	if level == null:
		return

	var spawned: int = mini(points.size(), wanted)

	for i: int in spawned:
		var broom: CleaningTool = broom_scene.instantiate() as CleaningTool

		#Si la escena asignada no es una escoba, se dice ahora y no dentro de tres
		#sistemas cuando algo no limpie.
		if broom == null:
			push_error("BroomSpawner: broom_scene no tiene el script cleaning_tool.gd en su raíz.")
			return

		#La ÚLTIMA es la automática, si se compró. Se marca antes del add_child() para
		#que su _ready() ya la vea autónoma: ahí es donde se despierta sola.
		broom.autonomous = auto > 0 and i == spawned - 1

		level.add_child(broom)

		#global_position y no position: se asigna DESPUÉS del add_child() porque hasta
		#estar en el árbol el nodo no tiene transform global contra el que resolverla.
		broom.global_position = points[i].global_position

	if print_events:
		print("[BroomSpawner] %d escoba(s) puestas en %d puntos (automáticas: %d)" % [spawned, points.size(), auto])


func _collect_points() -> Array[Marker2D]:
	var points: Array[Marker2D] = []

	for child: Node in get_children():
		var marker: Marker2D = child as Marker2D

		if marker != null:
			points.append(marker)

	return points
