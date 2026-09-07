# EcosystemSimulation Headless Test Runner
# Inherits from SceneTree to run headless via --script
extends SceneTree

func _initialize() -> void:
	var sim: EcosystemSimulation = EcosystemSimulation.new()
	var ok: bool = sim.run_headless_test()
	if not ok:
		push_error("EcosystemSimulation: headless self-test FAILED")
		quit(1)
	else:
		print("EcosystemSimulation: headless self-test PASSED")
		quit(0)
