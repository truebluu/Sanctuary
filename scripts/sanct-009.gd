class_name SanctuaryWeatherSystem
extends Node
## Sanctuary Weather System
## Integrates DayNightCycle and WeatherSystem to affect creature behavior and needs.
## Builds on existing CreatureNeeds, HabitatSystem, and EventBus.
## Tunables are grouped at the top for one-setting changes.

# --- Tunables (design for one-setting changes) ---
const DEFAULT_WEATHER_EFFECTS := {
	"clear": {
		"hunger_multiplier": 1.0,
		"happiness_multiplier": 1.0,
		"activity_multiplier": 1.0,
		"social_multiplier": 1.0,
	},
	"rain": {
		"hunger_multiplier": 1.2,   # Rain increases metabolism
		"happiness_multiplier": 0.9, # Slightly gloomy
		"activity_multiplier": 0.8,  # Less active
		"social_multiplier": 0.9,
	},
	"storm": {
		"hunger_multiplier": 1.4,
		"happiness_multiplier": 0.7,
		"activity_multiplier": 0.5,
		"social_multiplier": 0.6,
	},
	"snow": {
		"hunger_multiplier": 1.3,
		"happiness_multiplier": 0.8,
		"activity_multiplier": 0.6,
		"social_multiplier": 0.7,
	},
	"fog": {
		"hunger_multiplier": 1.0,
		"happiness_multiplier": 0.95,
		"activity_multiplier": 0.7,
		"social_multiplier": 0.8,
	},
	"heat": {
		"hunger_multiplier": 0.9,
		"happiness_multiplier": 0.85,
		"activity_multiplier": 0.6,
		"social_multiplier": 0.7,
	},
}

const NIGHT_HUNGER_MULTIPLIER := 0.8   # Less eating at night
const NIGHT_HAPPINESS_MULTIPLIER := 0.9 # Slightly lower mood
const NIGHT_ACTIVITY_MULTIPLIER := 0.6  # Sleepy
const NIGHT_SOCIAL_MULTIPLIER := 0.7

const DAY_HUNGER_MULTIPLIER := 1.0
const DAY_HAPPINESS_MULTIPLIER := 1.0
const DAY_ACTIVITY_MULTIPLIER := 1.2  # More active during day
const DAY_SOCIAL_MULTIPLIER := 1.1

const CREATURE_GROUP := "creatures"   # Group that all sanctuary creatures belong to

# --- State ---
var _current_weather: String = "clear"
var _is_night: bool = false
var _weather_effects: Dictionary = DEFAULT_WEATHER_EFFECTS

# --- References (injected or found) ---
var _day_night_cycle: Node
var _weather_system: Node
var _creature_needs_engine: Node

func _ready() -> void:
	# Find required systems (they may be autoloads or scene nodes)
	_day_night_cycle = get_node_or_null("/root/DayNightCycle")
	_weather_system = get_node_or_null("/root/WeatherSystem")
	_creature_needs_engine = get_node_or_null("/root/CreatureNeedsEngine")
	
	if not _day_night_cycle:
		push_warning("SanctuaryWeatherSystem: DayNightCycle not found. Day/night effects disabled.")
	if not _weather_system:
		push_warning("SanctuaryWeatherSystem: WeatherSystem not found. Weather effects disabled.")
	if not _creature_needs_engine:
		push_warning("SanctuaryWeatherSystem: CreatureNeedsEngine not found. Creature modifiers will not be applied.")
	
	# Connect to signals if available
	if _day_night_cycle and _day_night_cycle.has_signal("time_of_day_changed"):
		_day_night_cycle.connect("time_of_day_changed", _on_time_of_day_changed)
	if _weather_system and _weather_system.has_signal("weather_changed"):
		_weather_system.connect("weather_changed", _on_weather_changed)
	
	# Initial state
	if _day_night_cycle:
		_is_night = _day_night_cycle.is_night() if _day_night_cycle.has_method("is_night") else false
	if _weather_system:
		_current_weather = _weather_system.get_current_weather() if _weather_system.has_method("get_current_weather") else "clear"
	
	# Apply initial modifiers
	_apply_all_modifiers()

func _on_time_of_day_changed(time_of_day: float) -> void:
	# time_of_day: 0.0 = midnight, 0.5 = noon, 1.0 = midnight
	_is_night = time_of_day < 0.25 or time_of_day >= 0.75
	_apply_all_modifiers()

