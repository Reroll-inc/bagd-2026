extends CharacterBody2D

# &"jump" es el nombre de la acción del InputMap. El & la marca como texto fijo:
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"

# Ajustes: desde el Inspector
@export_group("Movimiento")
@export var move_speed: float = 220.0
@export var acceleration: float = 2200.0   #qué tan rápido arranca
@export var friction: float = 2600.0       #qué tan rápido frena
@export var air_control: float = 0.65      #control en el aire (1.0 = igual que en piso)
@export var gravity: float = 980.0

@export_group("Salto")
@export var jump_velocity: float = -420.0      #NEGATIVO: en Godot 2D, Y crece hacia ABAJO
@export var fall_gravity_scale: float = 1.4    #caer más pesado que subir = se siente mejor
@export var jump_cut_multiplier: float = 0.45  #soltar el botón corta el salto

@export_group("Debug")
@export var print_state: bool = false

enum State { GROUNDED, AIRBORNE }

var state: State = State.GROUNDED

var facing_direction: int = 1   # 1 derecha, -1 izquierda.

@onready var sprite: Sprite2D = $Sprite2D




func _physics_process(delta: float) -> void:
	#Según el estado, corre una función u otra. Nunca las dos.
	match state:
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
		velocity.y = jump_velocity
		_change_state(State.AIRBORNE)
	elif not is_on_floor():
		# Se cayó de una plataforma sin saltar
		_change_state(State.AIRBORNE)


func _state_airborne(delta: float) -> void:
	#velocity.y > 0 significa CAYENDO.
	var g_scale: float = 1.0

	if velocity.y > 0.0:
		g_scale = fall_gravity_scale

	_apply_gravity(delta, g_scale)
	_apply_movement(delta, air_control)

	# Salto de altura variable: si soltás el botón mientras subís, cortás el impulso.
	if velocity.y < 0.0 and not Input.is_action_pressed(ACTION_JUMP):
		velocity.y *= jump_cut_multiplier

	if is_on_floor():
		_change_state(State.GROUNDED)





# ═══════════════ HERRAMIENTAS ═══════════════

func _apply_gravity(delta: float, scale: float) -> void:
	velocity.y += gravity * scale * delta


func _apply_movement(delta: float, control: float) -> void:
	#get_axis(izq, der) devuelve -1, 0 o 1 ya calculado.
	var direction: float = Input.get_axis(ACTION_LEFT, ACTION_RIGHT)
	var target_speed: float = direction * move_speed

	#Si no hay input, frena. Si hay, acelera.
	var rate: float = acceleration
	if direction == 0.0:
		rate = friction

	#move_toward(actual, objetivo, paso) acerca un número a otro sin pasarse.
	velocity.x = move_toward(velocity.x, target_speed, rate * control * delta)

	if direction != 0.0:
		facing_direction = 1 if direction > 0.0 else -1
		sprite.flip_h = facing_direction < 0


#TODAS las transiciones pasan por acá. Si algún día el personaje queda
#trabado en un estado, este es el único lugar donde poner un breakpoint.
func _change_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	if print_state:
		print("[Player] estado → ", State.keys()[state])