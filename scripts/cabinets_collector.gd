@tool
extends Node3D

@export_file("*.tres") var database_path: String = "res://assets/cabinets.tres"

@export_tool_button("Собрать двери", "Callable")
var collect_doors_action = _collect_doors

func _collect_doors() -> void:
	var doors_by_floor: Dictionary = {}

	_collect_from_node(self, doors_by_floor)

	# Сортируем комнаты внутри каждого этажа
	for floor in doors_by_floor:
		doors_by_floor[floor].sort()

	var database := CabinetsList.new()
	database.doors_by_floor = doors_by_floor

	var error := ResourceSaver.save(database, database_path)

	if error != OK:
		push_error("Не удалось сохранить CabinetsList: %s" % error)
		return

	print("Список дверей сохранён: ", database_path)


func _collect_from_node(node: Node, result: Dictionary) -> void:
	for child in node.get_children():

		if child.is_in_group("cabinet_doors"):
			var floor: int = child.floor_number
			var door_id: int = child.door_id

			if not result.has(floor):
				result[floor] = []

			result[floor].append(door_id)

		_collect_from_node(child, result)
