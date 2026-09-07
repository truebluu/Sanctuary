# CreatureBonding — Taming (The Sanctuary)
# Affection/bond system for creatures. Tracks 0..100 affection per pet with
# diminishing returns, rank tiers, behavior modifiers, and passive tick decay/
# growth. Emits signals on changes and rank-ups.
# Integrates with Pet/Genetics: can be given a Pet node reference or path to
# read the pet's genome for personality-based modifiers.
class_name CreatureBonding
extends RefCounted

## Affection rank thresholds.
const RANK_THRESHOLDS := {
	"Stranger": 0,
	"Acquaintance": 25,
	"Friend": 50,
	"Confidant": 75,
	"Companion": 90,
}
const RANK_ORDER := ["Stranger", "Acquaintance", "Friend", "Confidant", "Companion"]

## Base decay per second when neglected (no care actions recently).
const BASE_DECAY_PER_SEC := 0.5
## Max boost per second during active care (feeding, petting, playing).
const MAX_CARE_BOOST_PER_SEC := 1.5
## Time window (seconds) to consider a pet "recently cared for".
const CARE_WINDOW_SEC := 30.0
## Diminishing returns curve sharpness (higher = steeper drop-off near 100).
const DIMINISHING_EXPONENT := 1.8

signal affection_changed(level: float)
signal rank_up(rank: int)  # rank index in RANK_ORDER

## Current affection level, clamped 0..100.
var _affection: float = 0.0
## Last affection rank index (for detecting rank-up).
var _current_rank_idx: int = 0
## Timestamp of last care action (for bonding_tick).
var _last_care_time: float = -1.0
## Optional reference to the Pet this bonding belongs to.
var _pet: Pet = null
## Optional node path to the Pet (resolved on demand).
var _pet_path: NodePath = null
## Cached genome reference (read from pet when available).
var _genome: Genetics.PetGenome = null
## Genome-derived personality modifier (affects decay/boost rates).
var _personality_modifier: float = 1.0

func _init() -> void:
	_current_rank_idx = 0
	_affection = 0.0
	_last_care_time = -1.0

## Initialize with a Pet node reference.
func setup_with_pet(pet: Pet) -> void:
	_pet = pet
	_pet_path = null
	_genome = pet.genome
	_personality_modifier = _compute_personality_modifier(_genome)

## Initialize with a node path to a Pet (resolved lazily).
func setup_with_pet_path(path: NodePath) -> void:
	_pet_path = path
	_pet = null
	_genome = null
	_personality_modifier = 1.0

## Resolve the pet path if needed and cache genome/personality.
func _ensure_pet_resolved() -> void:
	if _pet:
		return
	if _pet_path and get_tree() and get_tree().get_root().has_node(_pet_path):
		var node = get_node(_pet_path)
		if node is Pet:
			_pet = node
			_genome = _pet.genome
			_personality_modifier = _compute_personality_modifier(_genome)

## Compute a personality modifier from the pet's genome.
## Calm pets decay slower; energetic pets gain faster but decay faster.
## Shiny pets get a small bonus to both.
func _compute_personality_modifier(genome: Genetics.PetGenome) -> float:
	if not genome:
		return 1.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ph := genome.phenotype(rng)
	var mod: float = 1.0
	# Temperament influence
	match str(ph["temper"]["name"]):
		"calm":
			mod *= 0.85  # slower decay, slightly slower gain
		"energetic":
			mod *= 1.15  # faster gain, faster decay
		"shy":
			mod *= 0.95  # slightly slower gain, slower decay
	# Size influence (larger pets bond a bit slower but retain longer)
	match str(ph["size"]["name"]):
		"large":
			mod *= 0.95
		"small":
			mod *= 1.05
	# Shiny bonus
	if ph["element"]["shiny"] or ph["coat"]["shiny"] or ph["size"]["shiny"] or ph["temper"]["shiny"]:
		mod *= 1.1
	return clampf(mod, 0.5, 2.0)

## Get current affection level (0..100).
func get_affection_level() -> float:
	return _affection

## Get current bond rank name.
func get_bond_rank() -> String:
	return RANK_ORDER[_current_rank_idx]

## Get current bond rank index (0..4).
func get_bond_rank_index() -> int:
	return _current_rank_idx

## Add affection with diminishing returns near max.
## Diminishing returns formula: effective = amount * (1 - (current/100)^exponent)
func add_affection(amount: float) -> void:
	if amount <= 0:
		return
	_ensure_pet_resolved()
	var current := _affection
	# Diminishing returns: as current approaches 100, each point costs more.
	var diminishing_factor: float = 1.0 - powf(current / 100.0, DIMINISHING_EXPONENT)
	diminishing_factor = max(diminishing_factor, 0.05)  # floor so it never fully stops
	var effective_amount: float = amount * diminishing_factor * _personality_modifier
	var new_affection: float = clampf(current + effective_amount, 0.0, 100.0)
	if abs(new_affection - current) < 0.001:
		return
	_affection = new_affection
	_last_care_time = Time.get_ticks_msec() / 1000.0
	_update_rank()
	affection_changed.emit(_affection)

