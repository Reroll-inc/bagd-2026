extends Node2D

@onready var wand = $"../WandPivot"

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var should_draw = wand._cooldown_left > 0
	if should_draw:
		var t = wand._cooldown_left / wand.cast_cooldown
		draw_arc(Vector2.ZERO, 12, 2.0*PI*(1 - t) - PI/2.0, 2.0*PI - PI/2.0, 100, Color(0.525, 0.49, 0.714, 0.553), 24)
	pass
