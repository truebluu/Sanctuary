# Creature Codex — SANCT-1028
# RefCounted logbook class that stores discovered creature records.
# Pure logic for headless validation and runtime use.
class_name CreatureCodex
extends RefCounted

## Internal storage: creature_id -> record Dictionary
## Record keys: creature_id (String), display_name (String), species (String),
## discovered (bool), stats (Dictionary[String, float|int]), lore (String), evolution_hints (String)
var _creatures: Dictionary = {}

func _init() -> void:
	_creatures = {}

## Add a new creature entry to the codex.
## @param id Unique creature identifier
## @param name Display name for the creature
## @param species Species classification
func add_creature(id: String, name: String, species: String) -> void:
	if _creatures.has(id):
		return  # Already exists, don't overwrite
	_creatures[id] = {
		"creature_id": id,
		"display_name": name,
		"species": species,
		"discovered": false,
		"stats": {},
		"lore": "",
		"evolution_hints": ""
	}

## Mark a creature as discovered.
## @param id Creature identifier
func record_discovery(id: String) -> void:
	if _creatures.has(id):
		_creatures[id]["discovered"] = true

## Update stats dictionary for a creature (merges with existing stats).
## @param id Creature identifier
## @param stats Dictionary of stat_name -> value (float or int)
func update_stats(id: String, stats: Dictionary) -> void:
	if _creatures.has(id):
		var current_stats: Dictionary = _creatures[id]["stats"]
		for key in stats:
			current_stats[key] = stats[key]

## Set lore text for a creature.
## @param id Creature identifier
## @param lore Lore text string
func set_lore(id: String, lore: String) -> void:
	if _creatures.has(id):
		_creatures[id]["lore"] = lore

## Set evolution path hints for a creature.
## @param id Creature identifier
## @param hints Evolution hints text string
func set_evolution_hints(id: String, hints: String) -> void:
	if _creatures.has(id):
		_creatures[id]["evolution_hints"] = hints

## Get a creature record by ID.
## Returns empty Dictionary {} if not found.
## @param id Creature identifier
## @return Dictionary with creature data or empty dict
func get_creature(id: String) -> Dictionary:
	if _creatures.has(id):
		return _creatures[id].duplicate()
	return {}

## Check if a creature ID is known (exists in codex).
## @param id Creature identifier
## @return true if creature exists in codex
func is_known(id: String) -> bool:
	return _creatures.has(id)

## Check if a creature has been discovered.
## @param id Creature identifier
## @return true if discovered, false if unknown or not discovered
func is_discovered(id: String) -> bool:
	if _creatures.has(id):
		return _creatures[id]["discovered"]
	return false

## Get count of discovered creatures.
## @return Number of creatures with discovered == true
func discover_count() -> int:
	var count: int = 0
	for record in _creatures.values():
		if record["discovered"]:
			count += 1
	return count

## Get all creature IDs in the codex.
## @return Array of creature ID strings
func all_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _creatures.keys():
		result.append(id)
	return result

## Save codex to JSON file.
## @param path File path to save to
## @return true on success, false on failure
func save(path: String) -> bool:
	var data: Dictionary = {
		"version": 1,
		"creatures": _creatures
	}
	var json_string: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CreatureCodex.save: Failed to open file for writing: ", path)
		return false
	file.store_string(json_string)
	file.close()
	return true

