# CreatureCodex Headless Test Runner — SANCT-1028
# SceneTree-based test that validates the CreatureCodex system.
# Run with: godot --headless --path C:/Users/bluue/Documents/Galage --script res://tests/test_creature_codex.gd

class_name TestCreatureCodex
extends SceneTree

var _codex: CreatureCodex = null
var _tests_passed: int = 0
var _tests_failed: int = 0
var _test_step: int = 0

func _init() -> void:
	print("TestCreatureCodex: Initializing headless test runner")

func _initialize() -> void:
	_codex = CreatureCodex.new()
	if _codex == null:
		_fail("Failed to instantiate CreatureCodex")
		quit(1)
		return

	print("TestCreatureCodex: CreatureCodex instantiated")
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n=== Starting CreatureCodex Tests ===\n")

	_test_step = 0

	# Test 1: add_creature and get_creature
	_test_add_creature()

	# Test 2: record_discovery
	_test_record_discovery()

	# Test 3: update_stats
	_test_update_stats()

	# Test 4: set_lore
	_test_set_lore()

	# Test 5: set_evolution_hints
	_test_set_evolution_hints()

	# Test 6: is_known and is_discovered
	_test_is_known_discovered()

	# Test 7: discover_count with multiple creatures
	_test_discover_count()

	# Test 8: all_ids
	_test_all_ids()

	# Test 9: get_creature unknown returns empty dict
	_test_get_unknown()

	# Test 10: save/load round-trip
	_test_save_load_roundtrip()

	_print_summary()
	quit(1 if _tests_failed > 0 else 0)

func _test_add_creature() -> void:
	_test_step += 1
	print("Test %d: add_creature and get_creature" % _test_step)

	_codex.add_creature("emberling", "Emberling", "Fire")
	var creature = _codex.get_creature("emberling")

	if creature["creature_id"] != "emberling":
		_fail("Test %d: creature_id mismatch: %s" % [_test_step, creature["creature_id"]])
		return
	if creature["display_name"] != "Emberling":
		_fail("Test %d: display_name mismatch: %s" % [_test_step, creature["display_name"]])
		return
	if creature["species"] != "Fire":
		_fail("Test %d: species mismatch: %s" % [_test_step, creature["species"]])
		return
	if creature["discovered"] != false:
		_fail("Test %d: discovered should be false initially" % _test_step)
		return
	if not creature["stats"].is_empty():
		_fail("Test %d: stats should be empty initially" % _test_step)
		return
	if creature["lore"] != "":
		_fail("Test %d: lore should be empty initially" % _test_step)
		return
	if creature["evolution_hints"] != "":
		_fail("Test %d: evolution_hints should be empty initially" % _test_step)
		return

	_pass("Test %d: add_creature and get_creature work" % _test_step)

func _test_record_discovery() -> void:
	_test_step += 1
	print("Test %d: record_discovery marks discovered" % _test_step)

	_codex.record_discovery("emberling")

	if _codex.is_discovered("emberling") != true:
		_fail("Test %d: is_discovered should return true after record_discovery" % _test_step)
		return
	if _codex.discover_count() != 1:
		_fail("Test %d: discover_count should be 1, got %d" % [_test_step, _codex.discover_count()])
		return

	_pass("Test %d: record_discovery marks discovered" % _test_step)

func _test_update_stats() -> void:
	_test_step += 1
	print("Test %d: update_stats works" % _test_step)

	_codex.update_stats("emberling", {"hp": 40, "attack": 30, "defense": 20, "speed": 25})
	var creature = _codex.get_creature("emberling")

	if creature["stats"]["hp"] != 40:
		_fail("Test %d: hp mismatch: %d" % [_test_step, creature["stats"]["hp"]])
		return
	if creature["stats"]["attack"] != 30:
		_fail("Test %d: attack mismatch: %d" % [_test_step, creature["stats"]["attack"]])
		return
	if creature["stats"]["defense"] != 20:
		_fail("Test %d: defense mismatch: %d" % [_test_step, creature["stats"]["defense"]])
		return
	if creature["stats"]["speed"] != 25:
		_fail("Test %d: speed mismatch: %d" % [_test_step, creature["stats"]["speed"]])
		return

	_pass("Test %d: update_stats works" % _test_step)

func _test_set_lore() -> void:
	_test_step += 1
	print("Test %d: set_lore works" % _test_step)

	_codex.set_lore("emberling", "A fledgling fire creature born from volcanic ash.")
	var creature = _codex.get_creature("emberling")

	if creature["lore"] != "A fledgling fire creature born from volcanic ash.":
		_fail("Test %d: lore mismatch: %s" % [_test_step, creature["lore"]])
		return

	_pass("Test %d: set_lore works" % _test_step)

func _test_set_evolution_hints() -> void:
	_test_step += 1
	print("Test %d: set_evolution_hints works" % _test_step)

	_codex.set_evolution_hints("emberling", "Evolves at level 10 to Emberfox")
	var creature = _codex.get_creature("emberling")

	if creature["evolution_hints"] != "Evolves at level 10 to Emberfox":
		_fail("Test %d: evolution_hints mismatch: %s" % [_test_step, creature["evolution_hints"]])
		return

	_pass("Test %d: set_evolution_hints works" % _test_step)

