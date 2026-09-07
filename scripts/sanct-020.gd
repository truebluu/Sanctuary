# sanctuary_day_night_cycle.gd
# ------------------------------------------------------------------------------
# Sanctuary Day/Night Cycle
# Builds on the existing DayNightCycle global class and the Creature/CreatureNeeds
# systems. This script listens to the DayNightCycle's time-of-day signal and
# applies activity/mood modifiers to all creatures in the sanctuary group.
#
# Feel added: Day/night rhythm makes the sanctuary feel alive and gives the
# player a reason to check in at different times. Night reduces creature
# activity and slowly lowers happiness; day restores it. This integrates with
# the existing creature needs and mood systems without replacing them.
#
# Tunability: All gameplay-affecting values are exported or named constants at
# the top of the file. A designer can retune the whole cycle from one place.
# ------------------------------------------------------------------------------

extends Node
# This script should be attached to a node in the sanctuary scene, e.g. as a
# child of SanctuaryController. It expects a DayNightCycle node to be present
# either as a child or assigned via the inspector.

## Reference to the DayNightCycle node. If left empty, the script will try to
## find it in the scene tree on ready.
@export var day_night_cycle: Node = null

## Group name for all creatures in the sanctuary. Must match the group used by
## the creature spawner/manager.
@export var creature_group: StringName = &"creatures"

## Time-of-day thresholds (0.0 = midnight, 0.5 = noon, 1.0 = next midnight)
@export_range(0.0, 1.0) var night_start: float = 0.75   # 6 PM
@export_range(0.0, 1.0) var day_start: float = 0.25    # 6 AM

## Activity multiplier applied to creatures during night (0.0 = inactive, 1.0 = normal)
@export var night_activity_multiplier: float = 0.4
## Mood (happiness) change per second during night (negative = decrease)
@export var night_mood_delta_per_sec: float = -0.5
## Mood change per second during day (positive = increase)
@export var day_mood_delta_per_sec: float = 0.2

## How often (in seconds) the script applies continuous effects (mood drift).
@export var effect_tick_interval: float = 1.0

# Internal state
var _is_night: bool = false
var _effect_timer: float = 0.0

# Signal emitted when the day/night state changes (true = night, false = day)
signal day_night_state_changed(is_night: bool)

func _ready() -> void:
	# If no DayNightCycle assigned, try to find it via its autoload node-path
	# (/root/DayNightCycle). A sibling-relative "../DayNightCycle" or a child
	# search (_find_day_night_cycle) can never reach an autoload, so use the
	# absolute autoload path directly — matches the contract in
	# day_night_cycle.gd (get_node_or_null("/root/DayNightCycle")).
	if day_night_cycle == null:
		day_night_cycle = get_node_or_null("/root/DayNightCycle")
	if day_night_cycle == null:
		# Fallback: search the scene tree (only useful if not an autoload)
		day_night_cycle = _find_day_night_cycle(self)
	if day_night_cycle == null:
		push_warning("SanctuaryDayNightCycle: No DayNightCycle node found. Disabling.")
		set_process(false)
		return

	# Connect to the DayNightCycle's time-of-day signal.
	# The signal name is assumed to be "time_of_day_changed" and passes a float.
	if day_night_cycle.has_signal("time_of_day_changed"):
		day_night_cycle.connect("time_of_day_changed", _on_time_of_day_changed)
	else:
		push_warning("SanctuaryDayNightCycle: DayNightCycle has no 'time_of_day_changed' signal. Disabling.")
		set_process(false)
		return

	# Initialize state based on current time. The autoload exposes a method
	# get_time_of_day(), not a time_of_day property, so call it via has_method
	# (node.get("time_of_day") would spuriously null + push an error).
	var current_time: float = day_night_cycle.get_time_of_day() if day_night_cycle.has_method("get_time_of_day") else 0.0
	_update_night_state(current_time)

func _process(delta: float) -> void:
	# Apply continuous mood drift based on day/night.
	_effect_timer += delta
	if _effect_timer >= effect_tick_interval:
		_effect_timer = 0.0
		_apply_continuous_effects()

func _on_time_of_day_changed(new_time: float) -> void:
	_update_night_state(new_time)

func _update_night_state(time_of_day: float) -> void:
	var new_is_night: bool = _is_night_time(time_of_day)
	if new_is_night != _is_night:
		_is_night = new_is_night
		_apply_activity_multiplier()
		day_night_state_changed.emit(_is_night)

func _is_night_time(time_of_day: float) -> bool:
	# Handles wrap-around: night is between night_start and day_start (e.g., 0.75 to 0.25)
	if night_start < day_start:
		# Night spans midnight (e.g., 0.75 to 1.0 and 0.0 to 0.25)
		return time_of_day >= night_start or time_of_day < day_start
	else:
		# Night is a simple range (e.g., 0.75 to 0.25 is impossible, so this is a fallback)
		return time_of_day >= night_start and time_of_day < day_start

func _apply_activity_multiplier() -> void:
	# Set activity multiplier on all creatures in the group.
	var creatures := get_tree().get_nodes_in_group(creature_group)
	for creature in creatures:
		if creature.has_method("set_activity_multiplier"):
			creature.set_activity_multiplier(night_activity_multiplier if _is_night else 1.0)
		# If the creature doesn't have that method, we skip silently.
		# This keeps the script robust against creatures that don't implement it.

func _apply_continuous_effects() -> void:
	# Apply mood drift to all creatures.
	var mood_delta: float = night_mood_delta_per_sec * effect_tick_interval if _is_night else day_mood_delta_per_sec * effect_tick_interval
	var creatures := get_tree().get_nodes_in_group(creature_group)
	for creature in creatures:
		# Try to adjust happiness via the creature's own method.
		if creature.has_method("adjust_happiness"):
			creature.adjust_happiness(mood_delta)
		# Fallback: if the creature has a "mood" property, modify it directly.
		elif "mood" in creature:
			creature.mood = clampf(creature.mood + mood_delta, 0.0, 1.0)
		# If neither exists, we do nothing.

func _find_day_night_cycle(node: Node) -> Node:
	# Recursively search for a node that has a "time_of_day" property and a
	# "time_of_day_changed" signal.
	for child in node.get_children():
		if child.has_signal("time_of_day_changed") and child.get("time_of_day") != null:
			return child
		var found = _find_day_night_cycle(child)
		if found:
			return found
	return null