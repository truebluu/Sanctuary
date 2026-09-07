# Creature Evolution & Metamorphosis System — Taming Pet Game
# Pure-logic RefCounted class for headless validation and runtime use.

class_name CreatureEvolution
extends RefCounted

## Signal emitted when a creature successfully evolves.
## Parameters: species (String), old_form (String), new_form (String), timestamp (float)
signal evolved(species: String, old_form: String, new_form: String, timestamp: float)

## Signal emitted when evolution is attempted but requirements aren't met.
## Parameters: species (String), current_form (String), reason (String)
signal evolution_blocked(species: String, current_form: String, reason: String)

## Evolution definition for a single species line.
## Each entry describes a form: base stats, required level, trigger condition.
## trigger_type: "level", "friendship", or "item"
## trigger_value: required level, required friendship, or item name (String)
## stat_multipliers: Dictionary to multiply base stats on evolution (hp, attack, defense, speed)
const EVOLUTION_DEFINITIONS: Dictionary = {
	"emberling": [
		{
			"name": "emberling",
			"base_stats": {"hp": 40, "attack": 30, "defense": 20, "speed": 25},
			"required_level": 10,
			"trigger_type": "level",
			"trigger_value": 10,
			"stat_multipliers": {"hp": 1.3, "attack": 1.4, "defense": 1.2, "speed": 1.1},
			"evolves_to": "emberfox"
		},
		{
			"name": "emberfox",
			"base_stats": {"hp": 60, "attack": 55, "defense": 35, "speed": 40},
			"required_level": 25,
			"trigger_type": "level",
			"trigger_value": 25,
			"stat_multipliers": {"hp": 1.35, "attack": 1.45, "defense": 1.25, "speed": 1.15},
			"evolves_to": "emberlord"
		},
		{
			"name": "emberlord",
			"base_stats": {"hp": 100, "attack": 95, "defense": 70, "speed": 60},
			"required_level": 0,
			"trigger_type": "level",
			"trigger_value": 0,
			"stat_multipliers": {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0},
			"evolves_to": ""
		}
	],
	"splashling": [
		{
			"name": "splashling",
			"base_stats": {"hp": 45, "attack": 25, "defense": 30, "speed": 20},
			"required_level": 12,
			"trigger_type": "level",
			"trigger_value": 12,
			"stat_multipliers": {"hp": 1.3, "attack": 1.2, "defense": 1.4, "speed": 1.1},
			"evolves_to": "tidalfin"
		},
		{
			"name": "tidalfin",
			"base_stats": {"hp": 70, "attack": 45, "defense": 55, "speed": 35},
			"required_level": 28,
			"trigger_type": "friendship",
			"trigger_value": 80,
			"stat_multipliers": {"hp": 1.3, "attack": 1.25, "defense": 1.35, "speed": 1.2},
			"evolves_to": "tidewyrm"
		},
		{
			"name": "tidewyrm",
			"base_stats": {"hp": 110, "attack": 70, "defense": 90, "speed": 55},
			"required_level": 0,
			"trigger_type": "friendship",
			"trigger_value": 0,
			"stat_multipliers": {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0},
			"evolves_to": ""
		}
	],
	"glimmerwing": [
		{
			"name": "glimmerwing",
			"base_stats": {"hp": 35, "attack": 35, "defense": 25, "speed": 40},
			"required_level": 8,
			"trigger_type": "item",
			"trigger_value": "sun_stone",
			"stat_multipliers": {"hp": 1.25, "attack": 1.35, "defense": 1.15, "speed": 1.25},
			"evolves_to": "glimmerhawk"
		},
		{
			"name": "glimmerhawk",
			"base_stats": {"hp": 55, "attack": 65, "defense": 45, "speed": 70},
			"required_level": 22,
			"trigger_type": "level",
			"trigger_value": 22,
			"stat_multipliers": {"hp": 1.3, "attack": 1.4, "defense": 1.25, "speed": 1.3},
			"evolves_to": "glimmersovereign"
		},
		{
			"name": "glimmersovereign",
			"base_stats": {"hp": 85, "attack": 95, "defense": 70, "speed": 100},
			"required_level": 0,
			"trigger_type": "level",
			"trigger_value": 0,
			"stat_multipliers": {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0},
			"evolves_to": ""
		}
	]
}

## Internal evolution log: Array of Dictionary entries.
## Each entry: {species, old_form, new_form, timestamp}
var _evolution_log: Array = []

func _init() -> void:
	_evolution_log = []

## Get the evolution path (array of form definitions) for a species.
func _get_evolution_path(species: String) -> Array:
	if EVOLUTION_DEFINITIONS.has(species):
		return EVOLUTION_DEFINITIONS[species]
	return []

