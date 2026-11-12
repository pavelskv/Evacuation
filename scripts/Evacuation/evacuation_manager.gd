extends Node

signal tasks_reset
signal task_completed(task_id: StringName)
signal evacuation_finished(result: Dictionary)

const TASKS: Array = [
	{"id": &"turn_off_electrical", "title": "Отключить все электроприборы", "required": true, "points": 10},
	{"id": &"close_windows", "title": "Закрыть окна", "required": true, "points": 10},
	{"id": &"pickup_stuff", "title": "Взять личные вещи", "required": true, "points": 10},
	{"id": &"close_door", "title": "Закрыть дверь", "required": true, "points": 10},
	{"id": &"view_plan", "title": "Посмотреть план эвакуации", "required": false},
]

# Порог сдачи в процентах (для passed/failed).
const PASS_SCORE: float = 80.0

# Сколько из 100 баллов даёт маршрут. Остальное делится между обязательными задачами.
# Максимум всегда 100. Если результата маршрута нет, все 100 идут на задачи.
const ROUTE_POINTS: int = 40

var completed_tasks: Dictionary = {}	# id -> true
var is_running: bool = false
var is_finished: bool = false

var spawn_cabinet: Node3D

# Трекер маршрута. Присваивается из Main: EvacuationManager.route_tracker = tracker
# Менеджер сам слушает его сигнал tracking_finished и берёт оттуда результат.
var route_tracker: EvacuationTracker:
	set(value):
		if is_instance_valid(route_tracker) and route_tracker.tracking_finished.is_connected(finish):
			route_tracker.tracking_finished.disconnect(finish)

		route_tracker = value

		if route_tracker != null:
			route_tracker.tracking_finished.connect(finish)

var _route_result: Dictionary = {}	# результат EvacuationTracker
var _was_not_done: Dictionary = {}	# id -> true, если условие хоть раз было ложным
var _bounds_cabinet: Node3D
var _room_aabb: AABB
var _start_msec: int = 0
var _elapsed_sec: float = 0.0


func set_spawn_cabinet(cabinet: Node3D) -> void:
	spawn_cabinet = cabinet


# =========================================================
# Запуск и завершение
# =========================================================

func start() -> void:
	completed_tasks.clear()
	_route_result.clear()
	_was_not_done.clear()
	_bounds_cabinet = null

	is_running = true
	is_finished = false
	_start_msec = Time.get_ticks_msec()
	_elapsed_sec = 0.0

	Notify.alarm("Пожарная тревога!\nВсем сотрудникам необходимо покинуть здание!", "Внимание!")

	tasks_reset.emit()


# Можно вызывать откуда угодно без аргументов (например, из зоны выхода).
# Если идёт отслеживание маршрута, трекер сначала завершается сам, а его
# результат возвращается сюда через сигнал tracking_finished.
func finish(route_result: Dictionary = {}) -> void:
	if not is_running:
		return

	if route_result.is_empty() and is_instance_valid(route_tracker) and route_tracker.is_tracking():
		route_tracker.reach_exit_at_player()
		return

	_route_result = route_result.duplicate(true)
	_elapsed_sec = (Time.get_ticks_msec() - _start_msec) / 1000.0
	is_running = false
	is_finished = true
	
	var data := get_scorm_data()
	print("[SCORM] данные результата:\n", JSON.stringify(data, "  "))

	Scorm.set_score(data.score_raw)
	Scorm.set_lesson_status(
		Scorm.LessonStatus.PASSED if data.passed else Scorm.LessonStatus.FAILED
	)

	evacuation_finished.emit(get_result())
	Notify.clear_alarm()

func complete_task(task_id: StringName) -> void:
	if not is_running or completed_tasks.has(task_id):
		return

	if _find_task(task_id).is_empty():
		push_warning("EvacuationManager: complete_task для неизвестной задачи '%s'" % task_id)
		return

	completed_tasks[task_id] = true
	task_completed.emit(task_id)


func get_task_ids() -> Array[StringName]:
	var result: Array[StringName] = []

	for task: Dictionary in TASKS:
		result.append(task.id)

	return result


func get_task_title(task_id: StringName) -> String:
	return _find_task(task_id).get("title", str(task_id))


func is_task_required(task_id: StringName) -> bool:
	return _find_task(task_id).get("required", true)


func get_task_points(task_id: StringName) -> int:
	var task := _find_task(task_id)

	if not task.get("required", true):
		return 0

	return task.get("points", 1)


func is_task_done(task_id: StringName) -> bool:
	return completed_tasks.has(task_id)


func _find_task(task_id: StringName) -> Dictionary:
	for task: Dictionary in TASKS:
		if task.id == task_id:
			return task

	return {}


# =========================================================
# Результат
# =========================================================

