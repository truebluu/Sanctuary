# CreatureSaveLoad — Bluu Ink Sanctuary (taming/pet-evolution)
# Resource-based save/load for creature state (species, evolution stage, needs,
# photos). Serializes each creature to a JSON file under user://creatures/ and
# integrates with the GlobalSaveManager-style API. Handles missing files,
# corrupt data, and version mismatches gracefully.
extends RefCounted
class_name CreatureSaveLoad

## Directory (under user://) where per-creature save files are stored.
const SAVE_DIR := "user://creatures"
## Current schema version. Bumped when the serialized format changes.
const SAVE_VERSION := 1

## Emitted after a successful save (creature_id, path).
signal creature_saved(creature_id: int, path: String)
## Emitted after a successful load (creature_id, data).
signal creature_loaded(creature_id: int, data: Dictionary)
## Emitted when a save/load operation fails (creature_id, error_message).
signal operation_failed(creature_id: int, error_message: String)

## Build the full path for a creature's save file.
static func _path_for(creature_id: int) -> String:
	return "%s/creature_%d.json" % [SAVE_DIR, creature_id]

## Ensure the save directory exists. Returns true on success.
static func _ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return true
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	return err == OK

## Serialize a creature's state into a plain Dictionary for persistence.
## @param species  StringName species identifier
## @param evolution_stage  int current evolution stage index
## @param needs  Dictionary of need-name -> value (e.g. {"hunger": 0.8})
## @param photos  Array of photo resource paths (String)
## @param extra  optional Dictionary of additional fields to persist
## @return Dictionary ready for JSON.stringify
static func build_save_data(
	species: StringName,
	evolution_stage: int,
	needs: Dictionary,
	photos: Array = [],
	extra: Dictionary = {}
) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"species": String(species),
		"evolution_stage": evolution_stage,
		"needs": needs,
		"photos": photos,
		"extra": extra,
		"saved_at": Time.get_unix_time_from_system(),
	}

## Save a creature's state to disk.
## @param creature_id  unique id for the creature
## @param data  Dictionary produced by build_save_data (or equivalent)
## @return bool true if the save succeeded
func save_creature(creature_id: int, data: Dictionary) -> bool:
	if not _ensure_dir():
		operation_failed.emit(creature_id, "Could not create save directory")
		return false

	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at"] = Time.get_unix_time_from_system()

	var json_string := JSON.stringify(payload, "\t")
	var path := _path_for(creature_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		operation_failed.emit(creature_id, "Failed to open save file for writing")
		return false

	var err: bool = file.store_string(json_string)
	file.close()
	if not err:
		operation_failed.emit(creature_id, "Failed to write save data")
		return false

	creature_saved.emit(creature_id, path)
	return true

## Load a creature's state from disk.
## @param creature_id  unique id for the creature
## @return Dictionary of the creature's state, or {} if missing/corrupt
func load_creature(creature_id: int) -> Dictionary:
	var path := _path_for(creature_id)
	if not FileAccess.file_exists(path):
		operation_failed.emit(creature_id, "Save file not found")
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		operation_failed.emit(creature_id, "Failed to open save file for reading")
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		operation_failed.emit(creature_id, "Save file is corrupt (not valid JSON object)")
		return {}

	var version: int = int(parsed.get("version", 0))
	if version != SAVE_VERSION:
		operation_failed.emit(creature_id, "Save version mismatch (expected %d, got %d)" % [SAVE_VERSION, version])
		return {}

	creature_loaded.emit(creature_id, parsed)
	return parsed

## Delete a creature's save file. Returns true if removed (or already absent).
func delete_creature(creature_id: int) -> bool:
	var path := _path_for(creature_id)
	if not FileAccess.file_exists(path):
		return true
	var err := DirAccess.remove_absolute(path)
	return err == OK

## List all saved creature ids (from filenames in the save dir).
static func list_saved_creature_ids() -> Array[int]:
	var ids: Array[int] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return ids
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return ids
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with("creature_") and fname.ends_with(".json"):
			var id_str := fname.trim_prefix("creature_").trim_suffix(".json")
			if id_str.is_valid_int():
				ids.append(int(id_str))
		fname = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids
