class_name RunState
extends Node

##Las reglas de una run: reloj, magia acumulada, objetivo y fin.
##
##No dibuja nada ni conoce al HUD: solo emite señales.
##Vive DENTRO del nivel a propósito. Cuando la escena se recarga este nodo muere
##con ella y la run siguiente arranca limpia — sin un reset() que alguien se pueda
##olvidar de llamar. Como autoload sobreviviría al reinicio y arrastraría el estado.

##Emitida cuando cambia el segundo mostrado del reloj.
signal time_changed(seconds_left: int)

##Emitida al alcanzar el objetivo de magia. Manda el total con el que se ganó.
signal run_won(magic: int)

##Emitida cuando el reloj llega a 0 sin el objetivo. El nivel se recarga enseguida.
signal run_lost(magic: int)

##Emitida cada vez que cambia la magia acumulada.
signal magic_changed(total: int)

#tiempo total del nivel
@export_range(5.0, 600.0, 1.0) var run_seconds: float = 60.0

##Magia que hay que juntar antes de que se acabe el tiempo.
@export_range(1,1000,1) var magic_goal: int = 15

##Para probar el resto de los sistemas sin el reloj encima.
@export var clock_enable: bool = true

##Imprime en Output cada evento de la run. Mismo patrón que Player.print_state.
@export var print_events: bool = true

var _time_left: float = 0.0

#Bandera de "la run sigue viva".
var _running: bool = false

#El último entero que emitimos. Sirve para NO emitir la señal en los frames en los
#que el número visible no cambió.
var _last_emitted_second: int = -1

var _magic: int = 0

#Toda la magia que el nivel puede llegar a dar
var _magic_available: int = 0

func _ready() -> void:
	_time_left = run_seconds
	_running = true
	_emit_time_if_changed()
	magic_changed.emit(_magic)

	
	#Un llamado diferido corre cuando el árbol ya terminó de armarse: el orden deja de importar.
	_connect_to_dirt.call_deferred()


func _process(delta: float) -> void:
	if not _running or not clock_enable:
		return

	_time_left -= delta

	if _time_left <= 0.0:
		_time_left = 0.0
		_emit_time_if_changed()

		#Llegar acá ya es una derrota
		_end_run(false)
		return
	
	_emit_time_if_changed()



##Cuánto tiempo queda, en segundos enteros hacia arriba. Es lo que va a mostrar el HUD.
func get_seconds_left() -> int:
	return ceili(_time_left)


##Si la run sigue corriendo.
func is_running() -> bool:
	return _running


##La magia acumulada en esta run.
func get_magic() -> int:
	return _magic

#TODA run termina acá, gane o pierda.
func _end_run(won: bool) -> void:
	if not _running:
		return

	_running = false

	if won:
		if print_events:
			print("[RunState] ✅ VICTORIA — %d de magia en %d segundos" % [_magic, ceili(run_seconds - _time_left)])
		
		run_won.emit(_magic)
		return

	if print_events:
		print("[RunState] ❌ DERROTA — %d de %d de magia. Reiniciando nivel." % [_magic, magic_goal])

	run_lost.emit(_magic)


#Se suscribe a todos los parches del grupo. Una sola vez, al empezar
func _connect_to_dirt() -> void:
	var patches: Array[Node] = get_tree().get_nodes_in_group(Dirt.GROUP)

	if patches.is_empty():
		#Un nivel sin mugre no se puede ganar.
		push_warning("RunState: no hay nodos en el grupo '%s'. La run es inganable." % Dirt.GROUP)
		return

	var connected: int = 0

	for node: Node in patches:
		#'as' devuelve null si el nodo no es un Dirt en vez de reventar.
		var patch: Dirt = node as Dirt

		if patch == null:
			push_warning("RunState: '%s' está en el grupo '%s' pero no es un Dirt." % [node.name, Dirt.GROUP])
			continue

		patch.cleaned.connect(_on_dirt_cleaned)
		connected += 1

		if patch.data != null:
			_magic_available += patch.get_passes_left() * patch.data.magic_per_pass

	if print_events:
		print("[RunState] escuchando %d parches — %d de magia disponible, objetivo %d" % [connected, _magic_available, magic_goal])

	if magic_goal > _magic_available:
		push_warning("RunState: objetivo %d pero el nivel solo da %d de magia. Nivel Inganable." % [magic_goal, _magic_available])



func _on_dirt_cleaned(magic: int) -> void:
	if not _running:
		return
	
	_magic += magic
	magic_changed.emit(_magic)

	if print_events:
		print("[RunState] magia %d/%d (+%d)" % [_magic, magic_goal, magic])

	if _magic >= magic_goal:
		_end_run(true)


# ceili() y no int(): con truncado el reloj mostraría "0" durante todo el último
# segundo, y el jugador creería que perdió mientras todavía puede jugar.
func _emit_time_if_changed() -> void:
	var whole: int = ceili(_time_left)

	if whole == _last_emitted_second:
		return

	_last_emitted_second = whole
	time_changed.emit(whole)