@tool
class_name RBCM_GraphEditor extends GraphEdit


var nodes_editing_enabled := true:
	set(value):
		nodes_editing_enabled = value
		right_disconnects = value
		all_task_nodes_priority_chechbox_enabled(value)
	get:
		return nodes_editing_enabled


var selected_nodes: Array[RBCM_GraphNode] = []
var opened_file: String = ""


func all_task_nodes_priority_chechbox_enabled(new_state: bool) -> void:
	var nodes = get_children()
	for node in nodes:
		if node is RBCM_TaskNode: 
			node.priority_chechbox_enabled(new_state)
	

func MessageBox(msg: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.unresizable = true
	dialog.dialog_text = msg
	dialog.title = "RB Condition Manager"
	dialog.connect("confirmed", func() -> void:
		dialog.queue_free()
	)
	dialog.connect("canceled", func() -> void:
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()
	dialog.grab_focus()


func save_data(file: String) -> void:
	if get_start_node() == null:
		MessageBox("На графе должна быть одна(!) стартовая нода!")
		opened_file = ""
		return
	
	var SaveFile = FileAccess.open(file, FileAccess.WRITE)

	var nodes = get_children()
	for node in nodes:
		if node is RBCM_GraphNode:
			SaveFile.store_line(JSON.stringify(node.data))

	SaveFile.close()
	owner.log_append("Файл %s %s" % [bb.aqua(opened_file.get_file()), bb.green("сохранен")])


func load_data(file: String) -> void:
	var LoadFile = FileAccess.open(file, FileAccess.READ)
	
	clear_graph()
	
	# Загрузка всех нодов
	while LoadFile.get_position() < LoadFile.get_length():
		var line = LoadFile.get_line()
		var data = JSON.parse_string(line)
		
		var node
		
		match int(data.type):
			RBCM_GraphNode.NodeType.START:
				node = RBCM.start_node.instantiate()
			RBCM_GraphNode.NodeType.TASK: 
				node = RBCM.task_node.instantiate()
				node.reload_data(data)
		
		node.has_loaded_position = true
		node.data = data
		add_node(node, str_to_var("Vector2" + data.pos))
	
	# Восстановление соединений между нодами
	var nodes = get_children()
	for node in nodes:
		if node is RBCM_GraphNode:
			if not node.data.out_connection_ids.is_empty():
				for connection_node_id in node.data.out_connection_ids:
					var from_node = get_node_name_by_id(node.data.id)
					var to_node = get_node_name_by_id(connection_node_id)
					connect_node(from_node, 0, to_node, 0)
		
	LoadFile.close()
	
	owner.log_append("Файл %s %s" % [bb.aqua(file.get_file()), bb.green("загружен")])


func activate_connection_between_ids(from_node_id: String, to_node_id: String) -> void:
	var from_node = get_node_name_by_id(from_node_id)
	var to_node = get_node_name_by_id(to_node_id)
	set_connection_activity(from_node, 0, to_node, 0, 1)
	
func deactivate_connection_between_ids(from_node_id: String, to_node_id: String) -> void:
	var from_node = get_node_name_by_id(from_node_id)
	var to_node = get_node_name_by_id(to_node_id)
	set_connection_activity(from_node, 0, to_node, 0, 0)


func reset_connection_progress() -> void:
	var nodes = get_children()
	var connections = get_connection_list()
	
	for node in nodes:
		if node is RBCM_TaskNode: node.set_empty_state()
		
	for connection in connections:
		set_connection_activity(connection.from_node, connection.from_port, 
								connection.to_node, connection.to_port, 0)
		
	nodes_editing_enabled = true
	


func get_start_node() -> RBCM_GraphNode:
	var nodes = get_children()
	
	var start_nodes_count = 0
	var start_node: RBCM_GraphNode
	for node in nodes:
		if node is RBCM_GraphNode:
			if node.data.type == RBCM_GraphNode.NodeType.START:
				if start_nodes_count > 1:
					return null
				else:
					start_nodes_count += 1
					start_node = node
	
	return start_node


func get_node_name_by_id(id: String) -> StringName:
	var nodes = get_children()
	
	for node in nodes:
		if node is RBCM_GraphNode:
			if node.data.id == id:
				return node.name
	
	return StringName()
	
	
func get_node_by_id(id: String) -> RBCM_GraphNode:
	var nodes = get_children()
	
	for node in nodes:
		if node is RBCM_GraphNode:
			if node.data.id == id:
				return node
	
	return null


func clear_graph() -> void:
	clear_connections()
	for node in get_children():
		if node is RBCM_GraphNode:
			remove_child(node)
			node.queue_free()
	
	selected_nodes.clear()
	opened_file = ""
	
	owner.log_append("Очистка рабочего пространства")

func id_exists(id: String) -> bool:
	var nodes = get_children()
	
	for node in nodes:
		if node is RBCM_GraphNode:
			if node.data.id == id:
				return true
	
	return false
	
func nodes_count() -> int:
	var nodes = get_children()
	return nodes.size()


func add_node(new_node: RBCM_GraphNode, position_offset: Vector2) -> void:
	new_node.position_offset = position_offset
	if not new_node.has_loaded_position:
		new_node.position_offset += scroll_offset
		new_node.position_offset /= zoom
	
	if new_node.data.id.is_empty():
		var id_len = 4
		
		# Если нод больше, чем вариантов ID, то увеличить длину ID
		while nodes_count() >= id_len * RBCM_IdGenerator.ALPHABET.length():
			id_len += 1
		
		var generated_id = RBCM_IdGenerator.generate(id_len)
		var is_id_taken = id_exists(generated_id)
		while is_id_taken:
			generated_id = RBCM_IdGenerator.generate(id_len)
			is_id_taken = id_exists(generated_id)
		
		new_node.data.id = generated_id
		
	if new_node is RBCM_StartNode: 
		new_node.data.type = RBCM_GraphNode.NodeType.START
	if new_node is RBCM_TaskNode: 
		new_node.data.type = RBCM_GraphNode.NodeType.TASK
		# Отобразить ID на добавленной ноде
		new_node.reload_data(new_node.data)
		
	new_node.data.pos = new_node.position_offset
	
	add_child(new_node)



func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if not nodes_editing_enabled: return
	
	var connections := get_connection_list()
	var connections_to_remove: Array[Dictionary] = []
	var nodes_to_remove: Array[RBCM_GraphNode] = []
	for node in nodes:
		connections_to_remove.append_array(connections.filter(
			func(connection): return connection.from_node == node or connection.to_node == node
		))
		nodes_to_remove.append(get_node(NodePath(node)))
	var undo_redo := (Engine.get_meta("RBCM_Plugin") as EditorPlugin).get_undo_redo()
	undo_redo.create_action("Delete Nodes")
	undo_redo.add_do_method(self, "_delete_nodes", nodes_to_remove, connections_to_remove)
	undo_redo.add_undo_method(self, "_undo_delete_nodes", nodes_to_remove, connections_to_remove)
	undo_redo.commit_action()

func _delete_nodes(nodes: Array[RBCM_GraphNode], connections: Array[Dictionary]) -> void:
	for connection in connections:
		_disconnect_nodes(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
	for node in nodes:
		node.selected = false
		remove_child(node)
	
func _undo_delete_nodes(nodes: Array[RBCM_GraphNode], connections: Array[Dictionary]) -> void:
	for node in nodes:
		node.selected = true
		add_child(node)
	for connection in connections:
		_connect_nodes(connection.from_node, connection.from_port, connection.to_node, connection.to_port)



func has_direct_path(from_node: StringName, to_node: StringName) -> bool:
	var _from_node  = get_node(NodePath(from_node))
	var _to_node    = get_node(NodePath(to_node))
	
	for node in _from_node.data.out_connection_ids:
		# Если наш ID в списке тех у кого до нас есть прямой путь
		if _to_node.data.id in node.data.out_connection_ids:
			return true
		else:
			return has_direct_path(get_node_name_by_id(node.data.id), to_node)
	
	return false

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not nodes_editing_enabled: return
	
	var undo_redo := (Engine.get_meta("RBCM_Plugin") as EditorPlugin).get_undo_redo()
	undo_redo.create_action("Connect Nodes")
	undo_redo.add_do_method(self, "_connect_nodes", from_node, from_port, to_node, to_port)
	undo_redo.add_undo_method(self, "_disconnect_nodes", from_node, from_port, to_node, to_port)
	undo_redo.commit_action()
	
func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not nodes_editing_enabled: return
	
	var undo_redo := (Engine.get_meta("RBCM_Plugin") as EditorPlugin).get_undo_redo()
	undo_redo.create_action("Disconnect Nodes")
	undo_redo.add_do_method(self, "_disconnect_nodes", from_node, from_port, to_node, to_port)
	undo_redo.add_undo_method(self, "_connect_nodes", from_node, from_port, to_node, to_port)
	undo_redo.commit_action()

func _connect_nodes(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	connect_node(from_node, from_port, to_node, to_port)
	
	var _from_node  	= get_node(NodePath(from_node))
	var _from_node_id 	= _from_node.data.id
	
	var _to_node    	= get_node(NodePath(to_node))
	var _to_node_id 	= _to_node.data.id
	
	
	if not _from_node.data.out_connection_ids.has(_to_node_id):
		_from_node.data.out_connection_ids.append(_to_node_id)
		
	if not _to_node.data.parent_ids.has(_from_node_id):
		_to_node.data.parent_ids.append(_from_node_id)

func _disconnect_nodes(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	disconnect_node(from_node, from_port, to_node, to_port)
	
	var _from_node  	= get_node(NodePath(from_node))
	var _from_node_id 	= _from_node.data.id
	
	var _to_node    	= get_node(NodePath(to_node))
	var _to_node_id 	= _to_node.data.id
	
	if _from_node.data.out_connection_ids.has(_to_node_id):
		_from_node.data.out_connection_ids.erase(_to_node_id)
		
	if _to_node.data.parent_ids.has(_from_node_id):
		_to_node.data.parent_ids.erase(_from_node_id)



func _on_node_selected(node: Node) -> void:
	if not selected_nodes.has(node):
		selected_nodes.append(node)


func _on_node_deselected(node: Node) -> void:
	if selected_nodes.has(node):
		selected_nodes.erase(node)	



func _on_end_node_move() -> void:
	var undo_redo := (Engine.get_meta("RBCM_Plugin") as EditorPlugin).get_undo_redo()
	
	var movement_history = []
	for node in selected_nodes:
		movement_history.append([node, node.dragged_from, node.dragged_to])
	
	undo_redo.create_action("Move Nodes")
	undo_redo.add_do_method(self, "_move_node", movement_history)
	undo_redo.add_undo_method(self, "_undo_move_node", movement_history)
	undo_redo.commit_action()


func _move_node(movement_history: Array):
	for info in movement_history:
		var node = info[0]
		var from = info[1]
		var to = info[2]
		node.position_offset = to

func _undo_move_node(movement_history: Array):
	for info in movement_history:
		var node = info[0]
		var from = info[1]
		var to = info[2]
		node.position_offset = from
