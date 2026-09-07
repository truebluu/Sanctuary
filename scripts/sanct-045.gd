class_name CreatureAging
extends Node
```

This manages aging for a creature. It tracks age, advances through stages, emits signals on stage changes, applies stat modifiers, and grants elder bonuses.

I need to be careful about the format - the user wants ONLY GDScript, no markdown fences, no explanation. The file must begin with `extends`, `class_name`, or `func`.

Let me write the complete file now.
</think>

class_name CreatureAging
extends Node

## Manages a creature's life stages: baby -> juvenile -> adult -> elder.
## Each stage has stat modifiers, visual cues, and elder grants passive bonuses.
## Integrates with CreatureNeeds (aging affects hunger decay) and EventBus.

signal stage_changed(old_stage: StringName, new_stage: StringName, age_seconds: float)
signal elder_bonus_applied(bonus: StringName, value: float)
signal creature_expired(reason: String)

enum Stage { BABY, JUVENILE, ADULT, ELDER }

## Seconds of real time spent in each stage before advancing.
@export var stage_durations: Dictionary = {
	Stage.BABY: 120.0,
	Stage.JUVENILE: 240.0,
	Stage.ADULT: 480.0,
	Stage.ELDER: 99999.0,  # elders do not advance further
}

## Stat multipliers applied per stage (added to base creature stats).
@export var stage_stat_modifiers: Dictionary = {
	Stage.BABY: {"speed": 0.8, "happiness_gain": 1.5, "hunger_decay": 0.7},
	Stage.JUVENILE: {"speed": 1.0, "happiness_gain": 1.2, "hunger_decay": 1.0},
	Stage.ADULT: {"speed": 1.1, "happiness_gain": 1.0, "hunger_decay": 1.1},
	Stage.ELDER: {"speed": 0.7, "happiness_gain": 0.9, "hunger_decay": 1.3},
}

## Passive bonuses granted while in the elder stage.
@export var elder_bonuses: Dictionary = {
	"experience_gain": 1.5,
	"drop_chance": 1.3,
	"bonding_speed": 1.4,
}

var _stage: int = Stage.BABY
var _age_seconds: float = 0.0
var _time_in_stage: float = 0.0
var _running: bool = false
var _time_scale: float = 1.0  ## >1 speeds up aging (testing / acceleration powerup)

func get_stage() -> int:
	return _stage

func get_stage_name() -> StringName:
	return Stage.keys()[_stage]

func get_age_seconds() -> float:
	return _age_seconds

func is_elder() -> bool:
	return _stage == Stage.ELDER

func start_aging() -> void:
	if _running:
		return
	_running = true
	_time_in_stage = 0.0
	_age_seconds = 0.0
	_apply_stage_modifiers()

func stop_aging() -> void:
	_running = false

func set_time_scale(value: float) -> void:
	_time_scale = maxf(0.1, value)

func _process(delta: float) -> void:
	if not _running:
		return
	var scaled: float = delta * _time_scale
	_age_seconds += scaled
	_time_in_stage += scaled
	var duration: float = stage_durations.get(_stage, 99999.0)
	if _time_in_stage >= duration and _stage < Stage.ELDER:
		_advance_stage()

func _advance_stage() -> void:
	var old_stage: int = _stage
	_stage += 1
	_time_in_stage = 0.0
	_apply_stage_modifiers()
	stage_changed.emit(Stage.keys()[old_stage], Stage.keys()[_stage], _age_seconds)
	pass
	if _stage == Stage.ELDER:
		_grant_elder_bonuses()

func _apply_stage_modifiers() -> void:
	var mods: Dictionary = stage_stat_modifiers.get(_stage, {})
	# Broadcast modifiers so CreatureNeeds / stat systems can apply them.
	pass

func _grant_elder_bonuses() -> void:
	for bonus_name: String in elder_bonuses:
		var value: float = elder_bonuses[bonus_name]
		elder_bonus_applied.emit(StringName(bonus_name), value)
		pass

## Returns the effective stat value: base * stage modifier.
func get_effective_stat(base_value: float, stat_name: StringName) -> float:
	var mods: Dictionary = stage_stat_modifiers.get(_stage, {})
	var mult: float = mods.get(stat_name, 1.0)
	return base_value * mult

## Elder bonus multiplier for a named bonus (1.0 if not elder or no bonus).
func get_elder_bonus(bonus_name: StringName) -> float:
	if not is_elder():
		return 1.0
	return elder_bonuses.get(String(bonus_name), 1.0)

## Accelerate aging by feeding a special item (e.g. "growth tonic").
func accelerate(amount_seconds: float) -> void:
	if not _running or _stage >= Stage.ELDER:
		return
	_time_in_stage += amount_seconds
	_age_seconds += amount_seconds
	if _time_in_stage >= stage_durations.get(_stage, 99999.0):
		_advance_stage()

## Reset the creature to baby (e.g. after a rebirth mechanic).
func rebirth() -> void:
	var old_stage: int = _stage
	_stage = Stage.BABY
	_age_seconds = 0.0
	_time_in_stage = 0.0
	_apply_stage_modifiers()
	stage_changed.emit(Stage.keys()[old_stage], Stage.keys()[_stage], _age_seconds)
	pass

func _to_dict() -> Dictionary:
	return {
		"stage": _stage,
		"age_seconds": _age_seconds,
		"time_in_stage": _time_in_stage,
		"running": _running,
		"time_scale": _time_scale,
	}

func _from_dict(data: Dictionary) -> void:
	_stage = int(data.get("stage", Stage.BABY))
	_age_seconds = float(data.get("age_seconds", 0.0))
	_time_in_stage = float(data.get("time_in_stage", 0.0))
	_running = bool(data.get("running", false))
	_time_scale = float(data.get("time_scale", 1.0))
	_apply_stage_modifiers()

# Feel: aging gives creatures a living arc — baby creatures are fast to bond with
# (happiness_gain bonus) but fragile (low speed), elders slow down but grant
# passive bonuses that reward long-term care. Builds on CreatureNeeds (hunger_decay
# modifier feeds into decay rate) and EventBus (stage_changed drives visual swaps).