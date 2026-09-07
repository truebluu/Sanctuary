# CreatureEvolution Headless Test Runner
# SceneTree-based test that validates the CreatureEvolution system.
# Run with: godot --headless --path C:/Users/bluue/Documents/Galage --script tests/test_evolution.gd

class_name TestEvolution
extends SceneTree

var _evolution: CreatureEvolution = null
var _tests_passed: int = 0
var _tests_failed: int = 0
var _test_step: int = 0

# Signal test capture variables
var _test_signal_received: bool = false
var _test_signal_species: String = ""
var _test_signal_old_form: String = ""
var _test_signal_new_form: String = ""
var _test_signal_timestamp: float = 0.0
var _test_blocked_received: bool = false
var _test_blocked_reason: String = ""

func _init() -> void:
	print("TestEvolution: Initializing headless test runner")

func _initialize() -> void:
	_evolution = CreatureEvolution.new()
	if _evolution == null:
		_fail("Failed to instantiate CreatureEvolution")
		quit(1)
		return
	
	print("TestEvolution: CreatureEvolution instantiated")
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n=== Starting CreatureEvolution Tests ===\n")
	
	_test_step = 0
	
	# Test 1: Creature at level 1 cannot evolve
	_test_level_1_cannot_evolve()
	
	# Test 2: Raise level to trigger evolution, verify success and boosted stats
	_test_level_trigger_evolution()
	
	# Test 3: Non-matching creature returns false
	_test_non_matching_creature()
	
	# Test 4: Friendship trigger evolution
	_test_friendship_trigger()
	
	# Test 5: Item trigger evolution
	_test_item_trigger()
	
	# Test 6: Terminal form cannot evolve
	_test_terminal_form()
	
	# Test 7: Unknown species
	_test_unknown_species()
	
	# Test 8: Preview evolution stats
	_test_preview_stats()
	
	# Test 9: Evolution log persistence
	_test_evolution_log()
	
	# Test 10: Signal emission
	_test_signal_emission()
	
	_print_summary()
	quit(1 if _tests_failed > 0 else 0)

func _test_level_1_cannot_evolve() -> void:
	_test_step += 1
	print("Test %d: Creature at level 1 cannot evolve" % _test_step)
	
	var creature = _make_creature("emberling", 1, 0, {"hp": 40, "attack": 30, "defense": 20, "speed": 25}, "fire", "emberling")
	
	if _evolution.can_evolve(creature):
		_fail("Test %d: can_evolve() should return false for level 1" % _test_step)
		return
	
	if _evolution.evolve(creature):
		_fail("Test %d: evolve() should return false for level 1" % _test_step)
		return
	
	if creature["form"] != "emberling":
		_fail("Test %d: Form should remain emberling" % _test_step)
		return
	
	if creature["stats"]["hp"] != 40:
		_fail("Test %d: Stats should remain unchanged" % _test_step)
		return
	
	_pass("Test %d: Level 1 emberling correctly cannot evolve" % _test_step)

func _test_level_trigger_evolution() -> void:
	_test_step += 1
	print("Test %d: Level trigger evolution to emberfox" % _test_step)
	
	var creature = _make_creature("emberling", 10, 0, {"hp": 40, "attack": 30, "defense": 20, "speed": 25}, "fire", "emberling")
	
	if not _evolution.can_evolve(creature):
		_fail("Test %d: can_evolve() should return true for level 10" % _test_step)
		return
	
	if not _evolution.evolve(creature):
		_fail("Test %d: evolve() should return true for level 10" % _test_step)
		return
	
	if creature["form"] != "emberfox":
		_fail("Test %d: Form should be emberfox, got %s" % [_test_step, creature["form"]])
		return
	
	# Verify stat boosts (multipliers: hp 1.3, attack 1.4, defense 1.2, speed 1.1)
	if creature["stats"]["hp"] <= 40:
		_fail("Test %d: HP should be boosted from 40, got %d" % [_test_step, creature["stats"]["hp"]])
		return
	
	if creature["stats"]["attack"] <= 30:
		_fail("Test %d: Attack should be boosted from 30, got %d" % [_test_step, creature["stats"]["attack"]])
		return
	
	if creature["stats"]["defense"] <= 20:
		_fail("Test %d: Defense should be boosted from 20, got %d" % [_test_step, creature["stats"]["defense"]])
		return
	
	if creature["stats"]["speed"] <= 25:
		_fail("Test %d: Speed should be boosted from 25, got %d" % [_test_step, creature["stats"]["speed"]])
		return
	
	# Verify exact expected values (int(40*1.3)=52, int(30*1.4)=42, int(20*1.2)=24, int(25*1.1)=27)
	if creature["stats"]["hp"] != 52:
		_fail("Test %d: HP should be 52, got %d" % [_test_step, creature["stats"]["hp"]])
		return
	
	if creature["stats"]["attack"] != 42:
		_fail("Test %d: Attack should be 42, got %d" % [_test_step, creature["stats"]["attack"]])
		return
	
	if creature["stats"]["defense"] != 24:
		_fail("Test %d: Defense should be 24, got %d" % [_test_step, creature["stats"]["defense"]])
		return
	
	if creature["stats"]["speed"] != 27:
		_fail("Test %d: Speed should be 27, got %d" % [_test_step, creature["stats"]["speed"]])
		return
	
	_pass("Test %d: Level 10 emberling evolves to emberfox with correct boosted stats" % _test_step)

func _test_non_matching_creature() -> void:
	_test_step += 1
	print("Test %d: Non-matching creature (splashling at level 1) returns false" % _test_step)
	
	var creature = _make_creature("splashling", 1, 0, {"hp": 45, "attack": 25, "defense": 30, "speed": 20}, "water", "splashling")
	
	if _evolution.can_evolve(creature):
		_fail("Test %d: can_evolve() should return false for level 1 splashling" % _test_step)
		return
	
	if _evolution.evolve(creature):
		_fail("Test %d: evolve() should return false for level 1 splashling" % _test_step)
		return
	
	if creature["form"] != "splashling":
		_fail("Test %d: Form should remain splashling" % _test_step)
		return
	
	_pass("Test %d: Level 1 splashling correctly cannot evolve" % _test_step)

func _test_friendship_trigger() -> void:
	_test_step += 1
	print("Test %d: Friendship trigger evolution (splashling -> tidalfin)" % _test_step)
	
	var creature = _make_creature("splashling", 28, 80, {"hp": 70, "attack": 45, "defense": 55, "speed": 35}, "water", "tidalfin")
	
	if not _evolution.can_evolve(creature):
		_fail("Test %d: can_evolve() should return true for splashling with 80 friendship" % _test_step)
		return
	
	if not _evolution.evolve(creature):
		_fail("Test %d: evolve() should return true for friendship trigger" % _test_step)
		return
	
	if creature["form"] != "tidewyrm":
		_fail("Test %d: Form should be tidewyrm, got %s" % [_test_step, creature["form"]])
		return
	
	if creature["stats"]["hp"] <= 70:
		_fail("Test %d: HP should be boosted from 70, got %d" % [_test_step, creature["stats"]["hp"]])
		return
	
	_pass("Test %d: Splashling evolves to tidewyrm via friendship trigger" % _test_step)

func _test_item_trigger() -> void:
	_test_step += 1
	print("Test %d: Item trigger evolution (glimmerwing -> glimmerhawk)" % _test_step)
	
	var creature = _make_creature("glimmerwing", 8, 0, {"hp": 35, "attack": 35, "defense": 25, "speed": 40}, "light", "glimmerwing")
	creature["items"] = ["sun_stone"]
	
	if not _evolution.can_evolve(creature):
		_fail("Test %d: can_evolve() should return true for glimmerwing with sun_stone" % _test_step)
		return
	
	if not _evolution.evolve(creature):
		_fail("Test %d: evolve() should return true for item trigger" % _test_step)
		return
	
	if creature["form"] != "glimmerhawk":
		_fail("Test %d: Form should be glimmerhawk, got %s" % [_test_step, creature["form"]])
		return
	
	if creature["stats"]["speed"] <= 40:
		_fail("Test %d: Speed should be boosted from 40, got %d" % [_test_step, creature["stats"]["speed"]])
		return
	
	_pass("Test %d: Glimmerwing evolves to glimmerhawk via item trigger" % _test_step)

