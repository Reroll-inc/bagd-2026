class_name Projectile
extends Area2D
## Hechizo lanzado por la varita. Viaja en línea recta a velocidad constante.

#Normalizada SIEMPRE. Si midiera algo distinto de 1, su largo se multiplicaría
#contra speed y cada disparo viajaría a una velocidad distinta sin motivo visible.
var _direction: Vector2 = Vector2.RIGHT


var _spell: SpellData = null


#Segundos que lleva volando.
var _age: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	#Dirt es un Area2D, no un cuerpo
	area_entered.connect(_on_area_entered)


func launch(spawn_position: Vector2, direction: Vector2, spell: SpellData) -> void:
	_spell = spell

	#Sin hechizo no hay disparo posible
	if _spell == null:
		push_error("Projectile.launch() sin SpellData: se descarta el disparo")
		_die()
		return

	global_position = spawn_position

	_direction = direction.normalized()

	rotation = _direction.angle()

	#Reinicia el reloj de vida.
	_age = 0.0

	# El hechizo activo se lee de un vistazo por el color del proyectil
	modulate = _spell.color

	

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _spell.lifetime:

		#return obligatorio: queue_free() no interrumpe la función, solo agenda la
		#destrucción para el final del frame. Sin él, el proyectil todavía se movería
		#una última vez después de haber decidido que estaba muerto.
		_die()
		return
	
	#global_position y no position: el desplazamiento que calculamos está en
	#coordenadas del mundo. Si el nodo padre estuviera rotado o escalado, sumárselo
	#a position lo interpretaría en coordenadas del padre y el proyectil se desviaría.
	global_position += _direction * _spell.projectile_speed * delta


#si es un objeto animable, se le ofrece el
#hechizo y él decide si le sirve. Si no lo es —una pared, el piso— no pasa nada.
#En los dos casos el hechizo se gasta y el proyectil muere: pegarle a lo incorrecto
#tiene costo, y ese costo es lo que hace que apuntar importe.
func _on_body_entered(body: Node2D) -> void:
	var cleaning_tool: CleaningTool = body as CleaningTool
	if cleaning_tool != null:
		cleaning_tool.try_animate(_spell)

	_die()

# El hechizo que toca mugre se pierde sin efecto: limpiar es trabajo del objeto animado,
func _on_area_entered(_area: Area2D) -> void:
	_die()

#luego voy a hacer el pool
func _die() -> void:
	queue_free()
