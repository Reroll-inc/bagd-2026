class_name Main

extends Node

##Punto de entrada del juego y único dueño del ciclo de vida de los niveles:
##los instancia, los descarga y los recarga. Nadie más hace eso.
##
##Existe para que el HUD viva FUERA del nivel. Cuando se reinicia una run se destruye
##el nivel y nada más: la interfaz sobrevive intacta. El día que haya menú, selección
##de niveles o árbol de talentos, este es el nodo que los va a coordinar.

##Nivel que se carga al arrancar. Cambialo en el Inspector para probar otro.
@export var level_scene: PackedScene

##Segundos que queda el cartel de derrota antes de reiniciar solo.
@export_range(0.5, 10.0, 0.1) var restart_delay: float = 3.0
@export var print_events: bool = true

@onready var _level_container: Node2D = $LevelContainer
@onready var _hud: Hud = %HUD

#El nivel vivo. Null entre que se descarga uno y se instancia el siguiente.
var _level: Node = null

#La run terminó y estamos mostrando el cartel. Habilita la tecla de reinicio.
var _run_finished: bool = false

#Número de serie de la run actual.
var _run_id: int = 0



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if print_events:
		print("[Main] listo")

	_load_level()


##Descarga el nivel que haya, instancia uno nuevo y lo cablea.
func _load_level() -> void:
	if level_scene == null:
		push_error("Main sin level_scene asignado: no hay nada que cargar.")
		return
	
	get_tree().paused = false
	_run_finished = false
	_run_id += 1
	_hud.hide_end_message()

	_unload_level()

	_level = level_scene.instantiate()
	_level_container.add_child(_level)

	var run_state: RunState = _find_run_state(_level)

	if run_state == null:
		push_error("El nivel '%s' no tiene ningún RunState hijo. La run no puede terminar." % level_scene.resource_path)
		return

	run_state.run_lost.connect(_on_run_lost)
	run_state.run_won.connect(_on_run_won)

	_hud.bind_run_state(run_state)

	if print_events:
		print("[Main] nivel cargado")


func _unload_level() -> void:
	if _level == null:
		return

	_level_container.remove_child(_level)
	_level.queue_free()
	_level = null


#Busca el RunState entre los hijos directos del nivel. Por TIPO y no por nombre: si
#alguien renombra el nodo en el editor, esto sigue andando. Buscar por nombre sería
#un string mágico que se rompe en silencio.
func _find_run_state(level: Node) -> RunState:
	for child: Node in level.get_children():
		var run_state: RunState = child as RunState

		if run_state != null:
			return run_state

	return null


func _on_run_won(magic: int) -> void:
	if print_events:
		print("[Main] run ganada con %d de magia" % magic)

	#Sin reinicio automático: ganar es el premio, se mira el tiempo que uno quiera.
	_finish_run("¡GANASTE!\n%d de magia\n\nR para volver a jugar" % magic)


func _on_run_lost(magic: int) -> void:
	if print_events:
		print("[Main] run perdida con %d de magia — reiniciando en %.1f s" % [magic, restart_delay])

	#Dos líneas menos que la victoria: en la derrota el cartel se reinicia solo, así que
	_finish_run("SE ACABÓ EL TIEMPO\n%d de magia" % magic)

	var shown_at: int = Time.get_ticks_msec()

	var my_run: int = _run_id


	await get_tree().create_timer(restart_delay, true).timeout


	if print_events:
		print("[Main] cartel en pantalla %d ms (pedidos %d ms)" % [Time.get_ticks_msec() - shown_at, roundi(restart_delay * 1000.0)])

	if _run_id == my_run and _run_finished:
		_load_level()


#Congela el mundo y muestra el cartel.
func _finish_run(message: String) -> void:
	_run_finished = true
	get_tree().paused = true
	_hud.show_end_message(message)



func _unhandled_input(event: InputEvent) -> void:
	if not _run_finished:
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_R:
			_load_level()
