# weather_system.gd — Sanctuary autoload (String contract).
# The ONE source of truth for weather in the Sanctuary demo. Registered as
# autoload "WeatherSystem" in project.godot.
#
# Why a String contract: sanct-029.gd connects to /root/WeatherSystem and calls
# `weather_changed(new_weather: String)` + `get_current_weather() -> String`
# (sanct-029.gd:21-27). The quarantined creature-flavored WeatherSystem was
# enum-based (get_weather() -> WeatherState, no signal) and forge-1737 (Galage)
# was combat-flavored (3-arg enum signal, get_current_state()). NEITHER matches
# what sanct-029 actually calls, so we write a fresh String-contract autoload
# rather than resurrect a contract-mismatched file.
#
# NOTE: this file deliberately declares NO class_name — it is registered as an
# autoload whose node path name IS "WeatherSystem". Declaring the same class_name
# would trigger "Class 'WeatherSystem' hides an autoload singleton".
#
# Tunables: everything a designer would retune lives in one block below.
extends Node

## Emitted whenever the weather changes. Arg is the new weather as a String:
## one of "clear", "sun", "rain", "storm", "fog", "sandstorm".
signal weather_changed(new_weather: String)

## Emitted each time the weather cycles to a new random state on its own.
signal weather_cycled(new_weather: String)

## --- Tunables: one place to retune weather feel. ---
## How long (seconds) each weather phase lasts before auto-cycling. 0 disables
## the auto-cycle (weather changes only via set_weather/force_weather).
@export var cycle_duration: float = 15.0
## Whether the weather auto-advances on a timer (ambient sanctuary life).
@export var auto_cycle: bool = true
## RNG seed. Fixed for deterministic testing; 0 seeds from wall-clock.
@export var fixed_seed: int = 20260907

# Valid weather states (the String vocabulary the rest of the demo uses).
const WEATHERS: Array[String] = ["clear", "sun", "rain", "storm", "fog", "sandstorm"]

# Internal state.
var _current_weather: String = "clear"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer: float = 0.0

func _ready() -> void:
	if fixed_seed != 0:
		_rng.seed = fixed_seed
	else:
		_rng.randomize()
	_timer = cycle_duration
	# Announce the initial state so early listeners (sanct-029 connects in its
	# own _ready) sync even if they instantiate after us.
	weather_changed.emit(_current_weather)

func _process(delta: float) -> void:
	if not auto_cycle or cycle_duration <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = cycle_duration
		var next := _pick_next(_current_weather)
		set_weather(next)
		weather_cycled.emit(next)

func _pick_next(current: String) -> String:
	# Weighted roll that avoids repeating the same state; "storm"/"sandstorm"
	# are rarer so ambient weather doesn't feel like a constant hazard.
	var candidates: Array[String] = []
	var weights: Array[float] = []
	for w in WEATHERS:
		if w == current:
			continue
		candidates.append(w)
		match w:
			"storm":
				weights.append(0.8)
			"sandstorm":
				weights.append(1.0)
			"fog":
				weights.append(1.2)
			_:
				weights.append(2.0)
	var total: float = 0.0
	for i in candidates.size():
		total += weights[i]
	var cursor: float = 0.0
	var roll: float = _rng.randf()
	for i in candidates.size():
		cursor += weights[i] / total
		if roll <= cursor:
			return candidates[i]
	return candidates[-1]

## Set the weather. Emits weather_changed ONLY on an actual change and only
## for a valid state (invalid input is refused, not swallowed into a no-op).
func set_weather(new_weather: String) -> bool:
	if new_weather not in WEATHERS:
		push_warning("WeatherSystem.set_weather: unknown weather '%s' ignored" % new_weather)
		return false
	if new_weather == _current_weather:
		return false
	_current_weather = new_weather
	weather_changed.emit(new_weather)
	return true

## Scripted override (used by tests / creature casting). Same as set_weather.
func force_weather(new_weather: String) -> bool:
	return set_weather(new_weather)

## The current weather as a String (the contract sanct-029 expects).
func get_current_weather() -> String:
	return _current_weather

## Is the current weather hostile? Storm + sandstorm are the combative ones.
func is_hostile() -> bool:
	return _current_weather == "storm" or _current_weather == "sandstorm"

## Small test hook so the driver can assert the autoload is alive.
func test() -> bool:
	return has_signal("weather_changed") and has_method("get_current_weather")
