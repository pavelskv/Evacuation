extends CanvasLayer

@export var title: String = "Эвакуация при пожаре"
@export var color_completed: Color = Color(0.45, 0.9, 0.45)

@onready var _panel: PanelContainer = $PanelContainer
@onready var _stage_label: Label = $PanelContainer/VBoxContainer/StageLabel
@onready var _summary_label: Label = $PanelContainer/VBoxContainer/SummaryLabel
@onready var _task_list: VBoxContainer = $PanelContainer/VBoxContainer/TaskList


func _ready() -> void:
	EvacuationManager.tasks_reset.connect(_rebuild)
	EvacuationManager.task_completed.connect(_on_task_completed)
	EvacuationManager.evacuation_finished.connect(_refresh_header.unbind(1))

	_rebuild()


func _rebuild() -> void:
	for child in _task_list.get_children():
		child.queue_free()

	for task_id in EvacuationManager.completed_tasks:
		_add_row(task_id)

	_refresh_header()


func _on_task_completed(task_id: StringName) -> void:
	_add_row(task_id)
	_refresh_header()


func _add_row(task_id: StringName) -> void:
	var label := Label.new()
	label.text = "[x] %s" % EvacuationManager.completed_tasks[task_id]
	label.add_theme_color_override("font_color", color_completed)
	_task_list.add_child(label)


func _refresh_header() -> void:
	_panel.visible = EvacuationManager.is_running or EvacuationManager.is_finished

	_stage_label.text = (
		"%s: завершено" % title
		if EvacuationManager.is_finished
		else title
	)
	_summary_label.text = "Выполнено: %d" % EvacuationManager.completed_tasks.size()
