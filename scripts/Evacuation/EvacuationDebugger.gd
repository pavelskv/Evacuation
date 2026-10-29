extends Node3D

# Внутренний AStar, который скрипт собирает сам
var astar = AStar3D.new()
var exit_ids: Array[int] = []

# Вызывай этот метод из своего кода, когда захочешь сгенерировать и нарисовать граф:
# $GraphDebugger.run_and_draw()
func run_and_draw() -> void:
	# 1. Очищаем старые ноды и граф, если вызывается повторно
	for child in get_children():
		child.queue_free()
	astar.clear()
	exit_ids.clear()
	
	# 2. Сами собираем точки здания в наш astar
	build_building_graph()
	
	# 3. Рисуем линии и шарики
	visualize_graph()
	
	print("Дебаггер: Здание и граф сгенерированы! Точек: ", astar.get_point_count())


# --- САМОСТОЯТЕЛЬНАЯ СБОРКА ГРАФА ЗДАНИЯ ---
func build_building_graph() -> void:
	var num_floors = 4
	var floor_height = 4.0
	var rooms_per_floor = 3 
	
	var stair_left_x = -10.0
	var stair_right_x = 10.0
	var room_xs = [-6.0, 0.0, 6.0]
	
	for floor_idx in range(1, num_floors + 1):
		var y = (floor_idx - 1) * floor_height
		
		# Комнаты на этаже
		for r_i in range(rooms_per_floor):
			var room_id = floor_idx * 10000 + r_i * 100 + 1
			var pos = Vector3(room_xs[r_i], y, 0.0)
			astar.add_point(room_id, pos)
			
			if r_i > 0:
				var prev_room_id = floor_idx * 10000 + (r_i - 1) * 100 + 1
				astar.connect_points(room_id, prev_room_id, true)
		
		# Лестницы
		var stair_l_id = floor_idx * 10000 + 91
		var stair_r_id = floor_idx * 10000 + 92
		
		astar.add_point(stair_l_id, Vector3(stair_left_x, y, 0.0))
		astar.add_point(stair_r_id, Vector3(stair_right_x, y, 0.0))
		
		var left_room_id = floor_idx * 10000 + 1
		var right_room_id = floor_idx * 10000 + (rooms_per_floor - 1) * 100 + 1
		
		astar.connect_points(stair_l_id, left_room_id, true)
		astar.connect_points(stair_r_id, right_room_id, true)
		
		# Вертикальные связи лестниц
		if floor_idx > 1:
			var prev_l_id = (floor_idx - 1) * 10000 + 91
			var prev_r_id = (floor_idx - 1) * 10000 + 92
			astar.connect_points(stair_l_id, prev_l_id, true)
			astar.connect_points(stair_r_id, prev_r_id, true)
			
		# Выходы на 1 этаже
		if floor_idx == 1:
			var exit_1_id = 19901
			var exit_2_id = 19902
			var exit_3_id = 19903
			
			astar.add_point(exit_1_id, Vector3(stair_left_x, 0.0, 3.0))
			astar.add_point(exit_2_id, Vector3(0.0, 0.0, 3.0))
			astar.add_point(exit_3_id, Vector3(stair_right_x, 0.0, 3.0))
			
			astar.connect_points(exit_1_id, stair_l_id, true)
			astar.connect_points(exit_2_id, floor_idx * 10000 + 1, true)
			astar.connect_points(exit_3_id, stair_r_id, true)
			
			exit_ids.append(exit_1_id)
			exit_ids.append(exit_2_id)
			exit_ids.append(exit_3_id)


# --- ВИЗУАЛИЗАЦИЯ ---
func visualize_graph() -> void:
	var mi = MeshInstance3D.new()
	var im_mesh = ImmediateMesh.new()
	mi.mesh = im_mesh
	
	var line_mat = ORMMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color.CYAN
	mi.material_override = line_mat
	add_child(mi)
	
	im_mesh.surface_begin(Mesh.PRIMITIVE_LINES, null)
	
	for id in astar.get_point_ids():
		var pos = astar.get_point_position(id)
		
		# Спавним сферу на точку
		var sphere_mi = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		sphere_mi.mesh = sphere
		
		var s_mat = StandardMaterial3D.new()
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s_mat.albedo_color = Color.GREEN if abs(pos.y) < 0.1 else Color.YELLOW
		sphere_mi.material_override = s_mat
		
		add_child(sphere_mi)
		sphere_mi.global_position = pos
		
		# Линии к соседям
		for neighbor_id in astar.get_point_connections(id):
			if id < neighbor_id:
				var neighbor_pos = astar.get_point_position(neighbor_id)
				im_mesh.surface_set_color(Color.CYAN)
				im_mesh.surface_add_vertex(pos)
				im_mesh.surface_set_color(Color.CYAN)
				im_mesh.surface_add_vertex(neighbor_pos)
				
	im_mesh.surface_end()
