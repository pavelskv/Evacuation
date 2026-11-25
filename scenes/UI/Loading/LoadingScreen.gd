extends CanvasLayer
class_name LoadingScreen

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var percent_label: Label = %PercentLabel

func show_loading(title: String, detail: String = "") -> void:
	show()
	set_progress(0)

func hide_loading() -> void:
	set_progress(100)
	await get_tree().process_frame
	hide()

func set_progress(value: float) -> void:
	progress_bar.value = clampf(value, 0.0, 100.0)
	percent_label.text = "%d%%" % roundi(progress_bar.value)
