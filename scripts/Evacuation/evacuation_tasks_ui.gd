
extends CanvasLayer

@onready var stage_label: Label = $PanelContainer/VBoxContainer/StageLabel
@onready var summary_label: Label = $PanelContainer/VBoxContainer/SummaryLabel
@onready var task_list: VBoxContainer = $PanelContainer/VBoxContainer/TaskList


func _ready() -> void:
	if not EvacuationManager.scenario_started.is_connected(_on_scenario_started):
		EvacuationManager.scenario_started.connect(_on_scenario_started)

	if not EvacuationManager.scenario_status_changed.is_connected(_on_scenario_status_changed):
		EvacuationManager.scenario_status_changed.connect(_on_scenario_status_changed)

	if not EvacuationManager.task_added.is_connected(_on_task_changed):
		EvacuationManager.task_added.connect(_on_task_changed)

	if not EvacuationManager.task_updated.is_connected(_on_task_updated):
		EvacuationManager.task_updated.connect(_on_task_updated)

	if not EvacuationManager.scenario_finished.is_connected(_on_scenario_finished):
		EvacuationManager.scenario_finished.connect(_on_scenario_finished)

	refresh()


func _on_scenario_started(_title: String) -> void:
	refresh()


func _on_scenario_status_changed(_status: int) -> void:
	refresh()


func _on_task_changed(_task_id: StringName) -> void:
	refresh()


func _on_task_updated(_task_id: StringName, _status: int) -> void:
	refresh()


func _on_scenario_finished(result: Dictionary) -> void:
	refresh()

	summary_label.text = (
		"Тренировка завершена\n"
		+ "Выполнено: %d\n" % result.get("completed", 0)
		+ "Нарушений: %d\n" % result.get("failed", 0)
		+ "Пропущено: %d" % result.get("skipped", 0)
	)


func refresh() -> void:
	if not is_node_ready():
		return

	var status := EvacuationManager.scenario_status

	match status:
		EvacuationManager.ScenarioStatus.NOT_STARTED:
			stage_label.text = "Тренировка не начата"

		EvacuationManager.ScenarioStatus.RUNNING:
			stage_label.text = "Эвакуация: выполнение заданий"

		EvacuationManager.ScenarioStatus.COMPLETED:
			stage_label.text = "Тренировка завершена"

	_clear_task_list()

	var tasks: Array[EvacuationTask] = EvacuationManager.get_tasks()

	for task: EvacuationTask in tasks:
		var task_status: int = EvacuationManager.get_task_status(task.id)

		var row := Label.new()
		row.text = "%s — %s" % [
			task.title,
			_get_status_text(task_status)
		]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		task_list.add_child(row)

	if status != EvacuationManager.ScenarioStatus.COMPLETED:
		summary_label.text = "Заданий: %d" % tasks.size()


func _clear_task_list() -> void:
	for child in task_list.get_children():
		task_list.remove_child(child)
		child.queue_free()


func _get_status_text(status: int) -> String:
	match status:
		EvacuationManager.TaskStatus.UNAVAILABLE:
			return "ещё не требуется"

		EvacuationManager.TaskStatus.PENDING:
			return "ожидает выполнения"

		EvacuationManager.TaskStatus.COMPLETED:
			return "выполнено"

		EvacuationManager.TaskStatus.FAILED:
			return "нарушение"

		EvacuationManager.TaskStatus.SKIPPED:
			return "пропущено"

		EvacuationManager.TaskStatus.NOT_APPLICABLE:
			return "не требовалось"

		_:
			return "неизвестно"
