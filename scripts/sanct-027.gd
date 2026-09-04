class_name CreatureHappinessDecay
extends Node
## Happiness decay system for sanctuary creatures.
## Builds on the existing CreatureNeedsEngine and Creature classes.
## Reduces happiness over time when the creature is not played with, fed, or cleaned.
## When happiness drops below a threshold, it blocks evolution (affects evolution).
## Tunables are exported so a designer can adjust decay rate and evolution threshold in one place.

signal happiness_critical

@export var decay_per_second: float = 0.5          ## Happiness lost per second when needs are unmet.
@export var min_happiness_for_evolution: float = 0.3 ## Below this, evolution is blocked.
@export var decay_paused: bool = false             ## Manual override for testing or events.

var _creature: Node
var _was_critical: bool = false

func _ready() -> void:
	# Assume the parent is the Creature node.
	_creature = get_parent()
	if not _creature or not _creature.has_method("modify_happiness"):
		push_error("CreatureHappinessDecay must be a child of a Creature with modify_happiness().")
		set_process(false)
		return
	# Connect to the creature's happiness_changed signal if it exists.
	if _creature.has_signal("happiness_changed"):
		_creature.happiness_changed.connect(_on_happiness_changed)

func _process(delta: float) -> void:
	if decay_paused:
		return
	# Only decay if the creature is not currently being played with, fed, or cleaned.
	# We check a flag on the creature if available; otherwise we assume decay always applies.
	if _creature.has_method("is_interaction_active") and _creature.is_interaction_active():
		return
	# Apply decay.
	_creature.modify_happiness(-decay_per_second * delta)
	# Check critical threshold.
	var current_happiness: float = _creature.happiness if _creature.has_method("get_happiness") else _creature.get("happiness")
	if current_happiness < min_happiness_for_evolution and not _was_critical:
		_was_critical = true
		happiness_critical.emit()
		# Optionally notify the evolution system via EventBus.
		EventBus.emit_signal("creature_happiness_critical", _creature)
	elif current_happiness >= min_happiness_for_evolution and _was_critical:
		_was_critical = false

func _on_happiness_changed(new_value: float) -> void:
	# Update critical state if the signal is emitted.
	if new_value < min_happiness_for_evolution and not _was_critical:
		_was_critical = true
		happiness_critical.emit()
		EventBus.emit_signal("creature_happiness_critical", _creature)
	elif new_value >= min_happiness_for_evolution and _was_critical:
		_was_critical = false

## Public method to manually set decay pause state.
func set_decay_paused(paused: bool) -> void:
	decay_paused = paused