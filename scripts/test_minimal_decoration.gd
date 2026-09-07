# Minimal test for DecorationSystem
extends SceneTree

func _initialize() -> void:
	print("=== Minimal DecorationSystem Test ===")
	var ds := DecorationSystem.new(5, 5, 100.0)
	
	# Test basic placement
	var id = ds.place_decoration("toy_ball", 1, 1)
	print("Placed: %s" % id)
	assert(id != "", "Placement should succeed")
	
	# Test mood boost
	var boost = ds.get_mood_boost(Vector2(1.5, 1.5))
	print("Mood boost at center: %.3f" % boost)
	assert(boost > 0.0, "Should get mood boost")
	
	# Test mood_contribution
	var contrib = ds.mood_contribution("test_creature", Vector2(1.5, 1.5))
	print("Mood contribution: %.3f" % contrib)
	assert(contrib > 0.0, "Should get mood contribution")
	
	# Test removal
	assert(ds.remove_decoration(id) == true, "Removal should succeed")
	assert(ds.get_placed_count() == 0, "Should be empty after removal")
	
	print("=== ALL TESTS PASSED ===")
	quit(0)
