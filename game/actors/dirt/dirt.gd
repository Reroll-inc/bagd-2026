class_name Dirt

extends Area2D

## Un parche de mugre. Aguanta "passes_required" golpes y desaparece.
##
##No decide nada ni busca a nadie: recibe golpes de una herramienta y avisa cuánta
##magia entregó. Todo su comportamiento entra por clean().

##Emitida en cada golpe recibido, con la magia que ese golpe generó.
signal cleaned(magic: int)

##Emitida cuando el parche se agota, justo antes de destruirse.
signal depleted


# Cada parche se anota solo en este grupo al nacer. Así RunState los encuentra
#con get_tree().get_nodes_in_group() sin que nadie los cablee a mano en el editor —
#que es justo lo que no queremos, porque los niveles van a tener docenas.
const GROUP: StringName = &"dirt"

@export var data: DirtData

var _passes_left: int = 0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group(GROUP)

	#Sin data este nodo no puede hacer nada, y un parche
	#invisible que no se limpia es mucho más difícil de diagnosticar que un error rojo.
	if data == null:
		push_error("Dirt sin DirtData asignado: %s" % name)

	_passes_left = data.passes_required


	if data.texture != null:
		sprite.texture = data.texture
		_fit_sprite_to(data.display_size)


##Recibe un golpe de limpieza y devuelve la magia otorgada.
##La llama la herramienta que está limpiando. `power` es ToolData.cleaning_power.
func clean(power: int) -> int:
	if _passes_left <= 0:
		return 0

	#mini() evita cobrar de más: si quedaba 1 pase y la escoba pega con fuerza 3,
	#se pagan 1. Sin esto, subir cleaning_power sería subir la magia total del nivel.
	var passes_removed: int = mini(power, _passes_left)
	_passes_left -= passes_removed

	var magic: int = passes_removed * data.magic_per_pass
	cleaned.emit(magic)

	_refresh_visual()

	if _passes_left <=0:
		depleted.emit()
		queue_free()
	
	return magic

##Cuántos golpes le quedan.
func get_passes_left() -> int:
	return _passes_left



func _fit_sprite_to(target: Vector2) -> void:
	var texture_size: Vector2 = sprite.texture.get_size()

	#Guarda contra división por cero: una textura inválida daría scale = inf y el nodo
	#desaparecería de la pantalla sin ningún error que lo explique.
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	sprite.scale = target / texture_size

#Feedback de progreso sin arte nuevo: el parche se va desvaneciendo. El piso de 0.25
#es para que el último pase siga siendo visible — si llegara a 0 el jugador creería que
#ya lo limpió y se iría antes de terminar.
func _refresh_visual() -> void:
	var ratio: float = float(_passes_left) / float(data.passes_required)
	sprite.modulate.a = lerpf(0.25, 1.0, ratio)
