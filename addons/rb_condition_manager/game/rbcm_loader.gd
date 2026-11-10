class_name RBCM_Loader extends Node

var nodes = []

# Массивах хранятся ID нод
var tasks_active: Array[String] = []

@export_file("*.rbcm") var RBCM_Datafile


func _ready():
	# Код для считывания данных из файла и создания структуры из задач
	if RBCM_Datafile == null:
		printerr("ВНИМАНИЕ! В RBCM_Loader не указан файл данных. Отслеживание и выполнение задач невозможно.")
		return

	load_file(RBCM_Datafile)

	if RBCM_GameClient.is_sync_mode:
		await RBCM_GameClient.connected_to_server
		RBCM_GameClient.send(RBCM.Request.Start)
	
	
	var start_node_index = find_start_node_index(nodes)
	for out_connection_id in nodes[start_node_index].out_connection_ids:
		var node_data = nodes[find_node_index_by_id(out_connection_id)]
		
		# На случай увеличения кол-ва возможных нод
		match int(node_data.type):
			RBCM_GraphNode.NodeType.TASK:
				var task_timer = RBCM_TaskTimer.new(node_data)
				add_child(task_timer)


func load_file(file: String) -> void:
	var LoadFile = FileAccess.open(file, FileAccess.READ)
	
	while LoadFile.get_position() < LoadFile.get_length():
		var line = LoadFile.get_line()
		var data = JSON.parse_string(line)

		nodes.append(data)


func find_start_node_index(nodes: Array) -> int:
	var i = 0
	for node in nodes:
		if node.type == RBCM_GraphNode.NodeType.START:
			return i 
		i += 1
		
	return -1
	
	
func find_node_index_by_id(id: String) -> int:
	var i = 0
	for node in nodes:
		if node.id == id:
			return i 
		i += 1
		
	return -1
