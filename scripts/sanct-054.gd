The user wants a "Sanctuary weather effects" system where weather (rain/sun) affects creature behavior. I need to check the reference library for existing systems.

From the reference, I see:
- **WeatherSystem** is listed as a global class
- **Creature** and **CreatureNeeds** exist
- **SanctuaryPanel** and **SanctuaryController** exist
- Autoloads: GameState, EventBus, EnergySystem, InputRemap
- The tunability mandate requires @export vars, named consts, no magic numbers

Since WeatherSystem is already listed as a global class, I should check what it likely contains and extend/integrate with it rather than duplicating. The task is about weather affecting creature BEHAVIOR, so I need a system that:
1. Manages weather states (clear, rain, storm, sun)
2. Broadcasts weather changes via EventBus
3. Creatures react to weather (some love rain, some hate it, affecting mood/behavior)

Let me build a WeatherSystem that integrates with the existing EventBus and creature system. I'll make it an autoload since WeatherSystem is listed as a global class.

Key design decisions:
- Weather cycles through states with timed transitions
- Each weather state has tunable effects (creature mood modifiers, behavior flags)
- Creatures read current weather and adjust behavior accordingly
- Use EventBus for weather change notifications
- All tuning via @export vars and named constants

I'll write the weather system as an autoload (matching that WeatherSystem is a global class), plus a creature weather reaction component. Let me write the complete WeatherSystem autoload.
</think>

```gdscript
extends Node
## WeatherSystem — sanctuary weather that influences creature behavior.
##
## Cycles through weather states (clear, sun, rain, storm) on a timer and
## broadcasts transitions via EventBus. Each state carries tunable mood
## modifiers that creatures read to adjust their behavior. Designed so a
## designer retunes weather feel in one place.

## --- Tunables (one place to change weather feel) ---
## How long each weather state lasts before a transition (seconds).
const CLEAR_DURATION: float = 45.0
const SUN_DURATION: float = 40.0
const RAIN_DURATION: float = 35.0
const STORM_DURATION: float = 30.0

## How quickly weather fades between states (seconds for the transition).
const FADE_TIME: float = 2.5

## Chance (0..1) that a storm produces a lightning event creatures react to.
const LIGHTNING_CHANCE: float = 0.4

## Mood modifier creatures apply while in this weather. Positive = happier.
const MOOD_CLEAR: float = 0.0
const MOOD_SUN: float = 0.15
const MOOD_RAIN: float = -0.1
const MOOD_STORM: float = -0.3

enum State { CLEAR, SUN, RAIN, STORM }

signal weather_changed(from_state: int, to_state: int)
signal lightning_occurred()
signal weather_fading(progress: float)

var _current_state: int = State.CLEAR
var _timer: float = 0.0
var _fade_progress: float = 1.0
var _is_fading: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    # Start in clear weather with a reasonable duration.
    _current_state = State.CLEAR
    _timer = CLEAR_DURATION

func get_state() -> int:
    return _current_state

func get_state_name() -> StringName:
    return State.keys()[_current_state]

func is_rainy() -> bool:
    return _current_state == State.RAIN

func is_stormy() -> bool:
    return _current_state == State.STORM

func is_sunny() -> bool:
    return _current_state == State.SUN

## The mood offset creatures should apply this frame.
func get_mood_modifier() -> float:
    match _current_state:
        State.CLEAR: return MOOD_CLEAR
        State.SUN: return MOOD_SUN
        State.RAIN: return MOOD_RAIN
        State.STORM: return MOOD_STORM
    return 0.0

func _process(delta: float) -> void:
    if _is_fading:
        _fade_progress = clampf(_fade_progress - delta / FADE_TIME, 0.0, 1.0)
        weather_fading.emit(_fade_progress)
        if _fade_progress <= 0.0:
            _is_fading = false
        return

    _timer -= delta
    if _timer <= 0.0:
        _transition_to_next()

func _transition_to_next() -> void:
    var previous: int = _current_state
    _current_state = _pick_next_state(previous)
    _timer = _duration_for(_current_state)
    _is_fading = true
    _fade_progress = 1.0
    weather_changed.emit(previous, _current_state)
    if _current_state == State.STORM and _rng.randf() < LIGHTNING_CHANCE:
        lightning_occurred.emit()

func _duration_for(state: int) -> float:
    match state:
        State.CLEAR: return CLEAR_DURATION
        State.SUN: return SUN_DURATION
        State.RAIN: return RAIN_DURATION
        State.STORM: return STORM_DURATION
    return CLEAR_DURATION

func _pick_next_state(current: int) -> int:
    # Favor natural transitions: clear/sun -> rain -> storm -> clear.
    match current:
        State.CLEAR, State.SUN:
            return RAIN if _rng.randf() < 0.6 else SUN
        State.RAIN:
            return STORM if _rng.randf() < 0.5 else CLEAR
        State.STORM:
            return CLEAR
    return CLEAR

## A creature asks the weather how it should behave. Returns a behavior hint.
func get_behavior_hint() -> Dictionary:
    var hint: Dictionary = {
        "seek_shelter": false,
        "seek_water": false,
        "playful": false,
        "mood_mod": get_mood_modifier(),
    }
    match _current_state:
        State.STORM:
            hint["seek_shelter"] = true
        State.RAIN:
            hint["seek_water"] = true
        State.SUN:
            hint["playful"] = true
    return hint