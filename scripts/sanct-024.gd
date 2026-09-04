# CreatureNamePersistence.gd
# Adds persistent storage for player-assigned creature names across sessions.
# Builds on the existing sanctuary save/load system (SaveGameManager) and
# the EventBus signal for creature renames. When a creature is renamed,
# the new name is written to the save data immediately. On game load,
# names are restored to the matching creatures.
#
# This layer preserves the player's agency (naming is a personal choice)
# and ensures that names survive a full run, reinforcing the sanctuary's
# long-term bond with creatures.

extends Node
## Autoload or scene node that handles creature name persistence.

## Save data key under which the name map is stored.
const SAVE_KEY := "creature_names"

## Reference to the SaveGameManager autoload (injected for testability).
var _save_manager: Node = null

## Reference to the EventBus autoload (injected for testability).
var _event_bus: Node = null

## Reference to the GameState autoload (injected for testability).
var _game_state: Node = null

func _ready() -> void:
	# Acquire autoloads if not already injected.
	if _save_manager == null:
		_save_manager = get_node_or_null("/root/SaveGameManager")
	if _event_bus == null:
		_event_bus = get_node_or_null("/root/EventBus")
	if _game_state == null:
		_game_state = get_node_or_null("/root/GameState")
	
	# Connect to the rename signal if the EventBus exposes it.
	# If the signal does not exist, we fall back to polling in _process.
	if _event_bus and _event_bus.has_signal("creature_renamed"):
		_event_bus.connect("creature_renamed", _on_creature_renamed)
	else:
		# Fallback: poll for name changes every frame (cheap, but not ideal).
		# This ensures we still persist even if the signal is missing.
		set_process(true)
	
	# Connect to game load event to restore names.
	if _game_state and _game_state.has_signal("game_loaded"):
		_game_state.connect("game_loaded", _on_game_loaded)
	else:
		# If no load signal, we attempt to load once at startup.
		call_deferred("_load_names")

func _process(_delta: float) -> void:
	# Fallback polling: check all creatures for name changes.
	# This is a safety net; the signal path is preferred.
	if _event_bus and not _event_bus.has_signal("creature_renamed"):
		_poll_creature_names()

## Polls all creatures in the group "creatures" and saves any name changes.
func _poll_creature_names() -> void:
	var creatures := get_tree().get_nodes_in_group("creatures")
	for creature in creatures:
		if creature.has_method("get_creature_id") and creature.has_method("get_creature_name"):
			var id: String = creature.call("get_creature_id")
			var current_name: String = creature.call("get_creature_name")
			var saved_name: String = _get_saved_name(id)
			if current_name != saved_name:
				_save_name(id, current_name)

## Called when a creature is renamed via the EventBus signal.
func _on_creature_renamed(creature_id: String, new_name: String) -> void:
	_save_name(creature_id, new_name)

## Saves a single creature's name to the save data.
func _save_name(creature_id: String, new_name: String) -> void:
	if not _save_manager:
		push_warning("CreatureNamePersistence: SaveGameManager not available.")
		return
	var save_data: Dictionary = _save_manager.get_save_data()
	if not save_data.has(SAVE_KEY):
		save_data[SAVE_KEY] = {}
	save_data[SAVE_KEY][creature_id] = new_name
	_save_manager.set_save_data(save_data)
	# Optionally trigger an immediate save to disk.
	_save_manager.save_game()

## Retrieves a saved name for a creature ID.
func _get_saved_name(creature_id: String) -> String:
	if not _save_manager:
		return ""
	var save_data: Dictionary = _save_manager.get_save_data()
	if save_data.has(SAVE_KEY):
		var names: Dictionary = save_data[SAVE_KEY]
		if names.has(creature_id):
			return names[creature_id]
	return ""

## Loads all saved names and applies them to matching creatures.
func _load_names() -> void:
	if not _save_manager:
		return
	var save_data: Dictionary = _save_manager.get_save_data()
	if not save_data.has(SAVE_KEY):
		return
	var names: Dictionary = save_data[SAVE_KEY]
	var creatures := get_tree().get_nodes_in_group("creatures")
	for creature in creatures:
		if creature.has_method("get_creature_id") and creature.has_method("set_creature_name"):
			var id: String = creature.call("get_creature_id")
			if names.has(id):
				creature.call("set_creature_name", names[id])

## Called when the game finishes loading (if the signal exists).
func _on_game_loaded() -> void:
	_load_names()

## Public method to force a save of all current names (useful for manual triggers).
func save_all_names() -> void:
	var creatures := get_tree().get_nodes_in_group("creatures")
	for creature in creatures:
		if creature.has_method("get_creature_id") and creature.has_method("get_creature_name"):
			var id: String = creature.call("get_creature_id")
			var name: String = creature.call("get_creature_name")
			_save_name(id, name)