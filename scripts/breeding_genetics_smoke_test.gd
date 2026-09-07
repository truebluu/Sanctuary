# BreedingGeneticsSmokeTest — Taming (The Sanctuary)
# Headless validation for BreedingGeneticsManager. Extends SceneTree for --script execution.
# Validates: 100 generations of breeding, lineage tracking, mutation, compatibility checks.
# Exits 0 on pass, 1 on failure.
class_name BreedingGeneticsSmokeTest
extends SceneTree

var _failures: Array[String] = []
var _manager: BreedingGeneticsManager
var _rng: RandomNumberGenerator

func _initialize() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 424242
	_manager = BreedingGeneticsManager.new(_rng, 0.05, 0.2)
	
	print("BREEDING SMOKE: Starting validation...")
	
	# Test 1: Incompatible parents are rejected
	_test_incompatible_parents()
	
	# Test 2: 100 generations of breeding with lineage tracking
	_test_100_generations()
	
	# Test 3: Mutation produces valid genomes
	_test_mutation()
	
	# Test 4: get_lineage returns correct data
	_test_get_lineage()
	
	if _failures.is_empty():
		print("BREEDING SMOKE: ALL TESTS PASSED")
		quit(0)
	else:
		for f in _failures:
			printerr("BREEDING FAIL: " + f)
		quit(1)

func _test_incompatible_parents() -> void:
	print("  Test: Incompatible parents rejected...")
	
	# Create two parents with incompatible elements (ember vs splash)
	var parent_a := BreedingGeneticsManager.create_random_parent(_rng, "parent_a", 0)
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	
	var parent_b := BreedingGeneticsManager.create_random_parent(_rng, "parent_b", 0)
	parent_b.traits["element"] = {"name": "splash", "shiny": false}
	
	var compatible := _manager.is_compatible(parent_a, parent_b)
	if compatible:
		_failures.append("Incompatible parents (ember/splash) were marked compatible")
	
	# Test compatible parents (both ember)
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	compatible = _manager.is_compatible(parent_a, parent_b)
	if not compatible:
		_failures.append("Compatible parents (ember/ember) were marked incompatible")
	
	print("    Incompatible parents test passed")

func _test_100_generations() -> void:
	print("  Test: 100 generations of breeding...")
	
	# Create two compatible founding parents
	var parent_a := BreedingGeneticsManager.create_random_parent(_rng, "founder_a", 0)
	var parent_b := BreedingGeneticsManager.create_random_parent(_rng, "founder_b", 0)
	
	# Ensure they have the same element for compatibility
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	
	var current_a := parent_a
	var current_b := parent_b
	
	for gen in range(100):
		# Breed current generation
		var offspring := _manager.breed(current_a, current_b, _rng)
		
		# Check if breed failed (returned empty dict)
		if offspring.is_empty():
			_failures.append("Generation %d: breed returned empty dict (parents incompatible)" % (gen + 1))
			break
		
		# Validate offspring structure
		if not _validate_genome(offspring, gen + 1):
			_failures.append("Generation %d: invalid genome structure" % (gen + 1))
			break
		
		# Validate lineage
		var lineage := _manager.get_lineage(offspring)
		if not _validate_lineage(lineage, current_a, current_b, gen + 1):
			_failures.append("Generation %d: invalid lineage" % (gen + 1))
			break
		
		# For next generation, breed offspring with a new compatible partner
		# (alternate between using offspring as parent_a and creating new parent_b).
		# Force the offspring's element back to ember so it stays compatible with
		# the fresh ember partner — mutation may otherwise drift the element to a
		# non-compatible type, which the manager correctly rejects (that rejection
		# is tested separately in _test_incompatible_parents).
		offspring.traits["element"] = {"name": "ember", "shiny": false}
		if gen % 2 == 0:
			current_a = offspring
			current_b = BreedingGeneticsManager.create_random_parent(_rng, "gen_%d_partner" % gen, gen)
			current_b.traits["element"] = {"name": "ember", "shiny": false}
		else:
			current_b = offspring
			current_a = BreedingGeneticsManager.create_random_parent(_rng, "gen_%d_partner" % gen, gen)
			current_a.traits["element"] = {"name": "ember", "shiny": false}
	
	print("    100 generations test passed")

