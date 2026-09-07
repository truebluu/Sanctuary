# BreedingCooldown — Taming (The Sanctuary)
# SANCT-878: Per-creature breeding cooldown + egg incubation timer.
class_name BreedingCooldownTracker
extends RefCounted

signal egg_hatched(creature_id: String)
signal breeding_ready(creature_id: String)

const DEFAULT_BREED_COOLDOWN := 30.0
const DEFAULT_EGG_INCUBATION := 60.0

var _breed_cooldowns: Dictionary = {}   # creature_id -> remaining seconds
var _egg_timers: Dictionary = {}        # creature_id -> remaining seconds

func start_breeding(creature_id: String, cooldown: float = DEFAULT_BREED_COOLDOWN) -> void:
	_breed_cooldowns[creature_id] = cooldown

func start_egg_incubation(creature_id: String, duration: float = DEFAULT_EGG_INCUBATION) -> void:
	_egg_timers[creature_id] = duration

func check_ready(creature_id: String) -> bool:
	return not _breed_cooldowns.has(creature_id) or _breed_cooldowns[creature_id] <= 0.0

func get_remaining_time(creature_id: String) -> float:
	return _breed_cooldowns.get(creature_id, 0.0)

func get_egg_remaining(creature_id: String) -> float:
	return _egg_timers.get(creature_id, 0.0)

func tick(delta: float) -> void:
	# Advance all cooldowns and egg timers; emit signals on completion.
	for cid in _breed_cooldowns.keys():
		_breed_cooldowns[cid] -= delta
		if _breed_cooldowns[cid] <= 0.0:
			_breed_cooldowns[cid] = 0.0
			breeding_ready.emit(cid)
	for cid in _egg_timers.keys():
		_egg_timers[cid] -= delta
		if _egg_timers[cid] <= 0.0:
			_egg_timers.erase(cid)
			egg_hatched.emit(cid)

func run_test() -> bool:
	var ok := true
	start_breeding("creature_a", 10.0)
	if check_ready("creature_a"):
		ok = false  # should NOT be ready immediately
	start_egg_incubation("creature_a", 5.0)
	tick(6.0)  # egg hatches, cooldown still running
	if get_egg_remaining("creature_a") != 0.0:
		ok = false
	if check_ready("creature_a"):
		ok = false  # cooldown 10s, only 6s elapsed
	tick(5.0)  # now 11s total -> cooldown done
	if not check_ready("creature_a"):
		ok = false
	return ok
