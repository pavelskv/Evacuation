extends Node

var is_enabled: bool = false

func _ready():
	is_enabled = OS.is_debug_build()
	print("Дебаг-режим: ", is_enabled)

func _log(message: String, level: String = "info") -> void:
	if not is_enabled:
		return
	
	match level:
		"info":
			print("[INFO] ", message)
		"warning":
			print("[WARNING] ", message)
		"error":
			print("[ERROR] ", message)
		"debug":
			print("[DEBUG] ", message)
		_:
			print(message)

func i(message: String) -> void:
	_log(message, "info")

func w(message: String) -> void:
	_log(message, "warning")

func e(message: String) -> void:
	_log(message, "error")

func d(message: String) -> void:
	_log(message, "debug")
