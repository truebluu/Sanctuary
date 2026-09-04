# sanctuary_demo_test.gd — Headless integration test for the Sanctuary demo
# Simulates the demo flow: reroll parents -> breed -> verify offspring phenotype
# + stat power. Exits 0 on pass, 1 on failure.
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("SANCTUARY DEMO TEST: Starting...")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260828

	# Simulate GameState.new_random_parent
	var a := CreatureGenome.create_random_base_genome(rng, 0.5, 0.4, "drake")
	var b := CreatureGenome.create_random_base_genome(rng, 0.5, 0.4, "drake")
	_check(a != null, "parent A created")
	_check(b != null, "parent B created")

	# Simulate GameState.breed
	var child := CreatureGenome.breed(a, b, CreatureGenome.DEFAULT_MUTATION_RATE, rng)
	_check(child != null, "offspring created")
	_check(child.generation == 1, "offspring generation == 1 (got %d)" % child.generation)

	# Phenotype
	var ph := child.compute_phenotype(rng)
	_check(ph.has("element") and ph.has("coat") and ph.has("size"), "phenotype has all traits")
	_check(ph["element"].has("name"), "phenotype element has name")

	# Stat power
	var power := child.compute_stat_power({"hp": 100, "attack": 50, "defense": 50, "speed": 60, "special": 40}, rng)
	_check(power.has("hp") and power.has("attack"), "stat power computed")
	_check(power["hp"] > 0, "hp > 0 (got %d)" % power["hp"])

	# Describe
	var desc := child.describe(rng)
	_check(desc.length() > 0, "describe returns non-empty")

	if _failures.is_empty():
		print("SANCTUARY DEMO TEST: ALL PASSED")
		quit(0)
	else:
		print("SANCTUARY DEMO TEST: %d FAILURES" % _failures.size())
		for f in _failures:
			print("  FAIL: %s" % f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		_failures.append(msg)
		print("  FAIL: %s" % msg)
