# БАЗОВЫЙ КЛАСС ДЛЯ ВСЕХ НОД В РЕДАКТОРЕ

@tool
class_name RBCM_GraphNode extends GraphNode

enum NodeType {
	START, 
	TASK
}

@onready var graph_editor = get_parent() as RBCM_GraphEditor
@export var label_color: Color = Color.WHITE

var has_loaded_position := false
var dragged_from: Vector2
var dragged_to: Vector2

var data = {
	type = "",
	pos = "",
	id = "",
	priority = "",
	description = "",
	code = {
		condition = "",
		on_active = "",
		on_completed = ""
	},
	parent_ids = [],
	out_connection_ids = []
}


func _ready() -> void:
	if data.id.is_empty(): return

	var title_label := get_titlebar_hbox().get_children()[0] as Label
	title_label.add_theme_color_override("font_color", label_color)
	
	var delete_button: Button = Button.new()
	var node_name_array: Array[StringName] = [name]
	delete_button.icon = get_theme_icon("Close", "EditorIcons")
	delete_button.pressed.connect(get_parent()._on_delete_nodes_request.bind(node_name_array))
	delete_button.size_flags_horizontal = SIZE_SHRINK_END
	get_titlebar_hbox().add_child(delete_button)
	
	position_offset_changed.connect(_position_offset_changed)
	
	dragged.connect(_on_dragged)
	
	
func _on_dragged(from: Vector2, to: Vector2):
	dragged_from = from
	dragged_to = to


func _position_offset_changed() -> void:
	data.pos = position_offset
	
	
func activate_self_out_connections() -> void:
	# Подсветить все выходящие из себя линии связи 
	# и перевести последующие Task-ноды в активное состояние
	for out_node_id in data.out_connection_ids:
		graph_editor.activate_connection_between_ids(data.id, out_node_id)

		var out_node = graph_editor.get_node_by_id(out_node_id)
		match int(out_node.data.type):
			RBCM_GraphNode.NodeType.TASK:
				out_node.set_state(RBCM_TaskNode.State.ACTIVE)
