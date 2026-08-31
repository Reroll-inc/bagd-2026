class_name ShopScreen
extends Control

##La tienda de mejoras. Aparece cuando se acaba el tiempo, con la magia que el jugador
##viene juntando.
##
##No navega ni sabe qué viene después: emite señales y Main decide. Mismo patrón que
##MainMenu, ControlsScreen, GameOverScreen y VictoryScreen.
##
##Tampoco decide si una compra es válida: eso lo sabe PlayerProgress y se le pregunta.
##Acá solo se dibuja lo que el progreso responde.

##Seguir jugando: arranca la ronda siguiente.
signal continue_pressed

##Abandonar y volver al título.
signal menu_pressed


#Qué botón de la escena corresponde a cada mejora. Es el contrato real con mejoras.tscn:
#si alguien renombra uno de estos nodos, esa fila deja de funcionar y avisa por Output.
const BUTTON_NAMES: Dictionary[PlayerProgress.Upgrade, StringName] = {
	PlayerProgress.Upgrade.EXTRA_BROOM: &"ToolEscoba",
	PlayerProgress.Upgrade.FASTER_CAST: &"ToolCooldown",
	PlayerProgress.Upgrade.BONUS_TIME: &"ToolTime",
	PlayerProgress.Upgrade.AUTO_BROOM: &"ToolAuto",
}

#El label de cada fila es el hermano del botón y en la escena se llama así, en las tres.
const ROW_LABEL_NAME: StringName = &"Label"

#Dónde se escribe la magia disponible. "Puntaje" es como se llama en mejoras.tscn;
#MagicLabel es el nombre del contrato original, por si alguien rehace la pantalla.
const MAGIC_LABEL_NAMES: Array[StringName] = [&"Puntaje", &"MagicLabel"]

const CONTINUE_BUTTON_NAME: StringName = &"ToContinue"
const MENU_BUTTON_NAME: StringName = &"ToMenu"

var _magic_label: Label = null

#Por mejora: el botón que se aprieta y el label donde se escribe nombre, costo y nivel.
#Solo entran las mejoras cuyo botón existe de verdad en la escena.
var _buttons: Dictionary[PlayerProgress.Upgrade, Button] = {}
var _labels: Dictionary[PlayerProgress.Upgrade, Label] = {}

#Si la escena no trae botones de salida, se sale por teclado. Ver _unhandled_input().
var _has_exit_buttons: bool = false


func _ready() -> void:
	_magic_label = _find_first_label(MAGIC_LABEL_NAMES)

	if _magic_label == null:
		push_warning("ShopScreen: no encontré ningún Label llamado 'Puntaje' ni 'MagicLabel'. La magia no se va a mostrar.")

	_collect_upgrade_rows()
	_connect_exit_buttons()

	#Comprar cambia la magia, y con ella lo que se puede pagar: las filas se redibujan
	#solas ante cualquier cambio, venga de donde venga.
	PlayerProgress.magic_changed.connect(_on_magic_changed)

	_refresh()


#Arma el mapa mejora → (botón, label). Una mejora sin botón en la escena simplemente no
#se ofrece: es preferible una tienda con tres filas que una pantalla que no abre.
func _collect_upgrade_rows() -> void:
	for upgrade: PlayerProgress.Upgrade in BUTTON_NAMES:
		var button: Button = find_child(String(BUTTON_NAMES[upgrade]), true, false) as Button

		if button == null:
			push_warning("ShopScreen: falta el botón '%s' para la mejora '%s'. Esa mejora no se puede comprar." % [
				BUTTON_NAMES[upgrade], PlayerProgress.UPGRADE_NAME[upgrade]
			])
			continue

		_buttons[upgrade] = button

		#El texto de la fila vive en un Label hermano del botón, no en el botón: en esta
		#escena el botón es solo el ícono. Se busca desde el padre y no por ruta completa
		#para que mover la fila de contenedor no rompa nada.
		var row: Node = button.get_parent()
		var label: Label = null

		if row != null:
			label = row.get_node_or_null(NodePath(ROW_LABEL_NAME)) as Label

		if label != null:
			_labels[upgrade] = label

		#bind() le agrega un argumento fijo a la llamada: los botones entran todos por el
		#mismo método y este sabe cuál lo llamó, sin escribir un handler por mejora.
		button.pressed.connect(_on_buy_pressed.bind(upgrade))


