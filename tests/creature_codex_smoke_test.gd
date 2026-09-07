extends SceneTree

func _initialize() -> void:
	print("=== Creature Codex Smoke Test ===")
	
	# Load the creature codex scene
	var codex_scene = load("res://scenes/creature_codex.tscn")
	if not codex_scene:
		push_error("FAIL: Could not load creature_codex.tscn")
		quit(1)
		return
	
	var codex_instance = codex_scene.instantiate()
	if not codex_instance:
		push_error("FAIL: Could not instantiate creature_codex.tscn")
		quit(1)
		return
	
	# Add to root
	root.add_child(codex_instance)
	
	# Wait a frame for _ready to run
	await process_frame
	
	# Test that the script is attached and has the codex data
	var script = codex_instance.get_script()
	if not script:
		push_error("FAIL: No script attached to codex instance")
		quit(1)
		return
	
	# Check that CREATURE_CODEX constant exists
	var codex_dict = script.CREATURE_CODEX
	if not codex_dict or codex_dict.size() == 0:
		push_error("FAIL: CREATURE_CODEX dictionary is empty or missing")
		quit(1)
		return
	
	print("Creature Codex dictionary keys: " + str(script.CREATURE_CODEX.keys()))
	
	# Test that the scene structure is valid
	print("Root node name: " + codex_instance.name)
	print("Root node type: " + codex_instance.get_class())
	
	# Get children
	for child in codex_instance.get_children():
		print("Child: " + child.name + " (" + child.get_class() + ")")
	
	# Test selecting a creature via the script method
	var test_id = "verdant_sprite"
	codex_instance._on_creature_selected(test_id)
	
	await process_frame
	
	print("OK: Creature selection method called")
	print("=== SMOKE TEST PASSED ===")
	
	quit(0)