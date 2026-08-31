extends CharacterBody2D
class_name CleaningTool
## Objeto animable (escoba, plumero). Duerme apoyado en el suelo hasta que un hechizo
## compatible lo despierta. Dormido es decorado; animado acepta órdenes y limpia.


## Emitida cuando el objeto pasa de dormido a animado.
signal animated

## Emitida al llegar al destino de una orden.
signal arrived

# Igual que Dirt: cada objeto se anota solo, para que el nivel los encuentre sin
# cablearlos a mano uno por uno.
const GROUP: StringName = &"tools"
const ACTION_ORDER: StringName = &"order"

const ASLEEP_TINT: Color = Color(0.55, 0.55, 0.6)
const SELECTED_TINT: Color = Color(1.3, 1.3, 0.9)

#Tolerancia en píxeles para dar por llegado el destino
const ARRIVAL_THRESHOLD: float = 6.0

#Sonda de borde. Los tres valores son RELATIVOS al cuerpo, nunca absolutos: la escoba
#ya cambió de tamaño una vez (display_size pasó de 32×64 a 128×256) y con medidas fijas
#la sonda quedó colgando dentro del cuerpo, sin llegar nunca al piso.
#  MARGIN: cuánto MÁS ALLÁ del borde del cuerpo mira, hacia adelante.
#  RISE:   cuánto arranca por ENCIMA de los pies. Un rayo que nace justo sobre la
#          superficie puede no detectarla.
#  DEPTH:  cuánto baja por debajo de los pies. Más que esto es un precipicio.
const LEDGE_PROBE_MARGIN: float = 6.0
const LEDGE_PROBE_RISE: float = 8.0
const LEDGE_PROBE_DEPTH: float = 32.0

#Capa 1 = World. La sonda solo pregunta por piso, no por mugre ni por otros objetos.
const WORLD_LAYER_MASK: int = 1

#Distancia HORIZONTAL a la que el objeto alcanza mugre de su tipo.
#Se mide solo en X a propósito. La escoba y el parche están los dos apoyados en el
#piso, pero sus orígenes viven a alturas muy distintas 
#Esto vale mientras toda la mugre sea de piso. Si algún día entra DirtData
#Orientation.WALL o CEILING, ese caso necesita su propio criterio de alcance.
const CLEAN_RANGE: float = 60.0

#Cada cuánto busca trabajo una escoba autónoma que está sin nada que hacer. No es por
#frame porque cada búsqueda recorre TODO el grupo "dirt": a 60 fps eso serían 60 barridos
#por segundo para un resultado que casi nunca cambia entre frame y frame.
const AUTO_SEARCH_INTERVAL: float = 0.5

enum State {ASLEEP, IDLE, MOVING, CLEANING}

@export var data: ToolData

##La escoba automática de la tienda. No se hechiza, no se selecciona y no acepta órdenes:
##nace despierta y se busca el trabajo sola.
##Lo pone el BroomSpawner al instanciarla; en el editor va siempre en false.
@export var autonomous: bool = false

# No sale de ToolData porque no es una propiedad de la escoba: es del mundo. Si algún
# día hay un nivel con gravedad rara, se cambia acá y no en cada .tres.
@export var gravity: float = 980.0

var _state: State = State.ASLEEP
var _is_selected: bool = false
var _target_x: float = 0.0

#Segundos acumulados desde el último golpe. Mismo criterio que el _age del proyectil:
#un float propio en vez de un nodo Timer, porque resetearlo es una asignación.
var _clean_timer: float = 0.0

var _target_dirt: Dirt = null

#Segundos desde la última búsqueda de trabajo. Solo lo usa una escoba autónoma.
var _auto_search_timer: float = 0.0

#Hacia qué parche está caminando una escoba autónoma. No es lo mismo que _target_dirt:
#ese es el que está limpiando AHORA, este es el que se propuso alcanzar.
var _auto_target: Dirt = null

#Parches a los que esta escoba caminó y no pudo alcanzar — típicamente porque el freno
#de borde la paró en un precipicio. Sin esta lista se quedaría eligiendo eternamente el
#mismo parche inalcanzable, que además suele ser el más cercano.
#Se vacía cuando logra limpiar algo: si el mundo cambió, los descartes pueden no valer.
var _unreachable: Array[Dirt] = []

