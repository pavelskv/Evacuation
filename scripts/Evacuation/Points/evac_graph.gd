extends Node

const LINK_DIST := 5.0
const MAX_DY := 0.6

var astar := AStar3D.new()
var ids := {}
var exits: Array[int] = []
var route := PackedVector3Array()   # сохранённый маршрут

func reset() -> void:
	astar.clear()
	ids.clear()
	exits.clear()
	route = PackedVector3Array()
	


func register_group(root: Node) -> void:
	var wps := root.find_children("*", "Waypoint", true, false)
	for wp: Waypoint in wps:
		var id := astar.get_available_point_id()
		astar.add_point(id, wp.global_position)
		ids[wp] = id
		if wp.is_exit:
			exits.append(id)

	for wp: Waypoint in wps:
		for n in wp.neighbors:
			if ids.has(n):
				astar.connect_points(ids[wp], ids[n])
				
func _find_room_door(room: Node) -> Waypoint:
	for wp: Waypoint in room.find_children("*", "Waypoint", true, false):
		if wp.is_door:
			return wp
	return null
	
var corridor_id := -1
	
func _find_corridor_id(door: Waypoint) -> int:
	var corridor_id := astar.get_closest_point(door.global_position)
	if corridor_id == -1:
		push_error("В графе нет точек коридора!")
	return corridor_id

# подключить кабинет игрока к коридору
func attach_room(room: Node) -> void:
	var door: Waypoint = _find_room_door(room)
	if door == null:
		push_error("В кабинете нет Waypoint с Is Door!")
		return

	corridor_id = _find_corridor_id(door)

	register_group(room)
	astar.connect_points(ids[door], corridor_id)
	
func get_smoke_position(room: Node) -> Vector3:
	var door: Waypoint = _find_room_door(room)
	var smoke_id := corridor_id
	var prev_id = ids[door]
	
	for i in 2: # 2 шага по коридору от двери
		for next_id in astar.get_point_connections(smoke_id):
			if next_id != prev_id:
				prev_id = smoke_id
				smoke_id = next_id
				break

	astar.set_point_disabled(smoke_id, true)
	return astar.get_point_position(smoke_id)

# кратчайший путь до ближайшего выхода
func get_route(from_pos: Vector3) -> PackedVector3Array:
	var start := astar.get_closest_point(from_pos)
	var best := PackedVector3Array()
	var best_len := INF
	var best_exit := -1

	print("--- ROUTE DEBUG ---")

	for e in exits:
		var path := astar.get_point_path(start, e)

		if path.is_empty():
			print("Exit ", e, ": путь недоступен")
			continue

		var length := 0.0

		for i in range(path.size() - 1):
			length += path[i].distance_to(path[i + 1])

		print(
			"Exit: ", e,
			" | Distance: ", snappedf(length, 0.01),
			" | Points: ", path.size()
		)

		if length < best_len:
			best_len = length
			best = path
			best_exit = e

	print(
		"SELECTED EXIT: ", best_exit,
		" | DISTANCE: ", snappedf(best_len, 0.01)
	)

	return best
	
# посчитать маршрут ОДИН раз и запомнить
func build_route(from_pos: Vector3) -> void:
	route = get_route(from_pos)

# убирать пройденные точки маршрута
func advance_route(player_pos: Vector3) -> void:
	while route.size() > 1 and player_pos.distance_to(route[0]) < 1.5:
		route = route.slice(1)
		
func disable_points_around(pos: Vector3, radius: float) -> Array[int]:
	var disabled_ids: Array[int] = []
	for point_id in astar.get_point_ids():
		var point_pos := astar.get_point_position(point_id)
		if point_pos.distance_to(pos) <= radius:
			astar.set_point_disabled(point_id, true)
			disabled_ids.append(point_id)
			print("💨 Точка графа ID %d отключена (задымление)" % point_id)
	return disabled_ids
