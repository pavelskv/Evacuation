extends Node
class_name IntroCutscene

signal finished

@export var sit_time := 5
@export var turn_time := 0.8
@export var stand_time := 1.0

@export var speaker_look_time := 1.5

var _spawn_cabinet: Node3D

func play(player: CharacterBody3D, spawn_cabinet: Node3D) -> void:
	_spawn_cabinet = spawn_cabinet
	player.set("input_enabled", false)

	var spawn_node := spawn_cabinet.get_node_or_null("PlayerSpawn") as Node3D
	var stand_xf: Transform3D = spawn_node.global_transform if spawn_node != null else player.global_transform
	player.global_transform = stand_xf

	# Локальные смещения относительно ориентации PlayerSpawn:
	# -Z — вперёд по взгляду точки спавна, Y — высота от пола кабинета
	var sit_pos: Vector3 = stand_xf.origin + stand_xf.basis * Vector3(0.0, 1.2, -0.35)
	var stand_pos: Vector3 = stand_xf.origin + stand_xf.basis * Vector3(0.0, 1.6, 0.0)
	var pc_look_pos: Vector3 = sit_pos + (-stand_xf.basis.z * 1.5)

	var cam := Camera3D.new()
	get_tree().current_scene.add_child(cam)
	cam.global_position = sit_pos
	cam.look_at(pc_look_pos, Vector3.UP)
	cam.current = true
	
	get_tree().call_group("pc_active", "play_sound")

	# 1. Сидит за ПК
	await get_tree().create_timer(sit_time).timeout
	if not is_instance_valid(cam):
		return
		

	# 2. Сигнализация и взгляд на оповещатель только внутри своей комнаты
	get_tree().call_group("speaker", "play_sound")
	
	get_tree().call_group("pc_active", "stop_sound")

	Notify.alarm("Пожарная тревога!\nВсем сотрудникам необходимо покинуть здание!", "Внимание!")
	var speaker := _room_speaker(sit_pos)
	if speaker:
		var from_q := cam.global_transform.basis.get_rotation_quaternion()
		var to_q := cam.global_transform.looking_at(speaker.global_position, Vector3.UP).basis.get_rotation_quaternion()

		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(func(t: float) -> void:
			if not is_instance_valid(cam):
				return
			cam.global_transform.basis = Basis(from_q.slerp(to_q, t).normalized())
		, 0.0, 1.0, turn_time)
		await tw.finished
		await get_tree().create_timer(speaker_look_time).timeout

	# 3. Встаёт в точку спавна
	if is_instance_valid(cam):
		var from_q := cam.global_transform.basis.get_rotation_quaternion()
		var end_q := Transform3D.IDENTITY.looking_at(-stand_xf.basis.z, Vector3.UP).basis.get_rotation_quaternion()
		var start_pos := cam.global_position

		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(func(t: float) -> void:
			if not is_instance_valid(cam):
				return
			cam.global_position = start_pos.lerp(stand_pos, t)
			cam.global_transform.basis = Basis(from_q.slerp(end_q, t).normalized())
		, 0.0, 1.0, stand_time)
		await tw.finished

	# 4. Возврат управления игроку
	if is_instance_valid(player):
		player.global_transform = stand_xf
		var p_cam := player.get_node_or_null("Head/Camera3D") as Camera3D
		if p_cam:
			p_cam.rotation.x = 0.0
			p_cam.current = true
		player.set("input_enabled", true)

	if is_instance_valid(cam):
		cam.queue_free()

	finished.emit()

func _room_speaker(from_pos: Vector3) -> Node3D:
	if _spawn_cabinet == null:
		return null

	var best: Node3D = null
	var best_d := INF

	for n in get_tree().get_nodes_in_group("speaker"):
		if n is Node3D and is_instance_valid(n) and _spawn_cabinet.is_ancestor_of(n):
			var d := from_pos.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n

	return best
