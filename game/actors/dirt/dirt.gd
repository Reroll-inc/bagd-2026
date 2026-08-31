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
@onready var cleanSfx : AudioStreamPlayer2D = $CleanSfx
var dead = false

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

	_randomize_look()


##Recibe un golpe de limpieza y devuelve la magia otorgada.
##La llama la herramienta que está limpiando. `power` es ToolData.cleaning_power.
##
##`magic_scale` descuenta la magia de ESE golpe sin tocar los pases que saca. Lo usa el
##hechizo, que limpia igual que la escoba pero rinde menos magia. Por defecto 1.0, así
##que quien limpie normalmente ni se entera de que el parámetro existe.
func clean(power: int, magic_scale: float = 1.0) -> int:
	if _passes_left <= 0:
		return 0

	#Sin esta guarda un power de 0 sacaría 0 pases y aun así cobraría el mínimo de 1
	#de magia de abajo: magia gratis e infinita golpeando con fuerza cero.
	if power <= 0:
		return 0

	#mini() evita cobrar de más: si quedaba 1 pase y la escoba pega con fuerza 3,
	#se pagan 1. Sin esto, subir cleaning_power sería subir la magia total del nivel.
	var passes_removed: int = mini(power, _passes_left)
	_passes_left -= passes_removed

	#maxi(..., 1): un golpe que efectivamente sacó pases nunca paga 0. Con magic_scale
	#bajo y magic_per_pass chico el redondeo daría 0, y limpiar sin cobrar nada se lee
	#como que el golpe no contó.
	var magic: int = maxi(roundi(float(passes_removed * data.magic_per_pass) * magic_scale), 1)
	cleaned.emit(magic)

	# _refresh_visual()
	
	if _passes_left <=0:
		cleanSfx.play()
		depleted.emit()
		sprite.visible = false
		dead = true
	
	return magic

##Cuántos golpes le quedan.
func get_passes_left() -> int:
	return _passes_left



#Elige uno de los dibujos de la hoja. Vive acá y no en el spawner porque el que sabe
#cuántos frames tiene su textura es este nodo: el spawner decide DÓNDE va un parche,
#el parche decide CÓMO se ve. Con una textura de un solo frame esto no hace nada.
func _randomize_look() -> void:
	var frames: int = sprite.hframes * sprite.vframes

	if frames <= 1:
		return

	#API Godot 4 siembra el generador solo al arrancar, así que no hace falta llamar a
	#randomize(). Si dos partidas seguidas salieran idénticas, esto es lo primero a mirar.
	sprite.frame = randi() % frames


func _fit_sprite_to(target: Vector2) -> void:
	#get_size() devuelve la HOJA entera, pero con hframes/vframes el Sprite2D dibuja
	#una sola celda. Escalar contra la hoja achica el parche en proporción a la cantidad
	#de frames, y si hframes != vframes además lo deforma: dust.png es 256x64 con 4
	#frames, así que daba 0.1875 en x contra 0.75 en y. Sin frames esto divide por 1 y
	#queda igual que antes.
	var frame_size: Vector2 = sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)

	#Guarda contra división por cero: una textura inválida daría scale = inf y el nodo
	#desaparecería de la pantalla sin ningún error que lo explique.
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return

	sprite.scale = target / frame_size

#Feedback de progreso sin arte nuevo: el parche se va desvaneciendo. El piso de 0.25
#es para que el último pase siga siendo visible — si llegara a 0 el jugador creería que
#ya lo limpió y se iría antes de terminar.
func _refresh_visual() -> void:
	var ratio: float = float(_passes_left) / float(data.passes_required)
	sprite.modulate.a = lerpf(0.25, 1.0, ratio)
