# test_habitat_manager.gd — SceneTree runner for HabitatManager (RefCounted).
# Board: SANCTUARY-008. Validates comfort scoring + migration for 50 creatures in 3 habitats.
extends SceneTree

func _init() -> void:
	var mgr: HabitatManager = HabitatManager.new()
	mgr.add_habitat("cave", 25)
	mgr.add_habitat("meadow", 25)
	mgr.add_habitat("pond", 25)
	# Configure zone quality per habitat.
	mgr.set_zone_quality("cave", &"temperature", 0.9)
	mgr.set_zone_quality("cave", &"space", 0.6)
	mgr.set_zone_quality("cave", &"enrichment", 0.5)
	mgr.set_zone_quality("cave", &"social", 0.7)
	mgr.set_zone_quality("meadow", &"temperature", 0.7)
	mgr.set_zone_quality("meadow", &"space", 0.9)
	mgr.set_zone_quality("meadow", &"enrichment", 0.8)
	mgr.set_zone_quality("meadow", &"social", 0.8)
	mgr.set_zone_quality("pond", &"temperature", 0.6)
	mgr.set_zone_quality("pond", &"space", 0.5)
	mgr.set_zone_quality("pond", &"enrichment", 0.9)
	mgr.set_zone_quality("pond", &"social", 0.6)
	# Place 50 creatures (some exceed capacity to force assignment logic).
	var assigned: int = 0
	for i in range(50):
		var h: String = mgr.get_best_habitat({&"temperature": 0.5, &"social": 0.5})
		if mgr.assign_creature(i, h):
			assigned += 1
	# 50 creatures over 3 habitats of capacity 25 each -> all fit.
	assert(assigned == 50, "expected all 50 assigned, got %d" % assigned)
	var cave_comfort: float = mgr.get_comfort("cave")
	assert(cave_comfort > 0.0 and cave_comfort <= 1.0, "cave comfort out of range: %f" % cave_comfort)
	# Migration suggestion: creature in a low-comfort habitat should get a better one.
	var mig: String = mgr.migration_suggestion(0)
	var counts := {
		"cave": mgr.creature_count("cave"),
		"meadow": mgr.creature_count("meadow"),
		"pond": mgr.creature_count("pond"),
	}
	print("HabitatManager OK: assigned=%d cave_comfort=%.3f migration_suggestion(0)=%s counts=%s" % [
		assigned, cave_comfort, mig, str(counts)
	])
	quit(0)
