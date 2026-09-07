# PersonalityMutationSmokeTest — Taming (The Sanctuary)
# Headless validation harness for SANCT-033 (personality trait mutation).
# Asserts:
#   (a) fresh creature starts at its base axes
#   (b) apply_interaction shifts the expected axes and clamps to [0,100]
#   (c) tick() drifts axes back toward base over time
#   (d) archetype() labels the dominant axes correctly
# Results are written to a file; tree quits 0 on pass / 1 on failure.
extends Node2D

const RESULT_ABS := "C:/Users/bluue/Documents/Galage/personality_mutation_smoke_result.txt"

var _failures: Array[String] = []

func _ready() -> void:
	var pm = load("res://scripts/personality_mutation.gd").new({"energy": 50.0, "affection": 50.0, "boldness": 50.0})
	_run(pm)
	_quit()

func _run(pm) -> void:
	# (a) base
	_check(_eq(pm.axis("energy"), 50.0), "initial energy should be 50 (got %f)" % pm.axis("energy"))
	_check(_eq(pm.axis("affection"), 50.0), "initial affection should be 50 (got %f)" % pm.axis("affection"))
	_check(_eq(pm.axis("boldness"), 50.0), "initial boldness should be 50 (got %f)" % pm.axis("boldness"))

	# (b) play: energy +10, affection +6, boldness +3, then clamped
	pm.apply_interaction("play")
	_check(_eq(pm.axis("energy"), 60.0), "play should raise energy to 60 (got %f)" % pm.axis("energy"))
	_check(_eq(pm.axis("affection"), 56.0), "play should raise affection to 56 (got %f)" % pm.axis("affection"))
	_check(_eq(pm.axis("boldness"), 53.0), "play should raise boldness to 53 (got %f)" % pm.axis("boldness"))

	# repeatedly scold to test clamping at 0
	for i in range(20):
		pm.apply_interaction("scold")
	_check(pm.axis("affection") >= 0.0 and pm.axis("affection") <= 100.0, "affection must clamp to [0,100] (got %f)" % pm.axis("affection"))

	# (c) tick drifts back toward base (base is all 50)
	# Push boldness up, then let tick decay it back down below the +3 boost.
	var pm2 = load("res://scripts/personality_mutation.gd").new({"energy": 50.0, "affection": 50.0, "boldness": 50.0})
	pm2.apply_interaction("play")
	var before = pm2.axis("boldness")
	pm2.tick(60.0)  # long enough for heavy decay
	_check(pm2.axis("boldness") < before, "tick should drift boldness back toward base (before=%f after=%f)" % [before, pm2.axis("boldness")])

	# (d) archetype: high boldness + high energy -> playful
	var pm3 = load("res://scripts/personality_mutation.gd").new({"energy": 50.0, "affection": 50.0, "boldness": 50.0})
	for i in range(6):
		pm3.apply_interaction("play")  # energy 50->60+... boldness 50->53+...
	_check(pm3.archetype() == "playful" or pm3.archetype() == "energetic", "high energy should label archetype (got '%s')" % pm3.archetype())

func _eq(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func _check(cond: bool, msg: String) -> void:
	if cond:
		_log("PASS: " + msg)
	else:
		_failures.append(msg)
		_log("FAIL: " + msg)

func _log(msg: String) -> void:
	print(msg)
	var f := FileAccess.open(RESULT_ABS, FileAccess.WRITE)
	if f:
		f.store_line(msg)
		f.close()

func _quit() -> void:
	var code := 1
	if _failures.is_empty():
		_log("PERSONALITY MUTATION SMOKE: ALL PASS")
		code = 0
	else:
		_log("PERSONALITY MUTATION SMOKE: %d FAILURES" % _failures.size())
	var f := FileAccess.open(RESULT_ABS, FileAccess.WRITE)
	if f:
		f.store_line("EXIT=%d" % code)
		f.close()
	get_tree().quit(code)