func _test_terminal_form() -> void:
	_test_step += 1
	print("Test %d: Terminal form (emberlord) cannot evolve further" % _test_step)
	
	var creature = _make_creature("emberling", 100, 100, {"hp": 100, "attack": 95, "defense": 70, "speed": 60}, "fire", "emberlord")
	
	if _evolution.can_evolve(creature):
		_fail("Test %d: can_evolve() should return false for terminal form" % _test_step)
		return
	
	if _evolution.evolve(creature):
		_fail("Test %d: evolve() should return false for terminal form" % _test_step)
		return
	
	if creature["form"] != "emberlord":
		_fail("Test %d: Form should remain emberlord" % _test_step)
		return
	
	_pass("Test %d: Terminal form emberlord correctly cannot evolve" % _test_step)

func _test_unknown_species() -> void:
	_test_step += 1
	print("Test %d: Unknown species returns false" % _test_step)
	
	var creature = _make_creature("nonexistent", 50, 50, {"hp": 50, "attack": 50, "defense": 50, "speed": 50}, "normal", "nonexistent")
	
	if _evolution.can_evolve(creature):
		_fail("Test %d: can_evolve() should return false for unknown species" % _test_step)
		return
	
	if _evolution.evolve(creature):
		_fail("Test %d: evolve() should return false for unknown species" % _test_step)
		return
	
	_pass("Test %d: Unknown species correctly returns false" % _test_step)

func _test_preview_stats() -> void:
	_test_step += 1
	print("Test %d: Preview evolution stats" % _test_step)
	
	var creature = _make_creature("emberling", 10, 0, {"hp": 40, "attack": 30, "defense": 20, "speed": 25}, "fire", "emberling")
	
	var preview = _evolution.preview_evolution_stats(creature)
	
	if preview.is_empty():
		_fail("Test %d: Preview should not be empty for valid evolution" % _test_step)
		return
	
	if preview["hp"] != 52 or preview["attack"] != 42 or preview["defense"] != 24 or preview["speed"] != 27:
		_fail("Test %d: Preview stats incorrect: %s" % [_test_step, preview])
		return
	
	# Ensure preview doesn't mutate the creature
	if creature["form"] != "emberling":
		_fail("Test %d: Preview should not mutate creature form" % _test_step)
		return
	
	# Now actually evolve and verify same stats
	if not _evolution.evolve(creature):
		_fail("Test %d: evolve() should work after preview" % _test_step)
		return
	
	if creature["form"] != "emberfox":
		_fail("Test %d: Form should be emberfox after evolve" % _test_step)
		return
	
	if creature["stats"]["hp"] != preview["hp"] or creature["stats"]["attack"] != preview["attack"]:
		_fail("Test %d: Actual stats should match preview" % _test_step)
		return
	
	_pass("Test %d: Preview evolution stats works correctly" % _test_step)

func _test_evolution_log() -> void:
	_test_step += 1
	print("Test %d: Evolution log records events" % _test_step)
	
	_evolution.clear_evolution_log()
	
	var creature = _make_creature("emberling", 10, 0, {"hp": 40, "attack": 30, "defense": 20, "speed": 25}, "fire", "emberling")
	
	if not _evolution.evolve(creature):
		_fail("Test %d: evolve() should succeed" % _test_step)
		return
	
	var log = _evolution.get_evolution_log()
	
	if log.size() != 1:
		_fail("Test %d: Log should have 1 entry, got %d" % [_test_step, log.size()])
		return
	
	var entry = log[0]
	if entry["species"] != "emberling":
		_fail("Test %d: Log species should be emberling, got %s" % [_test_step, entry["species"]])
		return
	
	if entry["old_form"] != "emberling":
		_fail("Test %d: Log old_form should be emberling, got %s" % [_test_step, entry["old_form"]])
		return
	
	if entry["new_form"] != "emberfox":
		_fail("Test %d: Log new_form should be emberfox, got %s" % [_test_step, entry["new_form"]])
		return
	
	if entry["timestamp"] <= 0:
		_fail("Test %d: Log timestamp should be positive, got %f" % [_test_step, entry["timestamp"]])
		return
	
	# Second evolution
	creature["level"] = 25
	if not _evolution.evolve(creature):
		_fail("Test %d: Second evolve() should succeed" % _test_step)
		return
	
	log = _evolution.get_evolution_log()
	if log.size() != 2:
		_fail("Test %d: Log should have 2 entries, got %d" % [_test_step, log.size()])
		return
	
	if log[1]["old_form"] != "emberfox" or log[1]["new_form"] != "emberlord":
		_fail("Test %d: Second log entry incorrect: %s" % [_test_step, log[1]])
		return
	
	_pass("Test %d: Evolution log correctly records events with species, old_form, new_form, timestamp" % _test_step)

