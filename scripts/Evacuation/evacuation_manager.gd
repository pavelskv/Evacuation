
extends Node

signal scenario_started(title: String)
signal scenario_finished(result: Dictionary)
signal scenario_status_changed(status: int)
signal task_added(task_id: StringName)
signal task_updated(task_id: StringName, status: int)

enum ScenarioStatus {
	NOT_STARTED,
	RUNNING,
	COMPLETED
}

enum TaskStatus {
	UNAVAILABLE,
	PENDING,
	COMPLETED,
	FAILED,
	SKIPPED,
	NOT_APPLICABLE
}

var scenario_status: ScenarioStatus = ScenarioStatus.NOT_STARTED
var scenario: EvacuationScenario

var task_definitions: Dictionary = {}
var task_statuses: Dictionary = {}
var violations: Array[Dictionary] = []

var _connected_objects: Array[Interactable] = []

var spawn_cabinet: Node3D

func set_spawn_cabinet(cabinet: Node3D) -> void:
	spawn_cabinet = cabinet


# =========================================================
# Запуск и сброс сценария
# =========================================================

func start_scenario(new_scenario: EvacuationScenario) -> void:
	reset_scenario()

	if new_scenario == null:
		push_warning("EvacuationManager: сценарий не задан")
		return

	scenario = new_scenario

	for task: EvacuationTask in scenario.tasks:
		if task == null:
			continue

		if task.id == &"":
			push_warning("EvacuationManager: у задачи не задан ID")
			continue

		if task_definitions.has(task.id):
			push_warning("EvacuationManager: повторяющийся ID задачи: %s" % task.id)
			continue

		task_definitions[task.id] = task

		var initial_status: TaskStatus = (
			TaskStatus.PENDING
			if task.starts_available
			else TaskStatus.UNAVAILABLE
		)

		task_statuses[task.id] = initial_status
		task_added.emit(task.id)

	scenario_status = ScenarioStatus.RUNNING
	scenario_status_changed.emit(scenario_status)

	_connect_task_objects()

	scenario_started.emit(scenario.title)


func reset_scenario() -> void:
	_disconnect_task_objects()

	scenario_status = ScenarioStatus.NOT_STARTED
	scenario = null

	task_definitions.clear()
	task_statuses.clear()
	violations.clear()

	scenario_status_changed.emit(scenario_status)


# =========================================================
# Подключение интерактивных объектов
# =========================================================

func _connect_task_objects() -> void:
	for node: Node in get_tree().get_nodes_in_group("training_task_objects"):
		if not node is Interactable:
			continue

		var object := node as Interactable
		var task_id := object.get_training_task_id()

		if task_id == &"":
			continue

		if not task_definitions.has(task_id):
			continue

		if not object.state_changed.is_connected(_on_object_state_changed):
			object.state_changed.connect(_on_object_state_changed.bind(object))

		if not _connected_objects.has(object):
			_connected_objects.append(object)


func _disconnect_task_objects() -> void:
	for object: Interactable in _connected_objects:
		if not is_instance_valid(object):
			continue

		var callback := _on_object_state_changed.bind(object)

		if object.state_changed.is_connected(callback):
			object.state_changed.disconnect(callback)

	_connected_objects.clear()


func _on_object_state_changed(object: Interactable) -> void:
	if not _is_running():
		return

	if not is_instance_valid(object):
		return

	var task_id := object.get_training_task_id()

	if task_id == &"":
		return

	if not task_definitions.has(task_id):
		return

	if get_task_status(task_id) != TaskStatus.PENDING:
		return

	var task: EvacuationTask = task_definitions[task_id]

	if _validate_task(task):
		complete_task(task_id)


# =========================================================
# Управление задачами
# =========================================================

func activate_task(task_id: StringName) -> void:
	if not _is_running():
		return

	if not task_definitions.has(task_id):
		return

	if get_task_status(task_id) != TaskStatus.UNAVAILABLE:
		return

	_set_task_status(task_id, TaskStatus.PENDING)


