# SeasonalCycle — Sanctuary (Bluu Ink Studios)
# SANCT-731 Seasonal Cycle system (in-game day/season calendar).
# Pure simulation logic (headless-testable): models an in-game clock with
# day/night cycle and four seasons (Spring, Summer, Autumn, Winter). Each season
# has unique biome palette swaps, creature migration modifiers, resource
# availability shifts, and weather effects. Integrates with CreatureNeeds,
# BuildingSystem, and genetics via signals.

extends RefCounted
class_name SeasonalCycle

## Seasons in order.
enum Season { SPRING, SUMMER, AUTUMN, WINTER }

## In-game time scale: 1.0 = real-time seconds per in-game minute.
## Higher = faster day/night cycle.
@export var time_scale: float = 0.05

## Minutes per in-game day (default 24h = 1440 min).
@export var minutes_per_day: int = 1440

## Days per season.
@export var days_per_season: int = 15

## Current season (read-only).
var current_season: Season = Season.SPRING

## Current day within the season (1..days_per_season).
var day_of_season: int = 1

## Current hour (0..23).
var hour: int = 6

## Current minute (0..59).
var minute: int = 0

## Total days elapsed since start.
var total_days: int = 0

## True between sunset and sunrise.
var is_night: bool = false

## Accumulator for sub-tick time.
var _time_accum: float = 0.0

## Season definitions with gameplay modifiers.
var _season_data: Dictionary = {
	Season.SPRING: {
		"name": "Spring",
		"palette_shift": Color(0.2, 0.8, 0.3, 1.0),   # Fresh green
		"creature_spawn_bias": { "herbivore": 1.5, "social": 1.3, "shy": 1.2 },
		"resource_bonus": { "plant": 1.5, "nectar": 1.4, "water": 1.1 },
		"weather_weights": { "clear": 0.5, "rain": 0.3, "storm": 0.1, "wind": 0.1 },
		"temperature_range": Vector2(12.0, 22.0),       # Celsius
		"daylight_hours": Vector2i(6, 20),              # Sunrise 6, Sunset 20
		"migration_modifier": 1.2,
	},
	Season.SUMMER: {
		"name": "Summer",
		"palette_shift": Color(1.0, 0.9, 0.3, 1.0),     # Golden
		"creature_spawn_bias": { "carnivore": 1.3, "territorial": 1.4, "nocturnal": 0.8 },
		"resource_bonus": { "fruit": 1.6, "insect": 1.5, "water": 0.7 },
		"weather_weights": { "clear": 0.6, "rain": 0.2, "storm": 0.15, "wind": 0.05 },
		"temperature_range": Vector2(22.0, 35.0),
		"daylight_hours": Vector2i(5, 21),
		"migration_modifier": 1.0,
	},
	Season.AUTUMN: {
		"name": "Autumn",
		"palette_shift": Color(0.9, 0.5, 0.15, 1.0),    # Amber/orange
		"creature_spawn_bias": { "scavenger": 1.6, "social": 1.2, "alpha": 1.1 },
		"resource_bonus": { "seed": 1.7, "mushroom": 1.5, "berry": 1.3 },
		"weather_weights": { "clear": 0.4, "rain": 0.4, "storm": 0.1, "wind": 0.1 },
		"temperature_range": Vector2(8.0, 18.0),
		"daylight_hours": Vector2i(7, 18),
		"migration_modifier": 1.3,
	},
	Season.WINTER: {
		"name": "Winter",
		"palette_shift": Color(0.6, 0.8, 1.0, 1.0),     # Cool blue-white
		"creature_spawn_bias": { "carnivore": 0.7, "herbivore": 0.6, "nocturnal": 1.4, "shy": 1.3 },
		"resource_bonus": { "plant": 0.3, "water": 0.5, "crystal": 1.4, "preserved": 1.3 },
		"weather_weights": { "clear": 0.3, "rain": 0.1, "storm": 0.1, "snow": 0.4, "wind": 0.1 },
		"temperature_range": Vector2(-10.0, 5.0),
		"daylight_hours": Vector2i(8, 16),
		"migration_modifier": 0.5,
	},
}

