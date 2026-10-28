extends Node3D

@export var player_computer: Node3D

func initialize_room() -> void:
	var windows := _room_nodes(&"windows")

	if not windows.is_empty():
		var open_window = windows.pick_random()

		for window in windows:
			window.set_initial_state(window == open_window)

	for item in _room_nodes(&"shmot"):
		item.set_interactable()
			
	if player_computer != null:
		player_computer.set_screen(true)

func _room_nodes(group: StringName) -> Array[Node]:
	return get_tree().get_nodes_in_group(group).filter(
		func(n: Node) -> bool: 
			return is_ancestor_of(n)
)
