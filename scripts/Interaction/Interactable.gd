class_name Interactable
extends Node

signal state_changed

@export var message: String = "Взаимодействовать"
@export var outline: Material = preload("res://assets/shaders/outline.tres")

var is_focused: bool = false

func can_interact() -> bool:
	return true
	
func on_focus(value: bool) -> void:
	if is_focused == value:
		return

	is_focused = value

func interact():
	pass
	
func get_message() -> String:
	return message
	
func get_training_task_id() -> StringName:
	return &""

func is_task_completed() -> bool:
	return false
	
func notify_state_changed() -> void:
	state_changed.emit()
