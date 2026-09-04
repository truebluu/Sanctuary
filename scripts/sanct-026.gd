extends Node
## Creature Hunger Decay
## Adds time-based hunger decay to a creature and provides a feed method.
## Builds on the existing CreatureNeeds system (hunger property, feed()).
## This script should be attached to a creature node that has a `hunger` property
## (0.0 - 100.0) and a `hunger_changed` signal. If those are missing, it will
## create them locally to keep the component self-contained.

signal hunger_changed(new_value: float)

@export var max_hunger: float = 100.0
@export var hunger_decay_rate: float = 1.0  # hunger points per second
@export var min_hunger: float = 0.0

var hunger: float = max_hunger:
	set(value):
		hunger = clampf(value, min_hunger, max_hunger)
		hunger_changed.emit(hunger)

func _ready() -> void:
	# If the parent already has a hunger property, use it; otherwise we manage our own.
	if get_parent() and "hunger" in get_parent():
		hunger = get_parent().hunger
		# Connect to the parent's existing signal if available
		if get_parent().has_signal("hunger_changed"):
			get_parent().hunger_changed.connect(_on_parent_hunger_changed)
	else:
		# No parent hunger property, we are the source of truth.
		pass

func _process(delta: float) -> void:
	# Decrease hunger over time
	if hunger > min_hunger:
		hunger = max(min_hunger, hunger - hunger_decay_rate * delta)

## Feed the creature, restoring hunger.
## amount: how much hunger to restore (clamped to max_hunger).
func feed(amount: float) -> void:
	if amount <= 0.0:
		return
	hunger = min(max_hunger, hunger + amount)

## Called when the parent's hunger changes (if we are mirroring an external property).
func _on_parent_hunger_changed(new_value: float) -> void:
	hunger = new_value