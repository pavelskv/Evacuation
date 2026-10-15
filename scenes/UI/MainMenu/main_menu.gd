extends CanvasLayer

@export var cabinets_list: CabinetsList

@export var skip_start_menu: bool = false

@onready var floor_option: OptionButton = $Control/VBoxContainer/MarginContainerCommon/HBoxContainer/MarginContainerPanel/Panel/VBoxContainer/MarginContainerPanelPic/MarginContainerTask/VBoxContainer/MarginContainer/HBoxContainer/OptionButton
@onready var room_option: OptionButton = $Control/VBoxContainer/MarginContainerCommon/HBoxContainer/MarginContainerPanel/Panel/VBoxContainer/MarginContainerPanelPic/MarginContainerTask/VBoxContainer/MarginContainer/HBoxContainer/OptionButton2

func _ready() -> void:	
	GameState.set_state(GameState.State.PAUSED)
	
	Debug.i("Главное меню загружено")
	
	if skip_start_menu:
		loadMainScene()
		
	_fill_floors()
	floor_option.item_selected.connect(_on_floor_selected)

func loadMainScene() -> void:
	GameState.set_state(GameState.State.PLAYING)
	get_tree().change_scene_to_file("res://scenes/Main/main.tscn")

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

func _on_start_button_pressed() -> void:
	if room_option.selected >= 0:
		GameState.selected_door_id = room_option.get_item_metadata(room_option.selected)
	
	loadMainScene()

func _on_rich_text_label_materials_meta_clicked(meta):
	OS.shell_open(str(meta))

func _fill_floors() -> void:
	floor_option.clear()
	
	floor_option.add_item("Выберите этаж")
	floor_option.set_item_disabled(0, true)

	var floors := cabinets_list.doors_by_floor.keys()
	floors.sort()

	for floor in floors:
		floor_option.add_item("Этаж %d" % floor)
		floor_option.set_item_metadata(
			floor_option.item_count - 1,
			floor
		)
	
	floor_option.select(0)


func _on_floor_selected(index: int) -> void:
	var floor: int = floor_option.get_item_metadata(index)

	_fill_rooms(floor)


func _fill_rooms(floor: int) -> void:
	room_option.clear()

	var rooms: Array = cabinets_list.doors_by_floor[floor]

	for door_id in rooms:
		room_option.add_item("Комната %d" % door_id)
		room_option.set_item_metadata(
			room_option.item_count - 1,
			door_id
		)


func _on_start_random_button_pressed() -> void:
	GameState.selected_door_id = -1
	loadMainScene()
