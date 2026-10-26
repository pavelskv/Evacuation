
extends TaskValidator
class_name AllObjectsConfirmValidator


func validate(task: EvacuationTask) -> bool:
	var objects := _get_task_objects(task)

	if objects.is_empty():
		push_warning("Не найдены объекты для задачи: %s" % task.id)
		return false

	for object in objects:
		if not object.has_method("is_task_completed"):
			push_warning(
				"Объект %s не реализует is_task_completed()"
				% object.name
			)
			return false

		if not object.is_task_completed():
			return false

	return true


func _get_task_objects(task: EvacuationTask) -> Array[Node]:
	var result: Array[Node] = []
	var tree := Engine.get_main_loop() as SceneTree

	if tree == null:
		return result

	match task.validation_scope:
		EvacuationTask.ValidationScope.WHOLE_BUILDING:
			for node in tree.get_nodes_in_group("training_task_objects"):
				if not node is Interactable:
					continue

				var object := node as Interactable

				if object.get_training_task_id() == task.id:
					result.append(object)

		EvacuationTask.ValidationScope.STARTING_ROOM:
			var room: Node3D = EvacuationManager.spawn_cabinet

			if not is_instance_valid(room):
				push_warning("EvacuationManager: стартовый кабинет не найден")
				return result

			_collect_from_room(room, task.id, result)

	return result


func _collect_from_room(
	node: Node,
	task_id: StringName,
	result: Array[Node]
) -> void:
	if node is Interactable:
		var object := node as Interactable

		if (
			object.is_in_group("training_task_objects")
			and object.get_training_task_id() == task_id
		):
			result.append(object)

	for child in node.get_children():
		_collect_from_room(child, task_id, result)
