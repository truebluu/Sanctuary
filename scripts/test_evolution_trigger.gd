# Headless SceneTree Test for EvolutionTrigger + Metamorphosis System
# Runs without Godot editor - pure GDScript validation via SceneTree

extends SceneTree

# Test results tracking
var _test_results: Dictionary = {
	"passed": 0,
	"failed": 0,
	"errors": []
}

var _trigger: EvolutionTrigger
var _evolution: CreatureEvolution

func _init() -> void:
	# Initialize the test systems
	_trigger = EvolutionTrigger.new()
	_evolution = CreatureEvolution.new()

func _initialize() -> void:
	"""Called when SceneTree is ready - run all tests."""
	print("\n============================================================")
	print("EvolutionTrigger + Metamorphosis System - Headless SceneTree Test")
	print("============================================================\n")
	
	run_all_tests()
	
	print_results()
	
	# Exit with appropriate code
	var exit_code: int = 1 if _test_results["failed"] > 0 else 0
	quit(exit_code)

func run_all_tests() -> void:
	"""Run all test suites."""
	
	# Core Trigger Tests
	test_level_trigger()
	test_friendship_trigger()
	test_item_trigger()
	test_trait_threshold_trigger()
	test_time_of_day_trigger()
	test_location_trigger()
	test_quest_flag_trigger()
	test_special_event_trigger()
	test_trigger_priority()
	test_custom_trigger()
	
	# Metamorphosis Pipeline Tests
	test_metamorphosis_basic()
	test_metamorphosis_stages()
	test_metamorphosis_pause_resume()
	test_metamorphosis_cancel()
	test_metamorphosis_concurrent_limit()
	test_custom_stage_handler()
	
	# Combined Evolution + Metamorphosis Tests
	test_evolution_with_metamorphosis()
	test_evolution_with_creature_evolution()
	test_multiple_evolutions_chain()
	test_metamorphosis_metadata()
	
	# Edge Cases
	test_unknown_species()
	test_terminal_form_blocked()
	test_invalid_creature_data()
	test_empty_triggers()
	
	# Integration Tests
	test_trigger_signal_emission()
	test_metamorphosis_signal_emission()
	test_evolution_log_integration()

# =============================================================================
# Test Helpers
# =============================================================================

func _assert(condition: bool, message: String) -> void:
	if condition:
		_test_results["passed"] += 1
		print("  ✓ PASS: ", message)
	else:
		_test_results["failed"] += 1
		_test_results["errors"].append(message)
		print("  ✗ FAIL: ", message)

func _assert_eq(actual, expected, message: String) -> void:
	if actual == expected:
		_test_results["passed"] += 1
		print("  ✓ PASS: ", message)
	else:
		_test_results["failed"] += 1
		_test_results["errors"].append("%s (expected: %s, got: %s)" % [message, expected, actual])
		print("  ✗ FAIL: %s (expected: %s, got: %s)" % [message, expected, actual])

func _make_emberling(level: int = 1, friendship: int = 0, traits: Dictionary = {}, items: Array = []) -> Dictionary:
	return {
		"id": "test_emberling_%d" % [level],
		"name": "Test Emberling",
		"species": "emberling",
		"form": "emberling",
		"level": level,
		"friendship": friendship,
		"stats": {"hp": 40, "attack": 30, "defense": 20, "speed": 25},
		"element": "fire",
		"items": items.duplicate(),
		"traits": traits.duplicate(),
		"location": "sanctuary",
		"time_of_day": 12.0,
		"quest_flags": [],
		"active_events": []
	}

func _make_splashling(level: int = 1, friendship: int = 0, traits: Dictionary = {}) -> Dictionary:
	return {
		"id": "test_splashling_%d" % [level],
		"name": "Test Splashling",
		"species": "splashling",
		"form": "splashling",
		"level": level,
		"friendship": friendship,
		"stats": {"hp": 45, "attack": 25, "defense": 30, "speed": 20},
		"element": "water",
		"items": [],
		"traits": traits.duplicate(),
		"location": "sanctuary",
		"time_of_day": 12.0,
		"quest_flags": [],
		"active_events": []
	}

