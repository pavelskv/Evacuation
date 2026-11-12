extends EditorExportPlugin

const OPTION_ENABLE_SCORM := "SCORM/Экспорт в SCORM"
const OPTION_COURSE_TITLE := "SCORM/Название курса"
const OPTION_AUTO_ZIP := "SCORM/Упаковка в ZIP"
const OPTION_ZIP_FILENAME := "SCORM/Название архива (*.zip)"

const default_zip_filename := "scorm.zip"

const MANIFEST_FILENAME := "imsmanifest.xml"
const SCORMJS_FILENAME := "scorm.js"

var final_file_path: String
var export_dir_path: String

var _enable_scorm := false
var _auto_zip := true
var _zip_filename := "scorm.zip"
var _course_title := "Курс SCORM"

func _get_name() -> String:
	return "SCORM_Exporter"

func _get_export_options(platform: EditorExportPlatform) -> Array[Dictionary]:
	return [
		{
			"option": {
				"name": OPTION_ENABLE_SCORM,
				"type": TYPE_BOOL
			},
			"default_value": false
		},
		{
			"option": {
				"name": OPTION_COURSE_TITLE,
				"type": TYPE_STRING
			},
			"default_value": "Курс SCORM"
		},
		{
			"option": {
				"name": OPTION_AUTO_ZIP,
				"type": TYPE_BOOL
			},
			"default_value": true
		},
		{
			"option": {
				"name": OPTION_ZIP_FILENAME,
				"type": TYPE_STRING
			},
			"default_value": "scorm.zip"
		}
	]

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	final_file_path = path
	export_dir_path = final_file_path.get_base_dir()
	
	_enable_scorm = get_option(OPTION_ENABLE_SCORM)
	_auto_zip = get_option(OPTION_AUTO_ZIP)
	_zip_filename = get_option(OPTION_ZIP_FILENAME)
	_course_title = get_option(OPTION_COURSE_TITLE)

func _export_end() -> void:
	
	if not _enable_scorm:
		print(_pmsg("SCORM выключен"))
		return
	
	print(_pmsg("Инициализация..."))
	assert(final_file_path.contains(".html"), "Ошибка! Плагин SCORM ожидает на выходе HTML-файл. Убедитесь, что экспортируете Web (HTML5)")
	_copy_assets()
	_patch_final_file()
	_create_manifest_file()
	if(_auto_zip): _write_zip_file(export_dir_path, _zip_filename)


func _copy_assets() -> void:
	DirAccess.copy_absolute("res://addons/scorm/%s" % SCORMJS_FILENAME, "%s/%s" % [export_dir_path, SCORMJS_FILENAME])
	DirAccess.copy_absolute("res://addons/scorm/assets/%s" % MANIFEST_FILENAME, "%s/%s" % [export_dir_path, MANIFEST_FILENAME])
	var files := DirAccess.open("res://addons/scorm/assets")
	for file_name in files.get_files():
		if file_name.contains(".xsd"):
			DirAccess.copy_absolute("res://addons/scorm/assets/%s" % file_name, "%s/%s" % [export_dir_path, file_name])
	print(_pmsg("Ресурсы SCORM успешно скопированы в папку экспорта."))


func _create_manifest_file() -> void:
	const tag_res_file := "$FINAL_FILE"
	const tag_file_stub := "$FILE_LINKS"
	const tag_title_stub := "$COURSE_TITLE"

	var manifest_path := "%s/%s" % [export_dir_path, MANIFEST_FILENAME]

	var files := DirAccess.open(export_dir_path)

	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	var manifest_text: String = manifest_file.get_as_text()
	
	manifest_text = manifest_text.replace(tag_title_stub, _course_title)

	# Updates the <resource> with the exported main file's path.
	manifest_text = manifest_text.replace(tag_res_file, final_file_path.get_file())

	# Adds the exported files references as <file> tags inside the <resource>.
	var file_links := ""
	for file in files.get_files():
		if !_ignore_file(file):
			file_links += "<file href=\"%s\"/>\n\t\t\t" % file

	manifest_text = manifest_text.replace(tag_file_stub, file_links)

	manifest_file.close()
	manifest_file = FileAccess.open(manifest_path, FileAccess.WRITE)
	manifest_file.store_string(manifest_text)
	manifest_file.close()
	print(_pmsg("Файл '%s' создан." % MANIFEST_FILENAME))


func _patch_final_file() -> void:
	const tag_head_close := "</head>"	# TODO: Make the match process more robust (regex).
	const tag_head_tmpl := "<script src=\"%s\"></script>\n    </head>"
	const tag_body_open := "<body>"
	const tag_body_tmpl := "<body onload=\"doStart(false);\" onbeforeunload=\"doUnload(false);\" onunload=\"doUnload();\">"

	var html_file := FileAccess.open(final_file_path, FileAccess.READ)
	var html_text: String = html_file.get_as_text()

	html_text = html_text.replace(tag_head_close, tag_head_tmpl % [SCORMJS_FILENAME])

	html_text = html_text.replace(tag_body_open, tag_body_tmpl)

	html_file.close()
	html_file = FileAccess.open(final_file_path, FileAccess.WRITE)
	html_file.store_string(html_text)
	html_file.close()
	print(_pmsg("Файл '%s' модифицирован." % final_file_path.get_file()))


func _write_zip_file(dest_path: String = export_dir_path, zip_name: String = default_zip_filename) -> void:
	print(_pmsg("Подготовка к архивации файлов экспорта... Другие файлы .zip будут проигнорированы."))
	var writer := ZIPPacker.new()
	var err := writer.open("%s/%s" % [dest_path, zip_name])
	assert(err == OK, _pmsg("Произошла ошибка при попытке открыть путь '%s/%s' для записи." % [dest_path, zip_name]))

	var dir = DirAccess.open(dest_path)
	assert(dir, _pmsg("Произошла ошибка при попытке доступа к папке '%s'." % dest_path))

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if !dir.current_is_dir():
			#print("Found file: " + file_name)
			if !_ignore_file(file_name):
				#print("> Writing file: " + file_name)
				var file = FileAccess.open("%s/%s" % [dir.get_current_dir(), file_name], FileAccess.READ)
				writer.start_file(file_name)
				writer.write_file(file.get_buffer(file.get_length()))
				writer.close_file()
				file.close()
		file_name = dir.get_next()

	writer.close()
	print(_pmsg("Архив '%s' создан." % zip_name))


func _ignore_file(file_name: String) -> bool:
	return file_name.contains(".zip") || file_name.contains(".import")

# Misc
func _pmsg(msg: String) -> String:
	return "Плагин(Scorm): %s" % msg
