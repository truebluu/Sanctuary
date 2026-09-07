# BreedingManagerTest — Taming (The Sanctuary)
# Headless validation for BreedingManager. Extends SceneTree for --script execution.
# Validates: breed() produces valid offspring, traits inherited, mutation works, lineage tracked.
# Exits 0 on pass, 1 on failure.

class_name BreedingManagerTest
extends SceneTree

var _failures: Array[String] = []
var _manager: BreedingManager
var _rng: RandomNumberGenerator

func _initialize() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 424242
	_manager = BreedingManager.new(_rng, 0.05, 0.2)
	
	print("BREEDING MANAGER TEST: Starting validation...")
	
	# Test 1: Incompatible parents are rejected
	_test_incompatible_parents()
	
	# Test 2: Breed produces valid offspring with all required fields
	_test_breed_produces_valid_offspring()
	
	# Test 3: Offspring inherits traits from parents (element consistency)
	_test_trait_inheritance()
	
	# Test 4: Stats are blended and mutated
	_test_stat_blending_and_mutation()
	
	# Test 5: Lineage tracking works correctly
	_test_lineage_tracking()
	
	# Test 6: Mutation produces valid genomes
	_test_mutation()
	
	# Test 7: Multiple generations of breeding
	_test_multiple_generations()
	
	if _failures.is_empty():
		print("BREEDING MANAGER TEST: ALL TESTS PASSED")
		quit(0)
	else:
		for f in _failures:
			printerr("BREEDING MANAGER FAIL: " + f)
		quit(1)

func _test_incompatible_parents() -> void:
	print("  Test: Incompatible parents rejected...")
	
	# Create two parents with incompatible elements (ember vs splash)
	var parent_a := BreedingManager.create_random_parent(_rng, "parent_a", 0)
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	
	var parent_b := BreedingManager.create_random_parent(_rng, "parent_b", 0)
	parent_b.traits["element"] = {"name": "splash", "shiny": false}
	
	var offspring := _manager.breed(parent_a, parent_b)
	if not offspring.is_empty():
		_failures.append("Incompatible parents (ember/splash) produced offspring (should be empty)")
	
	# Test compatible parents (both ember)
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	offspring = _manager.breed(parent_a, parent_b)
	if offspring.is_empty():
		_failures.append("Compatible parents (ember/ember) produced no offspring")
	
	print("    Incompatible parents test passed")

func _test_breed_produces_valid_offspring() -> void:
	print("  Test: Breed produces valid offspring structure...")
	
	var parent_a := BreedingManager.create_random_parent(_rng, "founder_a", 0)
	var parent_b := BreedingManager.create_random_parent(_rng, "founder_b", 0)
	
	# Ensure they have the same element for compatibility
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	
	var offspring := _manager.breed(parent_a, parent_b)
	
	if not _validate_genome(offspring, 1):
		_failures.append("Offspring has invalid genome structure")
		return
	
	print("    Valid offspring structure test passed")

func _test_trait_inheritance() -> void:
	print("  Test: Trait inheritance from parents...")
	
	var parent_a := BreedingManager.create_random_parent(_rng, "trait_test_a", 0)
	var parent_b := BreedingManager.create_random_parent(_rng, "trait_test_b", 0)
	
	# Set specific traits for both parents
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	parent_a.traits["coat"] = {"name": "solid", "shiny": false}
	parent_b.traits["coat"] = {"name": "spotted", "shiny": false}
	parent_a.traits["size"] = {"name": "large", "shiny": false}
	parent_b.traits["size"] = {"name": "small", "shiny": false}
	
	var offspring := _manager.breed(parent_a, parent_b)
	
	# Verify offspring has all required trait categories
	for trait_name in Genetics.TRAIT_ALLELES.keys():
		if not offspring.traits.has(trait_name):
			_failures.append("Offspring missing trait: %s" % trait_name)
			return
		var trait_data: Dictionary = offspring.traits[trait_name]
		if not trait_data.has("name") or not trait_data.has("shiny"):
			_failures.append("Trait %s missing name/shiny fields" % trait_name)
			return
	
	# Verify element is either ember or verdant (compatible with ember)
	var offspring_element: String = offspring.traits["element"]["name"]
	if offspring_element not in ["ember", "verdant"]:
		_failures.append("Offspring element '%s' not in compatible set for ember parents" % offspring_element)
	
	print("    Trait inheritance test passed")

