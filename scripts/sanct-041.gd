class_name CreatureEnergy
extends Node

## Per-creature energy system. Energy depletes through activities and recovers
## during sanctuary night cycles; nearby rest spots boost recovery speed.
## Low energy drags mood down and reduces battle readiness.

# --- Tunable constants (one place to retune) ---
## Max energy a creature can hold.
const MAX_ENERGY: int = 100
## Energy lost per activity tick (e.g. a battle, a long play session).
const ENERGY_COST_PER_ACTIVITY: int = 12
## Base recovery per second during night (before rest-spot bonus).
const BASE_NIGHT_RECOVERY_PER_SEC: float = 2.0
## Recovery multiplier each rest spot within range provides.
const REST_SPOT_RECOVERY_MULTIPLIER: float = 1.5
## How far a rest spot's effect reaches in pixels.
const REST_SPOT_RANGE: float = 240.0
## Energy below which mood is penalized.
const LOW_ENERGY_THRESHOLD: int = 30
## Energy below which the creature refuses battle.
const MIN_ENERGY_FOR_BATTLE: int = 15
## Energy restored when the creature takes a short nap (player action).
const NAP_RESTORE: int = 25

signal energy_changed(current: int, maximum: int)
signal energy_depleted()
signal energy_restored(amount: int)
signal battle_readiness_changed(readiness: float)

@export var creature: Node = null
## If true, energy recovers even during day (e.g. a sleeping creature).
@export var is_resting: bool = false

var _energy: int = MAX_ENERGY
var _recovery_rate: float = BASE_NIGHT_RECOVERY_PER_SEC
var _accum: float = 0.0

func _ready() -> void:
	_energy = MAX_ENERGY
	energy_changed.emit(_energy, MAX_ENERGY)
	# DayNightCycle is a class_name (not an autoload) with no night_started/
	# day_started signals, so there is no night-cycle wiring to do here.

func _process(delta: float) -> void:
	if _energy >= MAX_ENERGY:
		return
	var rate := _recovery_rate
	# During day, only recover if the creature is actively resting.
	if not is_resting:
		if not _is_night():
			return
	_accum += rate * delta
	while _accum >= 1.0:
		_accum -= 1.0
		_energy = mini(MAX_ENERGY, _energy + 1)
		energy_changed.emit(_energy, MAX_ENERGY)
		energy_restored.emit(1)

func _is_night() -> bool:
	# DayNightCycle is a class_name (not an autoload) with no is_night method;
	# treat as day (recovery only when resting).
	return false

func _on_night_started() -> void:
	_recompute_recovery()

func _on_day_started() -> void:
	_recompute_recovery()

func _recompute_recovery() -> void:
	var rate := BASE_NIGHT_RECOVERY_PER_SEC
	if creature is Node2D:
		var pos := (creature as Node2D).global_position
		var spots := _count_rest_spots_near(pos)
		rate *= (1.0 + spots * REST_SPOT_RECOVERY_MULTIPLIER)
	_recovery_rate = rate

func _count_rest_spots_near(pos: Vector2) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("rest_spots"):
		if node is Node2D and node.global_position.distance_to(pos) <= REST_SPOT_RANGE:
			count += 1
	return count

## Called when the creature does something tiring (battle, play, travel).
func spend_energy(amount: int = ENERGY_COST_PER_ACTIVITY) -> void:
	_energy = maxi(0, _energy - amount)
	energy_changed.emit(_energy, MAX_ENERGY)
	if _energy == 0:
		energy_depleted.emit()

## Player places the creature down for a short nap.
func take_nap() -> void:
	var restored := mini(NAP_RESTORE, MAX_ENERGY - _energy)
	_energy += restored
	energy_changed.emit(_energy, MAX_ENERGY)
	energy_restored.emit(restored)

## 0.0 (exhausted) to 1.0 (fully ready). Driven by energy.
func get_battle_readiness() -> float:
	if _energy < MIN_ENERGY_FOR_BATTLE:
		return 0.0
	return clampf(float(_energy - MIN_ENERGY_FOR_BATTLE) / float(MAX_ENERGY - MIN_ENERGY_FOR_BATTLE), 0.0, 1.0)

## Mood modifier: negative when energy is low, neutral when healthy.
func mood_modifier() -> float:
	if _energy >= LOW_ENERGY_THRESHOLD:
		return 0.0
	# Linear penalty from -0.5 at threshold down to -1.0 at zero.
	return -0.5 * (1.0 - float(_energy) / float(LOW_ENERGY_THRESHOLD))

func can_battle() -> bool:
	return _energy >= MIN_ENERGY_FOR_BATTLE

func is_exhausted() -> bool:
	return _energy == 0

func get_energy_fraction() -> float:
	return float(_energy) / float(MAX_ENERGY)