#Los botones de salida son opcionales solo porque hoy mejoras.tscn no los tiene. Si
#existen mandan ellos; si no, queda el teclado para que el jugador no quede encerrado.
func _connect_exit_buttons() -> void:
	var continue_button: Button = find_child(String(CONTINUE_BUTTON_NAME), true, false) as Button
	var menu_button: Button = find_child(String(MENU_BUTTON_NAME), true, false) as Button

	if continue_button != null:
		continue_button.pressed.connect(func() -> void: continue_pressed.emit())

	if menu_button != null:
		menu_button.pressed.connect(func() -> void: menu_pressed.emit())

	_has_exit_buttons = continue_button != null

	if not _has_exit_buttons:
		push_warning("ShopScreen: mejoras.tscn no tiene un botón '%s'. Se sale con ENTER (seguir) o ESC (menú)." % CONTINUE_BUTTON_NAME)


#Salida de emergencia mientras la escena no tenga botones propios. Corre con el árbol
#pausado porque el CanvasLayer "GUI" está en process_mode ALWAYS.
#PROVISIONAL: se borra el día que mejoras.tscn tenga ToContinue y ToMenu.
func _unhandled_input(event: InputEvent) -> void:
	if _has_exit_buttons:
		return

	#set_input_as_handled() va SIEMPRE antes del emit(), nunca después. Emitir una señal
	#es una llamada común y síncrona: del otro lado Main cierra esta pantalla con
	#remove_child(), que la saca del árbol en el acto. Al volver de emit() este nodo ya
	#no tiene viewport, y get_viewport() devuelve null.
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		continue_pressed.emit()
		return

	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_pressed.emit()


func _on_buy_pressed(upgrade: PlayerProgress.Upgrade) -> void:
	#No se valida nada acá: buy() ya rechaza lo que no se puede pagar y devuelve false.
	#Repetir la condición sería tener dos reglas de negocio que se pueden desincronizar.
	PlayerProgress.buy(upgrade)


func _on_magic_changed(_total: int) -> void:
	_refresh()


#Todo lo que se dibuja sale de PlayerProgress. Esta pantalla no guarda estado propio.
func _refresh() -> void:
	if _magic_label != null:
		_magic_label.text = "Tenés: %d pts" % PlayerProgress.get_magic()

	for upgrade: PlayerProgress.Upgrade in _buttons:
		var level: int = PlayerProgress.get_level(upgrade)
		var max_level: int = PlayerProgress.MAX_LEVEL[upgrade]

		if _labels.has(upgrade):
			var name_text: String = PlayerProgress.UPGRADE_NAME[upgrade]

			if PlayerProgress.is_maxed(upgrade):
				_labels[upgrade].text = "%s    — COMPLETA (%d/%d)" % [name_text, level, max_level]
			else:
				_labels[upgrade].text = "%s    — %d pts (%d/%d)" % [
					name_text, PlayerProgress.get_cost(upgrade), level, max_level
				]

		#Se deshabilita en vez de esconderse: que el jugador vea lo que todavía no puede
		#pagar es la mitad de la razón para volver a jugar una ronda más.
		_buttons[upgrade].disabled = not PlayerProgress.can_afford(upgrade)


#Devuelve el primer Label que exista con alguno de esos nombres.
func _find_first_label(names: Array[StringName]) -> Label:
	for node_name: StringName in names:
		var label: Label = find_child(String(node_name), true, false) as Label

		if label != null:
			return label

	return null