## Called each frame (or at a fixed interval) to process passive decay/growth.
## delta: time in seconds since last tick.
## If the pet was cared for recently (within CARE_WINDOW_SEC), affection grows slowly.
## Otherwise, affection decays.
func bonding_tick(delta: float) -> void:
	if delta <= 0:
		return
	_ensure_pet_resolved()
	var now: float = Time.get_ticks_msec() / 1000.0
	var time_since_care: float = (now - _last_care_time) if _last_care_time >= 0 else CARE_WINDOW_SEC * 2
	var change: float = 0.0
	if time_since_care <= CARE_WINDOW_SEC:
		# Recently cared for: slow passive boost (tapers off as affection rises)
		var care_progress: float = 1.0 - (time_since_care / CARE_WINDOW_SEC)
		var boost_rate: float = MAX_CARE_BOOST_PER_SEC * care_progress * _personality_modifier
		# Diminishing returns on passive boost too
		var diminishing: float = 1.0 - powf(_affection / 100.0, DIMINISHING_EXPONENT * 0.5)
		diminishing = max(diminishing, 0.1)
		change = boost_rate * diminishing * delta
	else:
		# Neglected: decay
		var neglect_time: float = time_since_care - CARE_WINDOW_SEC
		# Decay accelerates slightly the longer the neglect
		var decay_accel: float = 1.0 + min(neglect_time / 300.0, 1.0)  # cap at 2x after 5 min
		var decay_rate: float = BASE_DECAY_PER_SEC * decay_accel * _personality_modifier
		# Lower affection decays slightly slower (creatures don't forget instantly)
		var retention: float = 0.5 + (_affection / 100.0) * 0.5
		change = -decay_rate * retention * delta
	var new_affection: float = clampf(_affection + change, 0.0, 100.0)
	if abs(new_affection - _affection) > 0.001:
		_affection = new_affection
		_update_rank()
		affection_changed.emit(_affection)

## Record a care action (feeding, petting, playing, etc.) to boost affection
## and reset the care window timer.
func record_care_action(affection_gain: float = 5.0) -> void:
	add_affection(affection_gain)

## Returns gameplay-relevant behavior modifiers that scale with bond rank.
## Keys: xp_multiplier, feeding_healing_bonus, following_distance_boost,
##       trust_bonus (affects breeding success, command obedience, etc.),
##       stress_reduction (lowers negative status buildup).
func behavior_modifiers() -> Dictionary:
	var rank: String = get_bond_rank()
	var idx: int = _current_rank_idx
	# Base values per rank (index 0..4)
	var base_xp_mult := [1.0, 1.05, 1.12, 1.22, 1.35]
	var base_heal_bonus := [0.0, 0.05, 0.12, 0.22, 0.35]
	var base_follow_boost := [0.0, 10.0, 25.0, 45.0, 70.0]  # pixels
	var base_trust := [0.0, 0.05, 0.15, 0.3, 0.5]
	var base_stress_red := [0.0, 0.03, 0.08, 0.15, 0.25]
	# Smooth interpolation within rank based on progress toward next threshold
	var progress: float = 0.0
	if idx < RANK_ORDER.size() - 1:
		var current_thresh: float = RANK_THRESHOLDS[RANK_ORDER[idx]]
		var next_thresh: float = RANK_THRESHOLDS[RANK_ORDER[idx + 1]]
		if next_thresh > current_thresh:
			progress = (_affection - current_thresh) / (next_thresh - current_thresh)
			progress = clampf(progress, 0.0, 1.0)
	# Interpolate toward next rank's values
	var next_idx: int = min(idx + 1, RANK_ORDER.size() - 1)
	var lerp := func(a: float, b: float) -> float: return a + (b - a) * progress
	return {
		"xp_multiplier": lerp(base_xp_mult[idx], base_xp_mult[next_idx]),
		"feeding_healing_bonus": lerp(base_heal_bonus[idx], base_heal_bonus[next_idx]),
		"following_distance_boost": lerp(base_follow_boost[idx], base_follow_boost[next_idx]),
		"trust_bonus": lerp(base_trust[idx], base_trust[next_idx]),
		"stress_reduction": lerp(base_stress_red[idx], base_stress_red[next_idx]),
		"bond_rank": rank,
		"bond_rank_index": idx,
		"affection": _affection,
	}

## Internal: update rank index and emit rank_up if changed.
func _update_rank() -> void:
	var new_idx: int = 0
	for i in range(RANK_ORDER.size() - 1, -1, -1):
		if _affection >= RANK_THRESHOLDS[RANK_ORDER[i]]:
			new_idx = i
			break
	if new_idx != _current_rank_idx:
		var old_idx := _current_rank_idx
		_current_rank_idx = new_idx
		if new_idx > old_idx:
			rank_up.emit(new_idx)

## Reset affection to 0 (e.g., on ownership transfer or severe neglect event).
func reset_affection() -> void:
	_affection = 0.0
	_current_rank_idx = 0
	_last_care_time = -1.0
	affection_changed.emit(0.0)

## Serialize bonding state to a dictionary (for save games).
func to_dict() -> Dictionary:
	return {
		"affection": _affection,
		"rank_index": _current_rank_idx,
		"last_care_time": _last_care_time,
		"pet_path": _pet_path,
	}

## Load bonding state from a dictionary.
func from_dict(data: Dictionary) -> void:
	_affection = data.get("affection", 0.0)
	_current_rank_idx = data.get("rank_index", 0)
	_last_care_time = data.get("last_care_time", -1.0)
	if data.has("pet_path"):
		_pet_path = data["pet_path"]
		_pet = null
		_genome = null
	_personality_modifier = 1.0
	_update_rank()