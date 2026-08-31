extends Node2D
##apunta la varita hacia el mouse, limitada a un arco alrededor de la horizontal

# 0° = vertical hacia el Techo
# 90° = horizontal
# 120° = el piso adelante del mago
#
#El arco ya no arranca en 0°: con la maga de 256px, apuntar recto al techo hace
#que la varita barra el cuerpo entero. Quedarse cerca de 90° la mantiene al costado.
#Son @export para que se balanceen desde el Inspector, sin tocar código.
@export_range(0.0, 180.0, 1.0) var arc_min_deg: float = 55.0
@export_range(0.0, 180.0, 1.0) var arc_max_deg: float = 125.0

#Dónde nace la varita, medido desde el centro del player. La x es "hacia ADELANTE"
#y va siempre POSITIVA: el código la espeja según facing_direction, porque flip_h
#espeja el dibujo del sprite pero no mueve ningún nodo hijo ni hermano.
#Esto pisa el position del nodo en cada frame: moverlo en el editor no hace nada,
#el valor que manda es este. Se calibra corriendo el juego, no mirando la escena.
@export var hand_offset: Vector2 = Vector2(24.0, 0.0)

const ACTION_CAST: StringName = &"cast"

#preload (no load): Godot lo resuelve al compilar el script, así el primer disparo
#no frena el juego leyendo del disco. El costo se paga una vez, al arrancar.
const PROJECTILE_SCENE: PackedScene = preload("res://game/actors/projectile/projectile.tscn")


@export var spell: SpellData

@export var cast_cooldown: float = 0.35

#Segundos que faltan para poder volver a disparar. Llega a 0 y se queda ahí.
var _cooldown_left: float = 0.0

@onready var player: Player = get_parent()
@onready var sprite: AnimatedSprite2D = get_parent().get_node("AnimatedSprite2D")
@onready var wand_sprite: Sprite2D = $WandSprite
@onready var muzzle: Marker2D = $Muzzle
@onready var wandSfx: AudioStreamPlayer2D = $"../WandSfx"

#hacia donde apunta la varita
var aim_direction: Vector2 = Vector2.RIGHT

#El ángulo dentro del arco, en grados. Útil para debug y para el HUD.
var aim_angle_deg: float = 90.0

func _ready() -> void:
	if spell == null:
		push_error("WandAimer sin SpellData asignado: la varita no va a disparar")



func _physics_process(delta: float) -> void:
	var facing: int = player.facing_direction

	# La mano cambia de lado cuando la maga voltea. Va ANTES de leer global_position:
	# el pivote tiene que estar en su lugar definitivo antes de medir hacia el mouse.
	position = Vector2(hand_offset.x * facing, hand_offset.y)

	var to_mouse: Vector2 = get_global_mouse_position() - global_position

	#espejamos la posición del mouse en X según hacia dónde mira el mago
	var local: Vector2 = Vector2(to_mouse.x * facing, to_mouse.y)

	#Da 0° si el mouse está arriba, 90° si está al costado, 180° si está abajo.
	var raw_angle: float = rad_to_deg(atan2(local.x, -local.y))

	#clampf() encierra el valor entre dos límites.
	aim_angle_deg = clampf(raw_angle, arc_min_deg, arc_max_deg)

	var radians: float = deg_to_rad(aim_angle_deg)
	var dir_local: Vector2 = Vector2(sin(radians), -cos(radians))
	aim_direction = Vector2(dir_local.x * facing, dir_local.y)

	rotation = aim_direction.angle()

	wand_sprite.flip_v = facing < 0

	_tick_cooldown(delta)


# ═══════════════ DISPARO ═══════════════

func _tick_cooldown(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if spell != null and _cooldown_left <= 0.0 and Input.is_action_just_pressed(ACTION_CAST):
		_cast()


func _cast() -> void:
	#La escala se pregunta en cada disparo y no se cachea en _ready(): así el valor
	#siempre es el vigente, sin depender de que este nodo haya nacido después de la
	#compra. Es una llamada por disparo, no por frame.
	#El cooldown que manda es este @export, no SpellData.cooldown: ese campo existe
	#pero no lo lee nadie.
	_cooldown_left = cast_cooldown * PlayerProgress.get_cast_cooldown_scale()

	var projectile: Projectile = PROJECTILE_SCENE.instantiate() as Projectile

	#cuelga de la escena actual porque todavía no existe un nodo
	#Level con su ProjectileContainer. Cuando exista, esto pasa a ser una referencia
	#inyectada. Está aislado en esta línea a propósito.
	get_tree().current_scene.add_child(projectile)

	projectile.launch(get_muzzle_position(), aim_direction, spell)
	wandSfx.play()
	
	var anim_tween = get_tree().create_tween()
	anim_tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.1).set_trans(Tween.TRANS_QUAD)
	anim_tween.tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.1).set_trans(Tween.TRANS_QUAD)
	anim_tween.tween_property(sprite, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_QUAD)

# de donde sale el hechizo
func get_muzzle_position() -> Vector2:
	return muzzle.global_position
