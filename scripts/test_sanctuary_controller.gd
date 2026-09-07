# test_sanctuary_controller.gd
# SceneTree-based smoke test runner for SanctuaryController
# Extends SceneTree to run headless tests on the SanctuaryPanel via its scene

extends SceneTree

func _initialize() -> void:
	print("=== SanctuaryController Smoke Test Runner ===")
	
	# Instantiate the SanctuaryController scene
	var scene = load("res://scenes/sanctuary_controller.tscn")
	if scene == null:
		printerr("FAIL: Could not load scene res://scenes/sanctuary_controller.tscn")
		quit(1)
		return
	
	var controller = scene.instantiate()
	if controller == null:
		printerr("FAIL: Could not instantiate SanctuaryController scene")
		quit(1)
		return
	
	# Add to scene tree so _ready() is called (builds UI)
	root.add_child(controller)
	
	# Call the headless test (no await needed - run_headless_test is synchronous)
	var success = controller.run_headless_test()
	
	if success:
		print("=== SanctuaryController Smoke Test: PASSED ===")
		quit(0)
	else:
		printerr("=== SanctuaryController Smoke Test: FAILED ===")
		quit(1)
