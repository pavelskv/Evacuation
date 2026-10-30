
extends Node

@export var cabinet_scenes: Array[PackedScene] = []
@export var player_scene: PackedScene

@export var evacuation_scenario: EvacuationScenario

@export var use_debug_camera: bool = false
@export var debug_camera_scene: PackedScene

var evacuation_tracker: EvacuationTracker

func _setup_debug_camera() -> void:
	if not use_debug_camera:
		return

	if debug_camera_scene == null:
		push_error("Не назначена сцена DebugCamera!")
		return

	var debug_camera = debug_camera_scene.instantiate()
	get_tree().current_scene.add_child(debug_camera)


func _ready() -> void:
	call_deferred("_spawn")
	call_deferred("_setup_debug_camera")

func _spawn() -> void:
	if cabinet_scenes.is_empty():
		push_error("Добавь сцены кабинетов в массив cabinet_scenes!")
		return

	if player_scene == null:
		push_error("Назначь сцену игрока в player_scene!")
		return

	var doors = get_tree().get_nodes_in_group("cabinet_doors")

	if doors.is_empty():
		push_error("Не найдено дверей в группе 'cabinet_doors'!")
		return

	var selected_door: Node3D = null
	var spawned_cabinets: Array[Node3D] = []
	
	EvacGraph.reset()
	EvacGraph.register_group(get_tree().current_scene)

	# Создаём кабинеты на месте всех дверей
	for door in doors:
		if not is_instance_valid(door):
			continue

		if not door is Node3D:
			continue

		var cabinet_index: int = door.cabinet_id - 1

		if cabinet_index < 0 or cabinet_index >= cabinet_scenes.size():
			push_error(
				"Некорректный cabinet_id = %d у двери %s"
				% [door.cabinet_id, door.name]
			)
			continue

		var cabinet := cabinet_scenes[cabinet_index].instantiate() as Node3D
		if cabinet == null:
			push_error("Сцена кабинета должна иметь корневой узел Node3D!")
			continue

		get_tree().current_scene.add_child(cabinet)
		cabinet.global_transform = door.global_transform
		
		cabinet.set_meta("cabinet_id", door.door_id)
		cabinet.set_meta("floor_number", door.floor_number)

		spawned_cabinets.append(cabinet)

		print(
			"🚪 Загружен кабинет №%d на месте двери %s (этаж %d)"
			% [door.cabinet_id, door.name, door.floor_number]
		)

		# Запоминаем выбранную дверь из меню
		if GameState.selected_door_id >= 0:
			if door.door_id == GameState.selected_door_id:
				selected_door = door

		door.queue_free()
	
	# Определяем кабинет для появления игрока
	var spawn_cabinet: Node3D = null

	if GameState.selected_door_id >= 0:
		if selected_door == null:
			push_error(
				"Не найдена дверь с door_id = %d"
				% GameState.selected_door_id
			)
			return

		# Находим созданный кабинет по позиции выбранной двери
		for cabinet in spawned_cabinets:
			var spawn := cabinet.get_node_or_null("PlayerSpawn")
			if spawn != null:
				# Сопоставление через позицию исходной двери
				if cabinet.global_position.distance_to(
					selected_door.global_position
				) < 0.01:
					spawn_cabinet = cabinet
					break
	else:
		if not spawned_cabinets.is_empty():
			spawn_cabinet = spawned_cabinets.pick_random()

	if spawn_cabinet == null:
		push_error("Не удалось определить кабинет для появления игрока!")
		return
		
	EvacuationManager.spawn_cabinet = spawn_cabinet
	
	spawn_cabinet.initialize_room()
	
	EvacGraph.attach_room(spawn_cabinet)

	# Создаём игрока один раз
	var player := player_scene.instantiate() as Node3D
	player.add_to_group("player")  
	get_tree().current_scene.add_child(player)

	var player_spawn := spawn_cabinet.get_node_or_null("PlayerSpawn")

	if player_spawn != null:
		player.global_transform = player_spawn.global_transform
		print("✅ Игрок заспавнен в кабинете: ", spawn_cabinet.name)
	else:
		push_warning("В сцене кабинета нет узла PlayerSpawn!")
	
	EvacGraph.build_route(player.global_position)
	
	evacuation_tracker = EvacuationTracker.new()
	add_child(evacuation_tracker)

	evacuation_tracker.tracking_finished.connect(
		_on_evacuation_tracking_finished
	)

	evacuation_tracker.start_tracking(player, EvacGraph)
		
	var cab_id: int = spawn_cabinet.get_meta("cabinet_id")
	var floor_num: int = spawn_cabinet.get_meta("floor_number")

	Notify.info(
		"Вы находитесь в кабинете №%d здания ПЛК на %d этаже" % [cab_id, floor_num],
	"	Местоположение"
	)
	EvacuationManager.start_scenario(evacuation_scenario)

func _on_evacuation_tracking_finished(result: Dictionary) -> void:
	print("=== РЕЗУЛЬТАТ ЭВАКУАЦИИ ===")

	print("Выход достигнут: ", result["reached_exit"])
	print("Время: %.1f сек." % result["elapsed_time"])
	print("Оптимальный путь: %.1f м" % result["optimal_distance"])
	print("Пройденный путь: %.1f м" % result["actual_distance"])
	print("Эффективность: %.1f%%" % result["efficiency"])
	print("Отклонения: ", result["deviation_count"])

	if result["route_correct"]:
		print("Результат: маршрут без отклонений")
	elif result["reached_exit"]:
		print("Результат: эвакуация завершена с отклонениями")
	else:
		print("Результат: эвакуация не завершена")
