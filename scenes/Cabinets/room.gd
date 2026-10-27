extends Node3D

func initialize_room() -> void:
	var windows: Array = get_tree().get_nodes_in_group("windows").filter(
		func(w): return is_ancestor_of(w)
	)
	if windows.is_empty():
		return

	var open_window = windows.pick_random()

	for window in windows:
		window.set_initial_state(window == open_window)
		
		
	for item in get_tree().get_nodes_in_group("shmot"):
		if is_ancestor_of(item):
			item.set_interactable()
	
