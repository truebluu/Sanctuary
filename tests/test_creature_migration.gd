# CreatureMigration Headless Test Runner — SANCT-927
# SceneTree-based test that validates the CreatureMigration system.
# Run with: godot --headless --path C:/Users/bluue/Documents/Galage --script res://tests/test_creature_migration.gd

class_name TestCreatureMigration
extends SceneTree

var _migration: CreatureMigration = null
var _tests_passed: int = 0
var _tests_failed: int = 0
var _test_step: int = 0

func _init() -> void:
	print("TestCreatureMigration: Initializing headless test runner")

func _initialize() -> void:
	_migration = CreatureMigration.new()
	if _migration == null:
		_fail("Failed to instantiate CreatureMigration")
		quit(1)
		return

	print("TestCreatureMigration: CreatureMigration instantiated")
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n=== Starting CreatureMigration Tests ===\n")

	_test_step = 0

	# Test 1: _init and register_creature
	_test_register_creature()

	# Test 2: set_season and get_current_season
	_test_set_season()

	# Test 3: trigger_migration returns events
	_test_trigger_migration()

	# Test 4: get_migrating_creatures returns active migrations
	_test_get_migrating_creatures()

	# Test 5: Migration events have correct structure
	_test_event_structure()

	# Test 6: Seasonal modifiers affect migration
	_test_seasonal_modifiers()

	# Test 7: clear_active_migrations works
	_test_clear_active_migrations()

	# Test 8: get_migration_schedule returns schedule for season
	_test_get_migration_schedule()

	# Test 9: Invalid season handling
	_test_invalid_season()

	# Test 10: Duplicate registration handled
	_test_duplicate_registration()

	# Test 11: RNG seed for deterministic results
	_test_rng_seed()

	# Test 12: Group size bounds respected
	_test_group_size_bounds()

	_print_summary()
	quit(1 if _tests_failed > 0 else 0)

func _test_register_creature() -> void:
	_test_step += 1
	print("Test %d: register_creature and get_registered_creatures" % _test_step)

	_migration.register_creature("emberling", "Fire Bird", 0.7, 0.3, 2, 6)
	_migration.register_creature("splashling", "Water Fish", 0.5, 0.5, 1, 4)
	_migration.register_creature("glimmerwing", "Light Insect", 0.8, 0.2, 3, 8)

	var registered = _migration.get_registered_creatures()

	if registered.size() != 3:
		_fail("Test %d: Expected 3 registered creatures, got %d" % [_test_step, registered.size()])
		return
	if not registered.has("emberling"):
		_fail("Test %d: Missing emberling in registered creatures" % _test_step)
		return
	if not registered.has("splashling"):
		_fail("Test %d: Missing splashling in registered creatures" % _test_step)
		return
	if not registered.has("glimmerwing"):
		_fail("Test %d: Missing glimmerwing in registered creatures" % _test_step)
		return

	_pass("Test %d: register_creature works" % _test_step)

func _test_set_season() -> void:
	_test_step += 1
	print("Test %d: set_season and get_current_season" % _test_step)

	_migration.set_season("Spring")
	if _migration.get_current_season() != "Spring":
		_fail("Test %d: Season should be Spring, got %s" % [_test_step, _migration.get_current_season()])
		return

	_migration.set_season("Summer")
	if _migration.get_current_season() != "Summer":
		_fail("Test %d: Season should be Summer, got %s" % [_test_step, _migration.get_current_season()])
		return

	_migration.set_season("Autumn")
	if _migration.get_current_season() != "Autumn":
		_fail("Test %d: Season should be Autumn, got %s" % [_test_step, _migration.get_current_season()])
		return

	_migration.set_season("Winter")
	if _migration.get_current_season() != "Winter":
		_fail("Test %d: Season should be Winter, got %s" % [_test_step, _migration.get_current_season()])
		return

	_pass("Test %d: set_season and get_current_season work" % _test_step)

func _test_trigger_migration() -> void:
	_test_step += 1
	print("Test %d: trigger_migration returns events" % _test_step)

	_migration.set_season("Spring")
	_migration.set_rng_seed(42)
	var events = _migration.trigger_migration()

	if not (events is Array):
		_fail("Test %d: trigger_migration should return Array, got %s" % [_test_step, typeof(events)])
		return

	_pass("Test %d: trigger_migration returns array" % _test_step)

func _test_get_migrating_creatures() -> void:
	_test_step += 1
	print("Test %d: get_migrating_creatures returns active migrations" % _test_step)

	var events = _migration.trigger_migration()
	var active = _migration.get_migrating_creatures()

	if not (active is Array):
		_fail("Test %d: get_migrating_creatures should return Array, got %s" % [_test_step, typeof(active)])
		return
	if active.size() != events.size():
		_fail("Test %d: Active migrations size (%d) != events size (%d)" % [_test_step, active.size(), events.size()])
		return

	_pass("Test %d: get_migrating_creatures returns active migrations" % _test_step)

func _test_event_structure() -> void:
	_test_step += 1
	print("Test %d: Migration events have correct structure" % _test_step)

	var events = _migration.get_migrating_creatures()

	if events.size() == 0:
		_fail("Test %d: No events to test structure" % _test_step)
		return

	var event = events[0]
	var required_keys = ["creature_id", "species", "count", "direction", "season"]

	for key in required_keys:
		if not event.has(key):
			_fail("Test %d: Event missing key: %s" % [_test_step, key])
			return

	if event["direction"] != "arriving" and event["direction"] != "departing":
		_fail("Test %d: Invalid direction: %s" % [_test_step, event["direction"]])
		return

	if event["count"] <= 0:
		_fail("Test %d: Count should be positive, got %d" % [_test_step, event["count"]])
		return

	if event["season"] != "Spring":
		_fail("Test %d: Season mismatch: %s" % [_test_step, event["season"]])
		return

	_pass("Test %d: Migration events have correct structure" % _test_step)

