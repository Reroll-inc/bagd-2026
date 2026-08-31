class_name Main

extends Node

##Punto de entrada del juego y único dueño del ciclo de vida de los niveles:
##los instancia, los descarga y los recarga. Nadie más hace eso.
##
##Existe para que el HUD viva FUERA del nivel. Cuando se reinicia una run se destruye
##el nivel y nada más: la interfaz sobrevive intacta. El día que haya menú, selección
##de niveles o árbol de talentos, este es el nodo que los va a coordinar.

##Nivel que se carga al jugar. Cambialo en el Inspector para probar otro.
@export var level_scene: PackedScene

##Pantalla de título. Es la primera cosa que ve el jugador.
@export var main_menu_scene: PackedScene

##Pantalla de controles, a la que se llega desde el título.
@export var controls_scene: PackedScene

##Pantalla de derrota, con sus botones de reintentar y volver al título.
@export var game_over_scene: PackedScene

##Pantalla de victoria. Misma forma que la de derrota, más la magia juntada.
@export var victory_scene: PackedScene

##Tienda de mejoras. Es lo que se muestra cuando se acaba el tiempo, en lugar de la
##pantalla de derrota.
@export var shop_scene: PackedScene

@export var print_events: bool = true

@onready var _level_container: Node2D = $LevelContainer
@onready var _hud: Hud = %HUD

#Dónde viven las pantallas de UI (menú, controles, fin de partida). Está en el mismo
#CanvasLayer que el HUD pero por debajo en el árbol, así se dibuja encima de él.
@onready var _screen_container: Control = %ScreenContainer

#El nivel vivo. Null entre que se descarga uno y se instancia el siguiente.
var _level: Node = null

#La pantalla de UI viva. Null mientras se está jugando.
var _screen: Node = null

#La run terminó y estamos mostrando el final. Habilita la tecla de reinicio.
var _run_finished: bool = false



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if print_events:
		print("[Main] listo")

	go_to_menu()


# ═══════════════ PANTALLAS ═══════════════


##Vuelve al título: descarga el nivel que haya, esconde el HUD y muestra el menú.
func go_to_menu() -> void:
	get_tree().paused = false
	_run_finished = false

	_unload_level()

	#El HUD vive fuera del nivel para sobrevivir a los reinicios, así que hay que
	#apagarlo a mano: descargar el nivel no lo toca.
	_hud.hide_end_message()
	_hud.visible = false

	var menu: MainMenu = _show_screen(main_menu_scene) as MainMenu

	if menu == null:
		push_error("Main: main_menu_scene está vacío, o su raíz no tiene el script main_menu.gd.")
		return

	menu.play_pressed.connect(start_game)
	menu.controls_pressed.connect(go_to_controls)


	if print_events:
		print("[Main] menú")


##Muestra los controles. La única salida es volver al título: esta pantalla no juega.
func go_to_controls() -> void:
	var controls: ControlsScreen = _show_screen(controls_scene) as ControlsScreen

	if controls == null:
		push_error("Main: controls_scene está vacío, o su raíz no tiene el script controls.gd.")
		return

	controls.back_pressed.connect(go_to_menu)

	if print_events:
		print("[Main] controles")


##Arranca una partida: cierra la pantalla, prende el HUD y carga el nivel.
func start_game() -> void:
	_close_screen()
	_hud.visible = true
	_load_level()


#Una sola pantalla viva a la vez. Devuelve la instancia para que quien la pidió le
#conecte las señales: así el que decide qué hace cada botón es siempre Main.
func _show_screen(scene: PackedScene) -> Node:
	_close_screen()

	if scene == null:
		return null

	_screen = scene.instantiate()
	_screen_container.add_child(_screen)

	return _screen


#Mismo criterio que _unload_level(): remove_child() la saca del árbol en el acto y
#queue_free() la destruye al final del frame. Con queue_free() solo, la pantalla vieja
#seguiría viva —y recibiendo clicks— durante el resto del frame.
func _close_screen() -> void:
	if _screen == null:
		return

	_screen_container.remove_child(_screen)
	_screen.queue_free()
	_screen = null


##Descarga el nivel que haya, instancia uno nuevo y lo cablea.
func _load_level() -> void:
	if level_scene == null:
		push_error("Main sin level_scene asignado: no hay nada que cargar.")
		return

	get_tree().paused = false
	_run_finished = false
	_hud.hide_end_message()

	_unload_level()

	_level = level_scene.instantiate()

	#Las escobas compradas las pone el BroomSpawner del nivel, en su propio _ready().
	#Esto solo avisa si se pagaron escobas y el nivel no tiene quien las ponga: la
	#compra cobra magia igual, y una mejora que se cobra sin efecto es peor que un error.
	_warn_if_brooms_have_nowhere_to_go(_level)

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


