# CreatureSaveLoadSmokeTest — Bluu Ink Sanctuary
# Headless SceneTree runner for the CreatureSaveLoad RefCounted class.
# Exercises save, load, delete, list, and corrupt/version-mismatch handling.
# Run with: godot --headless --path . --script res://scripts/creature_save_load_smoke_test.gd
extends SceneTree

var _failures: PackedStringArray = []
var _failed_signal: bool = false

func _check(label: String, cond: bool) -> void:
	if not cond:
		_failures.append(label)
		print("FAIL: ", label)
	else:
		print("PASS: ", label)

func _initialize() -> void:
	var mgr := CreatureSaveLoad.new()

	# Clean slate: remove any prior test save.
	var test_id := 424242
	if mgr.delete_creature(test_id):
		print("cleanup: removed prior test save")

	# 1. Load with no save -> empty dict + failure signal.
	_failed_signal = false
	mgr.operation_failed.connect(func(_id: int, _msg: String) -> void:
		_failed_signal = true
	)
	var empty := mgr.load_creature(test_id)
	_check("load_missing_returns_empty", empty.is_empty())
	_check("load_missing_emits_failure", _failed_signal)

	# 2. Save a creature.
	var data := CreatureSaveLoad.build_save_data(
		&"Glimmerwing", 2, {"hunger": 0.8, "happiness": 0.9}, ["res://photos/glimmer_1.png"]
	)
	var saved := mgr.save_creature(test_id, data)
	_check("save_ok", saved)
	_check("save_file_exists", FileAccess.file_exists(CreatureSaveLoad._path_for(test_id)))

	# 3. Load it back and verify round-trip.
	var loaded := mgr.load_creature(test_id)
	_check("load_ok", not loaded.is_empty())
	_check("species_roundtrip", loaded.get("species", "") == "Glimmerwing")
	_check("stage_roundtrip", int(loaded.get("evolution_stage", -1)) == 2)
	_check("needs_roundtrip", (loaded.get("needs", {}) as Dictionary).get("hunger", 0.0) == 0.8)
	_check("photos_roundtrip", (loaded.get("photos", []) as Array).size() == 1)

	# 4. List saved ids includes our test id.
	var ids := CreatureSaveLoad.list_saved_creature_ids()
	_check("list_contains_test_id", test_id in ids)

	# 5. Corrupt file -> load returns empty + failure.
	var corrupt_path := CreatureSaveLoad._path_for(test_id)
	var f := FileAccess.open(corrupt_path, FileAccess.WRITE)
	f.store_string("this is not json {{{")
	f.close()
	var corrupt := mgr.load_creature(test_id)
	_check("corrupt_returns_empty", corrupt.is_empty())

	# 6. Version mismatch -> rejected.
	var v2 := FileAccess.open(corrupt_path, FileAccess.WRITE)
	v2.store_string(JSON.stringify({"version": 99, "species": "X"}))
	v2.close()
	var mismatch := mgr.load_creature(test_id)
	_check("version_mismatch_rejected", mismatch.is_empty())

	# 7. Delete.
	_check("delete_ok", mgr.delete_creature(test_id))
	_check("delete_removes_file", not FileAccess.file_exists(corrupt_path))

	if _failures.is_empty():
		print("ALL PASSED")
		quit(0)
	else:
		print("FAILURES: ", _failures.size())
		quit(1)