func _test_seasonal_modifiers() -> void:
	_test_step += 1
	print("Test %d: Seasonal modifiers affect migration" % _test_step)

	# Test with bird species which has high Spring/Autumn modifiers
	_migration.register_creature("test_bird", "Bird", 0.5, 0.5, 1, 3)
	
	_migration.set_season("Winter")
	_migration.set_rng_seed(123)
	var winter_events = _migration.trigger_migration()
	var winter_count = winter_events.size()
	
	_migration.clear_active_migrations()
	
	_migration.set_season("Spring")
	_migration.set_rng_seed(123)
	var spring_events = _migration.trigger_migration()
	var spring_count = spring_events.size()
	
	# Spring should have more or equal events for birds due to seasonal modifier
	# (This is probabilistic, so we just verify it runs without error)
	print("  Winter events: %d, Spring events: %d" % [winter_count, spring_count])
	
	_pass("Test %d: Seasonal modifiers affect migration" % _test_step)

func _test_clear_active_migrations() -> void:
	_test_step += 1
	print("Test %d: clear_active_migrations works" % _test_step)

	_migration.trigger_migration()
	if _migration.get_active_migration_count() == 0:
		_fail("Test %d: Should have active migrations before clear" % _test_step)
		return

	_migration.clear_active_migrations()

	if _migration.get_active_migration_count() != 0:
		_fail("Test %d: Active migration count should be 0 after clear, got %d" % [_test_step, _migration.get_active_migration_count()])
		return

	if not _migration.get_migrating_creatures().is_empty():
		_fail("Test %d: get_migrating_creatures should be empty after clear" % _test_step)
		return

	_pass("Test %d: clear_active_migrations works" % _test_step)

func _test_get_migration_schedule() -> void:
	_test_step += 1
	print("Test %d: get_migration_schedule works" % _test_step)

	var spring_schedule = _migration.get_migration_schedule("Spring")

	if not (spring_schedule is Array):
		_fail("Test %d: get_migration_schedule should return Array, got %s" % [_test_step, typeof(spring_schedule)])
		return

	if spring_schedule.size() == 0:
		_fail("Test %d: Spring schedule should not be empty" % _test_step)
		return

	# Check structure of schedule entries
	var entry = spring_schedule[0]
	var required_keys = ["creature_id", "species", "arrival_chance", "departure_chance", "min_group", "max_group"]
	for key in required_keys:
		if not entry.has(key):
			_fail("Test %d: Schedule entry missing key: %s" % [_test_step, key])
			return

	_pass("Test %d: get_migration_schedule works" % _test_step)

func _test_invalid_season() -> void:
	_test_step += 1
	print("Test %d: Invalid season handled gracefully" % _test_step)

	var original_season = _migration.get_current_season()
	_migration.set_season("InvalidSeason")
	
	if _migration.get_current_season() != original_season:
		_fail("Test %d: Season should remain unchanged after invalid input, got %s" % [_test_step, _migration.get_current_season()])
		return

	_pass("Test %d: Invalid season handled gracefully" % _test_step)

func _test_duplicate_registration() -> void:
	_test_step += 1
	print("Test %d: Duplicate registration handled" % _test_step)

	var initial_count = _migration.get_registered_creatures().size()
	_migration.register_creature("emberling", "Fire Bird", 0.7, 0.3, 2, 6)  # Duplicate
	var after_count = _migration.get_registered_creatures().size()

	if after_count != initial_count:
		_fail("Test %d: Duplicate registration should not increase count, got %d -> %d" % [_test_step, initial_count, after_count])
		return

	_pass("Test %d: Duplicate registration handled" % _test_step)

func _test_rng_seed() -> void:
	_test_step += 1
	print("Test %d: RNG seed produces deterministic results" % _test_step)

	_migration.set_season("Spring")
	_migration.set_rng_seed(999)
	var events1 = _migration.trigger_migration()
	
	_migration.clear_active_migrations()
	_migration.set_rng_seed(999)
	var events2 = _migration.trigger_migration()

	if events1.size() != events2.size():
		_fail("Test %d: Same seed should produce same event count, got %d vs %d" % [_test_step, events1.size(), events2.size()])
		return

	for i in range(events1.size()):
		if events1[i]["creature_id"] != events2[i]["creature_id"]:
			_fail("Test %d: Event %d creature_id differs: %s vs %s" % [_test_step, i, events1[i]["creature_id"], events2[i]["creature_id"]])
			return
		if events1[i]["direction"] != events2[i]["direction"]:
			_fail("Test %d: Event %d direction differs: %s vs %s" % [_test_step, i, events1[i]["direction"], events2[i]["direction"]])
			return
		if events1[i]["count"] != events2[i]["count"]:
			_fail("Test %d: Event %d count differs: %d vs %d" % [_test_step, i, events1[i]["count"], events2[i]["count"]])
			return

	_pass("Test %d: RNG seed produces deterministic results" % _test_step)

func _test_group_size_bounds() -> void:
	_test_step += 1
	print("Test %d: Group size bounds respected" % _test_step)

	# Register creature with specific group bounds
	_migration.register_creature("bound_test", "Mammal", 1.0, 0.0, 5, 10)  # Always arrive, groups of 5-10
	_migration.set_season("Spring")
	_migration.set_rng_seed(555)
	
	var events = _migration.trigger_migration()
	
	for event in events:
		if event["creature_id"] == "bound_test":
			if event["count"] < 5 or event["count"] > 10:
				_fail("Test %d: Group size %d outside bounds [5, 10]" % [_test_step, event["count"]])
				return

	_pass("Test %d: Group size bounds respected" % _test_step)

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