func _on_weather_changed(weather: String) -> void:
	_current_weather = weather
	_apply_all_modifiers()

func _apply_all_modifiers() -> void:
	if not _creature_needs_engine:
		return
	# Get all creatures from group
	var creatures := get_tree().get_nodes_in_group(CREATURE_GROUP)
	for creature in creatures:
		_apply_modifiers_to_creature(creature)

func _apply_modifiers_to_creature(creature: Node) -> void:
	# Compute combined multipliers
	var weather_effect: Dictionary = _weather_effects.get(_current_weather, DEFAULT_WEATHER_EFFECTS["clear"])
	var hunger_mult := weather_effect.get("hunger_multiplier", 1.0)
	var happiness_mult := weather_effect.get("happiness_multiplier", 1.0)
	var activity_mult := weather_effect.get("activity_multiplier", 1.0)
	var social_mult := weather_effect.get("social_multiplier", 1.0)
	
	if _is_night:
		hunger_mult *= NIGHT_HUNGER_MULTIPLIER
		happiness_mult *= NIGHT_HAPPINESS_MULTIPLIER
		activity_mult *= NIGHT_ACTIVITY_MULTIPLIER
		social_mult *= NIGHT_SOCIAL_MULTIPLIER
	else:
		hunger_mult *= DAY_HUNGER_MULTIPLIER
		happiness_mult *= DAY_HAPPINESS_MULTIPLIER
		activity_mult *= DAY_ACTIVITY_MULTIPLIER
		social_mult *= DAY_SOCIAL_MULTIPLIER
	
	# Apply to creature if it has the expected interface
	if creature.has_method("set_weather_modifiers"):
		creature.set_weather_modifiers({
			"hunger_multiplier": hunger_mult,
			"happiness_multiplier": happiness_mult,
			"activity_multiplier": activity_mult,
			"social_multiplier": social_mult
		})
	elif creature.has_method("modify_needs"):
		# Fallback: directly modify needs if the creature exposes that
		creature.modify_needs({
			"hunger_rate": hunger_mult,
			"happiness_rate": happiness_mult,
			"activity_rate": activity_mult,
			"social_rate": social_mult
		})
	else:
		# If creature doesn't support modifiers, we can still adjust via CreatureNeedsEngine
		if _creature_needs_engine and _creature_needs_engine.has_method("apply_weather_to_creature"):
			_creature_needs_engine.apply_weather_to_creature(creature, {
				"hunger_multiplier": hunger_mult,
				"happiness_multiplier": happiness_mult,
				"activity_multiplier": activity_mult,
				"social_multiplier": social_mult
			})
		else:
			push_warning("SanctuaryWeatherSystem: Creature %s does not support weather modifiers and no fallback found." % creature.name)

# --- Public API for other systems to query current state ---
func get_current_weather() -> String:
	return _current_weather

func is_night() -> bool:
	return _is_night

func get_combined_multipliers() -> Dictionary:
	var weather_effect: Dictionary = _weather_effects.get(_current_weather, DEFAULT_WEATHER_EFFECTS["clear"])
	var result := {
		"hunger_multiplier": weather_effect.get("hunger_multiplier", 1.0),
		"happiness_multiplier": weather_effect.get("happiness_multiplier", 1.0),
		"activity_multiplier": weather_effect.get("activity_multiplier", 1.0),
		"social_multiplier": weather_effect.get("social_multiplier", 1.0)
	}
	if _is_night:
		result["hunger_multiplier"] *= NIGHT_HUNGER_MULTIPLIER
		result["happiness_multiplier"] *= NIGHT_HAPPINESS_MULTIPLIER
		result["activity_multiplier"] *= NIGHT_ACTIVITY_MULTIPLIER
		result["social_multiplier"] *= NIGHT_SOCIAL_MULTIPLIER
	else:
		result["hunger_multiplier"] *= DAY_HUNGER_MULTIPLIER
		result["happiness_multiplier"] *= DAY_HAPPINESS_MULTIPLIER
		result["activity_multiplier"] *= DAY_ACTIVITY_MULTIPLIER
		result["social_multiplier"] *= DAY_SOCIAL_MULTIPLIER
	return result