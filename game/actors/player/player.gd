extends CharacterBody2D

#permite que otros scripts (como wand_aimer.gd) escriban
#`var p: Player` y accedan a facing_direction con tipado y autocompletado.
class_name Player

# &"jump" es el nombre de la acción del InputMap. El & la marca como texto fijo:
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"
@export var properties: PlayerData = preload("res://game/actors/player/player_data.tres")

#Nombres de los clips del SpriteFrames. Hoy el recurso solo tiene "idle": los otros
#tres se piden igual y caen al fallback hasta que exista el arte.
const ANIM_IDLE: StringName = &"idle"
const ANIM_RUN: StringName = &"run"
const ANIM_JUMP: StringName = &"jump"
const ANIM_FALL: StringName = &"fall"

#Debajo de esta velocidad la maga cuenta como quieta. Existe porque la fricción
#deja residuos de fracciones de píxel: sin umbral, el clip parpadearía entre idle y
#run durante el frenado.
const IDLE_SPEED_THRESHOLD: float = 10.0

enum State {
	GROUNDED,
	AIRBORNE,
}

var _state: State = State.GROUNDED
var facing_direction: int = 1 # 1 derecha, -1 izquierda.

# El clip que está sonando y el último que se PIDIÓ. Son distintos a propósito: hoy
# se piden cuatro y suena uno solo.
var _current_anim: StringName = &""
var _last_wanted_anim: StringName = &""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	_update_facing() 
	
	match _state:
		State.GROUNDED:
			_state_grounded(delta)
		State.AIRBORNE:
			_state_airborne(delta)

	move_and_slide()
	_update_animation()
	var camera = ($Camera2D as Camera2D)
	ShaderVars.x_pos = camera.get_screen_center_position().x
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
	sprite.flip_h = facing_direction > 0

# ═══════════════ ANIMACIÓN ═══════════════


#Traductor entre gameplay y presentación: la máquina de estados decide QUÉ está
#haciendo la maga, esto decide CÓMO se ve.
func _update_animation() -> void:
	var wanted: StringName = _wanted_animation()

	# has_animation() es lo que hace seguro pedir un clip que todavía no existe:
	var actual: StringName = wanted
	if not sprite.sprite_frames.has_animation(wanted):
		actual = ANIM_IDLE

	var wanted_changed: bool = wanted != _last_wanted_anim
	_last_wanted_anim = wanted

	if wanted_changed and properties.print_animation:
		if wanted == actual:
			print("[Player] anim → ", wanted)
		else:
			print("[Player] anim → ", wanted, "  (no existe, cae a ", actual, ")")

	#play() solo cuando el clip CAMBIA. Llamarlo todos los frames es la forma
	#clásica de dejar una animación congelada para siempre en su primer cuadro.
	if actual == _current_anim:
		return

	_current_anim = actual
	sprite.play(actual)


# El único lugar que decide qué clip corresponde. Devuelve el nombre IDEAL, sin
# preguntarse si existe: de eso se ocupa quien llama.
func _wanted_animation() -> StringName:
	if _state == State.AIRBORNE:
		# velocity.y < 0 es SUBIENDO (en Godot 2D, Y crece hacia abajo).
		return ANIM_JUMP if velocity.y < 0.0 else ANIM_FALL

	if absf(velocity.x) > IDLE_SPEED_THRESHOLD:
		return ANIM_RUN

	return ANIM_IDLE


#TODAS las transiciones pasan por acá. Si algún día el personaje queda
#trabado en un estado, este es el único lugar donde poner un breakpoint.
func _change_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	if properties.print_state:
		print("[Player] estado → ", State.keys()[_state])
