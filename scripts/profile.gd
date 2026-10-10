class_name GameProfile
extends Node
## A small local ConfigFile; missing or damaged settings use safe defaults.

const SAVE_PATH: String = "user://profile.cfg"

var difficulty: int = 1
var sound_enabled: bool = true
var vibration_enabled: bool = true
var records: Array[int] = [0, 0, 0]
var storage_path: String = SAVE_PATH


func _ready() -> void:
	load_profile()


func load_profile(path: String = "") -> void:
	var config := ConfigFile.new()
	if config.load(storage_path if path.is_empty() else path) != OK:
		return
	difficulty = clampi(int(config.get_value("options", "difficulty", 1)), 0, 2)
	sound_enabled = bool(config.get_value("options", "sound", true))
	vibration_enabled = bool(config.get_value("options", "vibration", true))
	for index in range(3):
		records[index] = maxi(0, int(config.get_value("records", str(index), 0)))


func save_profile(path: String = "") -> Error:
	var config := ConfigFile.new()
	config.set_value("options", "difficulty", difficulty)
	config.set_value("options", "sound", sound_enabled)
	config.set_value("options", "vibration", vibration_enabled)
	for index in range(3):
		config.set_value("records", str(index), records[index])
	var result: Error = config.save(storage_path if path.is_empty() else path)
	if result != OK:
		push_warning("Could not save local settings: %s" % error_string(result))
	return result


func record_score(level: int, score_value: int) -> bool:
	if score_value <= records[level]:
		return false
	records[level] = score_value
	save_profile()
	return true