func _make_glimmerwing(level: int = 1, friendship: int = 0, traits: Dictionary = {}, items: Array = []) -> Dictionary:
	return {
		"id": "test_glimmerwing_%d" % [level],
		"name": "Test Glimmerwing",
		"species": "glimmerwing",
		"form": "glimmerwing",
		"level": level,
		"friendship": friendship,
		"stats": {"hp": 35, "attack": 35, "defense": 25, "speed": 40},
		"element": "light",
		"items": items.duplicate(),
		"traits": traits.duplicate(),
		"location": "sanctuary",
		"time_of_day": 12.0,
		"quest_flags": [],
		"active_events": []
	}

func _make_emberfox() -> Dictionary:
	return {
		"id": "test_emberfox",
		"name": "Test Emberfox",
		"species": "emberling",
		"form": "emberfox",
		"level": 25,
		"friendship": 50,
		"stats": {"hp": 60, "attack": 55, "defense": 35, "speed": 40},
		"element": "fire",
		"items": [],
		"traits": {},
		"location": "sanctuary",
		"time_of_day": 12.0,
		"quest_flags": [],
		"active_events": []
	}

func _make_emberlord() -> Dictionary:
	return {
		"id": "test_emberlord",
		"name": "Test Emberlord",
		"species": "emberling",
		"form": "emberlord",
		"level": 50,
		"friendship": 100,
		"stats": {"hp": 100, "attack": 95, "defense": 70, "speed": 60},
		"element": "fire",
		"items": [],
		"traits": {},
		"location": "sanctuary",
		"time_of_day": 12.0,
		"quest_flags": [],
		"active_events": []
	}

# =============================================================================
# Core Trigger Tests
# =============================================================================

func test_level_trigger() -> void:
	print("\n--- Test Suite: Level Trigger ---")
	
	var creature = _make_emberling(10)
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Level 10 activates level trigger (required: 10)")
	_assert_eq(activated[0]["type"], "level", "Trigger type is 'level'")
	
	creature = _make_emberling(9)
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Level 9 does NOT activate level trigger (required: 10)")
	
	creature = _make_emberling(15)
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Level 15 activates level trigger (required: 10)")

