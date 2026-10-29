extends CanvasLayer
## Внешний вид и позиция настраиваются в сцене notify.tscn.
## Autoload: res://notify.tscn, имя "Notify".

enum Type { INFO, WARNING, ALARM }

const BG_NORMAL := Color(0.08, 0.09, 0.11, 0.92)
const BG_ALARM := Color(0.35, 0.04, 0.04, 0.95)

const STYLES := {
	Type.INFO:    { "color": Color("#3b9cff"), "symbol": "i", "title": "Информация" },
	Type.WARNING: { "color": Color("#ffb020"), "symbol": "!", "title": "Внимание" },
	Type.ALARM:   { "color": Color("#ff2d2d"), "symbol": "!", "title": "ТРЕВОГА" },
}

## Откуда выезжает плашка относительно своего места в сцене
@export var slide_offset := Vector2(-60, 0)
## Сколько секунд тревога «кричит» в полную силу (виньетка, пульсация, звук)
@export var alarm_intense_time := 6.0

@onready var vignette: TextureRect = %Vignette
@onready var panel: PanelContainer = %Panel
@onready var icon_circle: PanelContainer = %IconCircle
@onready var icon_label: Label = %IconLabel
@onready var icon_tex: TextureRect = %IconTex
@onready var title_label: Label = %Title
@onready var text_label: Label = %Text
@onready var alarm_player: AudioStreamPlayer = %AlarmPlayer

var _panel_style: StyleBoxFlat
var _icon_style: StyleBoxFlat
var _rest_pos: Vector2
var _queue: Array = []
var _busy := false
var _token := 0
var _fx_tween: Tween
var _vig_tween: Tween

signal _dismiss


func _ready() -> void:
	_panel_style = panel.get_theme_stylebox("panel")
	_icon_style = icon_circle.get_theme_stylebox("panel")
	_rest_pos = panel.position  # место, где плашка стоит в сцене


# ------------------------------------------------------------ API

func info(text: String, title := "", icon: Texture2D = null, duration := 6.0) -> void:
	_enqueue(Type.INFO, text, title, icon, duration)

func warning(text: String, title := "", icon: Texture2D = null, duration := 7.0) -> void:
	_enqueue(Type.WARNING, text, title, icon, duration)

func alarm(text: String, title := "", icon: Texture2D = null, duration := 0.0) -> void:
	_enqueue(Type.ALARM, text, title, icon, duration)

func clear_alarm() -> void:
	_dismiss.emit()


# ------------------------------------------------------------ очередь

func _enqueue(type: int, text: String, title: String, icon: Texture2D, duration: float) -> void:
	var msg := { "type": type, "text": text, "title": title, "icon": icon, "duration": duration }
	if type == Type.ALARM and _busy:
		_queue.push_front(msg)  # тревога прерывает текущее сообщение
		_dismiss.emit()
	else:
		_queue.push_back(msg)
	_process_queue()


func _process_queue() -> void:
	if _busy:
		return
	_busy = true
	while not _queue.is_empty():
		await _play(_queue.pop_front())
	_busy = false


# ------------------------------------------------------------ показ

