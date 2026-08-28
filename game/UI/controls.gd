class_name ControlsScreen

extends Control

##Pantalla de controles. Igual que el menú: no navega, solo avisa.
##
##Se llama ControlsScreen y no Controls para no confundirse con Control, el nodo de
##Godot del que hereda.

##El jugador quiere salir de esta pantalla.
signal back_pressed

@onready var _back_button: Button = %ButtonBack


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	back_pressed.emit()