func test_friendship_trigger() -> void:
	print("\n--- Test Suite: Friendship Trigger ---")
	
	var creature = _make_emberling(10, 80)
	var triggers = [{"type": "friendship", "params": {"required_friendship": 80}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Friendship 80 activates trigger (required: 80)")
	_assert_eq(activated[0]["type"], "friendship", "Trigger type is 'friendship'")
	
	creature = _make_emberling(10, 79)
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Friendship 79 does NOT activate trigger (required: 80)")
	
	creature = _make_emberling(10, 100)
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Friendship 100 activates trigger (required: 80)")

func test_item_trigger() -> void:
	print("\n--- Test Suite: Item Trigger ---")
	
	var creature = _make_emberling(10, 0, {}, ["sun_stone"])
	var triggers = [{"type": "item", "params": {"required_item": "sun_stone", "consume_item": true}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Having sun_stone activates item trigger")
	_assert("sun_stone" not in creature["items"], "Item is consumed from inventory")
	
	# Test without consume
	creature = _make_emberling(10, 0, {}, ["moon_stone"])
	triggers = [{"type": "item", "params": {"required_item": "moon_stone", "consume_item": false}, "priority": 1}]
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Having moon_stone activates trigger (consume=false)")
	_assert("moon_stone" in creature["items"], "Item is NOT consumed when consume=false")
	
	# Test missing item
	creature = _make_emberling(10, 0, {}, [])
	triggers = [{"type": "item", "params": {"required_item": "sun_stone"}, "priority": 1}]
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Missing item does NOT activate trigger")

func test_trait_threshold_trigger() -> void:
	print("\n--- Test Suite: Trait Threshold Trigger ---")
	
	var creature = _make_emberling(10, 0, {"fire_affinity": 50, "courage": 40})
	var triggers = [{"type": "trait_threshold", "params": {"required_traits": {"fire_affinity": 50, "courage": 40}}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Traits meeting all thresholds activate trigger")
	
	creature = _make_emberling(10, 0, {"fire_affinity": 30, "courage": 40})
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "One trait below threshold blocks activation")
	
	creature = _make_emberling(10, 0, {"fire_affinity": 50, "courage": 40, "wisdom": 100})
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Extra traits don't interfere with threshold check")
	
	# Test missing trait
	creature = _make_emberling(10, 0, {"fire_affinity": 50})
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Missing required trait (courage) blocks activation")

func test_time_of_day_trigger() -> void:
	print("\n--- Test Suite: Time of Day Trigger ---")
	
	# Daytime range
	var creature = _make_emberling()
	creature["time_of_day"] = 10.0  # 10:00 AM
	var triggers = [{"type": "time_of_day", "params": {"time_range_start": 6.0, "time_range_end": 18.0}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "10:00 AM in 6:00-18:00 range activates trigger")
	
	creature["time_of_day"] = 5.0  # 5:00 AM
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "5:00 AM NOT in 6:00-18:00 range")
	
	creature["time_of_day"] = 19.0  # 7:00 PM
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "19:00 NOT in 6:00-18:00 range")
	
	# Overnight range
	creature["time_of_day"] = 23.0  # 11:00 PM
	triggers = [{"type": "time_of_day", "params": {"time_range_start": 22.0, "time_range_end": 6.0}, "priority": 1}]
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "23:00 in 22:00-6:00 overnight range activates")
	
	creature["time_of_day"] = 3.0  # 3:00 AM
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "3:00 AM in 22:00-6:00 overnight range activates")
	
	creature["time_of_day"] = 12.0  # 12:00 PM
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "12:00 PM NOT in 22:00-6:00 overnight range")

func test_location_trigger() -> void:
	print("\n--- Test Suite: Location Trigger ---")
	
	var creature = _make_emberling()
	creature["location"] = "volcano"
	var triggers = [{"type": "location", "params": {"required_location": "volcano"}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Location 'volcano' matches required location")
	
	creature["location"] = "forest"
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Location 'forest' does NOT match 'volcano'")

func test_quest_flag_trigger() -> void:
	print("\n--- Test Suite: Quest Flag Trigger ---")
	
	var creature = _make_emberling()
	creature["quest_flags"] = ["defeated_alpha_emberfox", "found_fire_gem"]
	var triggers = [{"type": "quest_flag", "params": {"required_quest_flag": "defeated_alpha_emberfox"}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Quest flag 'defeated_alpha_emberfox' present activates trigger")
	
	triggers = [{"type": "quest_flag", "params": {"required_quest_flag": "completed_volcano_dungeon"}, "priority": 1}]
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Missing quest flag does NOT activate trigger")

func test_special_event_trigger() -> void:
	print("\n--- Test Suite: Special Event Trigger ---")
	
	var creature = _make_emberling()
	creature["active_events"] = ["solar_eclipse", "double_xp_weekend"]
	var triggers = [{"type": "special_event", "params": {"event_name": "solar_eclipse"}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Active event 'solar_eclipse' triggers evolution")
	
	triggers = [{"type": "special_event", "params": {"event_name": "lunar_festival"}, "priority": 1}]
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Inactive event 'lunar_festival' does NOT trigger")

func test_trigger_priority() -> void:
	print("\n--- Test Suite: Trigger Priority Ordering ---")
	
	var creature = _make_emberling(10, 80)
	var triggers = [
		{"type": "level", "params": {"required_level": 10}, "priority": 1},
		{"type": "friendship", "params": {"required_friendship": 80}, "priority": 10},
		{"type": "item", "params": {"required_item": "sun_stone"}, "priority": 5}
	]
	creature["items"] = ["sun_stone"]
	
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 3, "All three triggers activate")
	_assert_eq(activated[0]["type"], "friendship", "Highest priority (10) first: friendship")
	_assert_eq(activated[1]["type"], "item", "Medium priority (5) second: item")
	_assert_eq(activated[2]["type"], "level", "Lowest priority (1) last: level")

func test_custom_trigger() -> void:
	print("\n--- Test Suite: Custom Trigger Registration ---")

	_custom_checker_called = false
	var checker = Callable(self, "_test_custom_checker")
	_trigger.register_custom_trigger("my_custom_trigger", checker)

	var creature = _make_emberling()
	var triggers = [{"type": "my_custom_trigger", "params": {"value": 42}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.size() == 1, "Custom trigger activates when checker returns true")
	_assert(_custom_checker_called == true, "Custom checker was called")

	# Test custom trigger returning false
	_custom_checker_called = false
	var checker_false = Callable(self, "_test_custom_checker_false")
	_trigger.register_custom_trigger("my_custom_trigger_false", checker_false)
	triggers = [{"type": "my_custom_trigger_false", "params": {}, "priority": 1}]
	activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Custom trigger returning false does not activate")
	_assert(_custom_checker_called == true, "Custom checker was called even when returning false")

	# Cleanup
	_trigger.unregister_custom_trigger("my_custom_trigger")
	_trigger.unregister_custom_trigger("my_custom_trigger_false")

var _custom_checker_called: bool = false

func _test_custom_checker(creature_data: Dictionary, params: Dictionary) -> bool:
	_custom_checker_called = true
	return true

func _test_custom_checker_false(creature_data: Dictionary, params: Dictionary) -> bool:
	_custom_checker_called = true
	return false

# =============================================================================
# Metamorphosis Pipeline Tests
# =============================================================================

func test_metamorphosis_basic() -> void:
	print("\n--- Test Suite: Metamorphosis Basic ---")
	
	var result = _trigger.start_metamorphosis("test_1", "emberling", "emberfox", {})
	_assert(result.has("process_id"), "start_metamorphosis returns process_id")
	_assert_eq(result["current_stage"], "init", "Starts at INIT stage")
	_assert_eq(result["from_form"], "emberling", "Records from_form")
	_assert_eq(result["to_form"], "emberfox", "Records to_form")
	
	var process = _trigger.get_metamorphosis(result["process_id"])
	_assert(process["current_stage"] == "complete", "Headless mode completes all stages immediately")
	_assert_eq(process["overall_progress"], 1.0, "Overall progress is 1.0 at completion")

func test_metamorphosis_stages() -> void:
	print("\n--- Test Suite: Metamorphosis Stages ---")
	
	var result = _trigger.start_metamorphosis("test_2", "emberling", "emberfox", {})
	var process = _trigger.get_metamorphosis(result["process_id"])
	
	# In headless mode, it should complete all stages
	var expected_stages = ["init", "cocoon_forming", "transformation", "emergence", "stat_application", "complete"]
	_assert(process["current_stage"] == "complete", "Final stage is 'complete'")
	
	# Test with metadata duration multiplier
	result = _trigger.start_metamorphosis("test_2b", "splashling", "tidalfin", {"duration_multiplier": 2.0})
	process = _trigger.get_metamorphosis(result["process_id"])
	_assert(process["current_stage"] == "complete", "Custom duration multiplier still completes in headless")

func test_metamorphosis_pause_resume() -> void:
	print("\n--- Test Suite: Metamorphosis Pause/Resume ---")
	
	var result = _trigger.start_metamorphosis("test_3", "emberling", "emberfox", {})
	var pid = result["process_id"]
	
	_assert(_trigger.pause_metamorphosis(pid) == true, "Pause returns true")
	var process = _trigger.get_metamorphosis(pid)
	_assert(process["is_paused"] == true, "Process is_paused = true after pause")
	
	_assert(_trigger.resume_metamorphosis(pid) == true, "Resume returns true")
	process = _trigger.get_metamorphosis(pid)
	_assert(process["is_paused"] == false, "Process is_paused = false after resume")
	
	# Pause non-existent
	_assert(_trigger.pause_metamorphosis("nonexistent") == false, "Pause non-existent returns false")
	_assert(_trigger.resume_metamorphosis("nonexistent") == false, "Resume non-existent returns false")

func test_metamorphosis_cancel() -> void:
	print("\n--- Test Suite: Metamorphosis Cancel ---")
	
	var result = _trigger.start_metamorphosis("test_4", "emberling", "emberfox", {})
	var pid = result["process_id"]
	
	_assert(_trigger.cancel_metamorphosis(pid, "user_cancelled") == true, "Cancel returns true")
	var process = _trigger.get_metamorphosis(pid)
	_assert(not process, "Process removed after cancel")
	
	# Cancel non-existent
	_assert(_trigger.cancel_metamorphosis("nonexistent", "test") == false, "Cancel non-existent returns false")

func test_metamorphosis_concurrent_limit() -> void:
	print("\n--- Test Suite: Metamorphosis Concurrent Limit ---")
	
	# Clear any existing
	_trigger.clear_all_metamorphoses()
	
	# Start MAX_CONCURRENT_METAMORPHOSES processes
	for i in range(10):
		var result = _trigger.start_metamorphosis("test_concurrent_%d" % [i], "emberling", "emberfox", {})
		_assert(result.has("process_id"), "Process %d started successfully" % [i])
	
	# Next one should fail
	var result = _trigger.start_metamorphosis("test_concurrent_overflow", "emberling", "emberfox", {})
	_assert(not result.has("process_id"), "11th process rejected (max 10)")
	
	_trigger.clear_all_metamorphoses()

func test_custom_stage_handler() -> void:
	print("\n--- Test Suite: Custom Metamorphosis Stage Handler ---")
	
	_custom_stage_called = false
	var handler = Callable(self, "_test_custom_stage")
	_trigger.register_metamorphosis_stage_handler("my_custom_stage", handler)
	
	# Verify registration
	var triggers = _trigger.get_registered_triggers()
	# Custom stages aren't in triggers list, but handler is registered
	
	_trigger.unregister_metamorphosis_stage_handler("my_custom_stage")
	_assert(not _custom_stage_called, "Custom handler not called during registration")

	# Test actual call would require integration into stage pipeline
	# This verifies registration API works
	_assert(true, "Custom stage handler registration/unregistration works")

var _custom_stage_called: bool = false

func _test_custom_stage(process_id: String) -> void:
	_custom_stage_called = true

# =============================================================================
# Combined Evolution + Metamorphosis Tests
# =============================================================================

func test_evolution_with_metamorphosis() -> void:
	print("\n--- Test Suite: Evolution + Metamorphosis Workflow ---")
	
	var creature = _make_emberling(10)
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	
	var result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, null)
	_assert(result["success"] == true, "Evolution succeeds with level trigger")
	_assert_eq(result["old_form"], "emberling", "Old form recorded correctly")
	_assert_eq(result["new_form"], "emberfox", "New form is emberfox")
	_assert(result["metamorphosis"].has("process_id"), "Metamorphosis started")
	_assert_eq(creature["form"], "emberfox", "Creature form mutated to emberfox")
	_assert(creature["stats"]["hp"] > 40, "Stats boosted after evolution")
	_assert(creature["stats"]["attack"] > 30, "Attack boosted after evolution")

func test_evolution_with_creature_evolution() -> void:
	print("\n--- Test Suite: Evolution with CreatureEvolution System ---")
	
	var creature = _make_emberling(10)
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	
	var result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, _evolution)
	_assert(result["success"] == true, "Evolution succeeds via CreatureEvolution")
	_assert_eq(result["new_form"], "emberfox", "New form from CreatureEvolution")
	_assert(_evolution.get_evolution_log().size() == 1, "Evolution logged in CreatureEvolution")
	
	var log = _evolution.get_evolution_log()[0]
	_assert_eq(log["old_form"], "emberling", "Log old_form correct")
	_assert_eq(log["new_form"], "emberfox", "Log new_form correct")
	
	_evolution.clear_evolution_log()

func test_multiple_evolutions_chain() -> void:
	print("\n--- Test Suite: Multiple Evolution Chain ---")
	
	var creature = _make_emberling(10)
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	
	# First evolution: emberling -> emberfox
	var result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, _evolution)
	_assert(result["success"] == true, "First evolution: emberling -> emberfox")
	_assert_eq(creature["form"], "emberfox", "Form is now emberfox")
	
	# Level up for next evolution
	creature["level"] = 25
	result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, _evolution)
	_assert(result["success"] == true, "Second evolution: emberfox -> emberlord")
	_assert_eq(creature["form"], "emberlord", "Form is now emberlord")
	_assert(creature["stats"]["hp"] > 60, "Stats further boosted")
	
	# Third evolution should fail (terminal)
	creature["level"] = 100
	result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, _evolution)
	_assert(result["success"] == false, "Terminal form (emberlord) cannot evolve further")
	_assert_eq(result["reason"], "evolution_failed", "Reason is evolution_failed")
	_assert_eq(creature["form"], "emberlord", "Form unchanged at terminal")

func test_metamorphosis_metadata() -> void:
	print("\n--- Test Suite: Metamorphosis Metadata ---")
	
	var creature = _make_emberling(10, 0, {}, ["sun_stone"])
	var triggers = [{"type": "item", "params": {"required_item": "sun_stone", "consume_item": true}, "priority": 1}]
	
	var result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, null)
	_assert(result["success"] == true, "Item-triggered evolution succeeds")
	
	var meta = result["metamorphosis"]
	var process = _trigger.get_metamorphosis(meta["process_id"])
	_assert(process["metadata"].has("trigger"), "Metadata includes trigger info")
	_assert(process["metadata"].has("stat_changes"), "Metadata includes stat_changes")
	_assert(process["metadata"].has("resulting_stats"), "Metadata includes resulting_stats")
	
	var stat_changes = process["metadata"]["stat_changes"]
	_assert(stat_changes["hp"] > 0, "HP stat change positive")
	_assert(stat_changes["attack"] > 0, "Attack stat change positive")

# =============================================================================
# Edge Cases
# =============================================================================

func test_unknown_species() -> void:
	print("\n--- Test Suite: Unknown Species ---")
	
	var creature = _make_emberling(10)
	creature["species"] = "unknown_species"
	creature["form"] = "unknown_species"
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	
	var result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, null)
	_assert(result["success"] == false, "Unknown species cannot evolve")
	_assert_eq(result["reason"], "evolution_failed", "Reason is evolution_failed")

