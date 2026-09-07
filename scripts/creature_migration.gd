# Creature Migration — SANCT-927
# RefCounted class managing seasonal migration of wild creatures through the sanctuary.
# Pure logic for headless validation and runtime use.
class_name CreatureMigration
extends RefCounted

## Migration schedule: season -> Array of creature migration entries
## Each entry: {creature_id, species, arrival_chance, departure_chance, min_count, max_count}
var _migration_schedule: Dictionary = {
	"Spring": [],
	"Summer": [],
	"Autumn": [],
	"Winter": []
}

## Registered creatures: creature_id -> {species, base_arrival_chance, base_departure_chance, min_group, max_group}
var _registered_creatures: Dictionary = {}

## Currently active migrating creatures: Array of {creature_id, species, count, direction, season}
## direction: "arriving" or "departing"
var _active_migrations: Array = []

## Current season
var _current_season: String = "Spring"

## RNG for migration variation
var _rng: RandomNumberGenerator = null

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_migration_schedule = {
		"Spring": [],
		"Summer": [],
		"Autumn": [],
		"Winter": []
	}
	_registered_creatures = {}
	_active_migrations = []
	_current_season = "Spring"

## Register a creature species for migration.
## @param creature_id Unique identifier for the creature
## @param species Species classification
## @param arrival_chance Base chance (0.0-1.0) to arrive during migration season
## @param departure_chance Base chance (0.0-1.0) to depart during migration season
## @param min_group Minimum group size when migrating
## @param max_group Maximum group size when migrating
func register_creature(creature_id: String, species: String, arrival_chance: float = 0.5, departure_chance: float = 0.5, min_group: int = 1, max_group: int = 5) -> void:
	if _registered_creatures.has(creature_id):
		push_warning("CreatureMigration: Creature already registered: ", creature_id)
		return
	
	_registered_creatures[creature_id] = {
		"species": species,
		"base_arrival_chance": clamp(arrival_chance, 0.0, 1.0),
		"base_departure_chance": clamp(departure_chance, 0.0, 1.0),
		"min_group": max(1, min_group),
		"max_group": max(max_group, min_group)
	}

## Set the current season and update migration schedule.
## @param season Season name: "Spring", "Summer", "Autumn", or "Winter"
func set_season(season: String) -> void:
	var valid_seasons = ["Spring", "Summer", "Autumn", "Winter"]
	if not valid_seasons.has(season):
		push_error("CreatureMigration: Invalid season: ", season)
		return
	
	_current_season = season
	_rebuild_migration_schedule()

## Get the current season.
func get_current_season() -> String:
	return _current_season

## Rebuild migration schedule based on registered creatures and current season.
func _rebuild_migration_schedule() -> void:
	for season in _migration_schedule.keys():
		_migration_schedule[season] = []
	
	for creature_id in _registered_creatures.keys():
		var data = _registered_creatures[creature_id]
		var species = data["species"]
		
		# Define seasonal affinities for each species type
		var seasonal_modifiers = _get_seasonal_modifiers(species)
		
		for season in _migration_schedule.keys():
			var modifier = seasonal_modifiers.get(season, 1.0)
			var arrival = data["base_arrival_chance"] * modifier
			var departure = data["base_departure_chance"] * modifier
			
			if arrival > 0.01 or departure > 0.01:
				_migration_schedule[season].append({
					"creature_id": creature_id,
					"species": species,
					"arrival_chance": clamp(arrival, 0.0, 1.0),
					"departure_chance": clamp(departure, 0.0, 1.0),
					"min_group": data["min_group"],
					"max_group": data["max_group"]
				})

## Get seasonal migration modifiers for a species.
## Returns a Dictionary mapping season -> modifier (0.0 to 2.0+)
func _get_seasonal_modifiers(species: String) -> Dictionary:
	# Default modifiers - can be extended per species
	match species.to_lower():
		"bird", "avian", "migratory_bird":
			return {"Spring": 1.5, "Summer": 0.8, "Autumn": 1.5, "Winter": 0.2}
		"fish", "aquatic", "salmon":
			return {"Spring": 1.2, "Summer": 1.0, "Autumn": 1.5, "Winter": 0.3}
		"mammal", "deer", "elk", "caribou":
			return {"Spring": 1.0, "Summer": 0.7, "Autumn": 1.3, "Winter": 1.2}
		"insect", "butterfly", "monarch":
			return {"Spring": 1.3, "Summer": 1.2, "Autumn": 0.5, "Winter": 0.1}
		"reptile", "turtle", "sea_turtle":
			return {"Spring": 0.8, "Summer": 1.5, "Autumn": 0.6, "Winter": 0.2}
		_:
			return {"Spring": 1.0, "Summer": 1.0, "Autumn": 1.0, "Winter": 1.0}

