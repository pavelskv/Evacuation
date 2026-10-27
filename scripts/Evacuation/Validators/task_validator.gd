extends Resource
class_name TaskValidator

func validate(_task: EvacuationTask) -> bool:
	return false

func get_task_objects(task: EvacuationTask) -> Array[Interactable]:
	var result: Array[Interactable] = []
	var tree := Engine.get_main_loop() as SceneTree

	if tree == null:
		return result

	var room: Node3D = null

	if task.validation_scope == EvacuationTask.ValidationScope.STARTING_ROOM:
		room = EvacuationManager.spawn_cabinet

		if not is_instance_valid(room):
			push_warning("EvacuationManager: стартовый кабинет не найден")
			return result

	for node in tree.get_nodes_in_group("training_task_objects"):
		var object := node as Interactable

		if object == null:
			continue

		if object.get_training_task_id() != task.id:
			continue

		if room != null and not room.is_ancestor_of(object):
			continue

		result.append(object)

	return result
