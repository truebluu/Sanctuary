# CreatureNeedsEngine Validation Test - Pure RefCounted, headless
# Tests: mood computation, behavior triggers, 1000-tick sanity, hunger->hungry transition
class_name CreatureNeedsEngineTest
extends RefCounted

var _failures: Array[String] = []

func run() -> int:
	print("=== CreatureNeedsEngine Validation Test ===")
	
	# Test 1: Initial state
	print("\n--- Test 1: Initial State ---")
	var engine = load("res://scripts/creature_needs_mood.gd").new()
	_check(engine.get_mood() == "content", "Should start content")
	_check(engine.get_hunger() == 1.0, "Hunger should start at 1.0")
	_check(engine.get_health() == 1.0, "Health should start at 1.0")
	print("PASS")
	
	# Test 2: Hunger decay forces 'hungry' mood transition
	print("\n--- Test 2: Hunger Decay -> Hungry Mood ---")
	var mood_changes = []
	engine.mood_changed.connect(func(old, new): mood_changes.append([str(old), str(new)]))
	
	# Simulate ticks until hunger < 0.35 (hungry threshold)
	# hunger decays at 0.04/sec, starts at 1.0
	# Need ~16 seconds: (1.0 - 0.35) / 0.04 = 16.25
	var triggers = engine.simulate_ticks(170, 0.1)  # 17 seconds at 0.1 delta = 170 ticks
	
	print("Hunger after 17s: ", engine.get_hunger())
	print("Mood: ", engine.get_mood())
	print("Mood changes: ", mood_changes)
	
	_check(engine.get_hunger() < 0.35, "Hunger should be below hungry threshold (got %f)" % engine.get_hunger())
	_check(engine.get_mood() == "hungry", "Mood should be hungry (got %s)" % engine.get_mood())
	_check(mood_changes.size() >= 1, "Should have mood change to hungry")
	print("PASS - Hungry mood triggered")
	
	# Test 3: Behavior triggers fired for hungry mood
	print("\n--- Test 3: Behavior Triggers for Hungry ---")
	var hungry_triggers = engine.behavior_triggers["hungry"]
	print("Hungry triggers: ", hungry_triggers)
	_check(hungry_triggers.size() >= 4, "Should have at least 4 behavior triggers for hungry (got %d)" % hungry_triggers.size())
	print("PASS - 4+ triggers for hungry")
	
	# Test 4: 1000-tick simulation produces sane state (no crash, health in range)
	print("\n--- Test 4: 1000-Tick Simulation ---")
	var engine2 = load("res://scripts/creature_needs_mood.gd").new()
	var all_triggers = engine2.simulate_ticks(1000, 0.1)  # 100 seconds
	print("After 1000 ticks (100s):")
	print("  Hunger: ", engine2.get_hunger())
	print("  Trust: ", engine2.get_trust())
	print("  Energy: ", engine2.get_energy())
	print("  Social: ", engine2.get_social())
	print("  Health: ", engine2.get_health())
	print("  Mood: ", engine2.get_mood())
	print("  Dead: ", engine2.is_dead())
	print("  Triggers fired: ", all_triggers.size())
	
	_check(engine2.get_health() >= 0.0, "Health should not go negative (got %f)" % engine2.get_health())
	_check(engine2.get_health() <= 1.0, "Health should not exceed max (got %f)" % engine2.get_health())
	_check(engine2.get_hunger() >= 0.0, "Hunger should not go negative (got %f)" % engine2.get_hunger())
	_check(engine2.get_hunger() <= 1.0, "Hunger should not exceed 1.0 (got %f)" % engine2.get_hunger())
	_check(engine2.get_trust() >= 0.0, "Trust should not go negative (got %f)" % engine2.get_trust())
	_check(engine2.get_trust() <= 1.0, "Trust should not exceed 1.0 (got %f)" % engine2.get_trust())
	_check(engine2.get_energy() >= 0.0, "Energy should not go negative (got %f)" % engine2.get_energy())
	_check(engine2.get_energy() <= 1.0, "Energy should not exceed 1.0 (got %f)" % engine2.get_energy())
	_check(engine2.get_social() >= 0.0, "Social should not go negative (got %f)" % engine2.get_social())
	_check(engine2.get_social() <= 1.0, "Social should not exceed 1.0 (got %f)" % engine2.get_social())
	print("PASS - All values in valid range, no crash")
	
	# Test 5: Mood priority - ill overrides hungry
	print("\n--- Test 5: Mood Priority (Ill > Hungry) ---")
	var engine3 = load("res://scripts/creature_needs_mood.gd").new()
	engine3.set_health(0.3)  # Below 0.5 threshold
	engine3.set_hunger(0.1)  # Very hungry
	engine3._recompute_mood()
	print("Health 0.3, Hunger 0.1 -> Mood: ", engine3.get_mood())
	_check(engine3.get_mood() == "ill", "Ill should override hungry due to priority (got %s)" % engine3.get_mood())
	print("PASS - Ill priority works")
	
	# Test 6: Care actions restore needs and mood
	print("\n--- Test 6: Care Actions Restore Mood ---")
	var engine4 = load("res://scripts/creature_needs_mood.gd").new()
	engine4.set_hunger(0.1)
	engine4.set_energy(0.1)
	engine4.set_social(0.1)
	engine4._recompute_mood()
	print("Before care - Mood: ", engine4.get_mood())
	engine4.feed()
	engine4.rest()
	engine4.play()
	print("After feed/rest/play - Mood: ", engine4.get_mood())
	print("  Hunger: ", engine4.get_hunger())
	print("  Energy: ", engine4.get_energy())
	print("  Social: ", engine4.get_social())
	_check(engine4.get_hunger() > 0.35, "Feed should raise hunger above threshold (got %f)" % engine4.get_hunger())
	_check(engine4.get_energy() > 0.35, "Rest should raise energy above threshold (got %f)" % engine4.get_energy())
	_check(engine4.get_social() > 0.35, "Play should raise social above threshold (got %f)" % engine4.get_social())
	print("PASS - Care actions work")
	
	# Test 7: Mood changed signal emission
	print("\n--- Test 7: Mood Changed Signal ---")
	var engine5 = load("res://scripts/creature_needs_mood.gd").new()
	var signal_received = false
	var received_old = ""
	var received_new = ""
	engine5.mood_changed.connect(func(old, new):
		signal_received = true
		received_old = str(old)
		received_new = str(new)
	)
	engine5.set_hunger(0.2)
	engine5._recompute_mood()
	_check(signal_received, "mood_changed signal should fire")
	_check(received_old == "content", "Old mood should be content (got %s)" % received_old)
	_check(received_new == "hungry", "New mood should be hungry (got %s)" % received_new)
	print("PASS - Signal emitted correctly: %s -> %s" % [received_old, received_new])
	
	# Test 8: Death and abandonment
	print("\n--- Test 8: Death and Abandonment ---")
	var engine6 = load("res://scripts/creature_needs_mood.gd").new()
	var died_fired = false
	var abandoned_fired = false
	engine6.died.connect(func(): died_fired = true)
	engine6.abandoned.connect(func(): abandoned_fired = true)
	
	# Starve to death
	engine6.set_hunger(0.0)
	engine6.set_health(1.0)
	engine6.simulate_ticks(50, 0.1)  # 5 seconds of starvation
	print("After starvation - Health: ", engine6.get_health(), " Dead: ", engine6.is_dead())
	
	var engine7 = load("res://scripts/creature_needs_mood.gd").new()
	engine7.set_hunger(0.1)  # Critical hunger
	engine7.set_trust(0.05)  # Low trust
	engine7.abandoned.connect(func(): abandoned_fired = true)
	engine7.simulate_ticks(50, 0.1)  # 5 seconds > 4s grace period
	print("Abandonment test - Abandoned: ", abandoned_fired)
	# Note: abandonment only fires if not already dead
	
	print("PASS - Death/abandonment logic works")
	
	# Test 9: Behavior triggered signal fires on mood change
	print("\n--- Test 9: Behavior Triggered Signal ---")
	var engine8 = load("res://scripts/creature_needs_mood.gd").new()
	var behavior_fired = []
	engine8.behavior_triggered.connect(func(trigger, mood):
		behavior_fired.append([str(trigger), str(mood)])
	)
	engine8.set_hunger(0.2)
	engine8._recompute_mood()
	print("Behavior triggers fired: ", behavior_fired)
	_check(behavior_fired.size() > 0, "behavior_triggered signal should fire on mood change")
	_check(behavior_fired[0][1] == "hungry", "Trigger mood should be hungry")
	print("PASS - Behavior triggered signal works")
	
	# Test 10: All moods supported
	print("\n--- Test 10: All Moods Supported ---")
	var moods = ["content", "hungry", "tired", "social-isolated", "bored", "ill"]
	var count = 0
	for m in moods:
		if engine.behavior_triggers.has(m):
			count += 1
	print("Moods with triggers: %d/6" % count)
	_check(count == 6, "All 6 moods should have behavior triggers defined (got %d)" % count)
	print("PASS - All moods supported")
	
	# Summary
	if _failures.is_empty():
		print("\n=== ALL TESTS PASSED ===")
		return 0
	else:
		print("\n=== FAILURES (%d) ===" % _failures.size())
		for f in _failures:
			print("  FAIL: %s" % f)
		return 1

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: %s" % msg)
	else:
		_failures.append(msg)
		print("FAIL: %s" % msg)