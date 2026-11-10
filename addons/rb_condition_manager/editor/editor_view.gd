@tool
class_name RBCM extends Control

enum Request {
	Start,
	ChangeTaskState,

}

# Список всех доступных в плагине нод
const start_node = preload("./nodes/start_node/rbcm_start_node.tscn")
const task_node = preload("./nodes/task_node/rbcm_task_node.tscn")

const sync_file_path := "res://sync.mode"
const save_file_path := "res://data.rbcm"

var server: WSServer
var file_open

@onready var graph_editor = %RBCM_GraphEditor as RBCM_GraphEditor

@onready var _log_dest = %LogRichTextLabel
@onready var _sync_checkbox = %SyncCheckbox


class WSServer:
	var _parent: Node
	var _server: WebSocketServer
	var _port: int
	
	func _init(parent: Node, port: int) -> void:
		_parent = parent
		_port = port
		
		_server = WebSocketServer.new()
		_server.use_tls = false
		_server.client_connected.connect(_on_client_connected)
		_server.client_disconnected.connect(_on_client_disconnected)
		_server.message_received.connect(_on_message_received)
		_parent.add_child(_server)
	
	
		
	func _on_client_connected(peer_id: int) -> void:
		var peer: WebSocketPeer = _server.peers[peer_id]
		_parent.log_append("Соединение с клиентом " + bb.green("установлено"))
		
		_parent.graph_editor.nodes_editing_enabled = false
		_parent.log_append(	"В режиме" + bb.yellow(" синхронизации ") + "редактирование нод " + 
							bb.coral("ограничено"))

	func _on_client_disconnected(peer_id: int) -> void:
		var peer: WebSocketPeer = _server.peers[peer_id]
		_parent.log_append("Соединение с клиентом " + bb.orange("разорвано"))
		_parent.graph_editor.reset_connection_progress()
		
		_parent.log_append(	"Редактирование нод снова " + bb.green("доступно"))

	func _on_message_received(peer_id: int, message: Variant) -> void:
		#var message = {
			#rqst = 0,
			#args = []
		#}
		
		# Если график пустой, то игнорируем сообщения клиента
		if _parent.graph_editor.opened_file.is_empty() \
		or _parent.graph_editor.nodes_count() == 0: 
			return
			
		match message.rqst:
			RBCM.Request.Start:
				_parent.graph_editor.get_start_node().activate_self_out_connections()
				_parent.log_append(bb.aqua("Клиент:") + " активация стартовой ноды")
			RBCM.Request.ChangeTaskState:
				var node_id = message.args[0]								# message.args[0] - ID ноды
				var node_new_state = message.args[1]						# message.args[1] - новое состояние ноды
				var new_state_txt = RBCM_TaskNode.StateText[node_new_state] # текст состояния ноды (см. RBCM_TaskNode)
				
				_parent.graph_editor.get_node_by_id(node_id).set_state(node_new_state)
				_parent.log_append(bb.aqua("Клиент: ") + "задача " + bb.coral(node_id) + 
								   " перешла в состояние " + bb.spgr(new_state_txt))


	func _exit_tree() -> void:
		_server.stop()
	
	func start() -> void:
		var err = _server.listen(_port)
		if err != OK:
			_parent.log_append("Не удалось открыть порт " + bb.orange(str(_port)))
			return
			
		_parent.log_append("Сервер синхронизации " + bb.green("запущен")) 
		
	func stop() -> void:
		_server.stop()
		_parent.log_append("Сервер синхронизации " + bb.orange("остановлен"))
		_parent.graph_editor.reset_connection_progress()
	
	func reload() -> void:
		# Запуск или остановка сервера в зависимости от чекбокса в окне плагина
		match _parent._sync_checkbox.button_pressed:
			true: start()
			false: stop()


func _ready() -> void:
	# Иконки для кнопок управления
	%SaveButton.icon = get_theme_icon("Save", "EditorIcons")
	%SaveAsButton.icon = get_theme_icon("Save", "EditorIcons")
	%LoadButton.icon = get_theme_icon("Load", "EditorIcons")
	%ClearButton.icon = get_theme_icon("Clear", "EditorIcons")
	
	# Удалить файл, активирующий синхронизацию для клиента, т.к. на запуске
	# галка плагина "Синхрозировать с прохождением" всегда отключена
	sync_file_set(false)
	
	# Запуск сервера отладки на порту 9999
	server = WSServer.new(self, 9999)
	server.reload()
	

func _on_debug_checkbox_toggled(toggled_on: bool) -> void:
	sync_file_set(toggled_on)
	if is_instance_valid(server): server.reload()
	

func _on_popup_request(position: Vector2) -> void:
	$PopupMenu.popup_on_parent(Rect2(get_global_mouse_position(), Vector2.ZERO))


func _on_popup_menu_index_pressed(index: int) -> void:
	var pos = graph_editor.get_local_mouse_position()
	match index:
		0: graph_editor.add_node(RBCM.start_node.instantiate(), pos)
		1: graph_editor.add_node(RBCM.task_node.instantiate(), pos)
	


func _save_button_pressed() -> void:
	if graph_editor.opened_file.is_empty():
		graph_editor.get_node("%SaveFileDialog").popup()
	else:
		graph_editor.save_data(graph_editor.opened_file)

func _on_save_as_button_pressed() -> void:
	graph_editor.get_node("%SaveFileDialog").popup()

func _load_button_pressed() -> void:
	graph_editor.get_node("%LoadFileDialog").popup()

func _clear_button_pressed() -> void:
	graph_editor.clear_graph()
	
	
func _on_save_file_dialog_file_selected(path: String) -> void:
	graph_editor.get_node("%SaveFileDialog").exclusive = false
	
	graph_editor.opened_file = path
	graph_editor.save_data(path)
	

func _on_load_file_dialog_file_selected(path: String) -> void:
	graph_editor.get_node("%LoadFileDialog").exclusive = false
	
	graph_editor.load_data(path)
	graph_editor.opened_file = path
	



func log_append(msg) -> void:
	var system_time = Time.get_time_dict_from_system()
	var time = "[[color=yellow]%02d:%02d:%02d[/color]] " % \
				[system_time.hour, system_time.minute, system_time.second]
	_log_dest.append_text(time + str(msg) + "\n")


func sync_file_set(current_sync_mode: bool):
	# Если синхронизация включена - создать файл sync.mode
	# Если синхронизация выключена - удалить этот файл
	# Данный файл проверяет autoload-клиент (RBCM_GameClient) для 
	# определения о том, надо ли пытаться подключаться к серверу
	if current_sync_mode: 
		var sync_file = FileAccess.open(sync_file_path, FileAccess.WRITE)
		sync_file.close()
	elif FileAccess.file_exists(RBCM.sync_file_path):
		DirAccess.remove_absolute(sync_file_path)
