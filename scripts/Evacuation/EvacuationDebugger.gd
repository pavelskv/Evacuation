extends Node3D

var astar = AStar3D.new()
var exit_ids: Array[int] = []

func _ready() -> void:
	print(">>> СКРИПТ УСПЕШНО ЗАПУСТИЛСЯ! <<<")
	
	# Спавним один большой красный шар в центре, чтобы проверить видимость камеры
	var test_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 2.0  # Большой размер, чтобы точно заметить
	sphere.height = 4.0
	test_mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.RED
	test_mesh.material_override = mat
	
	add_child(test_mesh)
	test_mesh.global_position = Vector3(0, 0, 0)
	print(">>> Красный тестовый шар создан в позиции (0,0,0) <<<")
# --- ПОСТРОЕНИЕ ГРАФА ---
func generate_building_graph() -> void:
	astar.clear()
	exit_ids.clear()
	
	var num_floors = 4
	var floor_height = 4.0
	var rooms_per_floor = 3 # Левая, Центральная, Правая комнаты
	
	var stair_left_x = -10.0
	var stair_right_x = 10.0
	var room_xs = [-6.0, 0.0, 6.0]
	
	for floor_idx in range(1, num_floors + 1):
		var y = (floor_idx - 1) * floor_height
		
		# 1. Создаем точки комнат на этаже
		for r_i in range(rooms_per_floor):
			var room_id = floor_idx * 10000 + r_i * 100 + 1
			var pos = Vector3(room_xs[r_i], y, 0.0)
			astar.add_point(room_id, pos)
			
			# Соединяем комнаты на этаже в цепочку
			if r_i > 0:
				var prev_room_id = floor_idx * 10000 + (r_i - 1) * 100 + 1
				astar.connect_points(room_id, prev_room_id, true)
		
		# 2. Создаем точки лестниц на этаже
		var stair_l_id = floor_idx * 10000 + 91 # Левая лестница
		var stair_r_id = floor_idx * 10000 + 92 # Правая лестница
		
		astar.add_point(stair_l_id, Vector3(stair_left_x, y, 0.0))
		astar.add_point(stair_r_id, Vector3(stair_right_x, y, 0.0))
		
		# Подключаем лестницы к первой и последней комнате этажа
		var left_room_id = floor_idx * 10000 + 1
		var right_room_id = floor_idx * 10000 + (rooms_per_floor - 1) * 100 + 1
		
		astar.connect_points(stair_l_id, left_room_id, true)
		astar.connect_points(stair_r_id, right_room_id, true)
		
		# 3. Вертикальные связи лестниц между этажами
		if floor_idx > 1:
			var prev_l_id = (floor_idx - 1) * 10000 + 91
			var prev_r_id = (floor_idx - 1) * 10000 + 92
			astar.connect_points(stair_l_id, prev_l_id, true)
			astar.connect_points(stair_r_id, prev_r_id, true)
			
		# 4. На 1 этаже добавляем 3 аварийных выхода
		if floor_idx == 1:
			var exit_1_id = 19901 # Левый выход
			var exit_2_id = 19902 # Центральный выход
			var exit_3_id = 19903 # Правый выход
			
			astar.add_point(exit_1_id, Vector3(stair_left_x, 0.0, 3.0))
			astar.add_point(exit_2_id, Vector3(0.0, 0.0, 3.0))
			astar.add_point(exit_3_id, Vector3(stair_right_x, 0.0, 3.0))
			
			astar.connect_points(exit_1_id, stair_l_id, true)
			astar.connect_points(exit_2_id, floor_idx * 10000 + 1, true)
			astar.connect_points(exit_3_id, stair_r_id, true)
			
			exit_ids.append(exit_1_id)
			exit_ids.append(exit_2_id)
			exit_ids.append(exit_3_id)

# --- ПОИСК ЛУЧШЕГО ВЫХОДА ---
func get_best_exit_route(from_pos: Vector3) -> PackedVector3Array:
	var start_id = astar.get_closest_point(from_pos)
	var best_path: PackedVector3Array = []
	var min_cost: float = INF
	
	for exit_id in exit_ids:
		var path = astar.get_point_path(start_id, exit_id)
		if path.size() > 0:
			var cost = _calculate_path_length(path)
			if cost < min_cost:
				min_cost = cost
				best_path = path
				
	return best_path

func _calculate_path_length(path: PackedVector3Array) -> float:
	var dist = 0.0
	for i in range(path.size() - 1):
		dist += path[i].distance_to(path[i + 1])
	return dist

# --- ВИЗУАЛИЗАЦИЯ ГРАФА В 3D (Исправленная версия) ---
func draw_debug_graph(im_mesh: ImmediateMesh) -> void:
	im_mesh.clear_surfaces()
	im_mesh.surface_begin(Mesh.PRIMITIVE_LINES, null)
	
	for id in astar.get_point_ids():
		var pos = astar.get_point_position(id)
		for neighbor_id in astar.get_point_connections(id):
			if id < neighbor_id:
				var neighbor_pos = astar.get_point_position(neighbor_id)
				# В Godot 4 для ImmediateMesh нужно указывать цвет или вызывать add_vertex подряд попарно
				im_mesh.surface_set_color(Color.CYAN)
				im_mesh.surface_add_vertex(pos)
				im_mesh.surface_set_color(Color.CYAN)
				im_mesh.surface_add_vertex(neighbor_pos)
				
	im_mesh.surface_end()
