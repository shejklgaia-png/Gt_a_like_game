extends RefCounted
## Versioned JSON with previous-good backup and atomic-ish write/rename.
const DATA_VERSION := 2

static func load_json(path: String) -> Dictionary:
	var current := _parse(path)
	if not current.is_empty():
		return current
	return _parse(path + ".bak")

static func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

static func save_json(path: String, payload: Dictionary) -> bool:
	var clean := payload.duplicate(true)
	clean["version"] = DATA_VERSION
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(clean, "\t"))
	f.flush()
	f.close()
	var full := ProjectSettings.globalize_path(path)
	var tmp_full := ProjectSettings.globalize_path(tmp)
	var bak := full + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(full, bak) != OK:
			return false
	if DirAccess.rename_absolute(tmp_full, full) != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(bak, full)
		return false
	return true