# Оценка = набранные баллы / максимум за обязательные задачи.
func get_result() -> Dictionary:
	var required_done := 0
	var required_total := 0
	var optional_done := 0
	var optional_total := 0
	var points_earned := 0
	var points_max := 0
	var missed_required: Array[String] = []
	var missed_optional: Array[String] = []

	for task: Dictionary in TASKS:
		var done := completed_tasks.has(task.id)

		if task.get("required", true):
			var points: int = task.get("points", 1)

			required_total += 1
			points_max += points

			if done:
				required_done += 1
				points_earned += points
			else:
				missed_required.append(task.title)
		else:
			optional_total += 1

			if done:
				optional_done += 1
			else:
				missed_optional.append(task.title)

	# points_earned / points_max здесь пока в весах задач, пересчитываем в баллы из 100.
	var budget := _tasks_budget()
	var tasks_points := budget if points_max == 0 else budget * points_earned / points_max

	var route_score := 0.0
	var route_points := 0.0
	var route_points_max := 0

	if not _route_result.is_empty():
		route_score = _calc_route_score()
		route_points_max = ROUTE_POINTS
		route_points = ROUTE_POINTS * route_score / 100.0

	var total_points := roundi(tasks_points + route_points)
	var score := float(total_points)

	var reached_exit: bool = _route_result.is_empty() or _route_result.get("reached_exit", false)

	return {
		"finished": is_finished,
		"points_earned": total_points,
		"points_max": 100,
		"score": score,
		"passed": score >= PASS_SCORE and reached_exit,
		"tasks_points_earned": roundi(tasks_points),
		"route": _route_result.duplicate(true),
		"route_score": route_score,
		"route_points": roundi(route_points),
		"route_points_max": route_points_max,
		"required_done": required_done,
		"required_total": required_total,
		"optional_done": optional_done,
		"optional_total": optional_total,
		"missed_required": missed_required,
		"missed_optional": missed_optional,
		"elapsed_sec": _elapsed_sec
	}


# Сколько баллов из 100 приходится на задачи.
func _tasks_budget() -> float:
	return 100.0 - ROUTE_POINTS if not _route_result.is_empty() else 100.0


# Баллы за одну обязательную задачу (для SCORM-взаимодействий).
func _task_share(task_id: StringName) -> float:
	var total_weight := 0

	for task: Dictionary in TASKS:
		if task.get("required", true):
			total_weight += task.get("points", 1)

	if total_weight == 0:
		return 0.0

	return snappedf(_tasks_budget() * get_task_points(task_id) / total_weight, 0.1)


# Оценка маршрута 0..100 берётся из результата трекера (поле score):
# эффективность пути 70% + скорость 30%, а при недойденном выходе 0.
func _calc_route_score() -> float:
	if not _route_result.get("reached_exit", false):
		return 0.0

	return clampf(_route_result.get("score", 0.0), 0.0, 100.0)


func get_scorm_data() -> Dictionary:
	var result := get_result()
	var interactions: Array[Dictionary] = []

	for task: Dictionary in TASKS:
		interactions.append({
			"id": str(task.id),
			"description": task.title,
			"weight": _task_share(task.id),
			"correct": completed_tasks.has(task.id)
		})

	if not _route_result.is_empty():
		interactions.append({
			"id": "route",
			"description": "Маршрут эвакуации",
			"weight": ROUTE_POINTS,
			"correct": _route_result.get("route_correct", false)
		})

	return {
		"score_raw": result.points_earned,
		"score_min": 0,
		"score_max": result.points_max,
		"passed": result.passed,
		"session_time_sec": result.elapsed_sec,
		"interactions": interactions
	}


func objects_of(task_id: StringName, starting_room: bool = false) -> Array[Interactable]:
	var result: Array[Interactable] = []
	var room: Node3D = null

	if starting_room:
		room = spawn_cabinet

		if not is_instance_valid(room):
			return result

	for node in get_tree().get_nodes_in_group("training_task_objects"):
		var object := node as Interactable

		if object == null or object.get_training_task_id() != task_id:
			continue

		if room != null and not room.is_ancestor_of(object):
			continue

		result.append(object)

	return result


# Все объекты задачи выполнены.
func all_done(task_id: StringName, starting_room: bool = false) -> bool:
	var objects := objects_of(task_id, starting_room)

	if objects.is_empty():
		return false

	for object in objects:
		if not object.is_task_completed():
			return false

	return true


# Выполнен хотя бы один объект задачи.
func any_done(task_id: StringName, starting_room: bool = false) -> bool:
	for object in objects_of(task_id, starting_room):
		if object.is_task_completed():
			return true

	return false


func player_outside_room() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D

	if player == null or not is_instance_valid(spawn_cabinet):
		return false

	if _bounds_cabinet != spawn_cabinet:
		_bounds_cabinet = spawn_cabinet
		_room_aabb = _calc_room_aabb(spawn_cabinet)

	if _room_aabb.size == Vector3.ZERO:
		return false

	var p := player.global_position

	return (
		p.x < _room_aabb.position.x or p.x > _room_aabb.end.x
		or p.z < _room_aabb.position.z or p.z > _room_aabb.end.z
	)


func _calc_room_aabb(room: Node3D) -> AABB:
	var result := AABB()
	var first := true

	for node in room.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		var box: AABB = geometry.global_transform * geometry.get_aabb()

		if first:
			result = box
			first = false
		else:
			result = result.merge(box)

	if first:
		push_warning("EvacuationManager: в стартовой комнате нет мешей, границы не определены")

	return result
