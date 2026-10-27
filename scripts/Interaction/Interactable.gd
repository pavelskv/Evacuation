class_name Interactable
extends Node

signal state_changed

@export var message: String = "Взаимодействовать"

func set_interactable() -> void:
	pass

func can_interact() -> bool:
	return true

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
