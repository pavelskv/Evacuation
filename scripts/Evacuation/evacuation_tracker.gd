
class_name EvacuationTracker
extends Node

signal tracking_finished(result: Dictionary)

const SAMPLE_INTERVAL := 0.15
const WAYPOINT_RADIUS := 3.0
const EXIT_RADIUS := 1.5

# Допустимое отклонение от кратчайшего маршрута
const ROUTE_TOLERANCE := 1.15
const EXTRA_DISTANCE := 10.0

@export var max_evacuation_time: float = 120.0

var _graph: Node
var _player: Node3D

var _tracking := false
var _sample_timer := 0.0
var _elapsed_time := 0.0

var _last_position := Vector3.ZERO

var _start_offset := 0.0
var _actual_distance := 0.0
var _optimal_distance := INF

var _optimal_exit_id := -1
var _initial_point_id := -1

var _last_waypoint_id := -1
var _actual_path: Array[int] = []


func start_tracking(player: Node3D, graph: Node) -> bool:
	if player == null or graph == null:
		push_error("EvacuationTracker: не назначен игрок или граф.")
		return false

	if graph.astar.get_point_count() == 0:
		push_error("EvacuationTracker: граф не содержит точек.")
		return false

	_reset_tracking()

	_player = player
	_graph = graph

	_last_position = player.global_position

	var nearest := _find_nearest_point(_last_position)

	if nearest.id == -1:
		push_error("EvacuationTracker: не найдена начальная точка.")
		return false

	_initial_point_id = nearest.id
	_last_waypoint_id = nearest.id
	_start_offset = nearest.distance

	_actual_path.append(_initial_point_id)

	_calculate_optimal_routes()

	if _optimal_exit_id == -1:
		push_error("EvacuationTracker: не найден доступный выход.")
		return false

	_tracking = true

	print("EvacuationTracker: отслеживание начато.")
	print("Начальная точка: ", _initial_point_id)
	print("Оптимальный выход: ", _optimal_exit_id)
	print("Кратчайший путь: %.2f м" % _optimal_distance)

	return true


func is_tracking() -> bool:
	return _tracking


func _reset_tracking() -> void:
	_tracking = false

	_sample_timer = 0.0
	_elapsed_time = 0.0

	_last_position = Vector3.ZERO

	_start_offset = 0.0
	_actual_distance = 0.0
	_optimal_distance = INF

	_optimal_exit_id = -1
	_initial_point_id = -1
	_last_waypoint_id = -1

	_actual_path.clear()


func _physics_process(delta: float) -> void:
	if not _tracking:
		return

	if not is_instance_valid(_player):
		return

	_elapsed_time += delta

	var position := _player.global_position

	# Фактическое пройденное расстояние
	_actual_distance += _last_position.distance_to(position)
	_last_position = position

	# Проверяем достижение выхода
	if _check_exit(position):
		return

	# Ограничение времени
	if _elapsed_time >= max_evacuation_time:
		finish_tracking(false)
		return

	# Запись посещённых точек
	_sample_timer += delta

	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_check_player_position(position)


# --------------------------------------------------
# ОБНАРУЖЕНИЕ ВЫХОДА
# --------------------------------------------------

func _check_exit(position: Vector3) -> bool:
	for exit_id in _graph.exits:
		var exit_position: Vector3 = _graph.astar.get_point_position(
			exit_id
		)

		if position.distance_to(exit_position) <= EXIT_RADIUS:
			finish_tracking(true, exit_id)
			return true

	return false


# --------------------------------------------------
# РАСЧЁТ ОПТИМАЛЬНОГО МАРШРУТА
# --------------------------------------------------

func _calculate_optimal_routes() -> void:
	_optimal_distance = INF
	_optimal_exit_id = -1

	for exit_id in _graph.exits:
		var graph_distance := _get_graph_distance(
			_initial_point_id,
			exit_id
		)

		if not is_finite(graph_distance):
			continue

		var total_distance := _start_offset + graph_distance

		if total_distance < _optimal_distance:
			_optimal_distance = total_distance
			_optimal_exit_id = exit_id


func _get_graph_distance(from_id: int, to_id: int) -> float:
	if from_id == -1 or to_id == -1:
		return INF

	if not _graph.astar.has_point(from_id):
		return INF

	if not _graph.astar.has_point(to_id):
		return INF

	var path: PackedVector3Array = _graph.astar.get_point_path(
		from_id,
		to_id
	)

	if path.is_empty():
		return INF

	var distance := 0.0

	for i in range(path.size() - 1):
		distance += path[i].distance_to(path[i + 1])

	return distance


# --------------------------------------------------
# ЗАПИСЬ ФАКТИЧЕСКОГО МАРШРУТА
# --------------------------------------------------

func _check_player_position(position: Vector3) -> void:
	var nearest := _find_nearest_point(position)

	if nearest.id == -1:
		return

	if nearest.distance > WAYPOINT_RADIUS:
		return

	if nearest.id != _last_waypoint_id:
		_record_waypoint(nearest.id)


func _record_waypoint(new_id: int) -> void:
	_last_waypoint_id = new_id

	if _actual_path.is_empty() or _actual_path.back() != new_id:
		_actual_path.append(new_id)


func _find_nearest_point(position: Vector3) -> Dictionary:
	var best_id := -1
	var best_distance := INF

	for point_id in _graph.astar.get_point_ids():
		var point_position: Vector3 = _graph.astar.get_point_position(
			point_id
		)

		var distance := position.distance_to(point_position)

		if distance < best_distance:
			best_distance = distance
			best_id = point_id

	return {
		"id": best_id,
		"distance": best_distance
	}


# --------------------------------------------------
# ЗАВЕРШЕНИЕ И ОЦЕНКА
# --------------------------------------------------

func finish_tracking(
	reached_exit: bool,
	exit_id: int = -1
) -> Dictionary:

	if not _tracking:
		return {}

	_tracking = false

	# Допустимая длина маршрута
	var allowed_distance := (
		_optimal_distance * ROUTE_TOLERANCE
		+ EXTRA_DISTANCE
	)

	# Эффективность маршрута
	var route_efficiency := 0.0

	if reached_exit and _actual_distance > 0.01:
		route_efficiency = clampf(
			allowed_distance / _actual_distance * 100.0,
			0.0,
			100.0
		)

	var score := roundf(route_efficiency)

	var route_correct := (
		reached_exit
		and route_efficiency >= 99.0
	)

	var result := {
		"reached_exit": reached_exit,
		"exit_id": exit_id,
		"optimal_exit_id": _optimal_exit_id,

		"elapsed_time": snappedf(_elapsed_time, 0.1),

		"optimal_distance": snappedf(_optimal_distance, 0.1),
		"actual_distance": snappedf(_actual_distance, 0.1),
		"allowed_distance": snappedf(allowed_distance, 0.1),

		"route_efficiency": snappedf(route_efficiency, 1.0),

		"efficiency": score,
		"score": score,

		"actual_path": _actual_path.duplicate(),
		"route_correct": route_correct
	}

	print("Эвакуация завершена: ", result)

	tracking_finished.emit(result)

	return result


func get_result() -> Dictionary:
	return {
		"reached_exit": false,
		"elapsed_time": _elapsed_time,
		"optimal_distance": _optimal_distance,
		"actual_distance": _actual_distance,
		"actual_path": _actual_path.duplicate()
	}
