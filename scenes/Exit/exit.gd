extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	print("зона: ", get_path(), " | тело: ", body.name)
	if not body.is_in_group("player"):
		return
		
	print("выход!")
	EvacuationManager.complete_scenario()
