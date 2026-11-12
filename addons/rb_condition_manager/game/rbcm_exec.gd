class_name RBCM_Exec extends Node


func _get_node_fix(line: String) -> String:
	var err_msg = """
		RB Condition Manager: Вместо $".." и $"." используйте уникальные имена (например, %MySprite) 
		или прямой путь от корня основной сцены (например, $Node2D/MySprite).
	"""
	assert(line.find("$\"..\"") == -1 and line.find("$\".\"") == -1, err_msg)
	
	
	var regex_get_node_fix = r"[$%][^\.) \n]+"
	var regex := RegEx.create_from_string(regex_get_node_fix)
	
	var callback = func(text:String) -> String: 
		return "RBCM_GameClient.find_node(\"%s\")" % text
		
	var regex_matches = regex.search_all(line)
	var offset = 0
	for regex_match in regex_matches:
		var start = regex_match.get_start()
		var end = regex_match.get_end()
		var length = end - start
		var text = line.substr(start + offset, length)
		var replacement = callback.call(text)
		
		line = line.substr(0, start + offset) + replacement + line.substr(end + offset)
		
		offset += replacement.length() - text.length()
	
	return line


func _get_tree_fix(line: String) -> String:
	return line.replace("get_tree()", "RBCM_GameClient.find_tree()")


func _fix_all(line: String) -> String:
	line = _get_tree_fix(line)
	line = _get_node_fix(line)
	return line


func run(code: String) -> Variant:
	var script = GDScript.new()
	
	script.source_code += "extends Node\n\n"
	script.source_code += "static func run():\n\tpass"
	
	for line in code.split("\n"):
		line = line.dedent()
		line = _fix_all(line)
		script.source_code += "\n\t" + line
		
	script.reload()
	var result = await script.run()
	return result


func check(code: String) -> bool:
	code = _fix_all(code)
	
	if code.is_empty(): 
		return true
	
	var script = GDScript.new()
	
	script.source_code += "extends Node\n\n"
	script.source_code += "static func check() -> bool:\n\t"
	script.source_code += "return " + code
	
	script.reload()
	var result = script.check()
	return result
