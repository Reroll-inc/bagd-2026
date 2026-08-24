extends Node2D
##apunta la varita hacia el mause, limitada al arco de 120 grados

# 0° = vertical hacia el Techo
# 90° = horizontal
# 120° = el piso adelante del mago
const ARC_MIN_DEG: float = 0.0
const ARC_MAX_DEG: float = 120.0

@onready var player: Player = get_parent()
@onready var wand_sprite: Sprite2D = $WandSprite
@onready var muzzle: Marker2D = $Muzzle

# hacia donde apunta la varita
var aim_direction: Vector2 = Vector2.RIGHT

# El ángulo dentro del arco, en grados. Útil para debug y para el HUD.
var aim_angle_deg: float = 90.0

func _physics_process(_delta: float) -> void:
	var facing: int = player.facing_direction
	var to_mouse: Vector2 = get_global_mouse_position() - global_position

	#espejamos la posición del mouse en X según hacia dónde mira el mago
	var local: Vector2 = Vector2(to_mouse.x * facing, to_mouse.y)

	#Da 0° si el mouse está arriba, 90° si está al costado, 180° si está abajo.
	var raw_angle: float = rad_to_deg(atan2(local.x, -local.y))

	#clampf() encierra el valor entre dos límites.
	aim_angle_deg = clampf(raw_angle, ARC_MIN_DEG, ARC_MAX_DEG)

	var radians: float = deg_to_rad(aim_angle_deg)
	var dir_local: Vector2 = Vector2(sin(radians), -cos(radians))
	aim_direction = Vector2(dir_local.x * facing, dir_local.y)

	rotation = aim_direction.angle()

	wand_sprite.flip_v = facing < 0

# de donde sale el hechizo
func get_muzzle_position() -> Vector2:
	return muzzle.global_position
