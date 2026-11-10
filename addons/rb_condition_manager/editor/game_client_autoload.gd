extends Node

signal connected_to_server

var server = "ws://localhost:9999/"
var client: WSClient

var is_sync_mode := FileAccess.file_exists(RBCM.sync_file_path)
var connected := false

class WSClient:
	var _parent: Node
	var _client: WebSocketClient
	var _server: String

	func _init(parent: Node, server: String) -> void:
		_server = server
		_parent = parent
		
		_client = WebSocketClient.new()
		_client.connected_to_server.connect(_on_connected_to_server)
		_client.connection_closed.connect(_on_connection_closed)
		_client.message_received.connect(_on_message_received)
		_client.tree_exiting.connect(disconnect_from_server)
		_parent.add_child(_client)
		
	func _on_connected_to_server():
		_parent.connected = true
		_parent.emit_signal("connected_to_server")
		#print("Соединение с сервером установлено")
		
	func _on_connection_closed():
		_parent.connected = false
		#print("Соединение с сервером разорвано")
		
	func _on_message_received(message):
		pass
		#print("Сообщение от сервера: %s" % message)


	func connect_to_server():
		#print("Попытка подключения к серверу: %s." % [_server])
		var err = _client.connect_to_url(_server)
		if err != OK:
			print("Ошибка при подключении серверу: %s" % [_server])
			return

	func disconnect_from_server() -> void:
		_client.close()

	func send(request_type: RBCM.Request, arguments: Array = [] ):
		var send_data = {
			rqst = 0,
			args = []
		}
		
		send_data.rqst = request_type
		send_data.args = arguments
		
		_client.send(send_data)



func _ready() -> void:
	if is_sync_mode:
		client = WSClient.new(self, server)
		client.connect_to_server()


func send(request_type: RBCM.Request, arguments: Array = [] ):
	# EXAMPLE SENDs
	# client.send(RBCM.Request.Start)
	# client.send(RBCM.Request.ChangeTaskState, ["JDC7hu31bo", RBCM_TaskNode.State.ACTIVE])
	if connected:
		client.send(request_type, arguments)
		

func find_node(node: String) -> Node:
	var root = get_tree().root
	var current_scene = root.get_child(root.get_child_count() - 1)
	return current_scene.get_node(node)

func find_tree() -> SceneTree:
	var root = get_tree().root
	var current_scene = root.get_child(root.get_child_count() - 1)
	return current_scene.get_tree()

