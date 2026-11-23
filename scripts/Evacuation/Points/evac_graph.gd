extends Node

const LINK_DIST := 5.0
const MAX_DY := 0.6

var astar := AStar3D.new()
var ids := {}
var exits: Array[int] = []
var route := PackedVector3Array()   # сохранённый маршрут

var corridor_id := -1
var corridor_ids: Array = []

const SMOKE_MIN_DIST := 5.0
const SMOKE_MAX_DIST := 15.0

func reset() -> void:
	astar.clear()
	ids.clear()
	exits.clear()
	#corridor_id = -1
	
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
	corridor_ids = astar.get_point_ids()

	register_group(room)
	astar.connect_points(ids[door], corridor_id)
	
func _closest_corridor_id(pos: Vector3) -> int:
	var best := -1
	var best_d := INF
	for id in corridor_ids:
		var d := astar.get_point_position(id).distance_to(pos)
		if d < best_d:
			best_d = d
			best = id
	return best

func get_smoke_position(player_room: Node, rooms: Array[Node3D]) -> Vector3:
	var player_door: Waypoint = _find_room_door(player_room)
	var start: int = ids[player_door]
	var origin := player_door.global_position

	# точки коридора напротив дверей соседних кабинетов
	var links: Array[int] = []
	for room in rooms:
		if room == player_room:
			continue
		var door := _find_room_door(room)
		if door == null:
			continue
		var d := door.global_position.distance_to(origin)
		if d < SMOKE_MIN_DIST or d > SMOKE_MAX_DIST:
			continue
		if absf(door.global_position.y - origin.y) > MAX_DY:
			continue   # другой этаж
		var link := _closest_corridor_id(door.global_position)
		if link == corridor_id or exits.has(link):
			continue   # не запираем свою дверь и не закрываем выход
		links.append(link)

	links.shuffle()
	for link in links:
		astar.set_point_disabled(link, true)
		if _any_exit_reachable(start):
			return astar.get_point_position(link)
		astar.set_point_disabled(link, false)   # перекрыл все выходы — берём другую дверь

	return Vector3.ZERO
	
func _any_exit_reachable(start: int) -> bool:
	for e in exits:
		if not astar.get_id_path(start, e).is_empty():
			return true
	return false

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
