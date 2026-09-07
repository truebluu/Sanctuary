# EvolutionController — Bluu Ink Sanctuary (SANCTUARY-014)
# Multi-stage evolution controller driven by training milestones and trait thresholds.
# Wires into TrainingManager, CreatureCodex, and EvolutionTree for a complete evolution pipeline.
extends Node
class_name EvolutionController

## Lightweight creature data holder used by the evolution system and its tests.
## A plain Object cannot hold arbitrary properties, so evolution data lives here.
class CreatureData:
	extends RefCounted
	var current_stage: String = ""
	var species: String = ""
	var training_level: int = 0
	var traits: Dictionary = {}
	var evolution_path_key: String = ""

	func _init(p_stage: String = "", p_level: int = 0, p_traits: Dictionary = {}) -> void:
		current_stage = p_stage
		species = p_stage
		training_level = p_level
		traits = p_traits.duplicate()
		evolution_path_key = ""

## Emitted when a creature successfully evolves from one stage to the next.
## Parameters: creature (Object with creature data), from_stage (String), to_stage (String)
signal creature_evolved(creature: Object, from_stage: String, to_stage: String)

## Emitted when evolution is blocked because requirements aren't met.
## Parameters: creature (Object), current_stage (String), reason (String)
signal evolution_blocked(creature: Object, current_stage: String, reason: String)

## Emitted when a creature's training/traits change and they become eligible for evolution.
signal evolution_ready(creature: Object, next_stage: String)

# Evolution thresholds configuration — exported for inspector tuning.
# Each path key maps to an array of stages. Stage 0 is the base form.
# Each stage defines: name, required_training_level, required_traits (Dictionary trait->score), evolves_to (next form name).
@export var EVOLUTION_THRESHOLDS: Dictionary = {
	"emberling": [
		{
			"name": "emberling",
			"required_training_level": 10,
			"required_traits": {"fire_affinity": 20, "courage": 15},
			"evolves_to": "emberfox"
		},
		{
			"name": "emberfox",
			"required_training_level": 25,
			"required_traits": {"fire_affinity": 50, "courage": 40, "wisdom": 20},
			"evolves_to": "emberlord"
		},
		{
			"name": "emberlord",
			"required_training_level": 0,
			"required_traits": {},
			"evolves_to": ""
		}
	],
	"splashling": [
		{
			"name": "splashling",
			"required_training_level": 12,
			"required_traits": {"water_affinity": 25, "patience": 15},
			"evolves_to": "tidalfin"
		},
		{
			"name": "tidalfin",
			"required_training_level": 28,
			"required_traits": {"water_affinity": 55, "patience": 45, "intuition": 25},
			"evolves_to": "tidewyrm"
		},
		{
			"name": "tidewyrm",
			"required_training_level": 0,
			"required_traits": {},
			"evolves_to": ""
		}
	],
	"glimmerwing": [
		{
			"name": "glimmerwing",
			"required_training_level": 8,
			"required_traits": {"light_affinity": 15, "curiosity": 10},
			"evolves_to": "glimmerhawk"
		},
		{
			"name": "glimmerhawk",
			"required_training_level": 22,
			"required_traits": {"light_affinity": 45, "curiosity": 40, "focus": 20},
			"evolves_to": "glimmersovereign"
		},
		{
			"name": "glimmersovereign",
			"required_training_level": 0,
			"required_traits": {},
			"evolves_to": ""
		}
	]
}

# Optional: reference to EvolutionTree for cross-referencing species paths.
# Note: Custom class references cannot be @export in Godot 4; assign via inspector or code.
var _evolution_tree: EvolutionTree

# Test-only signal capture (member vars so lambdas can mutate them).
var _test_signal_fired: bool = false
var _test_signal_from: String = ""
var _test_signal_to: String = ""

# Optional: reference to CreatureCodex for unlock notifications.
var _creature_codex: CreatureCodex

# Internal cache of connected signals for clean disconnection.
var _connected_signals: Array = []

func _init() -> void:
	# Ensure EvolutionTree is available for cross-referencing.
	if _evolution_tree == null:
		_evolution_tree = EvolutionTree.new()

func _ready() -> void:
	_wire_signals()

func _exit_tree() -> void:
	_unwire_signals()

func _wire_signals() -> void:
	"""Connect to TrainingManager and CreatureCodex signals if they exist in the scene tree."""
	var tree = get_tree()
	if tree == null:
		return

	# TrainingManager signal: training_completed(creature_id, training_type, level_gained, trait_gains)
	var training_mgr = tree.get_first_node_in_group("training_manager")
	if training_mgr != null and training_mgr.has_signal("training_completed"):
		training_mgr.training_completed.connect(_on_training_completed.bind())
		_connected_signals.append(["training_completed", training_mgr])

	# TrainingManager signal: milestone_reached(creature_id, milestone_name, new_level)
	if training_mgr != null and training_mgr.has_signal("milestone_reached"):
		training_mgr.milestone_reached.connect(_on_milestone_reached.bind())
		_connected_signals.append(["milestone_reached", training_mgr])

	# CreatureCodex signal: creature_selected(creature_id) — for UI-driven evolution checks
	if _creature_codex != null and _creature_codex.has_signal("creature_selected"):
		_creature_codex.creature_selected.connect(_on_codex_creature_selected.bind())
		_connected_signals.append(["creature_selected", _creature_codex])

	# CreatureCodex signal: evolution_ready(creature_id, next_species) — forward from codex
	if _creature_codex != null and _creature_codex.has_signal("evolution_ready"):
		_creature_codex.evolution_ready.connect(_on_codex_evolution_ready.bind())
		_connected_signals.append(["evolution_ready", _creature_codex])

func _unwire_signals() -> void:
	"""Disconnect all wired signals to prevent double-firing on scene reload."""
	for entry in _connected_signals:
		var signal_name: String = entry[0]
		var source: Object = entry[1]
		if is_instance_valid(source) and source.has_signal(signal_name):
			source.call_deferred("disconnect", signal_name, self, signal_name.to_snake_case().replace("_", "_"))
	_connected_signals.clear()

# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------

func _on_training_completed(creature_id: StringName, training_type: String, level_gained: int, trait_gains: Dictionary) -> void:
	"""React to training completion — check if creature can now evolve."""
	var creature = _get_creature_data(creature_id)
	if creature == null:
		return

	var current_stage = creature.get("current_stage") if _object_has_property(creature, "current_stage") else ""
	var can_evo = can_evolve(creature, current_stage)
	if can_evo:
		var next_stage = get_next_stage(creature)
		if next_stage != "":
			evolution_ready.emit(creature, next_stage)

func _on_milestone_reached(creature_id: StringName, milestone_name: String, new_level: int) -> void:
	"""React to training milestones — immediate evolution eligibility check."""
	var creature = _get_creature_data(creature_id)
	if creature == null:
		return

	var current_stage = creature.get("current_stage") if _object_has_property(creature, "current_stage") else ""
	var can_evo = can_evolve(creature, current_stage)
	if can_evo:
		var next_stage = get_next_stage(creature)
		if next_stage != "":
			evolution_ready.emit(creature, next_stage)

func _on_codex_creature_selected(creature_id: StringName) -> void:
	"""Codex UI selected a creature — verify evolution status for display."""
	var creature = _get_creature_data(creature_id)
	if creature == null:
		return

	var current_stage = creature.get("current_stage") if _object_has_property(creature, "current_stage") else ""
	var can_evo = can_evolve(creature, current_stage)
	if can_evo:
		var next_stage = get_next_stage(creature)
		if next_stage != "":
			evolution_ready.emit(creature, next_stage)

func _on_codex_evolution_ready(creature_id: StringName, next_species: StringName) -> void:
	"""Forward codex evolution_ready signal with full creature object."""
	var creature = _get_creature_data(creature_id)
	if creature != null:
		evolution_ready.emit(creature, next_species)

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

## Check if a creature can evolve from its current stage.
## creature: Object with at least {current_stage: String, training_level: int, traits: Dictionary}
## stage: String — the current stage name to check from (typically creature.current_stage)
## Returns: bool — true if all thresholds (training level + traits) are met for next stage.
func can_evolve(creature: Object, stage: String) -> bool:
	if creature == null:
		push_error("EvolutionController.can_evolve: creature is null")
		return false
	if stage == "" or stage == null:
		push_error("EvolutionController.can_evolve: stage is empty")
		return false

	var path = _get_evolution_path_for_creature(creature)
	if path.is_empty():
		return false

	var stage_index = _find_stage_index(path, stage)
	if stage_index == -1:
		push_warning("EvolutionController.can_evolve: stage '", stage, "' not found in path for ", _get_creature_path_key(creature))
		return false

	# Terminal stage check
	if stage_index >= path.size() - 1:
		return false

	# Requirements to evolve FROM current stage are stored IN the current stage entry
	var current_stage_data: Dictionary = path[stage_index]
	var required_level: int = int(current_stage_data.get("required_training_level", 0))
	var required_traits: Dictionary = current_stage_data.get("required_traits", {})

	# Check training level
	var creature_level: int = int(creature.get("training_level")) if _object_has_property(creature, "training_level") else 0
	if creature_level < required_level:
		return false

	# Check trait thresholds
	var creature_traits: Dictionary = creature.get("traits") if _object_has_property(creature, "traits") else {}
	for trait_name in required_traits:
		var required_score: int = int(required_traits[trait_name])
		var actual_score: int = int(creature_traits.get(trait_name, 0))
		if actual_score < required_score:
			return false

	return true

## Get the name of the next evolution stage for a creature.
## Returns empty string if no next stage (terminal or invalid).
func get_next_stage(creature: Object) -> String:
	if creature == null:
		return ""

	var path = _get_evolution_path_for_creature(creature)
	if path.is_empty():
		return ""

	var current_stage: String = creature.get("current_stage") if _object_has_property(creature, "current_stage") else ""
	var stage_index = _find_stage_index(path, current_stage)
	if stage_index == -1 or stage_index >= path.size() - 1:
		return ""

	return path[stage_index + 1]["name"]

## Attempt to evolve a creature to its next stage.
## Mutates creature.current_stage and returns true on success.
## Returns false if requirements not met, creature is null, or already at terminal stage.
func evolve(creature: Object) -> bool:
	if creature == null:
		push_error("EvolutionController.evolve: creature is null")
		return false

	var current_stage: String = creature.get("current_stage") if _object_has_property(creature, "current_stage") else ""
	if current_stage == "":
		push_error("EvolutionController.evolve: creature has no current_stage")
		return false

	if not can_evolve(creature, current_stage):
		evolution_blocked.emit(creature, current_stage, "requirements_not_met")
		return false

	var next_stage: String = get_next_stage(creature)
	if next_stage == "":
		evolution_blocked.emit(creature, current_stage, "terminal_or_invalid")
		return false

	# Perform the evolution — mutate the creature object
	var from_stage: String = current_stage
	creature.set("current_stage", next_stage)

	# Also update species if the creature tracks that separately
	if _object_has_property(creature, "species"):
		creature.set("species", next_stage)

	# Emit signals
	creature_evolved.emit(creature, from_stage, next_stage)

	# Notify EvolutionTree for cross-system consistency
	if _evolution_tree != null:
		# EvolutionTree uses species name and level/affection; map our data
		var level = int(creature.get("training_level")) if _object_has_property(creature, "training_level") else 0
		# We use a proxy affection score from traits for compatibility
		var affection = 0
		var creature_traits = creature.get("traits") if _object_has_property(creature, "traits") else {}
		for trait_val in creature_traits.values():
			affection += int(trait_val)
		_evolution_tree.evolve(from_stage, level, affection)

	# Notify CreatureCodex if connected
	if _creature_codex != null and _creature_codex.has_method("unlock_species"):
		_creature_codex.unlock_species(StringName(next_stage))

	return true

## Get the full evolution path for a creature's species line.
## Returns array of stage dictionaries (from EVOLUTION_THRESHOLDS).
func get_evolution_path(creature: Object) -> Array:
	return _get_evolution_path_for_creature(creature)

## Get requirements for the next stage (for UI preview).
## Returns dictionary with required_training_level and required_traits, or empty dict.
func get_next_stage_requirements(creature: Object) -> Dictionary:
	var path = _get_evolution_path_for_creature(creature)
	if path.is_empty():
		return {}

	var current_stage: String = creature.get("current_stage") if _object_has_property(creature, "current_stage") else ""
	var stage_index = _find_stage_index(path, current_stage)
	if stage_index == -1 or stage_index >= path.size() - 1:
		return {}

	var next_data = path[stage_index + 1]
	return {
		"required_training_level": next_data.get("required_training_level", 0),
		"required_traits": next_data.get("required_traits", {}).duplicate()
	}

## Force-evolve a creature to a specific stage (for testing / cheats / story events).
## Skips requirement checks. Returns true if stage exists in path.
func force_evolve_to(creature: Object, target_stage: String) -> bool:
	if creature == null or target_stage == "":
		return false

	var path = _get_evolution_path_for_creature(creature)
	var target_index = _find_stage_index(path, target_stage)
	if target_index == -1:
		return false

	var old_stage: String = creature.get("current_stage") if _object_has_property(creature, "current_stage") else ""
	creature.set("current_stage", target_stage)
	if _object_has_property(creature, "species"):
		creature.set("species", target_stage)

	creature_evolved.emit(creature, old_stage, target_stage)
	return true

# -----------------------------------------------------------------------------
# Internal Helpers
# -----------------------------------------------------------------------------

func _object_has_property(obj: Object, property_name: String) -> bool:
	"""Check if an Object has a dynamic property set."""
	if obj == null:
		return false
	return obj.get(property_name) != null

func _get_evolution_path_for_creature(creature: Object) -> Array:
	"""Determine which evolution path this creature belongs to."""
	# Try species first, then current_stage, then path_key
	var path_key: String = ""

	var evo_path_key = creature.get("evolution_path_key")
	if evo_path_key != null and evo_path_key != "":
		path_key = evo_path_key
	else:
		var species = creature.get("species")
		if species != null and species != "":
			# Map species to path key via CreatureCodex registry if available
			if _creature_codex != null and _creature_codex.has_method("get_species_data"):
				var data = _creature_codex.get_species_data(StringName(species))
				if data.has("evolution_path_key"):
					path_key = data["evolution_path_key"]
			# Fallback: species name might match a path key directly
			if path_key == "" and EVOLUTION_THRESHOLDS.has(species):
				path_key = species
		else:
			var current_stage = creature.get("current_stage")
			if current_stage != null and current_stage != "":
				# Last resort: infer from current stage name
				for key in EVOLUTION_THRESHOLDS:
					for stage_data in EVOLUTION_THRESHOLDS[key]:
						if stage_data["name"] == current_stage:
							path_key = key
							break
					if path_key != "":
						break

	if path_key == "" or not EVOLUTION_THRESHOLDS.has(path_key):
		return []

	return EVOLUTION_THRESHOLDS[path_key]

func _find_stage_index(path: Array, stage_name: String) -> int:
	for i in range(path.size()):
		if path[i]["name"] == stage_name:
			return i
	return -1

func _get_creature_path_key(creature: Object) -> String:
	if _object_has_property(creature, "evolution_path_key") and creature.get("evolution_path_key") != "":
		return creature.get("evolution_path_key")
	if _object_has_property(creature, "species"):
		return creature.get("species")
	return "unknown"

func _get_creature_data(creature_id: StringName) -> Object:
	"""Retrieve creature data from whatever registry/system holds it.
	Override or extend this to connect to your actual creature storage."""
	# First try CreatureCodex save system
	if _creature_codex != null and _creature_codex.has_method("_find_save_id_for_species"):
		var save_id = _creature_codex._find_save_id_for_species(creature_id)
		if save_id >= 0 and _creature_codex.has_method("_save_load"):
			var save_data = _creature_codex._save_load.load_creature(save_id)
			if save_data:
				return _dict_to_object(save_data)

	# Fallback: check if we have a creature registry in EvolutionTree group
	var tree = get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group("creature_registry"):
			if node.has_method("get_creature"):
				return node.get_creature(creature_id)

	return null

func _dict_to_object(data: Dictionary) -> Object:
	"""Convert a plain dictionary to an Object with dynamic properties."""
	var obj = Object.new()
	for key in data.keys():
		obj.set(key, data[key])
	return obj

# -----------------------------------------------------------------------------
# Headless Test Method
# -----------------------------------------------------------------------------