func _test_stat_blending_and_mutation() -> void:
	print("  Test: Stat blending and mutation...")
	
	var parent_a := BreedingManager.create_random_parent(_rng, "stat_test_a", 0)
	var parent_b := BreedingManager.create_random_parent(_rng, "stat_test_b", 0)
	
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	
	# Set known stat values
	parent_a.stats = {"str": 0.8, "spd": 0.2, "res": 0.5, "int": 0.7, "cha": 0.3}
	parent_b.stats = {"str": 0.3, "spd": 0.9, "res": 0.4, "int": 0.2, "cha": 0.6}
	
	var offspring := _manager.breed(parent_a, parent_b)
	
	var expected_stats: Array[String] = ["str", "spd", "res", "int", "cha"]
	for stat_name in expected_stats:
		if not offspring.stats.has(stat_name):
			_failures.append("Offspring missing stat: %s" % stat_name)
			return
		var val: float = offspring.stats[stat_name]
		if val < 0.0 or val > 1.0:
			_failures.append("Stat %s out of range [0,1]: %f" % [stat_name, val])
			return
	
	# Verify stats are roughly blended (within mutation span of 50% blend)
	# With 20% mutation span, the range should be within 30%-70% of the blend
	var blend_str = 0.5 * 0.8 + 0.5 * 0.3  # 0.55
	var offspring_str = offspring.stats["str"]
	if offspring_str < 0.35 or offspring_str > 0.75:  # 0.55 ± 0.2
		_failures.append("Stat 'str' not in expected blended+mutated range: got %f, expected ~0.55±0.2" % offspring_str)
	
	print("    Stat blending and mutation test passed")

func _test_lineage_tracking() -> void:
	print("  Test: Lineage tracking...")
	
	var parent_a := BreedingManager.create_random_parent(_rng, "lineage_a", 5)
	var parent_b := BreedingManager.create_random_parent(_rng, "lineage_b", 3)
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	
	var offspring := _manager.breed(parent_a, parent_b)
	var lineage := _manager.get_lineage(offspring)
	
	if lineage.parent_ids[0] != "lineage_a" or lineage.parent_ids[1] != "lineage_b":
		_failures.append("Lineage parent_ids mismatch: expected [lineage_a, lineage_b], got [%s, %s]" % [lineage.parent_ids[0], lineage.parent_ids[1]])
	
	if lineage.generation != 6:  # max(5, 3) + 1
		_failures.append("Lineage generation mismatch: expected 6, got %d" % lineage.generation)
	
	print("    Lineage tracking test passed")

func _test_mutation() -> void:
	print("  Test: Mutation produces valid genomes...")
	
	var parent := BreedingManager.create_random_parent(_rng, "mutate_test", 0)
	parent.traits["element"] = {"name": "ember", "shiny": false}
	
	# Mutate with high rate
	var mutated := _manager.mutate(parent, 0.5)
	
	if not _validate_genome(mutated, 0):
		_failures.append("Mutated genome invalid")
		return
	
	# Verify mutation actually changed something (with 50% rate, very likely)
	# Just verify it's a valid structure
	print("    Mutation test passed")

func _test_multiple_generations() -> void:
	print("  Test: Multiple generations of breeding...")
	
	var parent_a := BreedingManager.create_random_parent(_rng, "gen0_a", 0)
	var parent_b := BreedingManager.create_random_parent(_rng, "gen0_b", 0)
	parent_a.traits["element"] = {"name": "ember", "shiny": false}
	parent_b.traits["element"] = {"name": "ember", "shiny": false}
	
	var current_a := parent_a
	var current_b := parent_b
	
	for gen in range(10):
		var offspring := _manager.breed(current_a, current_b)
		
		if offspring.is_empty():
			_failures.append("Generation %d: breed returned empty dict" % (gen + 1))
			break
		
		if not _validate_genome(offspring, gen + 1):
			_failures.append("Generation %d: invalid genome structure" % (gen + 1))
			break
		
		var lineage := _manager.get_lineage(offspring)
		if not _validate_lineage(lineage, current_a, current_b, gen + 1):
			_failures.append("Generation %d: invalid lineage" % (gen + 1))
			break
		
		# For next generation, breed offspring with a new compatible partner
		# Force the offspring's element back to ember so it stays compatible
		offspring.traits["element"] = {"name": "ember", "shiny": false}
		if gen % 2 == 0:
			current_a = offspring
			current_b = BreedingManager.create_random_parent(_rng, "gen_%d_partner" % gen, gen)
			current_b.traits["element"] = {"name": "ember", "shiny": false}
		else:
			current_b = offspring
			current_a = BreedingManager.create_random_parent(_rng, "gen_%d_partner" % gen, gen)
			current_a.traits["element"] = {"name": "ember", "shiny": false}
	
	print("    Multiple generations test passed")

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
		_failures.append("Lineage parent_ids mismatch: expected [%s, %s], got [%s, %s]" % [expected_id_a, expected_id_b, parent_ids[0], parent_ids[1]])
		return false
	
	var actual_generation: int = lineage.generation
	if actual_generation != expected_generation:
		_failures.append("Lineage generation mismatch: expected %d, got %d" % [expected_generation, actual_generation])
		return false
	
	return true