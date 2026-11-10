extends Node

class_name bb

# Статический генератор цвета для RichTextLaber 

static func col(string: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, string]
	
static func aqua(string: String) -> String:
	return col(string, "aqua")
	
static func green(string: String) -> String:
	return col(string, "green")
	
static func coral(string: String) -> String:
	return col(string, "coral")
	
static func orange(string: String) -> String:
	return col(string, "orange")
	
static func yellow(string: String) -> String:
	return col(string, "yellow")
	
static func spgr(string: String) -> String:
	return col(string, "MEDIUM_SPRING_GREEN")