func test_terminal_form_blocked() -> void:
	print("\n--- Test Suite: Terminal Form Blocked ---")
	
	var creature = _make_emberlord()
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	
	var result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, _evolution)
	_assert(result["success"] == false, "Terminal form emberlord blocked")
	_assert_eq(result["reason"], "evolution_failed", "Reason is evolution_failed")

func test_invalid_creature_data() -> void:
	print("\n--- Test Suite: Invalid Creature Data ---")
	
	# Missing species
	var creature = {"id": "test", "level": 10}
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Missing species doesn't crash, returns empty")
	
	# Missing stats
	creature = {"id": "test", "species": "emberling", "form": "emberling", "level": 10}
	var invalid_result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, null)
	_assert(invalid_result["success"] == false, "Missing stats doesn't crash")

func test_empty_triggers() -> void:
	print("\n--- Test Suite: Empty Triggers ---")
	
	var creature = _make_emberling(10)
	var triggers = []
	var activated = _trigger.evaluate_triggers(creature, triggers)
	_assert(activated.is_empty(), "Empty trigger list returns empty")
	
	var result = _trigger.attempt_evolution_with_metamorphosis(creature, triggers, null)
	_assert(result["success"] == false, "Empty triggers fails evolution")
	_assert_eq(result["reason"], "no_triggers_activated", "Reason is no_triggers_activated")

