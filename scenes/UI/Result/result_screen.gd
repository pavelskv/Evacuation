extends Control

enum Outcome { WIN, NOT_CREDITED, LOST }

@export_file("*.tscn") var restart_scene: String = ""
@export_file("*.tscn") var menu_scene: String = ""

@export_group("Цвета")
@export var color_win: Color = Color(0.6, 0.85, 0.65)
@export var color_not_credited: Color = Color(0.95, 0.8, 0.5)
@export var color_lost: Color = Color(0.95, 0.5, 0.5)
@export var color_done: Color = Color(0.45, 0.9, 0.45)
@export var color_missed: Color = Color(1.0, 0.45, 0.45)
@export var color_muted: Color = Color(0.58, 0.6, 0.66)

@onready var _title: Label = %Title
@onready var _reason_block: VBoxContainer = %ReasonBlock
@onready var _reason_header: Label = %ReasonHeader
@onready var _reason: Label = %Reason
@onready var _done_list: VBoxContainer = %DoneList
@onready var _missed_header: Label = %MissedHeader
@onready var _missed_list: VBoxContainer = %MissedList
@onready var _score_value: Label = %ScoreValue
@onready var _buttons: HBoxContainer = %Buttons
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton

func _ready() -> void:
	GameState.set_state(GameState.State.PAUSED)

	var result := EvacuationManager.get_result()

	var outcome := _get_outcome(result)
	
	_show_outcome(outcome, result)

	var done_rows: Array[Dictionary] = []
	var missed_rows: Array[Dictionary] = []

	for title in result.done_titles:
		done_rows.append({"text": title, "color": color_done})

	for title in result.missed_required:
		missed_rows.append({"text": title, "color": color_missed})

	_add_route_row(result.route, done_rows, missed_rows)

	_fill_list(_done_list, done_rows, "Вы не выполнили задания")

	var has_missed := not missed_rows.is_empty()
	_missed_header.visible = has_missed
	_missed_list.visible = has_missed

	if has_missed:
		_fill_list(_missed_list, missed_rows, "")

	_score_value.text = "%d / 100" % roundi(result.score)

	_restart_button.visible = not restart_scene.is_empty()
	_menu_button.visible = not menu_scene.is_empty()
	_buttons.visible = _restart_button.visible or _menu_button.visible

	_restart_button.pressed.connect(_change_scene.bind(restart_scene))
	_menu_button.pressed.connect(_change_scene.bind(menu_scene))


func _get_outcome(result: Dictionary) -> Outcome:
	if result.passed:
		return Outcome.WIN

	if not result.fail_reason.is_empty():
		return Outcome.LOST

	return Outcome.NOT_CREDITED


func _show_outcome(outcome: Outcome, result: Dictionary) -> void:
	match outcome:
		Outcome.WIN:
			_title.text = "Эвакуация успешно завершена"
			_reason_block.visible = false

		Outcome.NOT_CREDITED:
			_title.text = "Эвакуация завершена с нарушениями"
			_reason_header.text = "ПРИЧИНА"
			_reason.text = "Набрано %d баллов из 100, для зачёта необходимо не менее %d баллов" % [
				roundi(result.score),
				roundi(EvacuationManager.PASS_SCORE)
			]

		Outcome.LOST:
			_title.text = "Эвакуация не завершена"
			_reason_header.text = "ПРИЧИНА"
			_reason.text = result.fail_reason


func _fill_list(container: VBoxContainer, rows: Array[Dictionary], empty_text: String) -> void:
	for child in container.get_children():
		child.queue_free()

	if rows.is_empty():
		if not empty_text.is_empty():
			container.add_child(_make_row(empty_text, color_muted))
		return

	for row in rows:
		container.add_child(_make_row("•  %s" % row.text, row.color))


func _add_route_row(route: Dictionary, done_rows: Array[Dictionary], missed_rows: Array[Dictionary]) -> void:
	if route.is_empty():
		return

	if not route.get("reached_exit", false):
		missed_rows.append({"text": "Выход из здания не достигнут", "color": color_missed})
		return

	var optimal: float = route.get("optimal_distance", 0.0)
	var selected: float = route.get("actual_distance", 0.0)

	if not is_finite(selected):
		missed_rows.append({"text": "Выбранный выход оказался недоступен", "color": color_missed})
		return

	var longer := selected / maxf(optimal, 0.01) - 1.0

	if longer > EvacuationTracker.ROUTE_TOLERANCE - 1.0:
		done_rows.append({
			"text": "Выбран путь длиннее оптимального",
			"color": color_not_credited
		})
	else:
		done_rows.append({"text": "Выбран оптимальный путь к выходу", "color": color_done})

func _make_row(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	return label

func _change_scene(path: String) -> void:
	if path.is_empty():
		return

	get_tree().change_scene_to_file(path)
