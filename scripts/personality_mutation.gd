# PersonalityMutation — Taming (The Sanctuary)
# SANCT-033 "Pet personality trait mutation".
# A pet's personality is not static: it drifts slowly toward an archetype based
# on how the player cares for it, and interactions nudge individual axes. This
# is the engine the creature's behavior/AI (pet.gd) reads every session.
#
# Three continuous axes, each in [0, 100]:
#   energy    — high = lively/active, low = docile/calm
#   affection — high = bonded/trusting, low = aloof/distant
#   boldness  — high = daring/curious, low = timid/cautious
#
# Axis drift: every interaction applies a delta; each `tick` also applies a slow
# decay toward the pet's "base" temper so it doesn't flip personality in one
# session. Deterministic-safe: callers may inject a seeded RNG for runs that must
# reproduce exactly (daily challenges, saved worlds).
class_name PersonalityMutation
extends RefCounted

signal personality_changed(archetype: String)

## Base drift per real second toward the creature's inherited base temper.
const DRIFT_PER_SEC := 2.0
## The axis shift per interaction (see apply_interaction).
const INTERACTION_STEP := 10.0
## Thresholds for archetype labelling.
const BOLD_HIGH := 65.0
const BOLD_LOW := 35.0
const ENERGY_HIGH := 60.0

## The three axis names exposed to other systems (CreatureNeeds, behavior AI).
const AXES: Array[String] = ["energy", "affection", "boldness"]

var energy: float = 50.0
var affection: float = 50.0
var boldness: float = 50.0

## Base "temper" axis values the pet slowly drifts back toward (from genetics).
var _base: Dictionary = {"energy": 50.0, "affection": 50.0, "boldness": 50.0}

## Optional deterministic RNG.
var _rng: RandomNumberGenerator

func _init(base: Dictionary = {}, rng: RandomNumberGenerator = null) -> void:
	if base.has("energy"):
		_base["energy"] = float(base["energy"])
	if base.has("affection"):
		_base["affection"] = float(base["affection"])
	if base.has("boldness"):
		_base["boldness"] = float(base["boldness"])
	energy = _base["energy"]
	affection = _base["affection"]
	boldness = _base["boldness"]
	_rng = rng if rng != null else RandomNumberGenerator.new()

## Apply one explicit care interaction. Maps Taming verbs (feed/play/rest/scold)
## to axis shifts so the pet's behaviour reacts to the player's choices.
func apply_interaction(verb: String) -> void:
	match verb:
		"feed":
			# Feeding raises trust, gently calms energy.
			affection += INTERACTION_STEP
			energy -= INTERACTION_STEP * 0.4
		"play":
			# Play boosts energy and affection, nudges boldness up a touch.
			energy += INTERACTION_STEP
			affection += INTERACTION_STEP * 0.6
			boldness += INTERACTION_STEP * 0.3
		"rest":
			# Rest restores energy but saps a little social drive.
			energy -= INTERACTION_STEP * 0.5
			affection -= INTERACTION_STEP * 0.2
		"scold":
			# Negative interaction lowers affection, raises boldness via defense.
			affection -= INTERACTION_STEP * 0.8
			boldness += INTERACTION_STEP * 0.5
		_:
			# Unknown verbs are ignored (no personality effect).
			_check_idle(verb)
	_clamp()

## A helper so an unrecognised verb doesn't silently mutate personality axes.
## (Kept as its own method so `apply_interaction` stays a clean match arm.)
func _check_idle(_verb: String) -> void:
	# no-op: unknown interactions leave the axes untouched
	return

## Advance real time by `delta` seconds, drifting the axes back toward their
## base so a single burst of care doesn't permanently rewrite the creature.
func tick(delta: float) -> void:
	var k := DRIFT_PER_SEC * delta
	energy = _lerp_toward(energy, _base["energy"], k)
	affection = _lerp_toward(affection, _base["affection"], k)
	boldness = _lerp_toward(boldness, _base["boldness"], k)

func axis(name: String) -> float:
	match name:
		"energy": return energy
		"affection": return affection
		"boldness": return boldness
	return 0.0

## A single-word archetype for UI/behavior labels, derived from the axes.
func archetype() -> String:
	var result: String
	if boldness >= BOLD_HIGH and energy >= ENERGY_HIGH:
		result = "playful"
	elif boldness >= BOLD_HIGH:
		result = "bold"
	elif energy >= ENERGY_HIGH:
		result = "energetic"
	elif affection >= BOLD_HIGH and energy < ENERGY_HIGH:
		result = "loyal"
	elif boldness <= BOLD_LOW:
		result = "timid"
	else:
		result = "calm"
	return result

func get_state() -> Dictionary:
	return {"energy": energy, "affection": affection, "boldness": boldness,
		"archetype": archetype()}

func _lerp_toward(cur: float, target: float, k: float) -> float:
	# k in [0..1]; frame-rate-invariant exponential decay.
	return cur + (target - cur) * (1.0 - exp(-k))

func _clamp() -> void:
	energy = clampf(energy, 0.0, 100.0)
	affection = clampf(affection, 0.0, 100.0)
	boldness = clampf(boldness, 0.0, 100.0)

