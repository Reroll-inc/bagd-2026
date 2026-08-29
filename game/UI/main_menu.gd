class_name MainMenu

extends Control

##Pantalla de título. No sabe nada del juego: solo avisa qué botón se apretó.
##
##Quien decide qué pasa es Main, igual que con RunState. Si esta pantalla llamara
##directo a "cargar el nivel", habría que abrirla y editarla el día que el arranque
##cambie — por ejemplo si alguna vez hay que pasar por el mapa de niveles primero.
##Avisando en vez de actuar, la pantalla se puede reusar en cualquier flujo.

##El jugador quiere jugar.
signal play_pressed

##El jugador quiere ver los controles.
signal controls_pressed

#Nombres únicos (%): si alguien rediseña la pantalla y mueve los botones adentro de otro
#contenedor, esto los sigue encontrando. Con rutas fijas se rompería en silencio.
@onready var _play_button: Button = %ToPlay
@onready var _controls_button: Button = %ToControls


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_controls_button.pressed.connect(_on_controls_pressed)


#Los botones no emiten las señales de la pantalla directamente: pasan por acá. Es un
#renglón de más que deja un solo lugar donde poner un breakpoint o un print si algún
#día un botón deja de responder.
func _on_play_pressed() -> void:
	play_pressed.emit()


func _on_controls_pressed() -> void:
	controls_pressed.emit()
