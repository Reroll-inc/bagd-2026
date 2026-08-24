extends Resource
class_name PlayerData

@export_category("Mechanics")
@export_group("Jump")
@export var jump_velocity: float = -420.0 #NEGATIVO: en Godot 2D, Y crece hacia ABAJO
@export var fall_gravity_scale: float = 1.4 #caer más pesado que subir = se siente mejor
@export var jump_cut_multiplier: float = 0.45 #soltar el botón corta el salto

@export_group("Movement")
@export var move_speed: float = 220.0
@export var acceleration: float = 2200.0 #qué tan rápido arranca
@export var friction: float = 2600.0 #qué tan rápido frena
@export var air_control: float = 0.65 #control en el aire (1.0 = igual que en piso)
@export var gravity: float = 980.0


@export_group("Aim")
@export var facing_deadzone: float = 6.0

@export_group("Debug")
@export var print_state: bool = false