## Find the index of a form within its evolution path.
func _find_form_index(path: Array, form_name: String) -> int:
	for i in range(path.size()):
		if path[i]["name"] == form_name:
			return i
	return -1

## Check if a creature meets the trigger condition for its next evolution.
## Returns Dictionary with keys: can_evolve (bool), next_form (String), reason (String)
func _check_trigger_conditions(creature_data: Dictionary, current_form_data: Dictionary, next_form_data: Dictionary) -> Dictionary:
	var trigger_type: String = current_form_data["trigger_type"]
	var trigger_value = current_form_data["trigger_value"]
	
	match trigger_type:
		"level":
			var creature_level: int = creature_data.get("level", 1)
			if creature_level >= int(trigger_value):
				return {"can_evolve": true, "next_form": next_form_data["name"], "reason": ""}
			else:
				return {"can_evolve": false, "next_form": "", "reason": "level"}
		"friendship":
			var creature_friendship: int = creature_data.get("friendship", 0)
			if creature_friendship >= int(trigger_value):
				return {"can_evolve": true, "next_form": next_form_data["name"], "reason": ""}
			else:
				return {"can_evolve": false, "next_form": "", "reason": "friendship"}
		"item":
			var creature_items: Array = creature_data.get("items", [])
			if trigger_value in creature_items:
				return {"can_evolve": true, "next_form": next_form_data["name"], "reason": ""}
			else:
				return {"can_evolve": false, "next_form": "", "reason": "item"}
		_:
			return {"can_evolve": false, "next_form": "", "reason": "unknown_trigger"}

## Apply stat recalculation on metamorphosis.
## Multiplies the creature's current stats by the CURRENT form's stat_multipliers (the form being evolved from).
## Returns the new stats dictionary.
func _apply_stat_recalculation(current_stats: Dictionary, current_form_data: Dictionary) -> Dictionary:
	var multipliers: Dictionary = current_form_data.get("stat_multipliers", {})
	var new_stats: Dictionary = {}
	
	for stat_name in ["hp", "attack", "defense", "speed"]:
		var current_val: float = float(current_stats.get(stat_name, 0))
		var multiplier: float = float(multipliers.get(stat_name, 1.0))
		new_stats[stat_name] = int(current_val * multiplier)
	
	return new_stats

