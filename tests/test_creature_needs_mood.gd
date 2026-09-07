extends SceneTree
## Smoke test for CreatureNeedsEngine (RefCounted) — Sanctuary SANCTUARY-018.
func _initialize() -> void:
	var script_ref = load("res://scripts/creature_needs_mood.gd")
	if script_ref == null:
		print("SMOKE_FAIL: cannot load creature_needs_mood.gd"); quit(1); return
	var c = script_ref.new()
	if c == null:
		print("SMOKE_FAIL: new() returned null"); quit(1); return
	var failures: Array[String] = []
	# 1000-tick sim
	var triggers: Array = c.simulate_ticks(1000, 1.0)
	if not triggers.is_empty():
		print("SMOKE_INFO: triggers fired: %s" % str(triggers))
	# Health stays in range
	var h = c.get_health()
	if h < -0.01 or h > 1.01:
		failures.append("health out of range: %s" % str(h))
	# get_mood returns a StringName/String
	var mood = c.get_mood()
	if not (mood is StringName or mood is String):
		failures.append("get_mood() returned unexpected type: %s" % str(mood))
	# A 1000-tick run should have triggered at least one need-based transition
	if triggers.is_empty():
		failures.append("no behavior triggers fired in 1000 ticks (mood never changed)")
	if failures.is_empty():
		print("SMOKE_PASS: creature_needs_mood 1000-tick OK, %d triggers" % triggers.size())
		quit(0)
	else:
		for f in failures: print("SMOKE_FAIL: " + f)
		quit(1)
