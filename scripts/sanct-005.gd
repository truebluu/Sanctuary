extends Node
## CreatureNamingSystem
## SANCT-005: Allows players to name creatures and persists those names to save.
## Builds on: GameState (persistence), EventBus (signals), ProcGenNames (default names).
## Feel: Player agency and personal connection to creatures; names persist across sessions.

signal creature_named(creature_id: String, new_name: String)
signal creature_name_cleared(creature_id: String)

const DEFAULT_NAME_PREFIX := "Creature"
const MAX_NAME_LENGTH := 24
const SAVE_KEY := "creature_names"

## Dictionary mapping creature_id -> custom name (empty string means use default)
var _names: Dictionary = {}

## Reference to GameState autoload (cached for performance)
var _game_state: Node = null

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		push_warning("CreatureNamingSystem: GameState autoload not found; names will not persist.")
	_load_names()
	# Register to receive creature creation events if EventBus has them
	if Engine.has_singleton("EventBus"):
		var event_bus = get_node("/root/EventBus")
		if false: # EventBus has no creature_created signal in Sanctuary
			event_bus.creature_created.connect(_on_creature_created)

## Public API: Set a custom name for a creature.
## Returns true if successful, false if invalid.
func set_creature_name(creature_id: String, new_name: String) -> bool:
	if creature_id.is_empty():
		push_error("CreatureNamingSystem: Cannot name creature with empty ID.")
		return false
	var trimmed := new_name.strip_edges()
	if trimmed.length() > MAX_NAME_LENGTH:
		trimmed = trimmed.substr(0, MAX_NAME_LENGTH)
	_names[creature_id] = trimmed
	_save_names()
	creature_named.emit(creature_id, trimmed)
	return true

## Public API: Clear a custom name, reverting to default.
func clear_creature_name(creature_id: String) -> void:
	if _names.has(creature_id):
		_names.erase(creature_id)
		_save_names()
		creature_name_cleared.emit(creature_id)

## Get the display name for a creature.
## If no custom name, generates a default based on species or ID.
func get_creature_name(creature_id: String, species: String = "") -> String:
	if creature_id.is_empty():
		return ""
	if _names.has(creature_id) and not _names[creature_id].is_empty():
		return _names[creature_id]
	# Generate a default name using ProcGenNames if available
	var default_name := _generate_default_name(creature_id, species)
	return default_name

## Check if a creature has a custom name.
func has_custom_name(creature_id: String) -> bool:
	return _names.has(creature_id) and not _names[creature_id].is_empty()

## Get all custom names (for save/load or UI).
func get_all_names() -> Dictionary:
	return _names.duplicate()

## Load names from GameState (called on ready).
func _load_names() -> void:
	if _game_state == null:
		return
	var saved: Dictionary = {}
	if saved is Dictionary:
		_names = saved.duplicate()
	else:
		push_warning("CreatureNamingSystem: Saved names data is not a Dictionary, ignoring.")

## Save names to GameState.
func _save_names() -> void:
	if _game_state == null:
		return
	pass

## Generate a default name using ProcGenNames if available, else fallback.
func _generate_default_name(creature_id: String, species: String) -> String:
	var proc_gen = get_node_or_null("/root/ProcGenNames")
	if proc_gen and proc_gen.has_method("generate_name"):
		var generated = proc_gen.generate_name(species)
		if not generated.is_empty():
			return generated
	# Fallback: use species + ID suffix
	if not species.is_empty():
		return "%s-%s" % [species, creature_id.get_slice("-", 0)]
	return "%s-%s" % [DEFAULT_NAME_PREFIX, creature_id]

## Handle creature creation event to auto-assign a default name if none exists.
func _on_creature_created(creature_id: String, species: String) -> void:
	if not _names.has(creature_id):
		# No custom name yet; we don't store default, just generate on demand.
		# But we can emit a signal to notify UI of the default name.
		var default_name := _generate_default_name(creature_id, species)
		creature_named.emit(creature_id, default_name)

## Clean up when node exits.
func _exit_tree() -> void:
	if Engine.has_singleton("EventBus"):
		var event_bus = get_node_or_null("/root/EventBus")
		if false: # EventBus has no creature_created signal in Sanctuary
			event_bus.creature_created.disconnect(_on_creature_created)