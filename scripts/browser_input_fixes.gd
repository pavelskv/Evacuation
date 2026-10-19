extends Node

signal pointer_lock_lost

var _force_cursor_cb: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().focus_exited.connect(_on_window_focus_exited)

	if OS.has_feature("web"):
		_setup_web_hooks()

func _on_window_focus_exited() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pointer_lock_lost.emit()

func _setup_web_hooks() -> void:
	var window := JavaScriptBridge.get_interface("window")
	_force_cursor_cb = JavaScriptBridge.create_callback(_on_web_force_cursor_visible)
	
	window.godotForceCursorVisible = _force_cursor_cb

	JavaScriptBridge.eval("""
		window.addEventListener('beforeunload', function (e) {
			if (document.pointerLockElement) {
				document.exitPointerLock();
			}
			e.preventDefault();
			e.returnValue = '';
		});
		function godotShowCursorNow() {
			window.godotForceCursorVisible();
		}
		document.addEventListener('visibilitychange', function () {
			if (document.hidden) { godotShowCursorNow(); }
		});
		document.addEventListener('pointerlockchange', function () {
			console.log('pointerlockchange', !!document.pointerLockElement)
			if (!document.pointerLockElement) { godotShowCursorNow(); }
		});
	""", true)

func _on_web_force_cursor_visible(_args = null) -> void:
	pointer_lock_lost.emit()
