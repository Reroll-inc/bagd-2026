class_name Hud

extends Control

##Muestra el estado de la run: tiempo restante y magia acumulada.
##No decide nada — escucha señales y dibuja. Toda la lógica vive en RunState.
##
##Vive FUERA del nivel (en el CanvasLayer "GUI" de main.tscn), así que sobrevive a los
##reinicios. Por eso no busca su RunState solo: se lo pasa Main cada vez que carga un
##nivel, porque cada nivel trae un RunState nuevo y el anterior ya murió.


##Debajo de estos segundos el reloj cambia de color.
@export_range(1, 60, 1) var warning_seconds: int = 10

@export var warning_color: Color = Color(0.7, 0.1, 0.1)

@export var show_p2_placeholders: bool = false

#los nombres únicos de escena sobreviven a que muevan el nodo de
#lugar.
@onready var _timer_label: Label = %TimerLabel
@onready var _energy_track: NinePatchRect = %EnergyTrack
@onready var _energy_fill: ColorRect = %EnergyFill
@onready var _control_meter: VBoxContainer = %ControlMeter
@onready var _bottom_bar: HBoxContainer = %BottomBar
@onready var _end_panel: Control = %EndPanel
@onready var _end_label: Label = %EndLabel

var _run_state: RunState = null

#Copia local del objetivo, para no depender de que _run_state siga vivo al dibujar.
var _magic_goal: int = 0

var _magic_ratio: float = 0.0

var _timer_normal_color: Color = Color.WHITE


func _ready() -> void:

	_end_panel.hide()

	_control_meter.visible = show_p2_placeholders
	_bottom_bar.visible = show_p2_placeholders

	_timer_normal_color = _timer_label.get_theme_color(&"font_color")

	_energy_track.resized.connect(_refresh_energy_fill)


##La llama Main con el RunState del nivel recién cargado.
func bind_run_state(run_state: RunState) -> void:
	_unbind()

	_run_state = run_state
	_magic_goal = maxi(run_state.magic_goal, 1) # 📖 Nunca 0: es divisor.

	_run_state.time_changed.connect(_on_time_changed)
	_run_state.magic_changed.connect(_on_magic_changed)

	
	#Sin estas dos líneas el HUD arrancaría con los valores de la run anterior hasta el primer tick.
	_on_time_changed(_run_state.get_seconds_left())
	_on_magic_changed(_run_state.get_magic())



func _unbind() -> void:
	if _run_state == null:
		return

	if is_instance_valid(_run_state):
		_run_state.time_changed.disconnect(_on_time_changed)
		_run_state.magic_changed.disconnect(_on_magic_changed)

	_run_state = null


##Muestra el cartel de fin de run. El texto lo arma Main: el HUD no sabe si ganaste.
func show_end_message(message: String) -> void:
	_end_label.text = message
	_end_panel.show()


func hide_end_message() -> void:
	_end_panel.hide()


func _on_time_changed(seconds_left: int) -> void:
	_timer_label.text = _format_time(seconds_left)

	var is_urgent: bool = seconds_left <= warning_seconds
	var color: Color = warning_color if is_urgent else _timer_normal_color

	_timer_label.add_theme_color_override(&"font_color", color)


func _on_magic_changed(total: int) -> void:
	_magic_ratio = clampf(float(total) / float(_magic_goal), 0.0, 1.0)
	_refresh_energy_fill()


func _refresh_energy_fill() -> void:
	var inset: float = _energy_fill.position.x
	var max_width: float = maxf(_energy_track.size.x - inset * 2.0, 0.0)

	_energy_fill.size.x = max_width * _magic_ratio


#mm:ss. La división entre enteros trunca, así que 45 / 60 da 0 y no 0.75 — que es
#justo lo que queremos para sacar los minutos.
func _format_time(total_seconds: int) -> String:
	@warning_ignore("integer_division")
	var minutes: int = total_seconds / 60

	var seconds: int = total_seconds % 60

	return "%02d:%02d" % [minutes, seconds]
