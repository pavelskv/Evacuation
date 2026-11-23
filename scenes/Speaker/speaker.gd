extends Node3D

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	add_to_group("speaker")

func _process(delta: float) -> void:
	pass

func play_sound() -> void:
	if not audio_player.playing:
		audio_player.play()
