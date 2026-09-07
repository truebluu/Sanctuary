# CreatureDietPreferences — Taming (The Sanctuary)
# SANCT-830: Per-species food preferences with nutrition values and feeding bonuses.
# Pure logic (RefCounted, headless-testable): maps species -> preferred foods,
# each with nutrition (int) and feeding bonus (float multiplier for bond/needs gain).
class_name CreatureDietPreferences
extends RefCounted

## Internal data structure: species -> Array of food entries.
## Each food entry: { "name": String, "nutrition": int, "bonus": float }
var _diet_data: Dictionary = {
	"emberling": [
		{ "name": "ember_berry", "nutrition": 25, "bonus": 1.5 },
		{ "name": "fire_moss", "nutrition": 18, "bonus": 1.3 },
		{ "name": "cinder_nut", "nutrition": 30, "bonus": 1.4 },
		{ "name": "ash_root", "nutrition": 15, "bonus": 1.1 },
	],
	"splashling": [
		{ "name": "aqua_kelp", "nutrition": 22, "bonus": 1.4 },
		{ "name": "pearl_shrimp", "nutrition": 28, "bonus": 1.5 },
		{ "name": "tide_algae", "nutrition": 16, "bonus": 1.2 },
		{ "name": "coral_cap", "nutrition": 20, "bonus": 1.3 },
	],
	"glimmerwing": [
		{ "name": "sun_nectar", "nutrition": 30, "bonus": 1.5 },
		{ "name": "wind_pollen", "nutrition": 18, "bonus": 1.3 },
		{ "name": "light_fruit", "nutrition": 25, "bonus": 1.4 },
		{ "name": "dawn_dew", "nutrition": 12, "bonus": 1.1 },
	],
	"thornsprout": [
		{ "name": "iron_root", "nutrition": 35, "bonus": 1.5 },
		{ "name": "stone_moss", "nutrition": 20, "bonus": 1.2 },
		{ "name": "crystal_fungus", "nutrition": 28, "bonus": 1.4 },
		{ "name": "deep_mud", "nutrition": 15, "bonus": 1.1 },
	],
}

## Returns an Array of preferred food names for the given species.
## Returns empty Array if species not found.
func get_preferred_foods(species: String) -> Array[String]:
	if not _diet_data.has(species):
		return []
	var foods: Array = _diet_data[species]
	var names: Array[String] = []
	for food in foods:
		names.append(food["name"])
	return names

## Returns the nutrition value (int) for a species/food pair.
## Returns 0 if the food is not a preferred food for that species.
func get_nutrition(species: String, food: String) -> int:
	if not _diet_data.has(species):
		return 0
	var foods: Array = _diet_data[species]
	for entry in foods:
		if entry["name"] == food:
			return int(entry["nutrition"])
	return 0

## Returns the feeding bonus multiplier (float) for a species/food pair.
## Returns 1.0 (no bonus) if the food is not preferred for that species.
func get_feeding_bonus(species: String, food: String) -> float:
	if not _diet_data.has(species):
		return 1.0
	var foods: Array = _diet_data[species]
	for entry in foods:
		if entry["name"] == food:
			return float(entry["bonus"])
	return 1.0

## Returns true if the given food is a preferred food for the species.
func is_preferred(species: String, food: String) -> bool:
	if not _diet_data.has(species):
		return false
	var foods: Array = _diet_data[species]
	for entry in foods:
		if entry["name"] == food:
			return true
	return false

## Internal test helper: checks a condition and increments success/failure counters.
func _check(condition: bool, msg: String) -> void:
	if condition:
		_test_passed += 1
		print("[OK] %s" % msg)
	else:
		_test_failed += 1
		printerr("[FAIL] %s" % msg)

var _test_passed: int = 0
var _test_failed: int = 0

