@tool
class_name RBCM_TaskNode extends RBCM_GraphNode

enum State {
	DISABLED,
	WAIT,
	ACTIVE,
	COMPLETED
}
const StateText = ["отключена по приоритетности", "в ожидании", "активна", "завершена"]

var col_disabled: Color = Color.html("#e1b267")
var col_wait: Color = Color.html("#d37f77")
var col_active: Color = Color.html("#57ccff")
var col_completed: Color = Color.html("#00bb00")

@onready var current_state := State.WAIT:
	set(value):
		current_state = value
		match current_state:
			State.DISABLED:
				%StateValue.add_theme_color_override("font_color", col_disabled)
				%StateValue.text = StateText[State.DISABLED]
				
				# Этот блок чисто на тест, его можно удалить!
				# Это обработка отключения ноды, когда сработала Priority
				for out_node_id in data.out_connection_ids:
					graph_editor.deactivate_connection_between_ids(data.id, out_node_id)
					
					#var out_node = graph_editor.get_node_by_id(out_node_id)
					#match int(out_node.data.type):
						#RBCM_GraphNode.NodeType.TASK:
							#out_node.set_state(RBCM_TaskNode.State.WAIT)
			State.WAIT:
				%StateValue.add_theme_color_override("font_color", col_wait)
				%StateValue.text = StateText[State.WAIT]
				
				for out_node_id in data.out_connection_ids:
					graph_editor.deactivate_connection_between_ids(data.id, out_node_id)
					
					var out_node = graph_editor.get_node_by_id(out_node_id)
					match int(out_node.data.type):
						RBCM_GraphNode.NodeType.TASK:
							
							if not out_node.current_state in \
							[RBCM_TaskNode.State.ACTIVE, RBCM_TaskNode.State.COMPLETED]:
								out_node.set_state(RBCM_TaskNode.State.WAIT)
			
			State.ACTIVE:
				%StateValue.add_theme_color_override("font_color", col_active)
				%StateValue.text = StateText[State.ACTIVE]
				
				# Когда нода стала активной:
				# - Отключить подсветку до всех нод на "выходе" (для петель)
				#
				# - Если ноды на "выходе" не в статусе "завершена" (т.е. это не петля к предыдущим шагам),
				#   то переключить ноду в статус "в ожидании". Другими словами - переключать в ожидание
				#   только те ноды, которые ранее еще не срабатывали
				for out_node_id in data.out_connection_ids:
					graph_editor.deactivate_connection_between_ids(data.id, out_node_id)
					
					var out_node = graph_editor.get_node_by_id(out_node_id)
					match int(out_node.data.type):
						RBCM_GraphNode.NodeType.TASK:
							out_node.set_state(RBCM_TaskNode.State.WAIT)
							#if not out_node.current_state in \
							#[RBCM_TaskNode.State.COMPLETED, RBCM_TaskNode.State.WAIT, RBCM_TaskNode.State.DISABLED]:
							#	out_node.set_state(RBCM_TaskNode.State.WAIT)
								

			State.COMPLETED:
				%StateValue.add_theme_color_override("font_color", col_completed)
				%StateValue.text = StateText[State.COMPLETED]
				activate_self_out_connections()
	get: 
		return current_state



func set_state(new_state: State) -> void:
	current_state = new_state
	
func set_priority(new_priority: int) -> void:
	match new_priority:
		1: %PriorityCheckBox.button_pressed = true
		0: %PriorityCheckBox.button_pressed = false
		
func priority_chechbox_enabled(new_state: bool) -> void:
	%PriorityCheckBox.disabled = not new_state
	
func set_empty_state() -> void:
	%StateValue.text = ""
	
func reload_data(data) -> void:
	set_priority(int(data.priority))
	%CopyIDButton.text = data.id
	%DescriptionTextEdit.text = data.description
	%ConditionTextEdit.text = data.code.condition
	%OnBecomeActiveTextEdit.text = data.code.on_active
	%OnCompletedTextEdit.text = data.code.on_completed

func _on_tab_bar_tab_changed(tab: int) -> void:
	match tab:
		0:
			%ConditionTextEdit.visible = true
			%OnBecomeActiveTextEdit.visible = false
			%OnCompletedTextEdit.visible = false
		1:
			%ConditionTextEdit.visible = false
			%OnBecomeActiveTextEdit.visible = true
			%OnCompletedTextEdit.visible = false
		2:
			%ConditionTextEdit.visible = false
			%OnBecomeActiveTextEdit.visible = false
			%OnCompletedTextEdit.visible = true


func _on_copy_id_button_pressed() -> void:
	DisplayServer.clipboard_set(%CopyIDButton.text)


func _description_text_changed() -> void:
	data.description = %DescriptionTextEdit.text


func _condition_text_changed() -> void:
	data.code.condition = %ConditionTextEdit.text


func _on_become_active_text_changed() -> void:
	data.code.on_active = %OnBecomeActiveTextEdit.text


func _on_complete_text_changed() -> void:
	data.code.on_completed = %OnCompletedTextEdit.text


func _on_priority_check_box_toggled(toggled_on: bool) -> void:
	match toggled_on:
		true: data.priority = 1
		false: data.priority = 0