func _play(m: Dictionary) -> void:
	_token += 1
	var my_token := _token
	var is_alarm: bool = m.type == Type.ALARM
	_apply(m)

	panel.position = _rest_pos + slide_offset
	panel.modulate.a = 0.0
	panel.visible = true

	var t_in := create_tween().set_parallel(true)
	t_in.tween_property(panel, "position", _rest_pos, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_in.tween_property(panel, "modulate:a", 1.0, 0.25)
	await t_in.finished

	if is_alarm:
		_start_alarm_fx()
	else:
		_pop_icon()

	if m.duration > 0.0:
		get_tree().create_timer(m.duration).timeout.connect(func():
			if _token == my_token:
				_dismiss.emit())
	await _dismiss

	if is_alarm:
		_stop_alarm_fx()
	var t_out := create_tween().set_parallel(true)
	t_out.tween_property(panel, "position", _rest_pos + slide_offset, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t_out.tween_property(panel, "modulate:a", 0.0, 0.4)
	await t_out.finished
	panel.visible = false


func _apply(m: Dictionary) -> void:
	var s: Dictionary = STYLES[m.type]
	var color: Color = s.color
	_panel_style.border_color = color
	_panel_style.bg_color = BG_NORMAL
	_icon_style.bg_color = color
	icon_label.text = s.symbol
	title_label.text = m.title if m.title != "" else s.title
	title_label.add_theme_color_override("font_color", color.lightened(0.25))
	text_label.text = m.text
	panel.reset_size()  # чтобы высота плашки подстроилась под новый текст
	panel.scale = Vector2.ONE
	icon_circle.scale = Vector2.ONE

	icon_tex.visible = m.icon != null
	icon_label.visible = m.icon == null
	if m.icon:
		icon_tex.texture = m.icon


# ------------------------------------------------------------ эффекты

func _pop_icon() -> void:
	var t := create_tween()
	t.tween_property(icon_circle, "scale", Vector2(1.3, 1.3), 0.15)
	t.tween_property(icon_circle, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _start_alarm_fx() -> void:
	var shake := create_tween()
	for i in 6:
		shake.tween_property(panel, "position:x", _rest_pos.x + randf_range(-10, 10), 0.04)
	shake.tween_property(panel, "position:x", _rest_pos.x, 0.05)

	if _vig_tween: _vig_tween.kill()
	vignette.visible = true
	_vig_tween = create_tween()
	_vig_tween.tween_property(vignette, "modulate:a", 0.25, 0.4)

	if _fx_tween: _fx_tween.kill()
	_fx_tween = create_tween().set_loops()
	_fx_tween.set_parallel(true)
	_fx_tween.tween_property(vignette, "modulate:a", 0.8, 0.5).set_trans(Tween.TRANS_SINE)
	_fx_tween.tween_property(_panel_style, "bg_color", BG_ALARM, 0.5)
	_fx_tween.tween_property(icon_circle, "scale", Vector2(1.25, 1.25), 0.5).set_trans(Tween.TRANS_SINE)
	_fx_tween.chain()
	_fx_tween.tween_property(vignette, "modulate:a", 0.25, 0.5).set_trans(Tween.TRANS_SINE)
	_fx_tween.tween_property(_panel_style, "bg_color", BG_NORMAL, 0.5)
	_fx_tween.tween_property(icon_circle, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

	if alarm_player.stream:
		alarm_player.play()

	# через alarm_intense_time секунд тревога «успокаивается», но остаётся на экране
	var tok := _token
	get_tree().create_timer(alarm_intense_time).timeout.connect(func():
		if _token == tok:
			_calm_down())


func _calm_down() -> void:
	if _fx_tween: _fx_tween.kill()
	if _vig_tween: _vig_tween.kill()
	alarm_player.stop()

	var t := create_tween().set_parallel(true)
	t.tween_property(vignette, "modulate:a", 0.0, 0.8)
	t.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(icon_circle, "scale", Vector2.ONE, 0.3)
	t.chain().tween_callback(func(): vignette.visible = false)

	# спокойная пульсация иконки, чтобы было видно, что тревога идёт
	_fx_tween = create_tween().set_loops()
	_fx_tween.tween_property(icon_circle, "scale", Vector2(1.15, 1.15), 0.8).set_trans(Tween.TRANS_SINE)
	_fx_tween.tween_property(icon_circle, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


func _stop_alarm_fx() -> void:
	if _fx_tween: _fx_tween.kill()
	if _vig_tween: _vig_tween.kill()
	alarm_player.stop()
	_vig_tween = create_tween()
	_vig_tween.tween_property(vignette, "modulate:a", 0.0, 0.6)
	_vig_tween.tween_callback(func(): vignette.visible = false)
