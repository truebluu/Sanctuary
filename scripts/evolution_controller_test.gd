# EvolutionController Headless Test Runner — SANCTUARY-014
# SceneTree runner for headless validation of EvolutionController.
# Instantiates EvolutionController, calls run_headless_test(), prints PASS/FAIL, exits with code.
extends SceneTree

var _controller: EvolutionController

func _init() -> void:
	pass

func _initialize() -> void:
	print("EvolutionControllerTestRunner: initializing...")
	_controller = EvolutionController.new()
	# Add to root so _ready runs (wires signals, initializes EvolutionTree)
	root.add_child(_controller)
	# Give it a frame to initialize, then run tests
	call_deferred("_run_tests")

func _run_tests() -> void:
	var ok: bool = _controller.run_headless_test()
	if not ok:
		push_error("EvolutionController: headless self-test FAILED")
		quit(1)
	else:
		print("EvolutionController: headless self-test PASSED")
		quit(0)

func _finalize() -> void:
	if is_instance_valid(_controller):
		_controller.queue_free()
	_controller = null