var _ledge_probe: RayCast2D

#Caja del cuerpo en coordenadas locales, medida una sola vez. De acá salen los pies y
#los bordes laterales, que es lo que la sonda necesita saber.
var _body_box: Rect2 = Rect2()

@onready var sprite: Sprite2D = $Sprite2D
@onready var _collider: CollisionShape2D = $CollisionShape2D
@onready var wakeUpSfx : AudioStreamPlayer2D = $WakeUpSfx
@onready var cleanSfx : AudioStreamPlayer2D = $CleanSfx
@onready var walkSfx : AudioStreamPlayer2D = $WalkSfx

func _ready() -> void:
	add_to_group(GROUP)
	_build_ledge_probe()

	if data == null:
		push_error("CleaningTool sin ToolData asignado: %s" % name)
		return

	#Misma regla que en Dirt: la escena manda. El .tres solo pisa textura y escala si
	#alguien le asigna una textura explícitamente.
	if data.texture != null:
		sprite.texture = data.texture
		_fit_sprite_to(data.display_size)

	_refresh_visual()

	#Una escoba autónoma no espera ningún hechizo: se compró ya animada. Va después del
	#_refresh_visual() de arriba para que el cambio de estado repinte el tinte de dormida.
	if autonomous:
		_change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)

	#Las dos formas de recibir trabajo se excluyen: la autónoma se lo busca sola y no
	#acepta órdenes, la normal solo hace lo que le mandan.
	if autonomous:
		_tick_autonomy(delta)
	else:
		_read_order()

	match _state:
		State.MOVING:
			_navigate_dumb()
		State.CLEANING:
			velocity.x = 0.0
			_do_cleaning(delta)
		_:
			velocity.x = 0.0

	move_and_slide()


## Intenta animar este objeto con un hechizo. Devuelve true solo si lo despertó.
## un hechizo anima al objeto que limpia su mismo tipo
## de mugre. El hechizo de polvo despierta escobas porque la escoba limpia polvo.
func try_animate(spell: SpellData) -> bool:
	if spell == null or data == null:
		return false
	
	if spell.animates != data.cleans:
		return false

	#La escoba automática ignora el hechizo: ya nació animada y no obedece órdenes, así
	#que seleccionarla dejaría al jugador dando clicks derechos que no hacen nada.
	#El proyectil se gasta igual al chocarla, como con cualquier cuerpo.
	if autonomous:
		return false

	var was_asleep: bool = _state == State.ASLEEP

	if was_asleep:
		_change_state(State.IDLE)
		animated.emit()
		wakeUpSfx.play()

	_select_exclusively()

	return was_asleep


func is_animated() -> bool:
	return _state != State.ASLEEP


func set_selected(value: bool) -> void:
	if _is_selected == value:
		return

	_is_selected = value
	_refresh_visual()


# ═══════════════ ÓRDENES Y MOVIMIENTO ═══════════════

func _apply_gravity(delta: float) -> void:
	# Cae siempre, duerma o no. Una escoba flotando porque nadie la animó todavía se
	#lee como bug, no como diseño.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta



#Todos los objetos leen el input, pero solo el seleccionado reacciona. Con dos o tres
#objetos en pantalla eso es más barato que montar un manager que reparta órdenes.
func _read_order() -> void:
	if not _is_selected or _state == State.ASLEEP:
		return

	if not Input.is_action_just_pressed(ACTION_ORDER):
		return

	#Solo importa la X: el destino es un punto del piso, no del aire.
	_target_x = get_global_mouse_position().x
	_change_state(State.MOVING)


# ═══════════════ AUTONOMÍA ═══════════════


