# CreatureNeeds — Sanctuary (Bluu Ink Studios)
# SANCT-141 Creature needs system.
# Pure simulation logic (headless-testable): models a creature's four needs —
#   hunger (0..1, 1 = full), trust (bond to tamer), energy, social.
# Each decays over time. Hunger falling below a floor drains health; health
# reaching 0 triggers `died`. If trust drops very low AND hunger stays critical
# for a while, the creature "abandons" (abandoned signal). Caring actions
# (feed / play) restore needs and raise trust.
class_name CreatureNeeds
extends RefCounted

signal need_changed(which: StringName, value: float)
signal health_changed(current: float, max: float)
signal died
signal abandoned

## Decay per second for each need (0..1 scale).
@export var decay_rate: Dictionary = {
	&"hunger": 0.04,
	&"trust": 0.012,
	&"energy": 0.03,
	&"social": 0.02,
}

## Below this hunger the creature starts taking damage each second.
@export var hunger_floor: float = 0.15
## Damage per second while starving.
@export var starvation_damage: float = 0.12
## Trust below this makes abandonment possible while hungry.
@export var abandon_trust_threshold: float = 0.10
## Hunger below this is considered critical for abandonment.
@export var abandon_hunger_threshold: float = 0.20
## Seconds of sustained critical-hunger-with-low-trust before abandon fires.
@export var abandon_grace_seconds: float = 4.0

## Current 0..1 value of each need.
var need_values: Dictionary = { &"hunger": 1.0, &"trust": 0.5, &"energy": 1.0, &"social": 0.6 }
var health: float = 1.0
var max_health: float = 1.0

var _abandon_timer: float = 0.0
var _dead: bool = false

## Advance the simulation by `delta` seconds. Watch the signals for outcomes.
func tick(delta: float) -> void:
	if _dead:
		return
	var starving := false
	for need in decay_rate.keys():
		var cur: float = float(need_values[need])
		var next: float = clampf(cur - float(decay_rate[need]) * delta, 0.0, 1.0)
		_set_need(StringName(need), next)
		if need == &"hunger" and next < hunger_floor:
			starving = true
	# Starvation drains health.
	if starving:
		take_damage(starvation_damage * delta)
	# Abandonment check: critical hunger AND low trust, sustained.
	var crit_hunger: bool = get_hunger() < abandon_hunger_threshold
	var low_trust: bool = get_trust() < abandon_trust_threshold
	if crit_hunger and low_trust:
		_abandon_timer += delta
		if _abandon_timer >= abandon_grace_seconds:
			_abandon()
	else:
		_abandon_timer = 0.0

## Feed the creature: satisfies hunger and raises trust.
func feed() -> void:
	_set_need(&"hunger", clampf(get_hunger() + 0.45, 0.0, 1.0))
	gain_trust(0.10)

## Play / interact: boosts social and a little trust.
func play() -> void:
	_set_need(&"social", clampf(get_social() + 0.35, 0.0, 1.0))
	gain_trust(0.05)

## Restore energy (e.g. sleeping).
func rest() -> void:
	_set_need(&"energy", clampf(get_energy() + 0.5, 0.0, 1.0))

func gain_trust(amount: float) -> void:
	_set_need(&"trust", clampf(get_trust() + amount, 0.0, 1.0))

func take_damage(amount: float) -> void:
	if _dead:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()

func get_hunger() -> float: return float(need_values[&"hunger"])
func get_trust() -> float: return float(need_values[&"trust"])
func get_energy() -> float: return float(need_values[&"energy"])
func get_social() -> float: return float(need_values[&"social"])
func is_dead() -> bool: return _dead

## Direct control of a need (tests / debug). Clamped to 0..1.
func set_hunger(v: float) -> void: _set_need(&"hunger", clampf(v, 0.0, 1.0))
func set_trust(v: float) -> void: _set_need(&"trust", clampf(v, 0.0, 1.0))
func set_energy(v: float) -> void: _set_need(&"energy", clampf(v, 0.0, 1.0))
func set_social(v: float) -> void: _set_need(&"social", clampf(v, 0.0, 1.0))

func _set_need(which: StringName, value: float) -> void:
	var old: float = float(need_values[which])
	if absf(old - value) < 1.0e-6:
		return
	need_values[which] = value
	need_changed.emit(which, value)

func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit()

func _abandon() -> void:
	if _dead:
		return
	_dead = true
	abandoned.emit()
