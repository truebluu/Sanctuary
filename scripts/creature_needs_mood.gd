# CreatureNeedsEngine — Sanctuary (Bluu Ink Studios)
# Complete 'Creature Needs & Mood Simulation' with mood state and behavior triggers.
# Extends the original CreatureNeeds logic (hunger/trust/energy/social decay) and adds:
#   - Continuous MOOD computation from need thresholds (content/hungry/tired/bored/ill/social-isolated)
#   - mood_changed signal when mood transitions
#   - Behavior triggers: Dictionary mapping mood -> Array of trigger names the game can react to
#   - simulate_ticks(ticks, delta_per_tick) for batch simulation
# Pure RefCounted, headless-testable, no Node dependencies.
class_name CreatureNeedsEngine
extends RefCounted

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted whenever the creature's mood changes.
## Args: old_mood (StringName), new_mood (StringName)
signal mood_changed(old_mood: StringName, new_mood: StringName)

## Emitted when a behavior trigger fires (game logic can react to these).
## Args: trigger_name (StringName), mood (StringName)
signal behavior_triggered(trigger_name: StringName, mood: StringName)

## Re-emit base need signals for convenience
signal need_changed(which: StringName, value: float)
signal health_changed(current: float, max: float)
signal died
signal abandoned

# ============================================================================
# EXPORTED CONFIGURATION
# ============================================================================