#Le busca trabajo a una escoba autónoma. Solo actúa cuando está en IDLE: interrumpir una
#limpieza a mitad porque apareció un parche más cerca haría que no termine ninguno, y
#recalcular el destino mientras camina la haría dudar en cada frame.
func _tick_autonomy(delta: float) -> void:
	if _state != State.IDLE:
		return

	_auto_search_timer += delta

	if _auto_search_timer < AUTO_SEARCH_INTERVAL:
		return

	_auto_search_timer = 0.0

	var target: Dirt = _find_nearest_dirt()

	#Sin trabajo se queda quieta y vuelve a preguntar dentro de medio segundo. No es un
	#error: puede ser que ya no quede mugre de su tipo, o que toda la que queda esté en
	#la lista de inalcanzables.
	if target == null:
		return

	_auto_target = target
	_target_x = target.global_position.x
	_change_state(State.MOVING)


#El parche más cercano de su tipo en TODO el nivel, sin el límite de CLEAN_RANGE: ese
#límite responde "¿lo tengo al lado?", y acá la pregunta es "¿hacia dónde camino?".
func _find_nearest_dirt() -> Dirt:
	var closest: Dirt = null
	var closest_distance: float = INF

	for node: Node in get_tree().get_nodes_in_group(Dirt.GROUP):
		var dirt: Dirt = node as Dirt

		if dirt == null or dirt.data == null:
			continue

		if dirt.data.type != data.cleans:
			continue

		if _unreachable.has(dirt):
			continue

		#Solo la separación horizontal, igual que _find_dirt_in_range(): esta escoba
		#camina en X y la distancia vertical entre orígenes no es distancia de viaje.
		var distance: float = absf(dirt.global_position.x - global_position.x)

		if distance < closest_distance:
			closest = dirt
			closest_distance = distance

	return closest




func _navigate_dumb() -> void:
	var distance: float = _target_x - global_position.x
	if not walkSfx.playing:
			walkSfx.play()
	if absf(distance) <= ARRIVAL_THRESHOLD:
		_stop_here()
		return

	#signf da -1 o 1: la dirección sin el tamaño.
	var direction: float = signf(distance)

	#Freno de borde. Sin esto el objeto camina más allá de la plataforma, se cae y el
	#jugador lo pierde para siempre
	if is_on_floor() and _is_ledge_ahead(direction):
		_stop_here()
		return

	velocity.x = direction * data.move_speed
	sprite.flip_h = velocity.x < 0.0



#La sonda se reubica adelante en la dirección de marcha y se fuerza a medir AHORA:
#force_raycast_update() evita usar el resultado del frame anterior, que corresponde
#a una posición que el objeto ya dejó atrás.
#Los dos bordes se calculan por separado porque el collider puede estar descentrado
func _is_ledge_ahead(direction: float) -> bool:
	if direction > 0.0:
		_ledge_probe.position.x = _body_box.end.x + LEDGE_PROBE_MARGIN
	else:
		_ledge_probe.position.x = _body_box.position.x - LEDGE_PROBE_MARGIN

	_ledge_probe.force_raycast_update()

	return not _ledge_probe.is_colliding()



func _stop_here() -> void:
	velocity.x = 0.0
	arrived.emit()
	_start_cleaning_or_idle()


# ═══════════════ LIMPIEZA ═══════════════

#La búsqueda corre solo en dos momentos: al frenar y al terminar un parche.
func _start_cleaning_or_idle() -> void:
	_target_dirt = _find_dirt_in_range()

	if _target_dirt == null:
		#Frenó sin nada de su tipo al alcance. Para una escoba autónoma eso significa que
		#el parche que se propuso no era alcanzable —casi siempre porque el freno de borde
		#la paró en un precipicio— y hay que anotarlo: si no, volvería a elegir el mismo,
		#que además suele ser el más cercano, y quedaría yendo y viniendo para siempre.
		#La lista NO se vacía nunca a propósito: el terreno de un nivel no cambia durante
		#la run, así que lo que no se pudo alcanzar una vez no se va a poder después.
		if autonomous and _auto_target != null and not _unreachable.has(_auto_target):
			_unreachable.append(_auto_target)

		_auto_target = null
		_change_state(State.IDLE)
		return

	_clean_timer = 0.0
	_change_state(State.CLEANING)


