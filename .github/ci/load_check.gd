extends Node

const EXTENSIONS := ["gd", "gdshader", "tres", "tscn"]

func _ready() -> void:
	var failed := 0
	var counts := {}
	for path in _files("res://"):
		var extension : String = path.get_extension()
		if not EXTENSIONS.has(extension):
			continue
		counts[extension] = counts.get(extension, 0) + 1
		printerr("LOADCHECK FILE ", path)
		var problem := _check(path)
		if problem != "":
			failed += 1
			printerr("LOADCHECK FAIL ", path, " | ", problem)
	printerr("LOADCHECK DONE files=", JSON.stringify(counts), " failed=", failed)
	get_tree().quit(0)

func _check(path : String) -> String:
	var resource : Resource = ResourceLoader.load(path)
	if resource == null:
		return "load returned null"
	if resource is GDScript and not resource.can_instantiate():
		return "script does not compile"
	if resource is PackedScene:
		if not resource.can_instantiate():
			return "scene cannot be instantiated"
		var instance : Node = resource.instantiate()
		if instance == null:
			return "instantiate returned null"
		instance.free()
	return ""

func _files(dir : String) -> Array[String]:
	var found : Array[String] = []
	var access := DirAccess.open(dir)
	if access == null or access.file_exists(".gdignore"):
		return found
	for sub in access.get_directories():
		if not sub.begins_with("."):
			found.append_array(_files(dir.path_join(sub)))
	for file in access.get_files():
		found.append(dir.path_join(file))
	return found
