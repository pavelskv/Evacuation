extends CanvasLayer

signal viewer_closed

const POPUP_SCALE := Vector2(0.12, 0.12)

@export_range(0.1, 2.0) var animation_duration: float = 0.3
@export_range(0.5, 1.0) var screen_ratio: float = 0.9
@export_range(0.0, 1.0) var background_opacity: float = 0.75

@export var min_zoom: float = 1.0
@export var max_zoom: float = 4.0
@export var zoom_step: float = 1.15
@export var pan_gesture_sensitivity: float = 0.05
@export var magnify_sensitivity: float = 1.0
@export var cursor_sensitivity: float = 1.0
@export var cursor_hotspot := Vector2.ZERO
@export var hand_open: Texture2D
@export var hand_closed: Texture2D
@export var info_rise_distance: float = 80.0

@onready var background: ColorRect = $Background
@onready var painting_texture: TextureRect = $Background/PlanTexture
@onready var info_root: Control = $InfoRoot
@onready var cursor: TextureRect = $InfoRoot/Cursor

var is_open := false
var current_zoom := 1.0

var _is_animating := false
var _is_dragging := false
var _tween: Tween
var _virtual_cursor := Vector2.ZERO


func _ready() -> void:
	add_to_group("plan_viewer")
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0)

	painting_texture.set_anchors_preset(Control.PRESET_TOP_LEFT)
	painting_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painting_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	painting_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE

	info_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_root.modulate.a = 0.0

	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_cursor_texture()

func show_painting(texture: Texture2D) -> void:
	if is_open or _is_animating or texture == null:
		return
	is_open = true
	_is_animating = true
	_set_dragging(false)

	current_zoom = 1.0
	painting_texture.texture = texture
	painting_texture.size = _viewport_size() * screen_ratio
	painting_texture.pivot_offset = painting_texture.size / 2.0
	painting_texture.position = _centered_pos()
	painting_texture.scale = POPUP_SCALE
	painting_texture.modulate.a = 1.0

	info_root.modulate.a = 0.0
	info_root.position = Vector2(0, info_rise_distance)

	_set_cursor(_viewport_size() / 2.0)
	background.color.a = 0.0
	show()

	var tw := _new_tween()
	tw.tween_property(background, "color:a", background_opacity, animation_duration)
	tw.tween_property(info_root, "modulate:a", 1.0, animation_duration)
	tw.tween_property(info_root, "position", Vector2.ZERO, animation_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(painting_texture, "scale", Vector2.ONE, animation_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func(): _is_animating = false)


func close_painting() -> void:
	if not is_open or _is_animating:
		return
	_is_animating = true
	_set_dragging(false)

	var tw := _new_tween()
	tw.tween_property(background, "color:a", 0.0, animation_duration)
	tw.tween_property(info_root, "modulate:a", 0.0, animation_duration)
	tw.tween_property(info_root, "position", Vector2(0, info_rise_distance), animation_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(painting_texture, "modulate:a", 0.0, animation_duration)
	tw.tween_property(painting_texture, "position", _centered_pos(), animation_duration)
	tw.tween_property(painting_texture, "scale", POPUP_SCALE, animation_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	hide()
	painting_texture.texture = null
	painting_texture.scale = Vector2.ONE
	painting_texture.position = _centered_pos()
	info_root.position = Vector2.ZERO
	current_zoom = 1.0
	is_open = false
	_is_animating = false
	viewer_closed.emit()

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if _is_animating:
		if event is InputEventMouseMotion:
			_set_cursor(_virtual_cursor + event.relative * cursor_sensitivity)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_interact"):
		close_painting()
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event.relative)
	elif event is InputEventMagnifyGesture:
		_zoom_at(pow(event.factor, magnify_sensitivity), _virtual_cursor)
	elif event is InputEventPanGesture:
		_zoom_at(exp(-event.delta.y * pan_gesture_sensitivity), _virtual_cursor)
	else:
		return

	get_viewport().set_input_as_handled()

func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at(zoom_step, _virtual_cursor)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at(1.0 / zoom_step, _virtual_cursor)
		MOUSE_BUTTON_LEFT:
			_set_dragging(event.pressed and current_zoom > min_zoom)
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				close_painting()


func _on_mouse_motion(relative: Vector2) -> void:
	if _is_dragging:
		var old_pos := painting_texture.position
		painting_texture.position = _clamp_position(old_pos + relative)
		_set_cursor(_virtual_cursor + (painting_texture.position - old_pos))
	else:
		_set_cursor(_virtual_cursor + relative * cursor_sensitivity)

func _set_dragging(value: bool) -> void:
	_is_dragging = value
	_update_cursor_texture()

func _update_cursor_texture() -> void:
	cursor.texture = hand_closed if _is_dragging else hand_open

func _set_cursor(pos: Vector2) -> void:
	_virtual_cursor = pos.clamp(Vector2.ZERO, _viewport_size())
	cursor.position = _virtual_cursor - cursor_hotspot

func _zoom_at(factor: float, point: Vector2) -> void:
	var new_zoom := clampf(current_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(new_zoom, current_zoom):
		return

	var pivot_screen := painting_texture.position + painting_texture.pivot_offset
	var new_pos := painting_texture.position \
		- (point - pivot_screen) * (new_zoom / current_zoom - 1.0)

	current_zoom = new_zoom
	painting_texture.scale = Vector2.ONE * current_zoom
	painting_texture.position = _clamp_position(new_pos)

func _clamp_position(desired_pos: Vector2) -> Vector2:
	var view := _viewport_size()
	var displayed := _get_displayed_size()
	var center := desired_pos + painting_texture.pivot_offset

	for axis in 2:
		if displayed[axis] <= view[axis]:
			center[axis] = view[axis] / 2.0
		else:
			var max_offset: float = (displayed[axis] - view[axis]) / 2.0
			center[axis] = clampf(center[axis], view[axis] / 2.0 - max_offset, view[axis] / 2.0 + max_offset)

	return center - painting_texture.pivot_offset


func _get_displayed_size() -> Vector2:
	var tex := painting_texture.texture
	if tex == null:
		return painting_texture.size * current_zoom
	var img_size := tex.get_size()
	var fit := minf(painting_texture.size.x / img_size.x, painting_texture.size.y / img_size.y)
	return img_size * fit * current_zoom

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _centered_pos() -> Vector2:
	return (_viewport_size() - painting_texture.size) / 2.0


func _new_tween() -> Tween:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	return _tween