func _do_cleaning(delta: float) -> void:
	#El parche puede haber desaparecido en el golpe ante	rior. queue_free() no pone la
	#variable en null: sigue apuntando a un objeto liberado, y tocarlo revienta.
	#is_instance_valid() es la única forma honesta de preguntar "¿esto todavía existe?".
	if not is_instance_valid(_target_dirt) or _target_dirt.dead:
		_start_cleaning_or_idle()
		return

	_clean_timer += delta

	if _clean_timer < data.clean_interval:
		return

	cleanSfx.play()
	_clean_timer = 0.0
	_target_dirt.clean(data.cleaning_power)
	


#Busca el parche más cercano DE SU TIPO dentro del alcance. Un objeto limpia una sola
#cosa: la escoba pasa por encima de una telaraña sin tocarla.
func _find_dirt_in_range() -> Dirt:
	var closest: Dirt = null
	var closest_distance: float = CLEAN_RANGE

	for node: Node in get_tree().get_nodes_in_group(Dirt.GROUP):
		var dirt: Dirt = node as Dirt

		if dirt.dead or dirt == null or dirt.data == null:
			continue

		if dirt.data.type != data.cleans:
			continue

		#Solo la separación horizontal: la vertical entre orígenes es ruido, no distancia.
		var distance: float = absf(dirt.global_position.x - global_position.x)

		if distance <= closest_distance:
			closest = dirt
			closest_distance = distance

	return closest


# ═══════════════ INTERNAS ═══════════════


func _build_ledge_probe() -> void:
	_body_box = _measure_body()

	_ledge_probe = RayCast2D.new()

	#Nace un poco arriba de los pies y baja hasta pasarlos. La x la fija _is_ledge_ahead()
	#en cada consulta, según hacia dónde marcha el objeto.
	_ledge_probe.position.y = _body_box.end.y - LEDGE_PROBE_RISE
	_ledge_probe.target_position = Vector2(0.0, LEDGE_PROBE_RISE + LEDGE_PROBE_DEPTH)

	_ledge_probe.collision_mask = WORLD_LAYER_MASK
	add_child(_ledge_probe)


#Mide el cuerpo real en coordenadas locales. Se llama una sola vez: el collider no
#cambia de tamaño en runtime, y medirlo por frame sería pagar lo mismo 60 veces.
func _measure_body() -> Rect2:
	var rect: RectangleShape2D = _collider.shape as RectangleShape2D

	#Solo sabe medir rectángulos. Si algún día alguien le pone una cápsula, que se entere
	#por el Output y no por una escoba que se niega a caminar sin decir por qué.
	if rect == null:
		push_error("CleaningTool %s: se esperaba un RectangleShape2D para medir la sonda de borde" % name)
		return Rect2(Vector2(-16.0, -16.0), Vector2(32.0, 32.0))

	var size: Vector2 = rect.size * _collider.scale

	#Rect2 se arma desde la esquina superior izquierda; el CollisionShape2D está centrado
	#en su position. De acá salen end.y (los pies) y los dos bordes laterales.
	return Rect2(_collider.position - size * 0.5, size)

#Selección exclusiva: hechizar a uno deselecciona a todos los demás. Sin esto, dos
#objetos seleccionados recibirían la misma orden y caminarían al mismo punto.
func _select_exclusively() -> void:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other: CleaningTool = node as CleaningTool
		if other != null:
			other.set_selected(other == self)



#Todas las transiciones pasan por acá, igual que en player.gd. Es el único lugar donde
#poner un breakpoint si algún objeto queda trabado en un estado.
func _change_state(new_state: State) -> void:
	if _state == new_state:
		return

	_state = new_state
	_refresh_visual()



#Mismo método que en Dirt: el sprite se escala para ocupar display_size, sea cual sea
#la resolución de la imagen.
func _fit_sprite_to(target: Vector2) -> void:
	#Mismo criterio que en dirt.gd: get_size() devuelve la HOJA entera, pero con
	#hframes/vframes el Sprite2D dibuja una sola celda. Hoy el arte de la escoba no usa
	#frames y esto divide por 1
	var frame_size: Vector2 = sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)

	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return

	sprite.scale = target / frame_size



#Cuando haya arte real esto pasa a ser animaciones.
func _refresh_visual() -> void:
	if _state == State.ASLEEP:
		sprite.modulate = ASLEEP_TINT
	elif _is_selected:
		sprite.modulate = SELECTED_TINT
	else:
		sprite.modulate = Color.WHITE