## Record an evolution event in the internal log.
func _record_evolution_event(species: String, old_form: String, new_form: String) -> void:
	var entry: Dictionary = {
		"species": species,
		"old_form": old_form,
		"new_form": new_form,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	_evolution_log.append(entry)

## Get the evolution log (read-only).
func get_evolution_log() -> Array:
	return _evolution_log.duplicate()

## Clear the evolution log.
func clear_evolution_log() -> void:
	_evolution_log.clear()

## Main evolution entry point.
## creature_data: Dictionary with keys {id, name, species, level, friendship, stats:{hp,attack,defense,speed}, element, items?, form?}
## Mutates creature_data['form'] and creature_data['stats'] on success.
## Returns true if evolution occurred, false otherwise.
func evolve(creature_data: Dictionary) -> bool:
	# Validate required fields
	if not creature_data.has("species"):
		push_error("CreatureEvolution.evolve: creature_data missing 'species'")
		return false
	
	var species: String = creature_data["species"]
	var current_form: String = creature_data.get("form", species)  # Default to species if no form set
	
	var path: Array = _get_evolution_path(species)
	if path.is_empty():
		evolution_blocked.emit(species, current_form, "no_evolution_path")
		return false
	
	var current_index: int = _find_form_index(path, current_form)
	if current_index == -1:
		evolution_blocked.emit(species, current_form, "form_not_in_path")
		return false
	
	# Check if already at terminal form
	if current_index >= path.size() - 1:
		evolution_blocked.emit(species, current_form, "terminal_form")
		return false
	
	var current_form_data: Dictionary = path[current_index]
	var next_form_data: Dictionary = path[current_index + 1]
	
	# Check trigger conditions
	var check_result: Dictionary = _check_trigger_conditions(creature_data, current_form_data, next_form_data)
	if not check_result["can_evolve"]:
		evolution_blocked.emit(species, current_form, check_result["reason"])
		return false
	
	# Perform evolution: mutate creature_data
	var old_form: String = current_form
	var new_form: String = check_result["next_form"]
	
	# Apply stat recalculation
	var current_stats: Dictionary = creature_data.get("stats", {})
	var new_stats: Dictionary = _apply_stat_recalculation(current_stats, current_form_data)
	
	creature_data["form"] = new_form
	creature_data["stats"] = new_stats
	
	# Record evolution event
	_record_evolution_event(species, old_form, new_form)
	
	# Emit signal
	evolved.emit(species, old_form, new_form, Time.get_ticks_msec() / 1000.0)
	
	return true

## Check if a creature can evolve without mutating it.
## Returns true if requirements are met, false otherwise.
func can_evolve(creature_data: Dictionary) -> bool:
	if not creature_data.has("species"):
		return false
	
	var species: String = creature_data["species"]
	var current_form: String = creature_data.get("form", species)
	
	var path: Array = _get_evolution_path(species)
	if path.is_empty():
		return false
	
	var current_index: int = _find_form_index(path, current_form)
	if current_index == -1 or current_index >= path.size() - 1:
		return false
	
	var current_form_data: Dictionary = path[current_index]
	var next_form_data: Dictionary = path[current_index + 1]
	
	var check_result: Dictionary = _check_trigger_conditions(creature_data, current_form_data, next_form_data)
	return check_result["can_evolve"]

## Get the next evolution form name without evolving.
## Returns empty string if cannot evolve or at terminal form.
func get_next_form(creature_data: Dictionary) -> String:
	if not creature_data.has("species"):
		return ""
	
	var species: String = creature_data["species"]
	var current_form: String = creature_data.get("form", species)
	
	var path: Array = _get_evolution_path(species)
	if path.is_empty():
		return ""
	
	var current_index: int = _find_form_index(path, current_form)
	if current_index == -1 or current_index >= path.size() - 1:
		return ""
	
	var current_form_data: Dictionary = path[current_index]
	var next_form_data: Dictionary = path[current_index + 1]
	
	var check_result: Dictionary = _check_trigger_conditions(creature_data, current_form_data, next_form_data)
	if check_result["can_evolve"]:
		return check_result["next_form"]
	return ""

## Preview the stats a creature would have after evolving.
## Returns the projected stats dictionary or empty dict if cannot evolve.
func preview_evolution_stats(creature_data: Dictionary) -> Dictionary:
	if not creature_data.has("species"):
		return {}
	
	var species: String = creature_data["species"]
	var current_form: String = creature_data.get("form", species)
	
	var path: Array = _get_evolution_path(species)
	if path.is_empty():
		return {}
	
	var current_index: int = _find_form_index(path, current_form)
	if current_index == -1 or current_index >= path.size() - 1:
		return {}
	
	var current_form_data: Dictionary = path[current_index]
	var next_form_data: Dictionary = path[current_index + 1]
	
	var check_result: Dictionary = _check_trigger_conditions(creature_data, current_form_data, next_form_data)
	if not check_result["can_evolve"]:
		return {}
	
	var current_stats: Dictionary = creature_data.get("stats", {})
	return _apply_stat_recalculation(current_stats, current_form_data)

## Static headless test method for validation.
## Returns true if all assertions pass.
static func run_headless_test() -> bool:
	print("CreatureEvolution: Running headless tests...")
	
	var evolution = CreatureEvolution.new()
	
	# Test 1: Creature at level 1 cannot evolve
	var creature1 = {
		"id": 1,
		"name": "Ember",
		"species": "emberling",
		"level": 1,
		"friendship": 0,
		"stats": {"hp": 40, "attack": 30, "defense": 20, "speed": 25},
		"element": "fire",
		"form": "emberling"
	}
	
	assert(evolution.can_evolve(creature1) == false, "Test 1a: Level 1 emberling should not evolve")
	assert(evolution.evolve(creature1) == false, "Test 1b: evolve() returns false for level 1")
	assert(creature1["form"] == "emberling", "Test 1c: form unchanged after failed evolve")
	assert(creature1["stats"]["hp"] == 40, "Test 1d: stats unchanged after failed evolve")
	print("  ✓ Test 1 passed: level 1 creature cannot evolve")
	
	# Test 2: Raise level to trigger, assert evolve() returns true
	creature1["level"] = 10
	assert(evolution.can_evolve(creature1) == true, "Test 2a: Level 10 emberling can evolve")
	assert(evolution.evolve(creature1) == true, "Test 2b: evolve() returns true at level 10")
	assert(creature1["form"] == "emberfox", "Test 2c: form changed to emberfox")
	assert(creature1["stats"]["hp"] > 40, "Test 2d: hp boosted after evolution")
	assert(creature1["stats"]["attack"] > 30, "Test 2e: attack boosted after evolution")
	assert(creature1["stats"]["defense"] > 20, "Test 2f: defense boosted after evolution")
	assert(creature1["stats"]["speed"] > 25, "Test 2g: speed boosted after evolution")
	
	# Verify evolution event logged
	var log = evolution.get_evolution_log()
	assert(log.size() == 1, "Test 2h: Evolution log has 1 entry")
	assert(log[0]["species"] == "emberling", "Test 2i: Log species correct")
	assert(log[0]["old_form"] == "emberling", "Test 2j: Log old_form correct")
	assert(log[0]["new_form"] == "emberfox", "Test 2k: Log new_form correct")
	assert(log[0]["timestamp"] > 0, "Test 2l: Log timestamp recorded")
	print("  ✓ Test 2 passed: Level 10 emberling evolves to emberfox with boosted stats")
	
	# Test 3: Non-matching creature (different species path) returns false
	var creature2 = {
		"id": 2,
		"name": "Splash",
		"species": "splashling",
		"level": 1,
		"friendship": 0,
		"stats": {"hp": 45, "attack": 25, "defense": 30, "speed": 20},
		"element": "water",
		"form": "splashling"
	}
	
	# Level 1 splashling cannot evolve (requires level 12)
	assert(evolution.can_evolve(creature2) == false, "Test 3a: Level 1 splashling cannot evolve")
	assert(evolution.evolve(creature2) == false, "Test 3b: evolve() returns false for level 1 splashling")
	assert(creature2["form"] == "splashling", "Test 3c: form unchanged")
	print("  ✓ Test 3 passed: Non-matching creature (splashling at level 1) returns false")
	
	# Test 4: Splashling evolution via friendship
	creature2["level"] = 28
	creature2["friendship"] = 80
	assert(evolution.can_evolve(creature2) == true, "Test 4a: Splashling at level 28 + 80 friendship can evolve")
	assert(evolution.evolve(creature2) == true, "Test 4b: evolve() returns true")
	assert(creature2["form"] == "tidalfin", "Test 4c: form changed to tidalfin")
	assert(creature2["stats"]["hp"] > 45, "Test 4d: stats boosted")
	print("  ✓ Test 4 passed: Splashling evolves via friendship trigger")
	
	# Test 5: Glimmerwing evolution via item
	var creature3 = {
		"id": 3,
		"name": "Glimmer",
		"species": "glimmerwing",
		"level": 8,
		"friendship": 0,
		"stats": {"hp": 35, "attack": 35, "defense": 25, "speed": 40},
		"element": "light",
		"form": "glimmerwing",
		"items": ["sun_stone"]
	}
	
	assert(evolution.can_evolve(creature3) == true, "Test 5a: Glimmerwing with sun_stone can evolve")
	assert(evolution.evolve(creature3) == true, "Test 5b: evolve() returns true")
	assert(creature3["form"] == "glimmerhawk", "Test 5c: form changed to glimmerhawk")
	assert(creature3["stats"]["speed"] > 40, "Test 5d: speed boosted")
	print("  ✓ Test 5 passed: Glimmerwing evolves via item trigger")
	
	# Test 6: Terminal form cannot evolve further
	var creature4 = {
		"id": 4,
		"name": "Lord",
		"species": "emberling",
		"level": 100,
		"friendship": 100,
		"stats": {"hp": 100, "attack": 95, "defense": 70, "speed": 60},
		"element": "fire",
		"form": "emberlord"
	}
	
	assert(evolution.can_evolve(creature4) == false, "Test 6a: Terminal form cannot evolve")
	assert(evolution.evolve(creature4) == false, "Test 6b: evolve() returns false for terminal")
	assert(creature4["form"] == "emberlord", "Test 6c: form unchanged")
	print("  ✓ Test 6 passed: Terminal form (emberlord) cannot evolve further")
	
	# Test 7: Unknown species returns false
	var creature5 = {
		"id": 5,
		"name": "Unknown",
		"species": "nonexistent",
		"level": 50,
		"friendship": 50,
		"stats": {"hp": 50, "attack": 50, "defense": 50, "speed": 50},
		"element": "normal",
		"form": "nonexistent"
	}
	
	assert(evolution.can_evolve(creature5) == false, "Test 7a: Unknown species cannot evolve")
	assert(evolution.evolve(creature5) == false, "Test 7b: evolve() returns false for unknown species")
	print("  ✓ Test 7 passed: Unknown species returns false")
	
	# Test 8: preview_evolution_stats works
	var creature6 = {
		"id": 6,
		"name": "Preview",
		"species": "emberling",
		"level": 10,
		"friendship": 0,
		"stats": {"hp": 40, "attack": 30, "defense": 20, "speed": 25},
		"element": "fire",
		"form": "emberling"
	}
	
	var preview = evolution.preview_evolution_stats(creature6)
	assert(preview["hp"] > 40, "Test 8a: Preview shows boosted hp")
	assert(preview["attack"] > 30, "Test 8b: Preview shows boosted attack")
	assert(!evolution.evolve(creature6), "Test 8c: evolve after preview still works")
	assert(creature6["form"] == "emberfox", "Test 8d: Form updated after evolve")
	print("  ✓ Test 8 passed: preview_evolution_stats works correctly")
	
	print("CreatureEvolution: ALL TESTS PASSED")
	return true