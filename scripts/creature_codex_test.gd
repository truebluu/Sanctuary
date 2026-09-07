# CreatureCodex Headless Test Runner — SANCTUARY-005
# Runs validation tests for CreatureCodex without requiring a scene.
extends SceneTree

func _init() -> void:
	pass

func _initialize() -> void:
	CreatureCodex._headless_test()