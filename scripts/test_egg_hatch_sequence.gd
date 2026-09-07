# test_egg_hatch_sequence.gd — SceneTree runner for EggHatchSequence (RefCounted).
# FORGE: headless execution test. Run with:
#   godot --headless --path C:/Users/bluue/Documents/Galage --script res://scripts/test_egg_hatch_sequence.gd

extends SceneTree

func _init() -> void:
	var script: GDScript = load("res://scripts/egg_hatch_sequence.gd")
	var seq: EggHatchSequence = script.new()
	var results: Dictionary = seq.run_tests()

	var all_passed: bool = true
	for key in results:
		var passed: bool = results[key]
		var status: String = "PASS" if passed else "FAIL"
		print("test_egg_hatch_sequence: %s - %s" % [status, key])
		if not passed:
			all_passed = false

	if all_passed:
		print("test_egg_hatch_sequence: ALL TESTS PASSED")
		quit(0)
	else:
		print("test_egg_hatch_sequence: SOME TESTS FAILED")
		quit(1)