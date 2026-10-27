extends Node3D

func initialize_room() -> void:
	var windows := _room_nodes(&"windows")

	if not windows.is_empty():
		var open_window = windows.pick_random()

		for window in windows:
			window.set_initial_state(window == open_window)

	for node in get_tree().get_nodes_in_group("training_task_objects"):
		var object := node as Interactable
		if object != null and is_ancestor_of(object):
			object.set_interactable()

func _room_nodes(group: StringName) -> Array[Node]:
	return get_tree().get_nodes_in_group(group).filter(
		func(n: Node) -> bool: 
			return is_ancestor_of(n)
)
