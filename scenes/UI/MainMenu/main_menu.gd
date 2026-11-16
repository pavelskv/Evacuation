extends CanvasLayer

@export var cabinets_list: CabinetsList

@export var skip_start_menu: bool = false

@onready var floor_option: OptionButton = %FloorOption
@onready var room_option: OptionButton = %RoomOption
@onready var start_button: Button = %StartButton


func _ready() -> void:
	GameState.set_state(GameState.State.PAUSED)

	# В 3D-игре курсор бывает захвачен, в меню он нужен
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	Debug.i("Главное меню загружено")

	if skip_start_menu:
		loadMainScene()
		return

	_fill_floors()
	_reset_rooms()

	floor_option.item_selected.connect(_on_floor_selected)
	room_option.item_selected.connect(_on_room_selected)


func loadMainScene() -> void:
	GameState.set_state(GameState.State.PLAYING)
	get_tree().change_scene_to_file("res://scenes/Main/main.tscn")


# --------------------------------------------------
# Страницы (задачи / управление / материалы)
# --------------------------------------------------

func show_controls() -> void:
	get_tree().set_group("StartMenu_TaskPage", "visible", false)
	get_tree().set_group("StartMenu_MaterialsPage", "visible", false)
	get_tree().set_group("StartMenu_ControlsPage", "visible", true)


func show_task() -> void:
	get_tree().set_group("StartMenu_ControlsPage", "visible", false)
	get_tree().set_group("StartMenu_MaterialsPage", "visible", false)
	get_tree().set_group("StartMenu_TaskPage", "visible", true)


func show_materials() -> void:
	get_tree().set_group("StartMenu_ControlsPage", "visible", false)
	get_tree().set_group("StartMenu_TaskPage", "visible", false)
	get_tree().set_group("StartMenu_MaterialsPage", "visible", true)


func _on_controls_button_pressed() -> void:
	show_controls()


func _on_task_button_pressed() -> void:
	show_task()


func _on_materials_button_pressed() -> void:
	show_materials()


func _on_rich_text_label_materials_meta_clicked(meta) -> void:
	OS.shell_open(str(meta))


# --------------------------------------------------
# Запуск
# --------------------------------------------------

func _on_start_button_pressed() -> void:
	if room_option.selected < 0:
		return

	var door_id = room_option.get_item_metadata(room_option.selected)

	# Заглушка «Выберите кабинет» не несёт метаданных
	if door_id == null:
		return

	GameState.selected_door_id = door_id
	loadMainScene()


func _on_start_random_button_pressed() -> void:
	GameState.selected_door_id = -1
	loadMainScene()


# --------------------------------------------------
# Выбор этажа и комнаты
# --------------------------------------------------

func _fill_floors() -> void:
	floor_option.clear()

	floor_option.add_item("Выберите этаж")
	floor_option.set_item_disabled(0, true)

	var floors := cabinets_list.doors_by_floor.keys()
	floors.sort()

	for floor_number in floors:
		floor_option.add_item("Этаж %d" % floor_number)
		floor_option.set_item_metadata(floor_option.item_count - 1, floor_number)

	floor_option.select(0)


func _reset_rooms() -> void:
	room_option.clear()

	room_option.add_item("Выберите кабинет")
	room_option.set_item_disabled(0, true)
	room_option.select(0)

	room_option.disabled = true
	start_button.disabled = true


func _on_floor_selected(index: int) -> void:
	var floor_number = floor_option.get_item_metadata(index)

	if floor_number == null:
		return

	_fill_rooms(floor_number)


func _fill_rooms(floor_number: int) -> void:
	_reset_rooms()

	var rooms: Array = cabinets_list.doors_by_floor[floor_number]

	for door_id in rooms:
		room_option.add_item("Комната %d" % door_id)
		room_option.set_item_metadata(room_option.item_count - 1, door_id)

	room_option.select(0)
	room_option.disabled = false


func _on_room_selected(index: int) -> void:
	start_button.disabled = room_option.get_item_metadata(index) == null
