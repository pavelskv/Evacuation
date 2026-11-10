@tool
extends EditorPlugin

var editor_view
var editor_button
var graph_editor


func _enter_tree() -> void:
	Engine.set_meta("RBCM_Plugin", self)
	
	editor_view = preload("res://addons/rb_condition_manager/editor/editor_view.tscn").instantiate()
	EditorInterface.get_editor_main_screen().add_child(editor_view)
	_make_visible(false)
	graph_editor = editor_view.graph_editor
	
	add_autoload_singleton("RBCM_GameClient", "res://addons/rb_condition_manager/editor/game_client_autoload.gd")


func _build() -> bool:
	editor_view.get_node("%LogRichTextLabel").clear()

	return true


func _has_main_screen():
	return true
	
func _make_visible(visible):
	if editor_view:
		editor_view.visible = visible
		
func _get_plugin_name():
	return "RB Condition Manager"
	
func _get_plugin_icon():
	return load("res://addons/rb_condition_manager/rbcm.svg")
	
func _exit_tree() -> void:
	Engine.remove_meta("RBCM_Plugin")
	
	remove_autoload_singleton("RBCM_GameClient")

	if editor_view:
		editor_view.queue_free()
