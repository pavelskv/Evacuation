class_name EvacuationTracker
extends Node

signal tracking_finished(result: Dictionary)

const SAMPLE_INTERVAL := 0.15
const WAYPOINT_RADIUS := 3.5        # рекомендуется чуть шире для надёжного перехвата
const EXIT_RADIUS := 1.5            # по горизонтали
const EXIT_HEIGHT_TOLERANCE := 3.0  # допустимая разница высот игрока и точки выхода
const OPTIMAL_TOLERANCE := 1.20     # допустимое отклонение от идеала (20% запас)

@export var max_evacuation_time: float = 120.0 # Лимит времени на эвакуацию (сек)

var _graph: Node
var _player: Node3D

var _tracking := false
var _sample_timer := 0.0
var _elapsed_time := 0.0

var _start_position := Vector3.ZERO
var _last_position := Vector3.ZERO
var _start_offset := 0.0	# расстояние от игрока до ближайшей точки графа

var _actual_distance := 0.0
var _optimal_distance := 0.0
var _actual_exit_distance := INF

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

	_start_position = player.global_position
	_last_position = _start_position

	_initial_point_id = _find_nearest_point_id(_start_position)
	_last_waypoint_id = _initial_point_id

	if _initial_point_id != -1:
		_actual_path.append(_initial_point_id)

	var route: PackedVector3Array = _graph.get_route(_start_position)

	if route.is_empty():
		push_error("EvacuationTracker: маршрут до выхода не найден.")
		return false

	_start_offset = _start_position.distance_to(route[0])
	_optimal_distance = _start_offset

	for i in range(route.size() - 1):
		_optimal_distance += route[i].distance_to(route[i + 1])

	_optimal_exit_id = _find_nearest_exit_id(route[route.size() - 1])

	_tracking = true

	print("EvacuationTracker: отслеживание начато.")
	print("Кратчайший маршрут: %.2f м" % _optimal_distance)
	print("Оптимальный целевой выход ID: ", _optimal_exit_id)

	return true


func _reset_tracking() -> void:
	_tracking = false
	_sample_timer = 0.0
	_elapsed_time = 0.0

	_start_position = Vector3.ZERO
	_last_position = Vector3.ZERO
	_start_offset = 0.0

	_actual_distance = 0.0
	_optimal_distance = 0.0
	_actual_exit_distance = INF

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

	# Проверка на лимит времени
	#if _elapsed_time >= max_evacuation_time:
		#finish_tracking(false, -1)
		#return

	var position := _player.global_position

	_actual_distance += _last_position.distance_to(position)
	_last_position = position

	if _check_exit(position):
		return

	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_check_player_position(position)


func _check_exit(position: Vector3) -> bool:
	for exit_id in _graph.exits:
		
		var exit_position: Vector3 = _graph.astar.get_point_position(exit_id)
		if position.distance_to(exit_position) <= EXIT_RADIUS:
			finish_tracking(true, exit_id)
			return true

	return false


func _check_player_position(position: Vector3) -> void:
	var nearest := _find_nearest_point(position)

	if nearest.id != -1 and nearest.distance <= WAYPOINT_RADIUS:
		if nearest.id != _last_waypoint_id:
			_record_waypoint(nearest.id)


func _record_waypoint(new_id: int) -> void:
	_last_waypoint_id = new_id

	if _actual_path.is_empty() or _actual_path.back() != new_id:
		_actual_path.append(new_id)


func finish_tracking(reached_exit: bool, exit_id: int = -1) -> Dictionary:
	if not _tracking:
		return {}

	_tracking = false

	if reached_exit and exit_id != -1:
		_actual_exit_distance = _start_offset + _get_graph_distance(_initial_point_id, exit_id)
	else:
		_actual_exit_distance = INF

	var efficiency := 0.0

	if _actual_distance > 0.01:
		efficiency = clampf(_optimal_distance / _actual_distance * 100.0, 0.0, 100.0)
	elif _optimal_distance <= 0.01:
		efficiency = 100.0

	var is_right_exit := (
		reached_exit
		and (
			exit_id == _optimal_exit_id
			or _actual_exit_distance <= _optimal_distance * OPTIMAL_TOLERANCE
		)
	)

	var route_correct := (
		reached_exit
		and is_right_exit
		and _actual_distance <= _optimal_distance * OPTIMAL_TOLERANCE
	)

	var time_factor := clampf(1.0 - (_elapsed_time / max_evacuation_time), 0.0, 1.0)
	#var score := roundf(efficiency * 0.7 + time_factor * 30.0) if reached_exit else 0.0
	var score := roundf(efficiency) if reached_exit else 0.0

	var result := {
		"reached_exit": reached_exit,
		"exit_id": exit_id,
		"optimal_exit_id": _optimal_exit_id,
		"is_right_exit": is_right_exit,
		"elapsed_time": snappedf(_elapsed_time, 0.1),
		"optimal_distance": snappedf(_optimal_distance, 0.1),
		"actual_distance": snappedf(_actual_distance, 0.1),
		"efficiency": snappedf(efficiency, 1.0),
		"score": score,
		"actual_path": _actual_path.duplicate(),
		"route_correct": route_correct
	}

	print("Эвакуация завершена: ", result)
	tracking_finished.emit(result)

	return result


func _find_nearest_point(position: Vector3) -> Dictionary:
	var best_id := -1
	var best_distance := INF

	for point_id in _graph.astar.get_point_ids():
		var point_position: Vector3 = _graph.astar.get_point_position(point_id)
		var distance := position.distance_to(point_position)

		if distance < best_distance:
			best_distance = distance
			best_id = point_id

	return {"id": best_id, "distance": best_distance}


func _find_nearest_point_id(position: Vector3) -> int:
	return _find_nearest_point(position).id


func _find_nearest_exit_id(position: Vector3) -> int:
	var best_id := -1
	var best_distance := INF

	for exit_id in _graph.exits:
		var exit_position: Vector3 = _graph.astar.get_point_position(exit_id)
		var distance := position.distance_to(exit_position)

		if distance < best_distance:
			best_distance = distance
			best_id = exit_id

	return best_id


func _get_graph_distance(from_id: int, to_id: int) -> float:
	if from_id == -1 or to_id == -1:
		return INF

	var path: PackedVector3Array = _graph.astar.get_point_path(from_id, to_id)

	if path.is_empty():
		return INF

	var distance := 0.0

	for i in range(path.size() - 1):
		distance += path[i].distance_to(path[i + 1])

	return distance


func get_result() -> Dictionary:
	return {
		"reached_exit": false,
		"elapsed_time": _elapsed_time,
		"optimal_distance": _optimal_distance,
		"actual_distance": _actual_distance,
		"actual_path": _actual_path.duplicate()
	}
