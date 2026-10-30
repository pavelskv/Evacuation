extends Node3D

@export var enabled := true

const C_EDGE := Color(0.3, 0.8, 0.3)
const C_POINT := Color(1, 1, 1)
const C_DOOR := Color(1, 0.9, 0.2)
const C_EXIT := Color(1, 0.2, 0.2)
const C_ROUTE := Color(0.2, 0.7, 1)

var mesh := ImmediateMesh.new()

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 100

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.top_level = true
	add_child(mi)

	var t := Timer.new()
	t.wait_time = 0.5
	t.timeout.connect(_redraw)
	add_child(t)
	t.start()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		enabled = not enabled
		_redraw()

func _redraw() -> void:
	mesh.clear_surfaces()
	if not enabled:
		return

	var astar := EvacGraph.astar
	var point_ids := astar.get_point_ids()
	if point_ids.is_empty():
		return

	var door_ids := {}
	for wp in EvacGraph.ids:
		if is_instance_valid(wp) and wp.is_door:
			door_ids[EvacGraph.ids[wp]] = true

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for id in point_ids:
		var a := astar.get_point_position(id)
		for n in astar.get_point_connections(id):
			if n > id:
				_line(a, astar.get_point_position(n), C_EDGE)

	for id in point_ids:
		var c := C_POINT
		if id in EvacGraph.exits:
			c = C_EXIT
		elif door_ids.has(id):
			c = C_DOOR
		_cross(astar.get_point_position(id), c)

	var path := EvacGraph.route
	for i in range(path.size() - 1):
		_line(path[i] + Vector3.UP * 0.15, path[i + 1] + Vector3.UP * 0.15, C_ROUTE)

	mesh.surface_end()

func _line(a: Vector3, b: Vector3, c: Color) -> void:
	mesh.surface_set_color(c)
	mesh.surface_add_vertex(a)
	mesh.surface_set_color(c)
	mesh.surface_add_vertex(b)

func _cross(p: Vector3, c: Color, s := 0.2) -> void:
	_line(p - Vector3(s, 0, 0), p + Vector3(s, 0, 0), c)
	_line(p - Vector3(0, s, 0), p + Vector3(0, s, 0), c)
	_line(p - Vector3(0, 0, s), p + Vector3(0, 0, s), c)