## Load codex from JSON file.
## @param path File path to load from
## @return true on success, false on failure
func load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("CreatureCodex.load: File not found: ", path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CreatureCodex.load: Failed to open file for reading: ", path)
		return false
	var text: String = file.get_as_text()
	file.close()
	var parse_result: Variant = JSON.parse_string(text)
	if parse_result is Dictionary and parse_result.has("creatures"):
		_creatures = parse_result["creatures"]
		return true
	push_error("CreatureCodex.load: Invalid JSON structure in file: ", path)
	return false

## Static headless test method for validation.
## Returns true if all assertions pass.
static func run_headless_test() -> bool:
	print("CreatureCodex: Running headless tests...")

	var codex = CreatureCodex.new()

	# Test 1: add_creature and get_creature
	codex.add_creature("emberling", "Emberling", "Fire")
	var creature = codex.get_creature("emberling")
	assert(creature["creature_id"] == "emberling")
	assert(creature["display_name"] == "Emberling")
	assert(creature["species"] == "Fire")
	assert(creature["discovered"] == false)
	assert(creature["stats"].is_empty())
	assert(creature["lore"] == "")
	assert(creature["evolution_hints"] == "")
	print("  ✓ Test 1 passed: add_creature and get_creature work")

	# Test 2: record_discovery
	codex.record_discovery("emberling")
	assert(codex.is_discovered("emberling") == true)
	assert(codex.discover_count() == 1)
	print("  ✓ Test 2 passed: record_discovery marks discovered")

	# Test 3: update_stats
	codex.update_stats("emberling", {"hp": 40, "attack": 30, "defense": 20, "speed": 25})
	creature = codex.get_creature("emberling")
	assert(creature["stats"]["hp"] == 40)
	assert(creature["stats"]["attack"] == 30)
	assert(creature["stats"]["defense"] == 20)
	assert(creature["stats"]["speed"] == 25)
	print("  ✓ Test 3 passed: update_stats works")

	# Test 4: set_lore
	codex.set_lore("emberling", "A fledgling fire creature born from volcanic ash.")
	creature = codex.get_creature("emberling")
	assert(creature["lore"] == "A fledgling fire creature born from volcanic ash.")
	print("  ✓ Test 4 passed: set_lore works")

	# Test 5: set_evolution_hints
	codex.set_evolution_hints("emberling", "Evolves at level 10 to Emberfox")
	creature = codex.get_creature("emberling")
	assert(creature["evolution_hints"] == "Evolves at level 10 to Emberfox")
	print("  ✓ Test 5 passed: set_evolution_hints works")

	# Test 6: is_known and is_discovered
	assert(codex.is_known("emberling") == true)
	assert(codex.is_known("unknown") == false)
	assert(codex.is_discovered("emberling") == true)
	assert(codex.is_discovered("unknown") == false)
	print("  ✓ Test 6 passed: is_known and is_discovered work")

	# Test 7: discover_count with multiple creatures
	codex.add_creature("splashling", "Splashling", "Water")
	codex.add_creature("glimmerwing", "Glimmerwing", "Light")
	assert(codex.discover_count() == 1)
	codex.record_discovery("splashling")
	assert(codex.discover_count() == 2)
	print("  ✓ Test 7 passed: discover_count works with multiple creatures")

	# Test 8: all_ids
	var ids = codex.all_ids()
	assert(ids.size() == 3)
	assert(ids.has("emberling"))
	assert(ids.has("splashling"))
	assert(ids.has("glimmerwing"))
	print("  ✓ Test 8 passed: all_ids returns all creature IDs")

	# Test 9: get_creature unknown returns empty dict
	var unknown = codex.get_creature("nonexistent")
	assert(unknown.is_empty())
	print("  ✓ Test 9 passed: get_creature unknown returns {}")

	# Test 10: save/load round-trip
	var save_path = "user://test_codex_save.json"
	assert(codex.save(save_path) == true)
	
	var codex2 = CreatureCodex.new()
	assert(codex2.load(save_path) == true)
	
	# Verify loaded data matches original
	assert(codex2.is_known("emberling") == true)
	assert(codex2.is_known("splashling") == true)
	assert(codex2.is_known("glimmerwing") == true)
	assert(codex2.is_discovered("emberling") == true)
	assert(codex2.is_discovered("splashling") == true)
	assert(codex2.is_discovered("glimmerwing") == false)
	assert(codex2.discover_count() == 2)
	
	var loaded_emberling = codex2.get_creature("emberling")
	assert(loaded_emberling["display_name"] == "Emberling")
	assert(loaded_emberling["species"] == "Fire")
	assert(loaded_emberling["stats"]["hp"] == 40)
	assert(loaded_emberling["stats"]["attack"] == 30)
	assert(loaded_emberling["lore"] == "A fledgling fire creature born from volcanic ash.")
	assert(loaded_emberling["evolution_hints"] == "Evolves at level 10 to Emberfox")
	print("  ✓ Test 10 passed: save/load round-trip works correctly")

	# Clean up test file
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.WRITE)
		if file:
			file.close()
		DirAccess.remove_absolute(save_path)

	print("CreatureCodex: ALL TESTS PASSED")
	return true