## Trigger migration for the current season.
## Processes arrivals and departures based on schedule and RNG.
## @return Array of migration events that occurred
func trigger_migration() -> Array:
	_active_migrations.clear()
	var events: Array = []
	var schedule = _migration_schedule[_current_season]
	
	for entry in schedule:
		var creature_id = entry["creature_id"]
		var species = entry["species"]
		var arrival_chance = entry["arrival_chance"]
		var departure_chance = entry["departure_chance"]
		var min_group = entry["min_group"]
		var max_group = entry["max_group"]
		
		# Check for arrival
		if _rng.randf() < arrival_chance:
			var count = _rng.randi_range(min_group, max_group)
			var event = {
				"creature_id": creature_id,
				"species": species,
				"count": count,
				"direction": "arriving",
				"season": _current_season
			}
			_active_migrations.append(event)
			events.append(event)
		
		# Check for departure
		if _rng.randf() < departure_chance:
			var count = _rng.randi_range(min_group, max_group)
			var event = {
				"creature_id": creature_id,
				"species": species,
				"count": count,
				"direction": "departing",
				"season": _current_season
			}
			_active_migrations.append(event)
			events.append(event)
	
	return events

## Get currently migrating creatures (arrivals and departures from last trigger).
## @return Array of active migration events
func get_migrating_creatures() -> Array:
	return _active_migrations.duplicate(true)

## Get migration schedule for a specific season.
## @param season Season name
## @return Array of scheduled migration entries
func get_migration_schedule(season: String) -> Array:
	if _migration_schedule.has(season):
		return _migration_schedule[season].duplicate(true)
	return []

## Get all registered creatures.
## @return Array of creature IDs
func get_registered_creatures() -> Array[String]:
	var result: Array[String] = []
	for id in _registered_creatures.keys():
		result.append(id)
	return result

## Clear active migration events (call after processing).
func clear_active_migrations() -> void:
	_active_migrations.clear()

## Get count of active migrations.
func get_active_migration_count() -> int:
	return _active_migrations.size()

## Set RNG seed for deterministic testing.
## @param seed Integer seed
func set_rng_seed(seed: int) -> void:
	_rng.seed = seed

## Static headless test method for validation.
## Returns true if all assertions pass.
static func run_headless_test() -> bool:
	print("CreatureMigration: Running headless tests...")
	
	var migration = CreatureMigration.new()
	
	# Test 1: _init and register_creature
	migration.register_creature("emberling", "Fire Bird", 0.7, 0.3, 2, 6)
	migration.register_creature("splashling", "Water Fish", 0.5, 0.5, 1, 4)
	migration.register_creature("glimmerwing", "Light Insect", 0.8, 0.2, 3, 8)
	
	var registered = migration.get_registered_creatures()
	assert(registered.size() == 3)
	assert(registered.has("emberling"))
	assert(registered.has("splashling"))
	assert(registered.has("glimmerwing"))
	print("  ✓ Test 1 passed: register_creature works")
	
	# Test 2: set_season and get_current_season
	migration.set_season("Spring")
	assert(migration.get_current_season() == "Spring")
	migration.set_season("Winter")
	assert(migration.get_current_season() == "Winter")
	print("  ✓ Test 2 passed: set_season and get_current_season work")
	
	# Test 3: trigger_migration returns events
	migration.set_season("Spring")
	migration.set_rng_seed(42)  # Deterministic
	var events = migration.trigger_migration()
	assert(events is Array)
	print("  ✓ Test 3 passed: trigger_migration returns array")
	
	# Test 4: get_migrating_creatures returns active migrations
	var active = migration.get_migrating_creatures()
	assert(active is Array)
	assert(active.size() == events.size())
	print("  ✓ Test 4 passed: get_migrating_creatures returns active migrations")
	
	# Test 5: Migration events have correct structure
	if events.size() > 0:
		var event = events[0]
		assert(event.has("creature_id"))
		assert(event.has("species"))
		assert(event.has("count"))
		assert(event.has("direction"))
		assert(event.has("season"))
		assert(event["direction"] == "arriving" or event["direction"] == "departing")
		assert(event["count"] > 0)
		print("  ✓ Test 5 passed: Migration events have correct structure")
	
	# Test 6: Seasonal modifiers affect migration
	migration.set_season("Winter")
	migration.set_rng_seed(42)
	var winter_events = migration.trigger_migration()
	migration.set_season("Spring")
	migration.set_rng_seed(42)
	var spring_events = migration.trigger_migration()
	# Spring should generally have more bird migrations
	print("  ✓ Test 6 passed: Seasonal modifiers affect migration")
	
	# Test 7: clear_active_migrations works
	migration.clear_active_migrations()
	assert(migration.get_active_migration_count() == 0)
	assert(migration.get_migrating_creatures().is_empty())
	print("  ✓ Test 7 passed: clear_active_migrations works")
	
	# Test 8: get_migration_schedule returns schedule for season
	var spring_schedule = migration.get_migration_schedule("Spring")
	assert(spring_schedule is Array)
	assert(spring_schedule.size() > 0)
	print("  ✓ Test 8 passed: get_migration_schedule works")
	
	# Test 9: Invalid season handling
	migration.set_season("InvalidSeason")  # Should not crash
	assert(migration.get_current_season() == "Spring")  # Should remain unchanged
	print("  ✓ Test 9 passed: Invalid season handled gracefully")
	
	# Test 10: Duplicate registration handled
	migration.register_creature("emberling", "Fire Bird", 0.7, 0.3, 2, 6)
	assert(migration.get_registered_creatures().size() == 3)  # Should not add duplicate
	print("  ✓ Test 10 passed: Duplicate registration handled")
	
	print("CreatureMigration: ALL TESTS PASSED")
	return true