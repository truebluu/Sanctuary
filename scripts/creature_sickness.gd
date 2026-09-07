# CreatureSickness — Sanctuary (Bluu Ink Studios)
# SANCT-831 Pet sickness & recovery system.
# Pure simulation logic (headless-testable): models illness from neglected needs.
# Hooks into CreatureNeeds: when hunger, hygiene, or energy fall below thresholds
# for a sustained period, the creature becomes sick. Sickness drains health over
# time and reduces trust. Medicine items trigger cure().
# Emits signals on sick / recovered for UI and gameplay reactions.
class_name CreatureSickness
extends RefCounted

signal sick(severity: float)
signal recovered
signal health_drained(amount: float)
signal worsened(severity: float)

## Need thresholds below which sickness can begin (0..1 scale).
@export var hunger_sickness_threshold: float = 0.25
@export var hygiene_sickness_threshold: float = 0.25
@export var energy_sickness_threshold: float = 0.20

## Seconds a need must stay below its threshold before sickness starts.
@export var onset_grace_seconds: float = 8.0

## Base severity added per tick while needs are neglected (0..1 scale).
@export var severity_gain_per_sec: float = 0.05

## Maximum sickness severity.
@export var max_severity: float = 1.0

## Health drain per second per severity point (0..1 scale).
@export var health_drain_per_severity_per_sec: float = 0.08

## Trust drain per second while sick.
@export var trust_drain_per_sec: float = 0.02

## Cure effectiveness: how much severity is removed per medicine use.
@export var cure_amount: float = 0.5

## Optional reference to the creature's CreatureNeeds (auto-wired via setup).
var _needs: CreatureNeeds = null

## Internal state.
var _is_sick: bool = false
var _severity: float = 0.0
var _neglect_timer: float = 0.0
var _health_drain_accum: float = 0.0

## Initialize with a CreatureNeeds instance.
func setup_with_needs(needs: CreatureNeeds) -> void:
	_needs = needs

## Check if creature is currently sick.
func is_sick() -> bool:
	return _is_sick

## Get current sickness severity (0..1).
func get_severity() -> float:
	return _severity

## Get current neglect timer (seconds).
func get_neglect_timer() -> float:
	return _neglect_timer

## Main simulation tick: call each frame or fixed step with delta seconds.
func tick(delta: float) -> void:
	if _needs == null:
		return

	# Check which needs are currently neglected.
	var hungry: bool = _needs.get_hunger() < hunger_sickness_threshold
	var dirty: bool = _needs.get_social() < hygiene_sickness_threshold  # social used as hygiene proxy
	var tired: bool = _needs.get_energy() < energy_sickness_threshold

	var any_neglected: bool = hungry or dirty or tired

	if any_neglected:
		_neglect_timer += delta
		if _neglect_timer >= onset_grace_seconds and not _is_sick:
			_become_sick()
		elif _is_sick:
			_worsen_sickness(delta)
	else:
		# Needs are being met: neglect timer resets, sickness can recover naturally.
		_neglect_timer = 0.0
		if _is_sick:
			_try_natural_recovery(delta)

	# If sick, apply ongoing health/trust drain.
	if _is_sick:
		_apply_sickness_effects(delta)

## Force sickness onset (for testing or gameplay events).
func force_sickness(initial_severity: float = 0.3) -> void:
	if _is_sick:
		return
	_is_sick = true
	_severity = clampf(initial_severity, 0.0, max_severity)
	sick.emit(_severity)

## Cure the creature using a medicine item.
## Returns true if cure was applied (creature was sick), false otherwise.
func cure() -> bool:
	if not _is_sick:
		return false

	_severity = clampf(_severity - cure_amount, 0.0, max_severity)

	if _severity <= 0.0:
		_recover()
	else:
		# Partial cure: emit worsened with new (lower) severity so UI can update.
		worsened.emit(_severity)

	return true

## Apply a custom cure amount (e.g., different medicine tiers).
func cure_with_amount(amount: float) -> bool:
	if not _is_sick or amount <= 0.0:
		return false

	_severity = clampf(_severity - amount, 0.0, max_severity)

	if _severity <= 0.0:
		_recover()
	else:
		worsened.emit(_severity)

	return true

## Serialize sickness state to a dictionary (for save games).
func to_dict() -> Dictionary:
	return {
		"is_sick": _is_sick,
		"severity": _severity,
		"neglect_timer": _neglect_timer,
	}

## Load sickness state from a dictionary.
func from_dict(data: Dictionary) -> void:
	_is_sick = data.get("is_sick", false)
	_severity = data.get("severity", 0.0)
	_neglect_timer = data.get("neglect_timer", 0.0)

func _become_sick() -> void:
	_is_sick = true
	_severity = 0.1  # starting severity
	sick.emit(_severity)

func _worsen_sickness(delta: float) -> void:
	_severity = clampf(_severity + severity_gain_per_sec * delta, 0.0, max_severity)
	worsened.emit(_severity)

func _try_natural_recovery(delta: float) -> void:
	# Slow natural recovery when needs are met (5% of severity per second).
	_severity = clampf(_severity - 0.05 * delta, 0.0, max_severity)
	if _severity <= 0.0:
		_recover()
	else:
		worsened.emit(_severity)

func _apply_sickness_effects(delta: float) -> void:
	# Health drain scales with severity.
	var drain: float = health_drain_per_severity_per_sec * _severity * delta
	if drain > 0.0:
		_health_drain_accum += drain
		if _health_drain_accum >= 0.001:
			if _needs != null:
				_needs.take_damage(_health_drain_accum)
				health_drained.emit(_health_drain_accum)
			_health_drain_accum = 0.0

	# Trust drain while sick.
	if _needs != null:
		var trust_loss: float = trust_drain_per_sec * delta
		_needs.gain_trust(-trust_loss)

func _recover() -> void:
	_is_sick = false
	_severity = 0.0
	_neglect_timer = 0.0
	_health_drain_accum = 0.0
	recovered.emit()