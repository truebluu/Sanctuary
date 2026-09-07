# CreatureSicknessSmokeTest — Sanctuary (Bluu Ink Studios)
# Headless validation harness for the SANCT-831 creature sickness system.
# Drives CreatureSickness with simulated time and asserts:
#   (a) sickness onset when needs neglected below threshold past grace period
#   (b) sickness worsens over time while needs still neglected
#   (c) sickness drains health via CreatureNeeds
#   (d) cure() reduces severity and eventually recovers
#   (e) natural recovery when needs are restored
# Results are written to a file, then the tree quits 0 on pass / 1 on failure.
extends Node2D

const RESULT_ABS := "C:/Users/bluue/Documents/Galage/creature_sickness_smoke_result.txt"

var _failures: Array[String] = []
# Signal capture via member variables (Godot lambdas cannot mutate captured locals).
var _sick_fired := false
var _recovered_fired := false
var _worsened_count := 0
var _health_drained_total := 0.0
var _last_severity := 0.0

func _ready() -> void:
	_run()
	_quit()

func _run() -> void:
	# (a) sickness onset when needs neglected below threshold past grace period
	_sick_fired = false
	_recovered_fired = false
	_worsened_count = 0
	_health_drained_total = 0.0
	_last_severity = 0.0

	var needs := CreatureNeeds.new()
	# Lower needs below thresholds
	needs.set_hunger(0.1)    # below 0.25
	needs.set_social(0.1)    # below 0.25 (hygiene proxy)
	needs.set_energy(0.1)    # below 0.20

	var sickness := CreatureSickness.new()
	sickness.setup_with_needs(needs)
	sickness.sick.connect(func(sev: float): _sick_fired = true)
	sickness.recovered.connect(func(): _recovered_fired = true)
	sickness.worsened.connect(func(sev: float):
		_worsened_count += 1
		_last_severity = sev
	)
	sickness.health_drained.connect(func(amt: float):
		_health_drained_total += amt
	)

	# Tick for grace period + a bit more (8s grace + 2s)
	var t := 0.0
	while t < 10.0:
		sickness.tick(1.0)
		t += 1.0

	_check(_sick_fired, "sick signal should fire after grace period with neglected needs")
	_check(sickness.is_sick(), "is_sick() should return true after onset")
	_check(sickness.get_severity() > 0.0, "severity should be > 0 after onset")

	# (b) sickness worsens over time while needs still neglected
	var severity_after_onset := sickness.get_severity()
	t = 0.0
	while t < 5.0:
		sickness.tick(1.0)
		t += 1.0

	_check(sickness.get_severity() > severity_after_onset, "severity should increase while needs neglected (%f -> %f)" % [severity_after_onset, sickness.get_severity()])
	_check(_worsened_count > 0, "worsened signal should fire during worsening")

	# (c) sickness drains health via CreatureNeeds
	var health_before := needs.health
	t = 0.0
	while t < 5.0:
		sickness.tick(1.0)
		t += 1.0

	var health_after := needs.health
	_check(health_after < health_before, "health should drain while sick (%f -> %f)" % [health_before, health_after])
	_check(_health_drained_total > 0.0, "health_drained signal should accumulate")

	# (d) cure() reduces severity and eventually recovers
	# Reset for this test
	needs = CreatureNeeds.new()
	needs.set_hunger(0.1)
	needs.set_social(0.1)
	needs.set_energy(0.1)

	sickness = CreatureSickness.new()
	sickness.setup_with_needs(needs)
	_sick_fired = false
	_recovered_fired = false
	sickness.sick.connect(func(sev: float): _sick_fired = true)
	sickness.recovered.connect(func(): _recovered_fired = true)

	# Get sick first
	t = 0.0
	while t < 10.0:
		sickness.tick(1.0)
		t += 1.0

	_check(_sick_fired, "should get sick before cure test")
	var severity_before_cure := sickness.get_severity()

	# Apply cure (default cure_amount = 0.5)
	var cured := sickness.cure()
	_check(cured, "cure() should return true when sick")
	_check(sickness.get_severity() < severity_before_cure, "severity should decrease after cure (%f -> %f)" % [severity_before_cure, sickness.get_severity()])

	# If not fully recovered yet, apply cure again
	if sickness.is_sick():
		cured = sickness.cure()
		_check(cured, "second cure() should return true when still sick")
	_check(_recovered_fired, "recovered signal should fire after full cure")
	_check(not sickness.is_sick(), "is_sick() should be false after recovery")

	# (e) natural recovery when needs are restored
	needs = CreatureNeeds.new()
	needs.set_hunger(0.1)
	needs.set_social(0.1)
	needs.set_energy(0.1)

	sickness = CreatureSickness.new()
	sickness.setup_with_needs(needs)
	_sick_fired = false
	_recovered_fired = false
	sickness.sick.connect(func(sev: float): _sick_fired = true)
	sickness.recovered.connect(func(): _recovered_fired = true)

	# Get sick
	t = 0.0
	while t < 10.0:
		sickness.tick(1.0)
		t += 1.0

	_check(_sick_fired, "should get sick for natural recovery test")

	# Now restore needs
	needs.set_hunger(1.0)
	needs.set_social(1.0)
	needs.set_energy(1.0)

	# Tick while needs are met - should naturally recover
	t = 0.0
	while t < 25.0 and not _recovered_fired:  # natural recovery is slow (5% per sec)
		sickness.tick(1.0)
		t += 1.0

	_check(_recovered_fired, "should naturally recover when needs restored (t=%.1fs)" % t)
	_check(not sickness.is_sick(), "is_sick() should be false after natural recovery")

	# (f) cure_with_amount with custom amount
	needs = CreatureNeeds.new()
	needs.set_hunger(0.1)
	needs.set_social(0.1)
	needs.set_energy(0.1)

	sickness = CreatureSickness.new()
	sickness.setup_with_needs(needs)
	t = 0.0
	while t < 10.0:
		sickness.tick(1.0)
		t += 1.0

	var sev_before := sickness.get_severity()
	var cured_amt := sickness.cure_with_amount(0.8)  # strong medicine
	_check(cured_amt, "cure_with_amount should return true")
	_check(sickness.get_severity() < sev_before, "severity should drop by custom amount (%f -> %f)" % [sev_before, sickness.get_severity()])

	# (g) serialization round-trip
	var data := sickness.to_dict()
	_check(data.has("is_sick"), "to_dict should include is_sick")
	_check(data.has("severity"), "to_dict should include severity")
	_check(data.has("neglect_timer"), "to_dict should include neglect_timer")

	var sickness2 := CreatureSickness.new()
	sickness2.setup_with_needs(needs)
	sickness2.from_dict(data)
	_check(sickness2.is_sick() == sickness.is_sick(), "is_sick should match after from_dict")
	_check(abs(sickness2.get_severity() - sickness.get_severity()) < 0.001, "severity should match after from_dict")

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
		_log("CREATURE SICKNESS SMOKE: ALL PASS")
		code = 0
	else:
		_log("CREATURE SICKNESS SMOKE: %d FAILURES" % _failures.size())
	var f := FileAccess.open(RESULT_ABS, FileAccess.WRITE)
	if f:
		f.store_line("EXIT=%d" % code)
		f.close()
	get_tree().quit(code)