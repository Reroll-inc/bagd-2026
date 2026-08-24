extends CharacterBody2D

#permite que otros scripts (como wand_aimer.gd) escriban
#`var p: Player` y accedan a facing_direction con tipado y autocompletado.
class_name Player

# &"jump" es el nombre de la acción del InputMap. El & la marca como texto fijo:
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"
@export var properties: PlayerData = preload("res://game/actors/player/player_data.tres")

enum State {
	GROUNDED,
	AIRBORNE,
}

var _state: State = State.GROUNDED
var facing_direction: int = 1 # 1 derecha, -1 izquierda.

@onready var sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	_update_facing() 
	
	match _state:
		State.GROUNDED:
			_state_grounded(delta)
		State.AIRBORNE:
			_state_airborne(delta)

	move_and_slide()

# ═══════════════ ESTADOS ═══════════════


func _state_grounded(delta: float) -> void:
	_apply_gravity(delta, 1.0)
	_apply_movement(delta, 1.0)

	if Input.is_action_just_pressed(ACTION_JUMP):
		velocity.y = properties.jump_velocity
		_change_state(State.AIRBORNE)
	elif not is_on_floor():
		# Se cayó de una plataforma sin saltar
		_change_state(State.AIRBORNE)


func _state_airborne(delta: float) -> void:
	#velocity.y > 0 significa CAYENDO.
	var g_scale: float = 1.0

	if velocity.y > 0.0:
		g_scale = properties.fall_gravity_scale

	_apply_gravity(delta, g_scale)
	_apply_movement(delta, properties.air_control)

	# Salto de altura variable: si soltás el botón mientras subís, cortás el impulso.
	if velocity.y < 0.0 and not Input.is_action_pressed(ACTION_JUMP):
		velocity.y *= properties.jump_cut_multiplier

	if is_on_floor():
		_change_state(State.GROUNDED)

# ═══════════════ HERRAMIENTAS ═══════════════


func _apply_gravity(delta: float, g_scale: float) -> void:
	velocity.y += properties.gravity * g_scale * delta


func _apply_movement(delta: float, control: float) -> void:
	#get_axis(izq, der) devuelve -1, 0 o 1 ya calculado.
	var direction: float = Input.get_axis(ACTION_LEFT, ACTION_RIGHT)
	var target_speed: float = direction * properties.move_speed

	#Si no hay input, frena. Si hay, acelera.
	var rate: float = properties.acceleration
	if direction == 0.0:
		rate = properties.friction

	#move_toward(actual, objetivo, paso) acerca un número a otro sin pasarse.
	velocity.x = move_toward(velocity.x, target_speed, rate * control * delta)


#el mago mira hacia el MOUSE. Eso te deja retroceder
#mientras seguís limpiando, y evita que la varita quede trabada contra el
#tope del arco cuando el cursor está del lado opuesto.
#La deadzone impide que el mago tiemble cuando el cursor pasa justo encima
func _update_facing() -> void:
	var offset_x: float = get_global_mouse_position().x - global_position.x

	if absf(offset_x)<properties.facing_deadzone:
		return

	facing_direction = 1 if offset_x > 0.0 else -1
	sprite.flip_h = facing_direction < 0


#TODAS las transiciones pasan por acá. Si algún día el personaje queda
#trabado en un estado, este es el único lugar donde poner un breakpoint.
func _change_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	if properties.print_state:
		print("[Player] estado → ", State.keys()[_state])
