class_name SanctuaryDecorationEffect
extends Node2D
## Sanctuary decoration effect: boosts creature mood and growth within a radius.
## Builds on the existing DecorationSystem and CreatureNeeds systems.
## Feel: rewards thoughtful placement of decorations near creatures, making the sanctuary feel alive.

## --- Tunables (one-place changes) ---
@export var effect_radius: float = 200.0          ## How close a creature must be to receive the boost.
@export var mood_boost_per_second: float = 2.0    ## Mood points added per second per creature.
@export var growth_boost_per_second: float = 1.0 ## Growth points added per second per creature.
@export var update_interval: float = 0.5          ## How often we apply the effect (seconds).

## --- Internal ---
var _creature_group: String = "creatures"
var _timer: Timer

func _ready() -> void:
	# Ensure we have a timer to apply effects periodically.
	_timer = Timer.new()
	_timer.wait_time = update_interval
	_timer.autostart = true
	_timer.timeout.connect(_apply_effects)
	add_child(_timer)
	# Add this node to a group for easy cleanup if needed.
	add_to_group("sanctuary_decorations")

func _apply_effects() -> void:
	var creatures = get_tree().get_nodes_in_group(_creature_group)
	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		var distance = global_position.distance_to(creature.global_position)
		if distance <= effect_radius:
			_apply_boost(creature)

func _apply_boost(creature: Node) -> void:
	# Use safe method calls; if the creature doesn't have these methods, ignore.
	if creature.has_method("add_mood"):
		creature.add_mood(mood_boost_per_second * update_interval)
	if creature.has_method("add_growth"):
		creature.add_growth(growth_boost_per_second * update_interval)
	# Also emit a signal for analytics/feedback.
	EventBus.emit_signal("sanctuary_decoration_effect_applied", self, creature, mood_boost_per_second * update_interval, growth_boost_per_second * update_interval)

func _exit_tree() -> void:
	# Clean up timer.
	if _timer:
		_timer.queue_free()