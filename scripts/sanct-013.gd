class_name SanctuaryExpansion
extends Node
## Unlockable sanctuary zones as the player progresses.
## Builds on the existing sanctuary system (SanctuaryPanel, HabitatManager)
## and GameState progression. Each zone has an unlock condition (wave, level,
## or a custom predicate) and is persisted via SaveGameManager.

signal zone_unlocked(zone_id: String)
signal zone_locked(zone_id: String)  # emitted when a zone is re-locked (if ever)

# --- Tunables (one place to adjust expansion pacing) ---
const SAVE_KEY := "sanctuary_unlocked_zones"
const DEFAULT_UNLOCKED: Array[String] = ["main_habitat"]  # always available

# Zone definitions: each entry is a Dictionary with:
#   id: String (unique)
#   name: String (display name)
#   description: String
#   unlock_type: String ("wave", "level", "custom")
#   unlock_value: int (for wave/level)
#   custom_check: Callable (optional, for custom logic)
@export var zone_definitions: Array[Dictionary] = [
	{
		"id": "main_habitat",
		"name": "Main Habitat",
		"description": "The starting sanctuary zone.",
		"unlock_type": "none",
		"unlock_value": 0
	},
	{
		"id": "garden_zone",
		"name": "Garden Zone",
		"description": "A lush area for plant-loving creatures.",
		"unlock_type": "wave",
		"unlock_value": 3
	},
	{
		"id": "aquatic_zone",
		"name": "Aquatic Zone",
		"description": "A watery habitat for aquatic creatures.",
		"unlock_type": "level",
		"unlock_value": 5
	},
	{
		"id": "sky_zone",
		"name": "Sky Zone",
		"description": "A high-altitude area for flying creatures.",
		"unlock_type": "custom",
		"unlock_value": 0,
		"custom_check": Callable(self, "_check_sky_zone_unlock")
	}
]

var _unlocked: Dictionary = {}  # zone_id -> true

func _ready() -> void:
	_load_unlocked()
	# Connect to GameState signals for progression changes
	if GameState.has_signal("wave_changed"):
		GameState.wave_changed.connect(_on_wave_changed)
	if GameState.has_signal("player_level_changed"):
		GameState.player_level_changed.connect(_on_level_changed)
	# Initial check
	check_unlocks()

# --- Public API ---

func is_zone_unlocked(zone_id: String) -> bool:
	return _unlocked.get(zone_id, false)

func get_unlocked_zones() -> Array[String]:
	return _unlocked.keys()

func get_locked_zones() -> Array[String]:
	var locked: Array[String] = []
	for zone in zone_definitions:
		if not _unlocked.has(zone["id"]):
			locked.append(zone["id"])
	return locked

func get_zone_data(zone_id: String) -> Dictionary:
	for zone in zone_definitions:
		if zone["id"] == zone_id:
			return zone
	return {}

func unlock_zone(zone_id: String) -> void:
	if _unlocked.has(zone_id):
		return
	_unlocked[zone_id] = true
	_save_unlocked()
	zone_unlocked.emit(zone_id)

func lock_zone(zone_id: String) -> void:
	if not _unlocked.has(zone_id):
		return
	_unlocked.erase(zone_id)
	_save_unlocked()
	zone_locked.emit(zone_id)

## Check all zones and unlock any that meet their conditions.
## Called on ready and on progression events.
func check_unlocks() -> void:
	for zone in zone_definitions:
		var zone_id: String = zone["id"]
		if _unlocked.has(zone_id):
			continue
		if _zone_condition_met(zone):
			unlock_zone(zone_id)

# --- Private helpers ---

func _zone_condition_met(zone: Dictionary) -> bool:
	match zone.get("unlock_type", "none"):
		"none":
			return true
		"wave":
			return GameState.current_wave >= zone.get("unlock_value", 0)
		"level":
			return GameState.player_level >= zone.get("unlock_value", 0)
		"custom":
			var check: Callable = zone.get("custom_check", Callable())
			if check.is_valid():
				return check.call()
			return false
	return false

func _check_sky_zone_unlock() -> bool:
	# Example custom condition: unlock after defeating the first boss
	return GameState.bosses_defeated >= 1

# --- Signal handlers ---

func _on_wave_changed(new_wave: int) -> void:
	check_unlocks()

func _on_level_changed(new_level: int) -> void:
	check_unlocks()

# --- Persistence ---

func _load_unlocked() -> void:
	# Start with defaults
	for zone_id in DEFAULT_UNLOCKED:
		_unlocked[zone_id] = true
	# Load saved data
	var saved = SaveGameManager.get_data(SAVE_KEY, {})
	if saved is Dictionary:
		for zone_id in saved:
			if saved[zone_id] == true:
				_unlocked[zone_id] = true

func _save_unlocked() -> void:
	SaveGameManager.set_data(SAVE_KEY, _unlocked)