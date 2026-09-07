extends Node
## Sanctuary Day/Night Cycle autoload.
## Registered as "DayNightCycle" in project.godot.
##
## NOTE: no `class_name` — the node-path name IS "DayNightCycle". Declaring a
## class_name of the same name here would trigger "Class hides an autoload
## singleton". Consumers (sanct-020, sanct-009) reach it via
## get_node_or_null("/root/DayNightCycle"), which the autoload satisfies.

## DayNightCycle — Sanctuary (Taming) day/night cycle.
## Models an in-game clock that cycles between day and night over a configurable
## duration. Affects creature activity and spawn rates: nocturnal creatures are
## more active at night. Integrates with the "creature" group (emits a
## time_of_day_changed signal that creature nodes can listen to) and with
## HabitatSystem's environment_changed signal so biome changes can adjust the
## cycle speed.

## Emitted whenever the ambient clock crosses a day/night boundary.
## Carries the normalized time-of-day fraction 0.0 (midnight) .. 1.0 (midnight).
## Both wired consumers (sanct-009:98, sanct-020:89) interpret this arg as a
## 0-1 fraction; emitting a bool would coerce to 1.0/0.0 and mis-classify
## daytime as night. Emit the fraction, not a bool.
signal time_of_day_changed(time_of_day: float)

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

func _ready() -> void:
	_time_seconds = day_start_hour * SECONDS_PER_HOUR
	_was_day = _is_day(_time_seconds)

func _process(delta: float) -> void:
	var prev_time: float = _time_seconds
	_time_seconds = fmod(_time_seconds + delta * (HOURS_PER_DAY * SECONDS_PER_HOUR / cycle_duration_seconds), HOURS_PER_DAY * SECONDS_PER_HOUR)

	var is_day_now: bool = _is_day(_time_seconds)
	if is_day_now != _was_day:
		_was_day = is_day_now
		time_of_day_changed.emit(get_time_of_day())
		# Notify each creature in the group so they can adjust their behavior.
		# Query the group lazily here (not once in _ready) — in _ready the main
		# scene isn't loaded yet, so a cached snapshot is permanently empty.
		for creature in get_tree().get_nodes_in_group("creatures"):
			if is_instance_valid(creature) and creature.has_method("on_time_of_day_changed"):
				creature.on_time_of_day_changed(is_day_now)

func _is_day(time_seconds: float) -> bool:
	var hour: float = time_seconds / SECONDS_PER_HOUR
	return hour >= day_start_hour and hour < night_start_hour

func get_time_of_day() -> float:
	return _time_seconds / (HOURS_PER_DAY * SECONDS_PER_HOUR)

func get_brightness() -> float:
	# Brightest at noon (t=0.5), darkest at midnight (t=0 or 1): a triangular
	# curve across the day peak. (Previously the day branch returned the dark
	# end at dawn/dusk and the night branch returned the bright end at midnight
	# — inverted.)
	var t: float = get_time_of_day()
	var phase: float = absf(t - 0.5) / 0.5
	return lerp(day_brightness, night_brightness, phase)

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
