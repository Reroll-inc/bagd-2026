class_name GlobalMusic
extends AudioStreamPlayer

const MUSIC_VOLUME_DB = -13

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func fade_low():
	var shop_fade_tween = get_tree().create_tween()
	shop_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	shop_fade_tween.tween_property(self, "volume_db", MUSIC_VOLUME_DB - 15, 0.3)
	

func fade_up():
	var shop_fade_tween = get_tree().create_tween()
	shop_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	shop_fade_tween.tween_property(self, "volume_db", MUSIC_VOLUME_DB, 0.3)

func start_playing():
	self.volume_db = -30
	self.play()
	var shop_fade_tween = get_tree().create_tween()
	shop_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	shop_fade_tween.tween_property(self, "volume_db", MUSIC_VOLUME_DB, 1.4)
