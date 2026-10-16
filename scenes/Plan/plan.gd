extends Interactable

@export var floor_number: int = 1
@export var plan_texture: Texture2D

func get_message() -> String:
	return "Посмотреть план эвакуации (%d-й этаж)  [E]" % floor_number

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