## Decay per second for each need (0..1 scale).
@export var decay_rate: Dictionary = {
	"hunger": 0.04,
	"trust": 0.012,
	"energy": 0.03,
	"social": 0.02,
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

# ---- Mood Thresholds (all 0..1) ----
## Hunger below this -> "hungry"
@export var mood_hungry_threshold: float = 0.35
## Energy below this -> "tired"
@export var mood_tired_threshold: float = 0.35
## Social below this -> "social-isolated"
@export var mood_social_threshold: float = 0.35
## Trust below this -> "bored" (enrichment deficit; low trust feels like boredom)
@export var mood_bored_threshold: float = 0.30
## Health below this -> "ill"
@export var mood_ill_threshold: float = 0.50

## Priority order when multiple moods apply (lower index = higher priority).
## Mood at index 0 overrides others if its condition is met.
@export var mood_priority: Array[StringName] = [
	&"ill",
	&"hungry",
	&"tired",
	&"social-isolated",
	&"bored",
	&"content",
]

# ---- Behavior Triggers Configuration ----
## Mapping: mood -> Array of trigger names fired when that mood becomes active.
## Triggers are strings the game can react to (e.g., "seek_food", "request_pet", "whine", "wander").
@export var behavior_triggers: Dictionary = {
	"hungry": ["seek_food", "whine", "nudge_bowl", "beg"],
	"tired": ["seek_bed", "yawn", "curl_up", "slow_down"],
	"social-isolated": ["call_out", "approach_player", "pace", "look_around"],
	"bored": ["explore", "play_with_toy", "dig", "stare_at_walls"],
	"ill": ["whimper", "lie_down", "refuse_food", "shiver"],
	"content": ["purr", "wag_tail", "follow_player", "relax"],
}

# ============================================================================
# INTERNAL STATE
# ============================================================================

## Current 0..1 value of each need.
var need_values: Dictionary = { "hunger": 1.0, "trust": 0.5, "energy": 1.0, "social": 0.6 }
var health: float = 1.0
var max_health: float = 1.0

var _abandon_timer: float = 0.0
var _dead: bool = false
var _current_mood: StringName = &"content"
var _mood_just_changed: bool = false

# ============================================================================
# PUBLIC API
# ============================================================================

## Advance the simulation by `delta` seconds. Emits signals for changes.
func tick(delta: float) -> void:
	if _dead:
		return
	var starving := false
	for need in decay_rate.keys():
		var cur: float = float(need_values[need])
		var next: float = clampf(cur - float(decay_rate[need]) * delta, 0.0, 1.0)
		_set_need(StringName(need), next)
		if need == "hunger" and next < hunger_floor:
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
	# Recompute mood after needs update.
	_recompute_mood()

## Feed the creature: satisfies hunger and raises trust.
func feed() -> void:
	_set_need(&"hunger", clampf(get_hunger() + 0.45, 0.0, 1.0))
	gain_trust(0.10)
	_recompute_mood()

## Play / interact: boosts social and a little trust.
func play() -> void:
	_set_need(&"social", clampf(get_social() + 0.35, 0.0, 1.0))
	gain_trust(0.05)
	_recompute_mood()

## Restore energy (e.g. sleeping).
func rest() -> void:
	_set_need(&"energy", clampf(get_energy() + 0.5, 0.0, 1.0))
	_recompute_mood()

## Increase trust (bonding action).
func gain_trust(amount: float) -> void:
	_set_need(&"trust", clampf(get_trust() + amount, 0.0, 1.0))

## Apply damage to health.
func take_damage(amount: float) -> void:
	if _dead:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
	_recompute_mood() # health drop may trigger "ill" mood

## Getters for needs.
func get_hunger() -> float: return float(need_values["hunger"])
func get_trust() -> float: return float(need_values["trust"])
func get_energy() -> float: return float(need_values["energy"])
func get_social() -> float: return float(need_values["social"])
func is_dead() -> bool: return _dead
func get_mood() -> StringName: return _current_mood
func get_health() -> float: return health
func get_max_health() -> float: return max_health

## Direct control of a need (tests / debug). Clamped to 0..1.
func set_hunger(v: float) -> void: _set_need(&"hunger", clampf(v, 0.0, 1.0))
func set_trust(v: float) -> void: _set_need(&"trust", clampf(v, 0.0, 1.0))
func set_energy(v: float) -> void: _set_need(&"energy", clampf(v, 0.0, 1.0))
func set_social(v: float) -> void: _set_need(&"social", clampf(v, 0.0, 1.0))
func set_health(v: float) -> void:
	health = clampf(v, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
	_recompute_mood()

## Simulate N ticks with fixed delta per tick.
## Returns an Array of ALL behavior trigger names fired during the simulation.
## Useful for batch testing or fast-forwarding time.
func simulate_ticks(ticks: int, delta_per_tick: float) -> Array[String]:
	var fired_triggers: Array[String] = []
	for i in range(ticks):
		var old_mood = _current_mood
		tick(delta_per_tick)
		if _current_mood != old_mood:
			# Mood changed this tick; collect triggers for the NEW mood
			var triggers = behavior_triggers.get(_current_mood, [])
			for t in triggers:
				fired_triggers.append(t)
				behavior_triggered.emit(StringName(t), _current_mood)
	return fired_triggers

# ============================================================================
# INTERNAL LOGIC
# ============================================================================

func _set_need(which: StringName, value: float) -> void:
	var old: float = float(need_values[which])
	if absf(old - value) < 1.0e-6:
		return
	need_values[which] = value
	need_changed.emit(which, value)

## Compute mood from current need values using priority order.
func _recompute_mood() -> void:
	var new_mood: StringName = &"content"
	for mood in mood_priority:
		if _check_mood_condition(mood):
			new_mood = mood
			break
	if new_mood != _current_mood:
		var old_mood = _current_mood
		_current_mood = new_mood
		mood_changed.emit(old_mood, new_mood)
		# Fire behavior triggers for the new mood immediately
		var triggers = behavior_triggers.get(new_mood, [])
		for t in triggers:
			behavior_triggered.emit(StringName(t), new_mood)

func _check_mood_condition(mood: StringName) -> bool:
	match mood:
		&"ill":
			return health < max_health * mood_ill_threshold
		&"hungry":
			return get_hunger() < mood_hungry_threshold
		&"tired":
			return get_energy() < mood_tired_threshold
		&"social-isolated":
			return get_social() < mood_social_threshold
		&"bored":
			return get_trust() < mood_bored_threshold
		&"content":
			return true # Default fallback
		_:
			return false

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