# ═══════════════ ESCOBAS COMPRADAS ═══════════════


#Red de seguridad, no lógica de spawn: quien pone las escobas es el BroomSpawner del
#nivel. Existe porque el modo de fallar es silencioso — la tienda cobra la magia igual
#y el jugador no ve ninguna escoba nueva ni ningún error.
func _warn_if_brooms_have_nowhere_to_go(level: Node) -> void:
	var bought: int = PlayerProgress.get_extra_brooms()

	if bought <= 0:
		return

	if _find_broom_spawner(level) != null:
		return

	push_warning("Main: hay %d escoba(s) compradas pero el nivel no tiene ningún BroomSpawner. Nadie las va a poner." % bought)


#Por TIPO y recursivo: el spawner puede colgar del nivel directamente o de un contenedor.
func _find_broom_spawner(node: Node) -> BroomSpawner:
	for child: Node in node.get_children():
		var spawner: BroomSpawner = child as BroomSpawner

		if spawner != null:
			return spawner

		var found: BroomSpawner = _find_broom_spawner(child)

		if found != null:
			return found

	return null


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

	_finish_run(true, magic)


func _on_run_lost(magic: int) -> void:
	if print_events:
		print("[Main] run perdida con %d de magia" % magic)

	_finish_run(false, magic)


#Ganar termina la PARTIDA, no solo la run: magia y mejoras se borran, y lo que venga
#después arranca de cero. Por eso el reset va acá y no en go_to_menu() ni en start_game(),
#que también los usa el flujo de la tienda, donde el progreso tiene que sobrevivir.
#
#El reset va ANTES de cargar el nivel a propósito: RunState lee el tiempo comprado en su
#_ready() y el BroomSpawner lee las escobas compradas. Reseteando después, la primera
#ronda de la partida nueva arrancaría con las mejoras de la partida anterior.
func _on_victory_play_again() -> void:
	PlayerProgress.reset()
	start_game()


func _on_victory_menu() -> void:
	PlayerProgress.reset()
	go_to_menu()


#Punto único de salida de una run, igual que _end_run() en RunState. Los dos finales
#terminan en una pantalla con los mismos dos botones; lo único que cambia es cuál.
func _finish_run(won: bool, magic: int) -> void:
	_run_finished = true
	get_tree().paused = true

	#La magia se acredita acá y en ningún otro lado: es el único punto por el que pasan
	#las dos salidas de una run. Se cobra también al perder, porque limpiar cuesta lo
	#mismo se llegue o no al final.
	#Reintentar el mismo nivel vuelve a pagar toda su magia. Farmear repitiendo es
	#posible y hoy nada lo impide; para la jam se asume.
	PlayerProgress.add_magic(magic)

	if won:
		var victory: VictoryScreen = _show_screen(victory_scene) as VictoryScreen

		if victory == null:
			push_error("Main: victory_scene está vacío, o su raíz no tiene el script victory.gd.")
			return

		victory.show_magic(magic)

		#Las DOS salidas de la victoria borran el progreso. No se conectan directo a
		#start_game()/go_to_menu() como las de la tienda justamente por eso: ganar cierra
		#la partida, perder la continúa.
		victory.play_again_pressed.connect(_on_victory_play_again)
		victory.menu_pressed.connect(_on_victory_menu)
		return

	#Se acabó el tiempo. Ya no es una derrota seca: el jugador se lleva la magia que juntó
	#y la gasta antes de la ronda siguiente.
	#game_over_scene quedó sin uso por esto. No se borra: es escena del equipo.
	var shop: ShopScreen = _show_screen(shop_scene) as ShopScreen

	if shop == null:
		push_error("Main: shop_scene está vacío, o su raíz no tiene el script shop.gd. Ojo que mejoras.tscn venía con game_over.gd puesto.")
		return

	#Seguir arranca una ronda NUEVA con el nivel completo, no la misma partida donde
	#quedó: el nivel se reinstancia entero y con él su RunState. Las mejoras compradas
	#son lo único que cruza de una ronda a la otra.
	#Las dos salidas despausan por su cuenta, en _load_level() y en go_to_menu().
	shop.continue_pressed.connect(start_game)
	shop.menu_pressed.connect(go_to_menu)