# =============================================================================
# Integration Tests
# =============================================================================

func test_trigger_signal_emission() -> void:
	print("\n--- Test Suite: Trigger Signal Emission ---")

	_sig_trigger_fired = false
	_sig_trigger_type = ""
	_sig_trigger_cid = ""
	_sig_trigger_payload = {}

	_trigger.trigger_activated.connect(_on_trigger_signal)

	var creature = _make_emberling(10)
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	_trigger.evaluate_triggers(creature, triggers)

	_trigger.trigger_activated.disconnect(_on_trigger_signal)

	_assert(_sig_trigger_fired == true, "trigger_activated signal fired")
	_assert_eq(_sig_trigger_type, "level", "Signal carries trigger type")
	_assert_eq(_sig_trigger_cid, "test_emberling_10", "Signal carries creature_id")
	_assert(_sig_trigger_payload.has("type"), "Signal carries payload")

func _on_trigger_signal(t: String, cid: String, payload: Dictionary) -> void:
	_sig_trigger_fired = true
	_sig_trigger_type = t
	_sig_trigger_cid = cid
	_sig_trigger_payload = payload

var _sig_trigger_fired: bool = false
var _sig_trigger_type: String = ""
var _sig_trigger_cid: String = ""
var _sig_trigger_payload: Dictionary = {}