func add_task(task: EvacuationTask) -> void:
	if not _is_running() or task == null:
		return

	if task.id == &"" or task_definitions.has(task.id):
		return

	task_definitions[task.id] = task

	var initial_status: TaskStatus = (
		TaskStatus.PENDING
		if task.starts_available
		else TaskStatus.UNAVAILABLE
	)

	task_statuses[task.id] = initial_status
	task_added.emit(task.id)


func complete_task(task_id: StringName) -> void:
	if not _is_running():
		return

	_set_task_status(task_id, TaskStatus.COMPLETED)


func fail_task(task_id: StringName) -> void:
	if not _is_running():
		return

	_set_task_status(task_id, TaskStatus.FAILED)


func skip_task(task_id: StringName) -> void:
	if not _is_running():
		return

	_set_task_status(task_id, TaskStatus.SKIPPED)


func mark_not_applicable(task_id: StringName) -> void:
	if not _is_running():
		return

	if not task_definitions.has(task_id):
		return

	var task: EvacuationTask = task_definitions[task_id]

	if not task.can_be_not_applicable:
		return

	_set_task_status(task_id, TaskStatus.NOT_APPLICABLE)


func _set_task_status(task_id: StringName, new_status: TaskStatus) -> void:
	if not task_definitions.has(task_id):
		return

	if not task_statuses.has(task_id):
		return

	if get_task_status(task_id) != TaskStatus.PENDING:
		return

	task_statuses[task_id] = new_status

	var task: EvacuationTask = task_definitions[task_id]

	if task.required and (
		new_status == TaskStatus.FAILED
		or new_status == TaskStatus.SKIPPED
	):
		_add_violation(task_id, new_status)

	task_updated.emit(task_id, new_status)


# =========================================================
# Валидация
# =========================================================

func _validate_task(task: EvacuationTask) -> bool:
	if task == null or task.validator == null:
		return false

	return task.validator.validate(task)


# =========================================================
# Завершение сценария
# =========================================================

func complete_scenario() -> void:
	if not _is_running():
		return

	# Последняя проверка: вдруг условие выполнено,
	# но объект не отправил сигнал изменения состояния.
	for task_id: StringName in task_definitions:
		if get_task_status(task_id) != TaskStatus.PENDING:
			continue

		var task: EvacuationTask = task_definitions[task_id]

		if _validate_task(task):
			_set_task_status(task_id, TaskStatus.COMPLETED)
		elif task.required:
			_set_task_status(task_id, TaskStatus.FAILED)
		else:
			_set_task_status(task_id, TaskStatus.SKIPPED)

	_disconnect_task_objects()

	scenario_status = ScenarioStatus.COMPLETED
	scenario_status_changed.emit(scenario_status)

	scenario_finished.emit(get_result())


# =========================================================
# Результат и вспомогательные методы
# =========================================================

func get_task_status(task_id: StringName) -> TaskStatus:
	if not task_statuses.has(task_id):
		return TaskStatus.UNAVAILABLE

	return task_statuses[task_id]


func get_tasks() -> Array[EvacuationTask]:
	var result: Array[EvacuationTask] = []

	for task_id: StringName in task_definitions:
		result.append(task_definitions[task_id])

	return result


func get_result() -> Dictionary:
	var completed := 0
	var failed := 0
	var skipped := 0
	var not_applicable := 0
	var pending := 0

	for task_id: StringName in task_statuses:
		match get_task_status(task_id):
			TaskStatus.COMPLETED:
				completed += 1
			TaskStatus.FAILED:
				failed += 1
			TaskStatus.SKIPPED:
				skipped += 1
			TaskStatus.NOT_APPLICABLE:
				not_applicable += 1
			TaskStatus.PENDING, TaskStatus.UNAVAILABLE:
				pending += 1

	return {
		"scenario_title": scenario.title if scenario != null else "",
		"status": scenario_status,
		"completed": completed,
		"failed": failed,
		"skipped": skipped,
		"not_applicable": not_applicable,
		"pending": pending,
		"violations": violations.duplicate(true)
	}


func _add_violation(
	task_id: StringName,
	status: TaskStatus
) -> void:
	violations.append({
		"task_id": task_id,
		"status": status
	})


func _is_running() -> bool:
	return scenario_status == ScenarioStatus.RUNNING
