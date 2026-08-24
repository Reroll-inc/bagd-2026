extends Resource
class_name PlayerData

@export_category("Stats")
@export var max_hp: int = 3


@export_category("Mechanics")
@export_group("Climb")
@export var climb_speed: float = 200.0
@export var climb_step_interval: float = 0.25

@export_group("Dash")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.4


@export_group("Jump")
@export var jump_height: float = -312.0
@export var jump_hold: float = 0.5
@export var gravity: float = 20.5
@export var fast_fall_gravity: float = 600.0

@export_group("Double Jump")
@export var double_jump_max: int = 1

@export_group("Fly")
@export var fly_speed: float = 200.0
@export var fly_flap_interval: float = 1.0
@export var air_acceleration: float = 10.0

@export_group("Movement")
@export var movement_step_interval: float = 0.3
@export var movement_max_speed: float = 200.0
@export var movement_acceleration: float = 54.5
@export var movement_friction: float = 12.5

@export_group("Kill")
@export var bounce_up_on_kill: float = -300.0
