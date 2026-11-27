extends CanvasLayer
class_name LoadingScreen

var _percent := 0.0
var _tween: Tween

@onready var progress_bar: ColorRect = $CenterContainer/Panel/Margin/VBoxContainer/Content/ColorRect
@onready var percent_label: Label = %PercentLabel

func _ready() -> void:
	progress_bar.material = progress_bar.material.duplicate()
	hide()

func _apply(v: float) -> void:
	_percent = v
	(progress_bar.material as ShaderMaterial).set_shader_parameter("progress", v / 100.0)
	percent_label.text = "%d%%" % roundi(v)

func show_loading(title: String = "", detail: String = "") -> void:
	if _tween:
		_tween.kill()
	_apply(0.0)
	show()
	await get_tree().process_frame

func set_progress(value: float, duration := 0.3) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply, _percent, clampf(value, 0.0, 100.0), duration)
	await _tween.finished

func hide_loading() -> void:
	await set_progress(100.0, 0.2)
	hide()
