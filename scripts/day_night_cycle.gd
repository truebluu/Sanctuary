extends Node
class_name DayNightCycle

## DayNightCycle — Sanctuary (Taming) day/night cycle.
## Models an in-game clock that cycles between day and night over a configurable
## duration. Affects creature activity and spawn rates: nocturnal creatures are
## more active at night. Integrates with the "creature" group (emits a
## time_of_day_changed signal that creature nodes can listen to) and with
## HabitatSystem's environment_changed signal so biome changes can adjust the
## cycle speed.

signal time_of_day_changed(is_day: bool)

@export var cycle_duration_seconds: float = 300.0
@export var day_brightness: float = 1.0
@export var night_brightness: float = 0.2
@export var day_start_hour: float = 6.0
@export var night_start_hour: float = 18.0
@export var night_spawn_multiplier: float = 1.5
@export var day_spawn_multiplier: float = 0.5

const HOURS_PER_DAY: float = 24.0
const SECONDS_PER_HOUR: float = 3600.0

var _time_seconds: float = 0.0
var _was_day: bool = true
var _creatures: Array[Node] = []

func _ready() -> void:
	_time_seconds = day_start_hour * SECONDS_PER_HOUR
	_was_day = _is_day(_time_seconds)
	# Collect creatures in the "creature" group so we can notify them on change.
	_creatures = get_tree().get_nodes_in_group("creature")

func _process(delta: float) -> void:
	var prev_time: float = _time_seconds
	_time_seconds = fmod(_time_seconds + delta * (HOURS_PER_DAY * SECONDS_PER_HOUR / cycle_duration_seconds), HOURS_PER_DAY * SECONDS_PER_HOUR)

	var is_day_now: bool = _is_day(_time_seconds)
	if is_day_now != _was_day:
		_was_day = is_day_now
		time_of_day_changed.emit(is_day_now)
		# Notify each creature in the group so they can adjust their behavior.
		for creature in _creatures:
			if is_instance_valid(creature) and creature.has_method("on_time_of_day_changed"):
				creature.on_time_of_day_changed(is_day_now)

func _is_day(time_seconds: float) -> bool:
	var hour: float = time_seconds / SECONDS_PER_HOUR
	return hour >= day_start_hour and hour < night_start_hour

func get_time_of_day() -> float:
	return _time_seconds / (HOURS_PER_DAY * SECONDS_PER_HOUR)

func get_brightness() -> float:
	var t: float = get_time_of_day()
	var day_t: float = day_start_hour / HOURS_PER_DAY
	var night_t: float = night_start_hour / HOURS_PER_DAY

	if t >= day_t and t < night_t:
		var day_progress: float = (t - day_t) / (night_t - day_t)
		return lerp(night_brightness, day_brightness, day_progress)
	else:
		var night_progress: float = 0.0
		if t < day_t:
			night_progress = t / day_t
		else:
			night_progress = (t - night_t) / (1.0 - night_t)
		return lerp(day_brightness, night_brightness, night_progress)

func get_spawn_multiplier() -> float:
	var t: float = get_time_of_day()
	var day_t: float = day_start_hour / HOURS_PER_DAY
	var night_t: float = night_start_hour / HOURS_PER_DAY

	if t >= day_t and t < night_t:
		return day_spawn_multiplier
	else:
		return night_spawn_multiplier

func get_activity_level() -> float:
	var brightness: float = get_brightness()
	return lerp(0.3, 1.0, brightness)

## Called by HabitatSystem when the biome changes; adjusts cycle speed.
func on_environment_changed(biome: StringName) -> void:
	# Different biomes have different day lengths (e.g. caves are darker).
	match biome:
		&"cave":
			cycle_duration_seconds = 600.0
		&"desert":
			cycle_duration_seconds = 200.0
		_:
			cycle_duration_seconds = 300.0
