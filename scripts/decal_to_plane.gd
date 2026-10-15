@tool
extends EditorScript

func _run() -> void:
	var edited_scene = get_editor_interface().get_edited_scene_root()
	if not edited_scene:
		print("ОШИБКА: Откройте сцену в редакторе перед запуском скрипта!")
		return
		
	var decals = []
	_find_decals(edited_scene, decals)
	
	if decals.is_empty():
		print("Узлы Decal в открытой сцене не найдены.")
		return
		
	var count = 0
	for decal in decals:
		if _convert_decal_to_plane_mesh(decal, edited_scene):
			count += 1
			
	print("Успешно заменено Decal -> MeshInstance3D (PlaneMesh): %d шт." % count)

func _find_decals(node: Node, result: Array) -> void:
	if node is Decal:
		result.append(node)
	for child in node.get_children():
		_find_decals(child, result)

func _convert_decal_to_plane_mesh(decal: Decal, scene_root: Node) -> bool:
	var parent = decal.get_parent()
	if not parent:
		return false
		
	var mesh_node = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	
	# У Decal размер проекции по плоскости — это X и Z
	plane.size = Vector2(decal.size.x, decal.size.z)
	mesh_node.mesh = plane
	
	# Настраиваем материал
	var mat = StandardMaterial3D.new()
	if decal.texture_albedo:
		mat.albedo_texture = decal.texture_albedo
		
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Устраняем Z-fighting (мерцание)
	mat.render_priority = 1
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	mesh_node.material_override = mat
	
	# Точно копируем трансформацию Decal 1:1
	mesh_node.name = decal.name + "_Plane"
	mesh_node.global_transform = decal.global_transform
	
	parent.add_child(mesh_node)
	mesh_node.owner = scene_root
	
	decal.queue_free()
	return true