func _test_signal_emission() -> void:
	_test_step += 1
	print("Test %d: Signal emission on evolution" % _test_step)
	
	# Use member variables to capture signal data
	_test_signal_received = false
	_test_signal_species = ""
	_test_signal_old_form = ""
	_test_signal_new_form = ""
	_test_signal_timestamp = 0.0
	
	_evolution.evolved.connect(_on_evolved_signal)
	
	var creature = _make_creature("emberling", 10, 0, {"hp": 40, "attack": 30, "defense": 20, "speed": 25}, "fire", "emberling")
	
	if not _evolution.evolve(creature):
		_fail("Test %d: evolve() should succeed" % _test_step)
		return
	
	if not _test_signal_received:
		_fail("Test %d: evolved signal not emitted" % _test_step)
		return
	
	if _test_signal_species != "emberling" or _test_signal_old_form != "emberling" or _test_signal_new_form != "emberfox":
		_fail("Test %d: Signal parameters incorrect: %s %s %s" % [_test_step, _test_signal_species, _test_signal_old_form, _test_signal_new_form])
		return
	
	if _test_signal_timestamp <= 0:
		_fail("Test %d: Signal timestamp should be positive" % _test_step)
		return
	
	# Test evolution_blocked signal
	_test_blocked_received = false
	_test_blocked_reason = ""
	
	_evolution.evolution_blocked.connect(_on_blocked_signal)
	
	var creature2 = _make_creature("emberling", 1, 0, {"hp": 40, "attack": 30, "defense": 20, "speed": 25}, "fire", "emberling")
	_evolution.evolve(creature2)
	
	if not _test_blocked_received:
		_fail("Test %d: evolution_blocked signal not emitted for failed evolution" % _test_step)
		return
	
	if _test_blocked_reason != "level":
		_fail("Test %d: Blocked reason should be 'level', got '%s'" % [_test_step, _test_blocked_reason])
		return
	
	_pass("Test %d: Signals emitted correctly on evolution and blocked evolution" % _test_step)

func _on_evolved_signal(species: String, old_form: String, new_form: String, timestamp: float) -> void:
	_test_signal_received = true
	_test_signal_species = species
	_test_signal_old_form = old_form
	_test_signal_new_form = new_form
	_test_signal_timestamp = timestamp

func _on_blocked_signal(species: String, current_form: String, reason: String) -> void:
	_test_blocked_received = true
	_test_blocked_reason = reason

func _make_creature(species: String, level: int, friendship: int, stats: Dictionary, element: String, form: String) -> Dictionary:
	return {
		"id": 1,
		"name": "TestCreature",
		"species": species,
		"level": level,
		"friendship": friendship,
		"stats": stats.duplicate(),
		"element": element,
		"form": form
	}

func _pass(message: String) -> void:
	_tests_passed += 1
	print("  PASS: %s" % message)

func _fail(message: String) -> void:
	_tests_failed += 1
	print("  FAIL: %s" % message)

func _print_summary() -> void:
	print("\n=== Test Summary ===")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("Total:  %d" % (_tests_passed + _tests_failed))
	if _tests_failed == 0:
		print("\nALL TESTS PASSED")
	else:
		print("\nSOME TESTS FAILED")

func _start() -> void:
	_initialize()