## Run self-validation tests for headless execution.
## Returns true if all tests pass, false otherwise.
func run_headless_test() -> bool:
	print("EvolutionController: Running headless tests...")

	# Test 1: Thresholds configuration is valid
	assert(EVOLUTION_THRESHOLDS.has("emberling"))
	assert(EVOLUTION_THRESHOLDS.has("splashling"))
	assert(EVOLUTION_THRESHOLDS.has("glimmerwing"))
	assert(EVOLUTION_THRESHOLDS["emberling"].size() == 3)
	print("  ✓ EVOLUTION_THRESHOLDS configured correctly")

	# Test 2: can_evolve returns false for null creature
	assert(can_evolve(null, "emberling") == false)
	print("  ✓ can_evolve(null) returns false")

	# Test 3: can_evolve returns false for missing stage
	var creature = _make_test_creature("emberling", 1, {})
	assert(can_evolve(creature, "nonexistent") == false)
	print("  ✓ can_evolve(unknown_stage) returns false")

	# Test 4: can_evolve returns false when training level too low
	creature = _make_test_creature("emberling", 5, {"fire_affinity": 20, "courage": 15})
	assert(can_evolve(creature, "emberling") == false)
	print("  ✓ can_evolve(level < required) returns false")

	# Test 5: can_evolve returns false when trait too low
	creature = _make_test_creature("emberling", 10, {"fire_affinity": 10, "courage": 15})
	assert(can_evolve(creature, "emberling") == false)
	print("  ✓ can_evolve(trait < required) returns false")

	# Test 6: can_evolve returns true when all requirements met
	creature = _make_test_creature("emberling", 25, {"fire_affinity": 50, "courage": 40, "wisdom": 20})
	assert(can_evolve(creature, "emberling") == true)
	print("  ✓ can_evolve(all met) returns true")

	# Test 7: can_evolve returns false for terminal stage
	creature = _make_test_creature("emberlord", 100, {"fire_affinity": 100, "courage": 100, "wisdom": 100})
	assert(can_evolve(creature, "emberlord") == false)
	print("  ✓ can_evolve(terminal) returns false")

	# Test 8: get_next_stage returns correct next stage
	creature = _make_test_creature("emberling", 25, {"fire_affinity": 50, "courage": 40, "wisdom": 20})
	assert(get_next_stage(creature) == "emberfox")
	print("  ✓ get_next_stage returns emberfox")

	creature = _make_test_creature("emberfox", 25, {"fire_affinity": 50, "courage": 40, "wisdom": 20})
	assert(get_next_stage(creature) == "emberlord")
	print("  ✓ get_next_stage returns emberlord")

	creature = _make_test_creature("emberlord", 100, {})
	assert(get_next_stage(creature) == "")
	print("  ✓ get_next_stage(terminal) returns empty")

	# Test 9: evolve() mutates creature and returns true on success
	creature = _make_test_creature("emberling", 25, {"fire_affinity": 50, "courage": 40, "wisdom": 20})
	var evolved = evolve(creature)
	assert(evolved == true)
	assert(creature.current_stage == "emberfox")
	assert(creature.species == "emberfox")
	print("  ✓ evolve() mutates creature and returns true")

	# Test 10: evolve() returns false when requirements not met
	creature = _make_test_creature("emberling", 5, {"fire_affinity": 10, "courage": 10})
	evolved = evolve(creature)
	assert(evolved == false)
	assert(creature.current_stage == "emberling")
	print("  ✓ evolve(requirements unmet) returns false and doesn't mutate")

	# Test 11: evolve() returns false for terminal stage
	creature = _make_test_creature("emberlord", 100, {})
	evolved = evolve(creature)
	assert(evolved == false)
	assert(creature.current_stage == "emberlord")
	print("  ✓ evolve(terminal) returns false")

	# Test 12: force_evolve_to works for valid target
	creature = _make_test_creature("emberling", 1, {})
	assert(force_evolve_to(creature, "emberlord") == true)
	assert(creature.current_stage == "emberlord")
	print("  ✓ force_evolve_to() works")

	# Test 13: get_next_stage_requirements returns correct data
	creature = _make_test_creature("emberling", 10, {"fire_affinity": 20, "courage": 15})
	var reqs = get_next_stage_requirements(creature)
	assert(reqs.has("required_training_level"))
	assert(reqs["required_training_level"] == 25)
	assert(reqs.has("required_traits"))
	assert(reqs["required_traits"]["fire_affinity"] == 50)
	print("  ✓ get_next_stage_requirements() returns correct data")

	# Test 14: Signal emission on successful evolution
	_test_signal_fired = false
	_test_signal_from = ""
	_test_signal_to = ""
	creature_evolved.connect(func(c, from_s, to_s):
		_test_signal_fired = true
		_test_signal_from = from_s
		_test_signal_to = to_s
	)
	creature = _make_test_creature("emberling", 25, {"fire_affinity": 50, "courage": 40, "wisdom": 20})
	evolve(creature)
	assert(_test_signal_fired == true)
	assert(_test_signal_from == "emberling")
	assert(_test_signal_to == "emberfox")
	print("  ✓ creature_evolved signal fires with correct data")

	# Test 15: EvolutionTree integration works if available
	if _evolution_tree != null:
		var evo_result = _evolution_tree.evolve("emberling", 25, 50)
		# EvolutionTree returns the evolves_to of the next stage; assert it produced
		# a real evolution (non-empty, different from the input species).
		assert(evo_result != "" and evo_result != "emberling")
		print("  ✓ EvolutionTree integration works (emberling -> ", evo_result, ")")

	print("EvolutionController: All headless tests PASSED")
	return true

func _make_test_creature(stage: String, level: int, traits: Dictionary) -> Object:
	"""Helper to create a test creature object."""
	var creature: CreatureData = CreatureData.new(stage, level, traits)
	creature.evolution_path_key = _infer_path_key_from_stage(stage)
	return creature

func _infer_path_key_from_stage(stage: String) -> String:
	for key in EVOLUTION_THRESHOLDS:
		for stage_data in EVOLUTION_THRESHOLDS[key]:
			if stage_data["name"] == stage:
				return key
	return ""