# CreatureNeedsSmokeTest — Sanctuary (Bluu Ink Studios)
# Headless validation harness for the SANCT-141 creature needs system.
# Drives CreatureNeeds with simulated time and asserts:
#   (a) each need decays from its initial value over time
#   (b) hunger falling below the floor drains health -> died signal
#   (c) feeding raises hunger AND trust
#   (d) sustained critical hunger + low trust -> abandoned signal
# Results are written to a file, then the tree quits 0 on pass / 1 on failure.
extends Node2D

const RESULT_ABS := "C:/Users/bluue/Documents/Galage/creature_needs_smoke_result.txt"

var _failures: Array[String] = []
# Signal capture via member variables (Godot lambdas cannot mutate captured locals).
var _starved_died := false
var _aband_died := false
var _aband_abandoned := false

func _ready() -> void:
	_run()
	_quit()

func _run() -> void:
	# (a) decay
	var c := CreatureNeeds.new()
	c.tick(5.0)   # 5 seconds
	_check(c.get_hunger() < 1.0, "hunger should decay below 1.0 (got %f)" % c.get_hunger())
	_check(c.get_energy() < 1.0, "energy should decay below 1.0 (got %f)" % c.get_energy())
	_check(c.get_social() < 1.0, "social should decay below 1.0 (got %f)" % c.get_social())
	_check(c.get_trust() < 0.5, "trust should decay below 0.5 (got %f)" % c.get_trust())

	# (c) feeding raises hunger and trust
	var fed := CreatureNeeds.new()
	fed.tick(20.0)                    # hunger ~ 1.0 - 0.04*20 = 0.2
	var hunger_before: float = fed.get_hunger()
	var trust_before: float = fed.get_trust()
	fed.feed()
	_check(fed.get_hunger() > hunger_before, "feeding should raise hunger (%f -> %f)" % [hunger_before, fed.get_hunger()])
	_check(fed.get_trust() > trust_before, "feeding should raise trust (%f -> %f)" % [trust_before, fed.get_trust()])

	# (b) starvation: hunger 0 (below floor) drains health -> died signal.
	_starved_died = false
	var starved := CreatureNeeds.new()
	starved.set_hunger(0.0)
	starved.died.connect(func(): _starved_died = true)
	var t := 0.0
	while t < 30.0 and not _starved_died:
		starved.tick(1.0)
		t += 1.0
	_check(_starved_died, "starving creature should emit died signal")

	# (d) abandon: critical hunger + low trust sustained past grace (4s) fires
	#     abandoned before starvation kills it.
	_aband_died = false
	_aband_abandoned = false
	var aband := CreatureNeeds.new()
	aband.set_hunger(0.05)
	aband.set_trust(0.05)
	aband.abandoned.connect(func(): _aband_abandoned = true)
	aband.died.connect(func(): _aband_died = true)
	t = 0.0
	while t < 12.0 and not (_aband_abandoned or _aband_died):
		aband.tick(0.5)
		t += 0.5
	_check(_aband_abandoned, "critical hunger + low trust should abandon before dying (abandoned=%s died=%s)" % [_aband_abandoned, _aband_died])

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
		_log("CREATURE NEEDS SMOKE: ALL PASS")
		code = 0
	else:
		_log("CREATURE NEEDS SMOKE: %d FAILURES" % _failures.size())
	var f := FileAccess.open(RESULT_ABS, FileAccess.WRITE)
	if f:
		f.store_line("EXIT=%d" % code)
		f.close()
	get_tree().quit(code)