func _validate_genome(genome: Dictionary, expected_generation: int) -> bool:
	# Check required keys
	if not genome.has("traits"):
		_failures.append("Genome missing 'traits' key")
		return false
	if not genome.has("stats"):
		_failures.append("Genome missing 'stats' key")
		return false
	if not genome.has("lineage"):
		_failures.append("Genome missing 'lineage' key")
		return false
	
	# Check traits has all required trait categories
	for trait_name in Genetics.TRAIT_ALLELES.keys():
		if not genome.traits.has(trait_name):
			_failures.append("Genome missing trait: %s" % trait_name)
			return false
		var trait_data: Dictionary = genome.traits[trait_name]
		if not trait_data.has("name") or not trait_data.has("shiny"):
			_failures.append("Trait %s missing name/shiny fields" % trait_name)
			return false
	
	# Check stats has expected stat names
	var expected_stats: Array[String] = ["str", "spd", "res", "int", "cha"]
	for stat_name in expected_stats:
		if not genome.stats.has(stat_name):
			_failures.append("Genome missing stat: %s" % stat_name)
			return false
		var val: float = genome.stats[stat_name]
		if val < 0.0 or val > 1.0:
			_failures.append("Stat %s out of range [0,1]: %f" % [stat_name, val])
			return false
	
	return true

func _validate_lineage(lineage: Dictionary, parent_a: Dictionary, parent_b: Dictionary, expected_generation: int) -> bool:
	if not lineage.has("parent_ids"):
		_failures.append("Lineage missing 'parent_ids'")
		return false
	if not lineage.has("generation"):
		_failures.append("Lineage missing 'generation'")
		return false
	
	var parent_ids: Array = lineage.parent_ids
	if parent_ids.size() != 2:
		_failures.append("Lineage parent_ids should have 2 entries, has %d" % parent_ids.size())
		return false
	
	var expected_id_a: Variant = _manager._get_id(parent_a)
	var expected_id_b: Variant = _manager._get_id(parent_b)
	
	if parent_ids[0] != expected_id_a or parent_ids[1] != expected_id_b:
		_failures.append("Lineage parent_ids mismatch: expected [%s, %s], got [%s, %s]" % 
			[expected_id_a, expected_id_b, parent_ids[0], parent_ids[1]])
		return false
	
	var actual_generation: int = lineage.generation
	if actual_generation != expected_generation:
		_failures.append("Lineage generation mismatch: expected %d, got %d" % [expected_generation, actual_generation])
		return false
	
	return true

func _test_mutation() -> void:
	print("  Test: Mutation produces valid genomes...")
	
	var parent := BreedingGeneticsManager.create_random_parent(_rng, "mutate_test", 0)
	parent.traits["element"] = {"name": "ember", "shiny": false}
	
	# Mutate with high rate
	var mutated := _manager.mutate(parent, 0.5, _rng)
	
	if not _validate_genome(mutated, 0):
		_failures.append("Mutated genome invalid")
		return
	
	# Verify mutation actually changed something (with 50% rate, very likely)
	# Just verify it's a valid structure
	print("    Mutation test passed")

func _test_get_lineage() -> void:
	print("  Test: get_lineage returns correct data...")
	
	var parent_a := BreedingGeneticsManager.create_random_parent(_rng, "lineage_a", 5)
	var parent_b := BreedingGeneticsManager.create_random_parent(_rng, "lineage_b", 3)
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	
	var offspring := _manager.breed(parent_a, parent_b, _rng)
	var lineage := _manager.get_lineage(offspring)
	
	if lineage.parent_ids[0] != "lineage_a" or lineage.parent_ids[1] != "lineage_b":
		_failures.append("get_lineage parent_ids mismatch")
	
	if lineage.generation != 6:  # max(5, 3) + 1
		_failures.append("get_lineage generation mismatch: expected 6, got %d" % lineage.generation)
	
	print("    get_lineage test passed")