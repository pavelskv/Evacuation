extends Node3D

@export var door_id: int = -1
@export var floor_number: int = 1
@export_enum(
	"1 окно:1",
	"2 окна:2",
	"2 окна (право):5",
	"3 окна (право):6",
	"3 окна:3",
	"4 окна:4"
)
var cabinet_id: int = 1

func _ready():
	add_to_group("cabinet_doors")
