class_name GameOverScreen

extends Control

##Pantalla de derrota. Mismo contrato que el menú y los controles: avisa, no navega.
##
##Aparece con el árbol pausado, así que depende de que el CanvasLayer "GUI" de main.tscn
##esté en process_mode ALWAYS. Si algún día sus botones dejan de responder al perder,
##ese es el primer lugar donde mirar.

##El jugador quiere reintentar el mismo nivel.
signal play_again_pressed

##El jugador quiere volver al título.
signal menu_pressed

@onready var _play_again_button: Button = %ToPlayAgain
@onready var _menu_button: Button = %ToMenu


func _ready() -> void:
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func _on_play_again_pressed() -> void:
	play_again_pressed.emit()


func _on_menu_pressed() -> void:
	menu_pressed.emit()
