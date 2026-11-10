class_name JsonDataLoader
extends RefCounted
## Loads JSON data files with explicit error reporting.
## Single place for data-file loading so every system fails loudly in the same way.


## Loads a JSON file whose top level is an object. Returns {} (and logs the cause) on failure.
static func load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JsonDataLoader: data file not found: %s" % path)
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		push_error("JsonDataLoader: %s line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		push_error("JsonDataLoader: expected a JSON object in %s" % path)
		return {}
	return parser.data


## Sorted list of the .json files directly inside a directory.
static func list_json_files(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("JsonDataLoader: cannot open data directory: %s" % directory)
		return paths
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			paths.append(directory.path_join(file_name))
	paths.sort()
	return paths
