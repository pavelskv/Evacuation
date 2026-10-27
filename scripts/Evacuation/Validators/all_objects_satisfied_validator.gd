extends TaskValidator
class_name AllObjectsConfirmValidator


func validate(task: EvacuationTask) -> bool:
	var objects := get_task_objects(task)

	if objects.is_empty():
		push_warning("Не найдены объекты для задачи: %s" % task.id)
		return false

	for object in objects:
		if not object.is_task_completed():
			return false

	return true