## Signals for integration with other systems.
signal season_changed(new_season: Season, season_name: String)
signal day_changed(day: int, season: Season)
signal hour_changed(hour: int, is_night: bool)
signal weather_changed(weather: String, intensity: float)
signal temperature_changed(temp_celsius: float)
signal daylight_changed(sunrise: int, sunset: int)
signal migration_event(direction: String, intensity: float)
signal resource_shift(resource: String, multiplier: float)

func _init(scale: float = 0.05, mins_per_day: int = 1440, days_per_szn: int = 15) -> void:
	time_scale = maxf(0.001, scale)
	minutes_per_day = maxi(60, mins_per_day)
	days_per_season = maxi(1, days_per_szn)
	_reset_time()

func _reset_time() -> void:
	hour = 6
	minute = 0
	day_of_season = 1
	current_season = Season.SPRING
	total_days = 0
	_update_night_state()
	_update_daylight()

## Advance the simulation by `delta` real-time seconds.
func tick(delta: float) -> void:
	_time_accum += delta * time_scale
	var minutes_advanced: int = int(_time_accum)
	if minutes_advanced <= 0:
		return
	_time_accum -= minutes_advanced

	for _ in range(minutes_advanced):
		_advance_minute()

func _advance_minute() -> void:
	minute += 1
	if minute >= 60:
		minute = 0
		hour += 1
		_hour_changed()
		if hour >= 24:
			hour = 0
			_advance_day()

func _hour_changed() -> void:
	var was_night := is_night
	_update_night_state()
	_update_daylight()
	hour_changed.emit(hour, is_night)
	if is_night != was_night:
		# Dawn or dusk — temperature shift
		var temp := get_current_temperature()
		temperature_changed.emit(temp)

func _advance_day() -> void:
	day_of_season += 1
	total_days += 1
	day_changed.emit(day_of_season, current_season)

	if day_of_season > days_per_season:
		day_of_season = 1
		_advance_season()

	# Daily resource shift notification
	_resource_daily_shift()

func _advance_season() -> void:
	var old_season := current_season
	current_season = Season((int(current_season) + 1) % 4)
	var data: Dictionary = _season_data[current_season]
	season_changed.emit(current_season, String(data["name"]))

	# Notify daylight change for new season
	_update_daylight()

	# Migration event
	var mig_mod := float(data.get("migration_modifier", 1.0))
	var dir := "north" if current_season == Season.SPRING or current_season == Season.SUMMER else "south"
	migration_event.emit(dir, mig_mod)

	# Resource shifts for the new season
	_apply_season_resource_bonuses(data)

	# Weather roll for season start
	_roll_weather()

func _update_night_state() -> void:
	var data: Dictionary = _season_data[current_season]
	var daylight: Vector2i = data["daylight_hours"]
	var sunrise := daylight.x
	var sunset := daylight.y
	is_night = (hour < sunrise) or (hour >= sunset)

func _update_daylight() -> void:
	var data: Dictionary = _season_data[current_season]
	var daylight: Vector2i = data["daylight_hours"]
	daylight_changed.emit(daylight.x, daylight.y)

func _resource_daily_shift() -> void:
	var data: Dictionary = _season_data[current_season]
	var bonuses: Dictionary = data["resource_bonus"]
	for res in bonuses:
		resource_shift.emit(res, float(bonuses[res]))

func _apply_season_resource_bonuses(data: Dictionary) -> void:
	var bonuses: Dictionary = data["resource_bonus"]
	for res in bonuses:
		resource_shift.emit(res, float(bonuses[res]))

func _roll_weather() -> void:
	var data: Dictionary = _season_data[current_season]
	var weights: Dictionary = data["weather_weights"]
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var roll := randf() * total
	var accum := 0.0
	for wtype in weights:
		accum += float(weights[wtype])
		if roll <= accum:
			var intensity := randf_range(0.3, 1.0)
			weather_changed.emit(wtype, intensity)
			# Temperature varies with weather
			var base_temp := get_current_temperature()
			if wtype == "rain" or wtype == "storm" or wtype == "snow":
				base_temp -= 3.0 * intensity
			elif wtype == "clear":
				base_temp += 2.0 * intensity
			temperature_changed.emit(base_temp)
			break

## Get the current season's data dictionary.
func get_season_data() -> Dictionary:
	return _season_data[current_season].duplicate(true)