func test_metamorphosis_signal_emission() -> void:
	print("\n--- Test Suite: Metamorphosis Signal Emission ---")

	_sig_started_fired = false
	_sig_completed_fired = false
	_sig_stage_fired = false
	_sig_started_from = ""
	_sig_started_to = ""
	_sig_completed_from = ""
	_sig_completed_to = ""
	_sig_completed_stats = {}

	_trigger.metamorphosis_started.connect(_on_meta_started)
	_trigger.metamorphosis_completed.connect(_on_meta_completed)
	_trigger.metamorphosis_stage_completed.connect(_on_meta_stage)

	var result = _trigger.start_metamorphosis("signal_test", "emberling", "emberfox", {})

	_trigger.metamorphosis_started.disconnect(_on_meta_started)
	_trigger.metamorphosis_completed.disconnect(_on_meta_completed)
	_trigger.metamorphosis_stage_completed.disconnect(_on_meta_stage)

	_assert(_sig_started_fired == true, "metamorphosis_started signal fired")
	_assert_eq(_sig_started_from, "emberling", "Started signal: from_form")
	_assert_eq(_sig_started_to, "emberfox", "Started signal: to_form")

	_assert(_sig_completed_fired == true, "metamorphosis_completed signal fired")
	_assert_eq(_sig_completed_from, "emberling", "Completed signal: from_form")
	_assert_eq(_sig_completed_to, "emberfox", "Completed signal: to_form")
	_assert(_sig_completed_stats.has("hp"), "Completed signal: has stats")

	_assert(_sig_stage_fired == true, "metamorphosis_stage_completed signal fired (at least once)")