func _test_is_known_discovered() -> void:
	_test_step += 1
	print("Test %d: is_known and is_discovered work" % _test_step)

	if _codex.is_known("emberling") != true:
		_fail("Test %d: is_known should return true for known creature" % _test_step)
		return
	if _codex.is_known("unknown") != false:
		_fail("Test %d: is_known should return false for unknown creature" % _test_step)
		return
	if _codex.is_discovered("emberling") != true:
		_fail("Test %d: is_discovered should return true for discovered creature" % _test_step)
		return
	if _codex.is_discovered("unknown") != false:
		_fail("Test %d: is_discovered should return false for unknown creature" % _test_step)
		return

	_pass("Test %d: is_known and is_discovered work" % _test_step)

func _test_discover_count() -> void:
	_test_step += 1
	print("Test %d: discover_count works with multiple creatures" % _test_step)

	_codex.add_creature("splashling", "Splashling", "Water")
	_codex.add_creature("glimmerwing", "Glimmerwing", "Light")

	if _codex.discover_count() != 1:
		_fail("Test %d: discover_count should be 1 (only emberling discovered), got %d" % [_test_step, _codex.discover_count()])
		return

	_codex.record_discovery("splashling")

	if _codex.discover_count() != 2:
		_fail("Test %d: discover_count should be 2, got %d" % [_test_step, _codex.discover_count()])
		return

	_pass("Test %d: discover_count works with multiple creatures" % _test_step)

func _test_all_ids() -> void:
	_test_step += 1
	print("Test %d: all_ids returns all creature IDs" % _test_step)

	var ids = _codex.all_ids()

	if ids.size() != 3:
		_fail("Test %d: all_ids should have 3 entries, got %d" % [_test_step, ids.size()])
		return
	if not ids.has("emberling"):
		_fail("Test %d: all_ids missing emberling" % _test_step)
		return
	if not ids.has("splashling"):
		_fail("Test %d: all_ids missing splashling" % _test_step)
		return
	if not ids.has("glimmerwing"):
		_fail("Test %d: all_ids missing glimmerwing" % _test_step)
		return

	_pass("Test %d: all_ids returns all creature IDs" % _test_step)

func _test_get_unknown() -> void:
	_test_step += 1
	print("Test %d: get_creature unknown returns empty dict" % _test_step)

	var unknown = _codex.get_creature("nonexistent")

	if not unknown.is_empty():
		_fail("Test %d: get_creature unknown should return empty dict, got %s" % [_test_step, unknown])
		return

	_pass("Test %d: get_creature unknown returns empty dict" % _test_step)

func _test_save_load_roundtrip() -> void:
	_test_step += 1
	print("Test %d: save/load round-trip" % _test_step)

	var save_path = "user://test_codex_save.json"

	if _codex.save(save_path) != true:
		_fail("Test %d: save() returned false" % _test_step)
		return

	var codex2 = CreatureCodex.new()
	if codex2.load(save_path) != true:
		_fail("Test %d: load() returned false" % _test_step)
		return

	# Verify loaded data matches original
	if codex2.is_known("emberling") != true:
		_fail("Test %d: loaded codex missing emberling" % _test_step)
		return
	if codex2.is_known("splashling") != true:
		_fail("Test %d: loaded codex missing splashling" % _test_step)
		return
	if codex2.is_known("glimmerwing") != true:
		_fail("Test %d: loaded codex missing glimmerwing" % _test_step)
		return
	if codex2.is_discovered("emberling") != true:
		_fail("Test %d: loaded codex emberling not discovered" % _test_step)
		return
	if codex2.is_discovered("splashling") != true:
		_fail("Test %d: loaded codex splashling not discovered" % _test_step)
		return
	if codex2.is_discovered("glimmerwing") != false:
		_fail("Test %d: loaded codex glimmerwing should not be discovered" % _test_step)
		return
	if codex2.discover_count() != 2:
		_fail("Test %d: loaded codex discover_count should be 2, got %d" % [_test_step, codex2.discover_count()])
		return

	var loaded_emberling = codex2.get_creature("emberling")
	if loaded_emberling["display_name"] != "Emberling":
		_fail("Test %d: loaded display_name mismatch: %s" % [_test_step, loaded_emberling["display_name"]])
		return
	if loaded_emberling["species"] != "Fire":
		_fail("Test %d: loaded species mismatch: %s" % [_test_step, loaded_emberling["species"]])
		return
	if loaded_emberling["stats"]["hp"] != 40:
		_fail("Test %d: loaded hp mismatch: %d" % [_test_step, loaded_emberling["stats"]["hp"]])
		return
	if loaded_emberling["stats"]["attack"] != 30:
		_fail("Test %d: loaded attack mismatch: %d" % [_test_step, loaded_emberling["stats"]["attack"]])
		return
	if loaded_emberling["lore"] != "A fledgling fire creature born from volcanic ash.":
		_fail("Test %d: loaded lore mismatch: %s" % [_test_step, loaded_emberling["lore"]])
		return
	if loaded_emberling["evolution_hints"] != "Evolves at level 10 to Emberfox":
		_fail("Test %d: loaded evolution_hints mismatch: %s" % [_test_step, loaded_emberling["evolution_hints"]])
		return

	# Clean up test file
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.WRITE)
		if file:
			file.close()
		DirAccess.remove_absolute(save_path)

	_pass("Test %d: save/load round-trip works correctly" % _test_step)

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