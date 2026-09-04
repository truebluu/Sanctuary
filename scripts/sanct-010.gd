extends Node
## Creature Codex
## Catalogs discovered creatures with stats, lore, and evolution tree.
## Builds on the existing Creature, CreatureGenome, and GameState systems.
## Provides signals for UI updates and persistence via GameState.

signal creature_discovered(creature_id: String, data: Dictionary)
signal creature_updated(creature_id: String, data: Dictionary)
signal codex_cleared()

## Tunables (one-place changes)
const MAX_ENTRIES := 64  # Hard cap on catalogued creatures
const DEFAULT_LORE := "Unknown creature. Further observation required."
const DEFAULT_EVOLUTION_TREE := []  # Empty until discovered

## Internal storage: creature_id -> {name, species, stats, lore, evolution_tree, discovered_at}
var _entries: Dictionary = {}

## Reference to GameState for persistence (autoload)
var _game_state: Node = null

func _ready() -> void:
	_game_state = get_node("/root/GameState") if has_node("/root/GameState") else null
	if _game_state:
		_load_from_game_state()
	else:
		push_warning("CreatureCodex: GameState autoload not found; persistence disabled.")

## Register a creature encounter. If new, emits creature_discovered.
## If existing, updates stats/lore and emits creature_updated.
func register_creature(creature_id: String, data: Dictionary) -> void:
	if creature_id.is_empty():
		push_error("CreatureCodex: Cannot register creature with empty ID.")
		return
	if _entries.size() >= MAX_ENTRIES and not _entries.has(creature_id):
		push_warning("CreatureCodex: Max entries reached, ignoring new creature '%s'." % creature_id)
		return

	var existing: Dictionary = _entries.get(creature_id, {})
	var is_new := existing.is_empty()

	# Merge data with defaults
	var merged := {
		"name": data.get("name", creature_id),
		"species": data.get("species", "Unknown"),
		"stats": data.get("stats", {}),
		"lore": data.get("lore", DEFAULT_LORE),
		"evolution_tree": data.get("evolution_tree", DEFAULT_EVOLUTION_TREE),
		"discovered_at": existing.get("discovered_at", Time.get_unix_time_from_system())
	}
	# Preserve existing fields not overwritten
	for key in existing:
		if not merged.has(key):
			merged[key] = existing[key]

	_entries[creature_id] = merged
	_save_to_game_state()

	if is_new:
		creature_discovered.emit(creature_id, merged)
	else:
		creature_updated.emit(creature_id, merged)

## Update stats for an existing creature (e.g., after battle).
func update_stats(creature_id: String, stats: Dictionary) -> void:
	if not _entries.has(creature_id):
		push_warning("CreatureCodex: Cannot update stats for unknown creature '%s'." % creature_id)
		return
	var entry: Dictionary = _entries[creature_id]
	entry["stats"] = stats
	_entries[creature_id] = entry
	_save_to_game_state()
	creature_updated.emit(creature_id, entry)

## Add lore text to a creature (append or replace).
func set_lore(creature_id: String, lore: String) -> void:
	if not _entries.has(creature_id):
		push_warning("CreatureCodex: Cannot set lore for unknown creature '%s'." % creature_id)
		return
	var entry: Dictionary = _entries[creature_id]
	entry["lore"] = lore
	_entries[creature_id] = entry
	_save_to_game_state()
	creature_updated.emit(creature_id, entry)

## Mark an evolution as discovered for a creature.
func discover_evolution(creature_id: String, evolution_id: String) -> void:
	if not _entries.has(creature_id):
		push_warning("CreatureCodex: Cannot discover evolution for unknown creature '%s'." % creature_id)
		return
	var entry: Dictionary = _entries[creature_id]
	var tree: Array = entry.get("evolution_tree", [])
	if not tree.has(evolution_id):
		tree.append(evolution_id)
		entry["evolution_tree"] = tree
		_entries[creature_id] = entry
		_save_to_game_state()
		creature_updated.emit(creature_id, entry)

## Get full data for a creature. Returns empty Dictionary if not found.
func get_creature_data(creature_id: String) -> Dictionary:
	return _entries.get(creature_id, {})

## Get all discovered creature IDs.
func get_discovered_ids() -> Array:
	return _entries.keys()

## Get all entries as a Dictionary (for UI or save).
func get_all_entries() -> Dictionary:
	return _entries.duplicate(true)

## Clear all entries (e.g., new game+).
func clear_codex() -> void:
	_entries.clear()
	_save_to_game_state()
	codex_cleared.emit()

## Check if a creature has been discovered.
func is_discovered(creature_id: String) -> bool:
	return _entries.has(creature_id)

## Persistence via GameState (if available).
func _save_to_game_state() -> void:
	if _game_state and _game_state.has_method("set_codex_data"):
		_game_state.set_codex_data(_entries)

func _load_from_game_state() -> void:
	if _game_state and _game_state.has_method("get_codex_data"):
		var saved: Dictionary = _game_state.get_codex_data()
		if saved is Dictionary and not saved.is_empty():
			_entries = saved.duplicate(true)
			# Emit discovered for all loaded entries? UI can refresh on ready.
			for id in _entries:
				creature_discovered.emit(id, _entries[id])