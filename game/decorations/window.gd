extends Node2D

func _process(_delta: float) -> void:
	var window_panes : Sprite2D = $WindowPanes
	(window_panes.material as ShaderMaterial).set_shader_parameter("x_pos", ShaderVars.x_pos)
