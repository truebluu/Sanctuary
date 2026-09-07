# egg_hatch_sequence.gd — Bluu Ink Forge (Galage)
# Egg hatching sequence state machine: idle -> shaking -> cracking -> hatching -> hatched.
# Pure-logic RefCounted class for animated pet egg hatching.

extends RefCounted
class_name EggHatchSequence

## Emitted when the hatch stage advances.
signal stage_changed(stage: StringName)

## Emitted when hatching completes and a pet is born.
signal hatch_complete(pet_id: String)

## Stage names in order.
const STAGES: Array[StringName] = [
	"idle",
	"shaking",
	"cracking",
	"hatching",
	"hatched"
]

## Duration (in seconds) for each non-terminal stage.
const STAGE_DURATIONS: Dictionary = {
	"shaking": 2.0,
	"cracking": 1.5,
	"hatching": 3.0
}

var _current_stage: StringName = "idle"
var _stage_timer: float = 0.0
var _pet_id: String = ""
var _is_complete: bool = false

## Start the hatching sequence from idle.
func start_hatch() -> void:
	if _current_stage != "idle":
		return
	_stage_timer = 0.0
	_is_complete = false
	_set_stage("shaking")

## Advance the sequence by delta seconds.
func update(delta: float) -> void:
	if _is_complete or _current_stage == "idle" or _current_stage == "hatched":
		return

	var remaining_delta: float = delta
	while remaining_delta > 0.0 and not _is_complete and _current_stage != "hatched":
		_stage_timer += remaining_delta
		var duration: float = STAGE_DURATIONS.get(_current_stage, 0.0)

		if _stage_timer >= duration:
			var excess: float = _stage_timer - duration
			_advance_stage()
			remaining_delta = excess
		else:
			remaining_delta = 0.0

## Get current stage name.
func get_stage() -> StringName:
	return _current_stage

## Get progress within current stage (0.0 to 1.0).
func get_progress() -> float:
	if _current_stage == "idle" or _current_stage == "hatched":
		return 0.0 if _current_stage == "idle" else 1.0

	var duration: float = STAGE_DURATIONS.get(_current_stage, 1.0)
	return min(_stage_timer / duration, 1.0)

## Check if hatching sequence is complete.
func is_complete() -> bool:
	return _is_complete

## Get the hatched pet ID (valid after hatch_complete).
func get_hatched_pet_id() -> String:
	return _pet_id

## Set the pet ID that will be emitted on hatch_complete.
func set_pet_id(id: String) -> void:
	_pet_id = id

## Internal: set current stage and emit signal.
func _set_stage(stage: StringName) -> void:
	_current_stage = stage
	_stage_timer = 0.0
	emit_signal("stage_changed", stage)

## Internal: advance to next stage in sequence.
func _advance_stage() -> void:
	var current_index: int = STAGES.find(_current_stage)
	if current_index == -1:
		return

	var next_index: int = current_index + 1
	if next_index >= STAGES.size():
		return

	var next_stage: StringName = STAGES[next_index]

	if next_stage == "hatched":
		_is_complete = true
		_set_stage(next_stage)
		emit_signal("hatch_complete", _pet_id)
	else:
		_set_stage(next_stage)

## Run deterministic self-tests. Returns Dictionary of test_name -> pass/fail (bool).
func run_tests() -> Dictionary:
	var results: Dictionary = {}

	# Test 1: Initial idle state
	var seq1: EggHatchSequence = EggHatchSequence.new()
	results["initial_idle_state"] = seq1.get_stage() == "idle"
	results["initial_not_complete"] = not seq1.is_complete()
	results["initial_progress_zero"] = seq1.get_progress() == 0.0

	# Test 2: start_hatch transitions to shaking
	var seq2: EggHatchSequence = EggHatchSequence.new()
	seq2.start_hatch()
	results["start_hatch_to_shaking"] = seq2.get_stage() == "shaking"
	results["start_hatch_not_complete"] = not seq2.is_complete()

	# Test 3: Full sequence completes
	var seq3: EggHatchSequence = EggHatchSequence.new()
	seq3.set_pet_id("pet_001")
	seq3.start_hatch()
	# shaking (2.0s) + cracking (1.5s) + hatching (3.0s) = 6.5s total
	seq3.update(6.5)
	results["full_sequence_completes"] = seq3.is_complete()
	results["final_stage_hatched"] = seq3.get_stage() == "hatched"
	results["hatched_pet_id"] = seq3.get_hatched_pet_id() == "pet_001"

	# Test 4: Progress monotonic within stages
	var seq4: EggHatchSequence = EggHatchSequence.new()
	seq4.start_hatch()
	var prev_progress: float = 0.0
	var monotonic: bool = true
	for i in range(10):
		seq4.update(0.2)  # 0.2s steps
		var prog: float = seq4.get_progress()
		if prog < prev_progress - 0.001:  # allow small floating point
			monotonic = false
			break
		prev_progress = prog
	results["progress_monotonic"] = monotonic

	# Test 5: is_complete true at end
	var seq5: EggHatchSequence = EggHatchSequence.new()
	seq5.start_hatch()
	seq5.update(6.5)
	results["is_complete_true_at_end"] = seq5.is_complete()

	# Test 6: Signal emission
	var seq6: EggHatchSequence = EggHatchSequence.new()
	var stage_changes: Array[StringName] = []
	var hatch_state: Dictionary = {"completed": false, "pet_id": ""}
	seq6.stage_changed.connect(func(stage: StringName): stage_changes.append(stage))
	seq6.hatch_complete.connect(func(pid: String):
		hatch_state["completed"] = true
		hatch_state["pet_id"] = pid
	)
	seq6.set_pet_id("signal_pet")
	seq6.start_hatch()
	seq6.update(6.5)
	results["stage_changed_emitted"] = (
		stage_changes.size() == 4
		and stage_changes[0] == &"shaking"
		and stage_changes[1] == &"cracking"
		and stage_changes[2] == &"hatching"
		and stage_changes[3] == &"hatched"
	)
	results["hatch_complete_emitted"] = hatch_state["completed"]
	results["hatch_complete_pet_id"] = hatch_state["pet_id"] == "signal_pet"

	# Test 7: start_hatch from non-idle does nothing
	var seq7: EggHatchSequence = EggHatchSequence.new()
	seq7.start_hatch()
	seq7.update(1.0)  # in shaking
	seq7.start_hatch()  # should be ignored
	results["start_hatch_idempotent"] = seq7.get_stage() == "shaking"

	# Test 8: update on idle does nothing
	var seq8: EggHatchSequence = EggHatchSequence.new()
	seq8.update(10.0)
	results["update_idle_noop"] = seq8.get_stage() == "idle"

	# Test 9: update on hatched does nothing
	var seq9: EggHatchSequence = EggHatchSequence.new()
	seq9.start_hatch()
	seq9.update(6.5)
	var stage_after: StringName = seq9.get_stage()
	seq9.update(10.0)
	results["update_hatched_noop"] = seq9.get_stage() == stage_after

	# Test 10: get_progress approaches 1.0 at stage end (just before advancing)
	var seq10: EggHatchSequence = EggHatchSequence.new()
	seq10.start_hatch()
	seq10.update(1.99)  # just before end of shaking (2.0s)
	results["progress_one_at_stage_end"] = abs(seq10.get_progress() - 1.0) < 0.01

	return results