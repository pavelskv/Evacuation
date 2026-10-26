class_name EvacuationTask
extends Resource

@export_group("Задание")

@export var id: StringName
@export var title: String
@export_multiline var description: String = ""

@export_group("Правила")

# Учитывать ли нарушение в оценке.
@export var required: bool = true

# Можно ли признать задание неприменимым.
@export var can_be_not_applicable: bool = false

# Доступно ли задание сразу при запуске сценария.
# Если false, оно появится после activate_task().
@export var starts_available: bool = true

@export var validator: TaskValidator

enum ValidationScope {
	WHOLE_BUILDING,
	STARTING_ROOM
}

@export var validation_scope: ValidationScope = (
	ValidationScope.WHOLE_BUILDING
)
