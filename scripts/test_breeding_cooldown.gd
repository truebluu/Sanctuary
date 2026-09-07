# test_breeding_cooldown.gd — Headless SceneTree validation for BreedingCooldown.
# Run: godot --headless --path . --script scripts/test_breeding_cooldown.gd
extends SceneTree

var _test_passed: bool = false

func _initialize() -> void:
	print("\n=== BreedingCooldown Headless Test ===\n")
	var script_res = load("res://scripts/breeding_cooldown.gd")
	var instance = script_res.new()
	_test_passed = instance.run_test()
	print("\n=== SUMMARY ===")
	if _test_passed:
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL")
		quit(1)
