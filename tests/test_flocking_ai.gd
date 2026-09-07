# test_flocking_ai.gd — SceneTree runner for FlockingAI (RefCounted).
# Board: SANCTUARY-011. Validates flocking simulation produces group cohesion.
extends SceneTree

func _init() -> void:
	var flock: FlockingAI = FlockingAI.new()
	flock.neighbor_radius = 200.0   # agents interact across a wide area
	flock.max_speed = 150.0
	# Start 10 agents in a moderately-spread ring so they can see each other
	# (within neighbor_radius) but are NOT overlapping (avoids blast-apart).
	for i in range(10):
		var ang: float = (float(i) / 10.0) * TAU
		var pos: Vector2 = Vector2(cos(ang), sin(ang)) * 60.0
		flock.add_agent(i, pos, Vector2(30, 0))
		flock.set_personality(i, 0.6, 0.2)
	# Cohesion-dominant weights (low separation) so a real flock forms.
	flock.set_weights(0.3, 0.8, 1.4)
	# Simulate 6 seconds.
	for _step in range(360):
		flock.step(1.0 / 60.0)
	var cohesion: float = flock.cohesion_metric()
	if cohesion <= 0.0:
		push_error("FlockingAI FAIL: cohesion=%f (expected >0 after 6s sim)" % cohesion)
		var p := ""
		for i in range(10):
			p += str(flock.get_position(i)) + " "
		print("flock positions:", p)
		quit(1)
		return
	print("FlockingAI OK: agents=%d cohesion=%.3f pos0=%s" % [
		flock.get_agents().size(), cohesion, str(flock.get_position(0))
	])
	quit(0)
