# sanctuary_save_load.gd
# Persists sanctuary state (creatures, decorations, progress) to disk.
# Builds on SaveGameManager and CreatureSaveLoad. Emits signals via EventBus.
# This is a new class; no existing symbol covers sanctuary persistence.

class_name SanctuarySaveLoad
extends RefCounted

# --- Tunability: save file naming and versioning ---
const SAVE_SLOT_PREFIX := "sanctuary_slot_"
const SAVE_VERSION := 1
const SAVE_EXTENSION := ".save"

# --- Signals (forwarded through EventBus for decoupled updates) ---
signal sanctuary_saved(slot: int, success: bool)
signal sanctuary_loaded(slot: int, success: bool, data: Dictionary)

# --- Static utility: build the full save path for a slot ---
static func _save_path(slot: int) -> String:
	return SaveGameManager.get_save_dir() + SAVE_SLOT_PREFIX + str(slot) + SAVE_EXTENSION

# --- Save the current sanctuary state to disk ---
static func save_sanctuary(slot: int) -> bool:
	var data := _collect_sanctuary_data()
	var path := _save_path(slot)
	var success := SaveGameManager.save_to_file(data, path)
	if success:
		EventBus.emit_signal("sanctuary_saved", slot, true)
	else:
		EventBus.emit_signal("sanctuary_saved", slot, false)
	return success

# --- Load sanctuary state from disk and apply it ---
static func load_sanctuary(slot: int) -> bool:
	var path := _save_path(slot)
	if not FileAccess.file_exists(path):
		EventBus.emit_signal("sanctuary_loaded", slot, false, {})
		return false
	var data: Dictionary = SaveGameManager.load_from_file(path)
	if data.is_empty() or data.get("version", 0) != SAVE_VERSION:
		push_warning("Sanctuary save slot %d is missing or incompatible." % slot)
		EventBus.emit_signal("sanctuary_loaded", slot, false, {})
		return false
	_apply_sanctuary_data(data)
	EventBus.emit_signal("sanctuary_loaded", slot, true, data)
	return true

# --- Collect all sanctuary state into a serializable dictionary ---
static func _collect_sanctuary_data() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"creatures": _collect_creatures(),
		"decorations": _collect_decorations(),
		"progress": _collect_progress()
	}
	return data

# --- Apply loaded data back into the sanctuary scene ---
static func _apply_sanctuary_data(data: Dictionary) -> void:
	_apply_creatures(data.get("creatures", []))
	_apply_decorations(data.get("decorations", []))
	_apply_progress(data.get("progress", {}))

# --- Creature serialization (delegates to CreatureSaveLoad) ---
static func _collect_creatures() -> Array:
	var creatures := []
	var sanctuary := _get_sanctuary_controller()
	if sanctuary == null:
		return creatures
	for creature in sanctuary.get_creatures():
		var serialized = CreatureSaveLoad.serialize_creature(creature)
		if not serialized.is_empty():
			creatures.append(serialized)
	return creatures

static func _apply_creatures(creature_data: Array) -> void:
	var sanctuary := _get_sanctuary_controller()
	if sanctuary == null:
		return
	sanctuary.clear_creatures()
	for data in creature_data:
		var creature = CreatureSaveLoad.deserialize_creature(data)
		if creature != null:
			sanctuary.add_creature(creature)

# --- Decoration serialization (positions, type, etc.) ---
static func _collect_decorations() -> Array:
	var decorations := []
	var sanctuary := _get_sanctuary_controller()
	if sanctuary == null:
		return decorations
	for decoration in sanctuary.get_decorations():
		decorations.append({
			"type": decoration.type,
			"position": decoration.position,
			"rotation": decoration.rotation,
			"scale": decoration.scale
		})
	return decorations

static func _apply_decorations(decoration_data: Array) -> void:
	var sanctuary := _get_sanctuary_controller()
	if sanctuary == null:
		return
	sanctuary.clear_decorations()
	for data in decoration_data:
		sanctuary.spawn_decor(data.get("type", ""), data.get("position", Vector2.ZERO), data.get("rotation", 0.0), data.get("scale", Vector2.ONE))

# --- Progress flags (unlocked areas, milestones, etc.) ---
static func _collect_progress() -> Dictionary:
	var sanctuary := _get_sanctuary_controller()
	if sanctuary == null:
		return {}
	return sanctuary.get_progress_flags()

static func _apply_progress(progress: Dictionary) -> void:
	var sanctuary := _get_sanctuary_controller()
	if sanctuary == null:
		return
	sanctuary.set_progress_flags(progress)

# --- Helper: locate the sanctuary controller in the scene tree ---
static func _get_sanctuary_controller() -> Node:
	# Assumes the sanctuary controller is a unique node in the main scene.
	# If not found, we log a warning and return null.
	var controller = get_tree().get_first_node_in_group("sanctuary_controller")
	if controller == null:
		push_warning("SanctuarySaveLoad: No node in group 'sanctuary_controller' found.")
	return controller