extends TaskValidator
class_name AnyObjectConfirmValidator


func validate(task: EvacuationTask) -> bool:
	for object in get_task_objects(task):
		if object.is_task_completed():
			return true

	return false
