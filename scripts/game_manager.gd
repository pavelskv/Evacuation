
extends Node

@export var cabinet_scenes: Array[PackedScene] = []
@export var player_scene: PackedScene

@export var use_debug_camera: bool = false
@export var debug_camera_scene: PackedScene

@onready var loading_screen: LoadingScreen = $"../LoadingScreen"

const SHADER_WARMUP_SCRIPT = preload("res://scripts/ShaderWarmup.gd")

const SMOKE_SCENE: PackedScene = preload("res://scenes/Smoke/smoke.tscn")
const CABINETS_PER_FRAME: int = 1

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

func _create_cabinet_for_door(door: Node3D, scene_root: Node) -> Node3D:
	var cabinet_index: int = door.cabinet_id - 1
	if cabinet_index < 0 or cabinet_index >= cabinet_scenes.size():
		push_error(
			"Некорректный cabinet_id = %d у двери %s"
			% [door.cabinet_id, door.name]
		)
		return null

	var cabinet := cabinet_scenes[cabinet_index].instantiate() as Node3D
	if cabinet == null:
		push_error("Сцена кабинета должна иметь корневой узел Node3D!")
		return null

	cabinet.global_transform = door.global_transform
	cabinet.set_meta("cabinet_id", door.door_id)
	cabinet.set_meta("floor_number", door.floor_number)
	scene_root.add_child(cabinet)

	print(
		"🚪 Загружен кабинет №%d на месте двери %s (этаж %d)"
		% [door.cabinet_id, door.name, door.floor_number]
	)

	door.queue_free()
	return cabinet


func _spawn() -> void:
	if cabinet_scenes.is_empty():
		push_error("Добавь сцены кабинетов в массив cabinet_scenes!")
		return

	if player_scene == null:
		push_error("Назначь сцену игрока в player_scene!")
		return

	var raw_doors := get_tree().get_nodes_in_group("cabinet_doors")
	if raw_doors.is_empty():
		push_error("Не найдено дверей в группе 'cabinet_doors'!")
		return

	var valid_doors: Array[Node3D] = []
	for door in raw_doors:
		if is_instance_valid(door) and door is Node3D:
			valid_doors.append(door)

	if valid_doors.is_empty():
		push_error("Нет валидных дверей Node3D в группе 'cabinet_doors'!")
		return

	var scene_root := get_tree().current_scene

	EvacGraph.reset()
	EvacGraph.register_group(scene_root)

	# 1. Выбираем дверь для стартового кабинета
	var primary_door: Node3D = null
	if GameState.selected_door_id >= 0:
		for door in valid_doors:
			if door.door_id == GameState.selected_door_id:
				primary_door = door
				break

		if primary_door == null:
			push_error(
				"Не найдена дверь с door_id = %d"
				% GameState.selected_door_id
			)
			return
	else:
		primary_door = valid_doors.pick_random()

	# 2. Сначала создаём стартовый кабинет и подключаем его к графу
	var spawn_cabinet := _create_cabinet_for_door(primary_door, scene_root)
	if spawn_cabinet == null:
		push_error("Не удалось создать стартовый кабинет!")
		return

	var spawned_cabinets: Array[Node3D] = [spawn_cabinet]

	EvacuationManager.spawn_cabinet = spawn_cabinet
	spawn_cabinet.initialize_room()
	EvacGraph.attach_room(spawn_cabinet)
	
	await get_tree().process_frame

	# 3. Сразу создаём игрока в стартовом кабинете
	var player := player_scene.instantiate() as Node3D
	player.add_to_group("player")

	var player_spawn := spawn_cabinet.get_node_or_null("PlayerSpawn") as Node3D
	if player_spawn != null:
		player.global_transform = player_spawn.global_transform
		print("✅ Игрок заспавнен в кабинете: ", spawn_cabinet.name)
	else:
		push_warning("В сцене кабинета нет узла PlayerSpawn!")
		
	scene_root.add_child(player)
	
	var player_camera := player.get_node("Head/Camera3D") as Camera3D

	await SHADER_WARMUP_SCRIPT.run(
		player_camera,
		loading_screen,
		12
	)

	
	await loading_screen.hide_loading()
	
	print("Позиция игрока: ", player.global_position)
	
	var cab_id: int = spawn_cabinet.get_meta("cabinet_id")
	var floor_num: int = spawn_cabinet.get_meta("floor_number")

	Notify.info(
		"Вы находитесь в кабинете №%d здания ПЛК на %d этаже" % [cab_id, floor_num],
		"Местоположение"
	)

	var cutscene := IntroCutscene.new()
	scene_root.add_child(cutscene)
	cutscene.play(player, spawn_cabinet)
	
	# 4. Доспавниваем остальные кабинеты по несколько штук за кадр
	var spawned_in_step := 0
	for door in valid_doors:
		if door == primary_door or not is_instance_valid(door):
			continue

		var cabinet := _create_cabinet_for_door(door, scene_root)
		if cabinet != null:
			spawned_cabinets.append(cabinet)
			# Если у других кабинетов есть свои Waypoint и они нужны в графе:
			# EvacGraph.register_group(cabinet)

		spawned_in_step += 1
		if spawned_in_step >= CABINETS_PER_FRAME:
			spawned_in_step = 0
			await get_tree().process_frame

	# 5. Ставим дым после появления остальных кабинетов и строим маршрут
	var smoke_pos := EvacGraph.get_smoke_position(spawn_cabinet, spawned_cabinets)
	if smoke_pos != Vector3.ZERO:
		var smoke := SMOKE_SCENE.instantiate()
		scene_root.add_child(smoke)
		smoke.global_position = smoke_pos

	EvacGraph.build_route(player.global_position)
	
	await cutscene.finished

	evacuation_tracker = EvacuationTracker.new()
	add_child(evacuation_tracker)
	evacuation_tracker.tracking_finished.connect(_on_evacuation_tracking_finished)
	evacuation_tracker.start_tracking(player, EvacGraph)

	EvacuationManager.start()
	print("Позиция игрока: ", player.global_position)
	player.fade_in_fog(5.0, 0.5)
	
	
	
	#get_tree().call_group("speaker", "play_sound")
	
func _on_evacuation_tracking_finished(result: Dictionary) -> void:
	EvacuationManager.finish(result)
	print("=== РЕЗУЛЬТАТ ЭВАКУАЦИИ ===")

	print("Выход достигнут: ", result["reached_exit"])
	print("Время: %.1f сек." % result["elapsed_time"])
	print("Оптимальный путь: %.1f м" % result["optimal_distance"])
	print("Пройденный путь: %.1f м" % result["actual_distance"])
	print("Эффективность: %.1f%%" % result["efficiency"])
	#print("Отклонения: ", result["deviation_count"])

	if result["route_correct"]:
		print("Результат: маршрут без отклонений")
	elif result["reached_exit"]:
		print("Результат: эвакуация завершена с отклонениями")
	else:
		print("Результат: эвакуация не завершена")
