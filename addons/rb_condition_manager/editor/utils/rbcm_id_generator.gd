class_name RBCM_IdGenerator extends RefCounted


const ALPHABET := "1234567890ABCDEFGHIJKLMNOPQUWXYZabcdefghkmnopquwxyz"
const DEFAULT_LENGTH := 21


static func generate(length := DEFAULT_LENGTH) -> String:
	var id: String = ""
	for i in range(length):
		id += ALPHABET[randi() % ALPHABET.length()]
	return id