## Get the current season name as string.
func get_season_name() -> String:
	return String(_season_data[current_season]["name"])

## Get current temperature in Celsius (with weather influence).
func get_current_temperature() -> float:
	var data: Dictionary = _season_data[current_season]
	var range: Vector2 = data["temperature_range"]
	# Base temperature varies by hour (warmer midday)
	var hour_factor := abs(float(hour - 14)) / 14.0  # 0 at 14:00, 1 at 0:00/23:00
	var base := lerpf(range.y, range.x, hour_factor)
	return base

## Get creature spawn bias for a given archetype.
func get_spawn_bias(archetype: String) -> float:
	var data: Dictionary = _season_data[current_season]
	var biases: Dictionary = data["creature_spawn_bias"]
	return float(biases.get(archetype, 1.0))

## Get resource availability multiplier for a resource type.
func get_resource_multiplier(resource: String) -> float:
	var data: Dictionary = _season_data[current_season]
	var bonuses: Dictionary = data["resource_bonus"]
	return float(bonuses.get(resource, 1.0))

## Get current weather weights for spawning weather effects.
func get_weather_weights() -> Dictionary:
	return _season_data[current_season]["weather_weights"].duplicate(true)

## Get migration modifier for current season.
func get_migration_modifier() -> float:
	return float(_season_data[current_season].get("migration_modifier", 1.0))

## Get daylight hours for current season (sunrise, sunset).
func get_daylight_hours() -> Vector2i:
	return _season_data[current_season]["daylight_hours"]

## Check if it's currently night.
func is_night_time() -> bool:
	return is_night

## Get time of day as 0..1 (0 = midnight, 0.5 = noon).
func get_time_of_day() -> float:
	return (float(hour) + float(minute) / 60.0) / 24.0

## Get progress through current season as 0..1.
func get_season_progress() -> float:
	return float(day_of_season - 1) / float(days_per_season)

## Get progress through current day as 0..1.
func get_day_progress() -> float:
	return get_time_of_day()

## Format current time as HH:MM.
func get_time_string() -> String:
	return "%02d:%02d" % [hour, minute]

## Format current date as "Season Day X".
func get_date_string() -> String:
	return "%s Day %d" % [get_season_name(), day_of_season]

## Get total days since start.
func get_total_days() -> int:
	return total_days

## Serialize state for saving.
func get_state() -> Dictionary:
	return {
		"season": int(current_season),
		"day_of_season": day_of_season,
		"hour": hour,
		"minute": minute,
		"total_days": total_days,
		"time_scale": time_scale,
		"minutes_per_day": minutes_per_day,
		"days_per_season": days_per_season,
		"_time_accum": _time_accum,
	}

## Load state from save.
func set_state(state: Dictionary) -> void:
	current_season = Season(int(state.get("season", 0)))
	day_of_season = int(state.get("day_of_season", 1))
	hour = int(state.get("hour", 6))
	minute = int(state.get("minute", 0))
	total_days = int(state.get("total_days", 0))
	time_scale = float(state.get("time_scale", time_scale))
	minutes_per_day = int(state.get("minutes_per_day", minutes_per_day))
	days_per_season = int(state.get("days_per_season", days_per_season))
	_time_accum = float(state.get("_time_accum", 0.0))
	_update_night_state()
	_update_daylight()

## Force set season (for testing / debug).
func set_season(season: Season) -> void:
	current_season = season
	day_of_season = 1
	_update_daylight()
	var data: Dictionary = _season_data[current_season]
	season_changed.emit(current_season, String(data["name"]))
	_apply_season_resource_bonuses(data)
	_roll_weather()

## Force set time of day (for testing / debug).
func set_time(h: int, m: int) -> void:
	hour = clampi(h, 0, 23)
	minute = clampi(m, 0, 59)
	_hour_changed()

## Advance to next season immediately.
func advance_season() -> void:
	_advance_season()

## Advance to next day immediately.
func advance_day() -> void:
	_advance_day()

## Set time scale at runtime.
func set_time_scale(scale: float) -> void:
	time_scale = maxf(0.001, scale)

## Get biome palette shift color for current season.
func get_palette_shift() -> Color:
	return _season_data[current_season]["palette_shift"]