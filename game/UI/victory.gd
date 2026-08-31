class_name VictoryScreen

extends Control

##Pantalla de victoria. Mismo contrato que game_over.gd: avisa qué botón se apretó y
##no decide nada. Es una clase aparte y no una reutilización de GameOverScreen porque
##además muestra la magia juntada, y porque una pantalla que dice "GANASTE" cargando
##un script llamado GameOver es una trampa para el que venga después.

##El jugador quiere jugar otra vez el mismo nivel.
signal play_again_pressed

##El jugador quiere volver al título.
signal menu_pressed

@onready var _play_again_button: Button = %ToPlayAgain
@onready var _menu_button: Button = %ToMenu

#OPCIONAL a propósito. victory-final.tscn, que es la pantalla de victoria desde el
#rediseño, no tiene MagicLabel: es un mapa de pisos, no un cartel de puntaje. Con % a
#secas el nodo faltante rompe la escena entera al instanciarla; con get_node_or_null()
#la pantalla abre igual y lo único que se pierde es el número.
@onready var _magic_label: Label = get_node_or_null("%MagicLabel") as Label


func _ready() -> void:
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


##Cuánta magia juntó el jugador. La llama Main al abrir la pantalla: igual que el HUD,
##esta escena no sale a buscar el RunState, se lo pasan ya masticado.
##Sin MagicLabel en la escena no hace nada, en vez de reventar.
func show_magic(magic: int) -> void:
	if _magic_label == null:
		return

	_magic_label.text = "%d de magia" % magic


func _on_play_again_pressed() -> void:
	play_again_pressed.emit()


func _on_menu_pressed() -> void:
	menu_pressed.emit()