## Run headless unit tests. Asserts known species/food lookups return expected values.
## Returns true if all assertions succeed, false otherwise.
func run_headless_test() -> bool:
	_test_passed = 0
	_test_failed = 0

	# --- Species existence ---
	_check(has_species("emberling"), "Species 'emberling' exists")
	_check(has_species("splashling"), "Species 'splashling' exists")
	_check(has_species("glimmerwing"), "Species 'glimmerwing' exists")
	_check(has_species("thornsprout"), "Species 'thornsprout' exists")
	_check(not has_species("unknown"), "Species 'unknown' does not exist")

	# --- get_preferred_foods ---
	_check(get_preferred_foods("emberling").size() == 4, "emberling has 4 preferred foods")
	_check(get_preferred_foods("splashling").size() == 4, "splashling has 4 preferred foods")
	_check(get_preferred_foods("glimmerwing").size() == 4, "glimmerwing has 4 preferred foods")
	_check(get_preferred_foods("thornsprout").size() == 4, "thornsprout has 4 preferred foods")
	_check(get_preferred_foods("unknown").is_empty(), "Unknown species returns empty array")

	# --- is_preferred ---
	_check(is_preferred("emberling", "ember_berry"), "ember_berry is preferred for emberling")
	_check(is_preferred("emberling", "fire_moss"), "fire_moss is preferred for emberling")
	_check(is_preferred("splashling", "pearl_shrimp"), "pearl_shrimp is preferred for splashling")
	_check(is_preferred("glimmerwing", "sun_nectar"), "sun_nectar is preferred for glimmerwing")
	_check(is_preferred("thornsprout", "iron_root"), "iron_root is preferred for thornsprout")
	_check(not is_preferred("emberling", "aqua_kelp"), "aqua_kelp is NOT preferred for emberling")
	_check(not is_preferred("splashling", "ember_berry"), "ember_berry is NOT preferred for splashling")
	_check(not is_preferred("unknown", "anything"), "Unknown species has no preferred foods")

	# --- get_nutrition ---
	_check(get_nutrition("emberling", "ember_berry") == 25, "ember_berry nutrition = 25")
	_check(get_nutrition("emberling", "fire_moss") == 18, "fire_moss nutrition = 18")
	_check(get_nutrition("emberling", "cinder_nut") == 30, "cinder_nut nutrition = 30")
	_check(get_nutrition("emberling", "ash_root") == 15, "ash_root nutrition = 15")
	_check(get_nutrition("splashling", "pearl_shrimp") == 28, "pearl_shrimp nutrition = 28")
	_check(get_nutrition("glimmerwing", "sun_nectar") == 30, "sun_nectar nutrition = 30")
	_check(get_nutrition("thornsprout", "iron_root") == 35, "iron_root nutrition = 35")
	_check(get_nutrition("emberling", "unknown_food") == 0, "Non-preferred food returns 0 nutrition")
	_check(get_nutrition("unknown", "anything") == 0, "Unknown species returns 0 nutrition")

	# --- get_feeding_bonus ---
	_check(abs(get_feeding_bonus("emberling", "ember_berry") - 1.5) < 0.001, "ember_berry bonus = 1.5")
	_check(abs(get_feeding_bonus("emberling", "fire_moss") - 1.3) < 0.001, "fire_moss bonus = 1.3")
	_check(abs(get_feeding_bonus("emberling", "cinder_nut") - 1.4) < 0.001, "cinder_nut bonus = 1.4")
	_check(abs(get_feeding_bonus("emberling", "ash_root") - 1.1) < 0.001, "ash_root bonus = 1.1")
	_check(abs(get_feeding_bonus("splashling", "pearl_shrimp") - 1.5) < 0.001, "pearl_shrimp bonus = 1.5")
	_check(abs(get_feeding_bonus("glimmerwing", "sun_nectar") - 1.5) < 0.001, "sun_nectar bonus = 1.5")
	_check(abs(get_feeding_bonus("thornsprout", "iron_root") - 1.5) < 0.001, "iron_root bonus = 1.5")
	_check(abs(get_feeding_bonus("emberling", "unknown_food") - 1.0) < 0.001, "Non-preferred food returns 1.0 bonus")
	_check(abs(get_feeding_bonus("unknown", "anything") - 1.0) < 0.001, "Unknown species returns 1.0 bonus")

	# --- Cross-species distinctness ---
	_check(get_nutrition("emberling", "ember_berry") != get_nutrition("splashling", "aqua_kelp"), "Different species have different nutrition values")
	_check(get_feeding_bonus("emberling", "ember_berry") != get_feeding_bonus("thornsprout", "stone_moss"), "Different species have different bonus values")

	print("CreatureDietPreferences: %d passed, %d failed" % [_test_passed, _test_failed])
	return _test_failed == 0

func has_species(species: String) -> bool:
	return _diet_data.has(species)

## Godot lifecycle: run headless tests automatically when in headless mode.
func _ready() -> void:
	if OS.has_feature("headless"):
		var ok: bool = run_headless_test()
		# Note: RefCounted cannot call get_tree().quit(). Test result is returned.
		# The caller should check the return value and exit accordingly.