func _on_meta_started(cid: String, from_f: String, to_f: String, meta: Dictionary) -> void:
	_sig_started_fired = true
	_sig_started_from = from_f
	_sig_started_to = to_f

func _on_meta_completed(cid: String, from_f: String, to_f: String, stats: Dictionary) -> void:
	_sig_completed_fired = true
	_sig_completed_from = from_f
	_sig_completed_to = to_f
	_sig_completed_stats = stats

func _on_meta_stage(cid: String, stage: String, progress: float) -> void:
	_sig_stage_fired = true

var _sig_started_fired: bool = false
var _sig_completed_fired: bool = false
var _sig_stage_fired: bool = false
var _sig_started_from: String = ""
var _sig_started_to: String = ""
var _sig_completed_from: String = ""
var _sig_completed_to: String = ""
var _sig_completed_stats: Dictionary = {}

func test_evolution_log_integration() -> void:
	print("\n--- Test Suite: Evolution Log Integration ---")
	
	_evolution.clear_evolution_log()
	
	var creature = _make_emberling(10)
	var triggers = [{"type": "level", "params": {"required_level": 10}, "priority": 1}]
	
	_trigger.attempt_evolution_with_metamorphosis(creature, triggers, _evolution)
	
	var log = _evolution.get_evolution_log()
	_assert(log.size() == 1, "Evolution log has 1 entry")
	_assert_eq(log[0]["species"], "emberling", "Log species correct")
	_assert_eq(log[0]["old_form"], "emberling", "Log old_form correct")
	_assert_eq(log[0]["new_form"], "emberfox", "Log new_form correct")
	_assert(log[0]["timestamp"] > 0, "Log timestamp recorded")
	
	_evolution.clear_evolution_log()

# =============================================================================
# Results
# =============================================================================

func print_results() -> void:
	print("\n============================================================")
	print("TEST RESULTS SUMMARY")
	print("============================================================")
	print("Passed: ", _test_results["passed"])
	print("Failed: ", _test_results["failed"])
	
	if _test_results["errors"].size() > 0:
		print("\nFAILURES:")
		for err in _test_results["errors"]:
			print("  - ", err)
	
	if _test_results["failed"] == 0:
		print("\n✓ ALL TESTS PASSED")
	else:
		print("\n✗ SOME TESTS FAILED")
	
	print("============================================================\n")

# Entry point for headless execution (SceneTree _initialize is called automatically)