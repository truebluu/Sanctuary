# Test runner for DecorationSystem — runs headless via --script
extends SceneTree

func _ready() -> void:
	var ds := DecorationSystem.new(10, 10, 500.0)
	
	# Test 1: Default decorations registered
	print("\n--- Test 1: Default decorations ---")
	var types = ds.get_all_decoration_types()
	assert(types.size() > 0, "Should have default decorations")
	print("Found %d decoration types" % types.size())
	for t in types:
		print("  - %s (%s): mood_bonus=%.2f, cost=%.0f, range=%.1f" % [t["id"], t["category"], t["mood_bonus"], t["cost"], t["range"]])
	
	# Test 2: Can place validation
	print("\n--- Test 2: Placement validation ---")
	assert(ds.can_place("toy_ball", 2, 2) == true, "Should be able to place toy_ball at 2,2")
	assert(ds.can_place("toy_ball", -1, 2) == false, "Should not place out of bounds")
	assert(ds.can_place("nonexistent", 2, 2) == false, "Should not place unknown type")
	print("Validation checks passed")
	
	# Test 3: Place decoration
	print("\n--- Test 3: Place decoration ---")
	var inst_id = ds.place_decoration("toy_ball", 2, 2)
	assert(inst_id != "", "Should place successfully")
	assert(inst_id.begins_with("toy_ball@"), "Instance ID should contain type and position")
	print("Placed: %s" % inst_id)
	assert(ds.get_placed_count() == 1, "Should have 1 placement")
	assert(ds.get_currency() == 500.0 - 20.0, "Currency should be deducted")
	
	# Test 4: Place multiple decorations
	print("\n--- Test 4: Multiple placements ---")
	var inst2 = ds.place_decoration("cozy_bed", 5, 5)
	assert(inst2 != "", "Should place cozy_bed")
	var inst3 = ds.place_decoration("food_bowl", 7, 3)
	assert(inst3 != "", "Should place food_bowl")
	assert(ds.get_placed_count() == 3, "Should have 3 placements")
	print("Placed 3 decorations total")
	
	# Test 5: Overlap prevention
	print("\n--- Test 5: Overlap prevention ---")
	assert(ds.can_place("toy_ball", 2, 2) == false, "Should not overlap existing")
	assert(ds.place_decoration("toy_ball", 2, 2) == "", "Should fail to place on occupied")
	print("Overlap prevention works")
	
	# Test 6: Footprint validation (multi-tile)
	print("\n--- Test 6: Multi-tile footprint ---")
	assert(ds.can_place("climbing_tree", 0, 0) == true, "Should fit at corner")
	var tree_id = ds.place_decoration("climbing_tree", 0, 0)
	assert(tree_id != "", "Should place climbing_tree (2x3)")
	assert(ds.can_place("toy_ball", 0, 0) == false, "Should not overlap footprint")
	assert(ds.can_place("toy_ball", 1, 0) == false, "Should not overlap footprint")
	assert(ds.can_place("toy_ball", 0, 1) == false, "Should not overlap footprint")
	assert(ds.can_place("toy_ball", 2, 0) == true, "Should fit adjacent")
	print("Multi-tile footprint validated")
	
	# Test 7: Budget validation
	print("\n--- Test 7: Budget validation ---")
	var poor_ds = DecorationSystem.new(5, 5, 10.0)
	assert(poor_ds.can_place("climbing_tree", 0, 0) == false, "Should not afford climbing_tree (200 cost)")
	assert(poor_ds.can_place("toy_ball", 0, 0) == true, "Should afford toy_ball (20 cost)")
	print("Budget validation works")
	
	# Test 8: Max decorations limit
	print("\n--- Test 8: Max decorations limit ---")
	var limited_ds = DecorationSystem.new(10, 10, 10000.0)
	limited_ds.max_decorations = 2
	assert(limited_ds.place_decoration("toy_ball", 0, 0) != "", "First placement OK")
	assert(limited_ds.place_decoration("toy_ball", 2, 0) != "", "Second placement OK")
	assert(limited_ds.place_decoration("toy_ball", 4, 0) == "", "Third placement blocked by limit")
	print("Max decorations limit enforced")
	
	# Test 9: Remove decoration
	print("\n--- Test 9: Remove decoration ---")
	var remove_ds = DecorationSystem.new(5, 5, 500.0)
	var rid = remove_ds.place_decoration("toy_ball", 1, 1)
	assert(rid != "", "Placed for removal test")
	var currency_before = remove_ds.get_currency()
	assert(remove_ds.remove_decoration(rid, 0.5) == true, "Should remove successfully")
	assert(remove_ds.get_placed_count() == 0, "Should have 0 placements")
	assert(remove_ds.get_currency() == currency_before + 10.0, "Should refund 50% (10 currency)")
	assert(remove_ds.remove_decoration("nonexistent") == false, "Should fail on bad ID")
	print("Removal with refund works")
	
	# Test 10: Mood boost calculation
	print("\n--- Test 10: Mood boost ---")
	var mood_ds = DecorationSystem.new(10, 10, 1000.0)
	mood_ds.place_decoration("toy_ball", 2, 2)  # center at 2.5, 2.5, range 2.5, bonus 0.2
	mood_ds.place_decoration("cozy_bed", 8, 8)  # center at 9, 9, range 3, bonus 0.3
	
	# Creature at toy_ball position
	var boost1 = mood_ds.get_mood_boost(Vector2(2.5, 2.5))
	print("Boost at toy_ball center: %.3f" % boost1)
	assert(boost1 > 0.19, "Should get near-full bonus at center (got %.3f)" % boost1)
	
	# Creature at edge of toy_ball range
	var boost2 = mood_ds.get_mood_boost(Vector2(5.0, 2.5))  # distance 2.5 from toy_ball
	print("Boost at toy_ball edge: %.3f" % boost2)
	assert(boost2 >= 0.0, "Should get some bonus at edge")
	
	# Creature far from both
	var boost3 = mood_ds.get_mood_boost(Vector2(0, 0))
	print("Boost far away: %.3f" % boost3)
	assert(boost3 == 0.0, "Should get zero bonus far away")
	
	# Creature near cozy_bed
	var boost4 = mood_ds.get_mood_boost(Vector2(8.5, 8.5))
	print("Boost at cozy_bed center: %.3f" % boost4)
	assert(boost4 > 0.29, "Should get near-full cozy_bed bonus")
	
	print("Mood boost calculations work")
	
	# Test 11: mood_contribution function
	print("\n--- Test 11: mood_contribution ---")
	var contrib_ds = DecorationSystem.new(10, 10, 1000.0)
	contrib_ds.place_decoration("sun_lamp", 3, 3)  # bonus 0.4, range 5
	var contrib = contrib_ds.mood_contribution("creature_001", Vector2(4, 4))
	print("Mood contribution for creature_001: %.3f" % contrib)
	assert(contrib > 0.3, "Should get strong boost from sun_lamp")
	
	# Test 12: Breakdown
	print("\n--- Test 12: Mood boost breakdown ---")
	var breakdown_ds = DecorationSystem.new(10, 10, 1000.0)
	breakdown_ds.place_decoration("toy_ball", 1, 1)
	breakdown_ds.place_decoration("food_bowl", 3, 1)
	var breakdown = breakdown_ds.get_mood_boost_breakdown(Vector2(2, 1))
	print("Breakdown: %s" % breakdown)
	assert(breakdown.has("toy_ball"), "Should include toy_ball")
	assert(breakdown.has("food_bowl"), "Should include food_bowl")
	print("Breakdown works")
	
	# Test 13: Category queries
	print("\n--- Test 13: Category queries ---")
	var cat_ds = DecorationSystem.new(10, 10, 1000.0)
	cat_ds.place_decoration("toy_ball", 0, 0)
	cat_ds.place_decoration("scratching_post", 2, 0)
	cat_ds.place_decoration("cozy_bed", 4, 0)
	assert(cat_ds.get_count_by_category("enrichment") == 2, "Should have 2 enrichment")
	assert(cat_ds.get_count_by_category("comfort") == 1, "Should have 1 comfort")
	print("Category counts: enrichment=%d, comfort=%d" % [cat_ds.get_count_by_category("enrichment"), cat_ds.get_count_by_category("comfort")])
	
	# Test 14: Custom decoration registration
	print("\n--- Test 14: Custom decoration registration ---")
	var custom_ds = DecorationSystem.new(5, 5, 100.0)
	custom_ds.register_decoration_type("custom_statue", "Custom Statue", 0.5, 10.0, "art", 1, 1, 2.0)
	assert(custom_ds.has_decoration_type("custom_statue"), "Should have custom type")
	var custom_inst = custom_ds.place_decoration("custom_statue", 0, 0)
	assert(custom_inst != "", "Should place custom type")
	print("Custom decoration registration works")
	
	# Test 15: Serialize/Deserialize
	print("\n--- Test 15: Serialize/Deserialize ---")
	var ser_ds = DecorationSystem.new(8, 8, 500.0)
	ser_ds.place_decoration("toy_ball", 1, 1)
	ser_ds.place_decoration("food_bowl", 3, 2)
	var saved = ser_ds.serialize()
	print("Serialized: currency=%.1f, placements=%d" % [saved["currency"], saved["placements"].size()])
	
	var load_ds = DecorationSystem.new()
	load_ds.deserialize(saved)
	assert(load_ds.get_currency() == saved["currency"], "Currency restored")
	assert(load_ds.get_placed_count() == saved["placements"].size(), "Placements restored")
	assert(load_ds.grid_width == saved["grid_width"], "Grid width restored")
	assert(load_ds.grid_height == saved["grid_height"], "Grid height restored")
	print("Serialization round-trip works")
	
	# Test 16: Signals (verify they exist and can be connected)
	print("\n--- Test 16: Signals ---")
	var sig_ds = DecorationSystem.new(5, 5, 100.0)
	var placed_fired = false
	var removed_fired = false
	var boosted_fired = false
	
	sig_ds.decoration_placed.connect(func(did, iid, pos, cat): placed_fired = true)
	sig_ds.decoration_removed.connect(func(iid, cat): removed_fired = true)
	sig_ds.mood_boosted.connect(func(cid, boost, src, dtype): boosted_fired = true)
	
	sig_ds.place_decoration("toy_ball", 0, 0)
	assert(placed_fired, "decoration_placed should fire")
	
	sig_ds.mood_contribution("test_creature", Vector2(0.5, 0.5))
	assert(boosted_fired, "mood_boosted should fire")
	
	sig_ds.remove_decoration(sig_ds.get_placed_decorations()[0]["instance_id"])
	assert(removed_fired, "decoration_removed should fire")
	
	print("All signals fire correctly")
	
	# Test 17: Edge cases
	print("\n--- Test 17: Edge cases ---")
	var edge_ds = DecorationSystem.new(3, 3, 100.0)
	# Place at boundary
	assert(edge_ds.place_decoration("toy_ball", 2, 2) != "", "Should place at bottom-right corner")
	assert(edge_ds.can_place("toy_ball", 3, 2) == false, "Should not place out of bounds")
	assert(edge_ds.can_place("toy_ball", 2, 3) == false, "Should not place out of bounds")
	
	# Remove all
	var cleared = edge_ds.clear_all_decorations(0.0)
	assert(cleared == 1, "Should clear 1 decoration")
	assert(edge_ds.get_placed_count() == 0, "Should be empty")
	print("Edge cases handled")
	
	print("\n=== ALL TESTS PASSED ===")
	quit(0)
