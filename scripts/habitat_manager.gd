# HabitatManager — Sanctuary (Bluu Ink Studios)
# SANCTUARY-022 Creature Habitat World Integration
# Pure simulation logic (headless-testable): manages creature habitats with zone-based
# comfort scoring across 4 dimensions (temperature, space, enrichment, social) each 0..1.
#
# Integration with CreatureNeeds (class_name CreatureNeeds, extends RefCounted, at res://scripts/creature_needs.gd):
#   - Habitat comfort feeds the creature's 'social' need conceptually. A habitat's social zone quality
#     represents the quality of social interaction opportunities available in that enclosure.
#   - In migration_suggestion(), we consider the creature's current habitat comfort vs. alternatives.
#     Low social comfort in the current habitat should correlate with declining CreatureNeeds.get_social().
#   - External systems should call CreatureNeeds.set_social() based on habitat comfort when ticking
#     creature needs, e.g.: needs.set_social(lerp(needs.get_social(), habitat_comfort * 0.8, 0.1 * delta))
#
# Integration with CreatureSpawner (class_name CreatureSpawner, extends Node, at res://scripts/creature_spawner.gd):
#   - HabitatManager provides habitat zone data for spawning decisions.
#   - spawn_creature_in_habitat() assigns spawned creatures to appropriate habitats.
#
# Architecture:
#   - Habitats are identified by String ID, have a fixed capacity, and store zone qualities.
#   - Creatures are assigned by integer creature_id. A creature can only be in one habitat at a time.
#   - Comfort is a weighted average of zone qualities (weights configurable per habitat or global defaults).
#   - get_best_habitat() selects the highest-comfort habitat matching a creature's preferred dimensions.
#   - Migration is suggested when current comfort drops below a threshold (default 0.4) AND a better
#     habitat exists with comfort exceeding the current by a margin (default 0.15).

class_name HabitatManager
extends RefCounted

# Emitted when a habitat zone quality changes, carrying the new clamped value.
signal comfort_changed(habitat_id: String, zone: StringName, value: float)
# Emitted when a creature migrates from one habitat to another (including initial assignment).
signal migrated(creature_id: int, from_habitat: String, to_habitat: String)
# Emitted when a creature is spawned into a habitat.
signal creature_spawned(creature_id: int, habitat_id: String, species_id: StringName)

# Default zone quality for new habitats (neutral midpoint). Exported for inspector tuning.
@export var default_zone_quality: float = 0.5
# Global migration threshold: below this comfort, creatures seek better habitats.
@export var migration_threshold: float = 0.4

# Constants for magic numbers used in logic.
const DEFAULT_MIGRATION_MARGIN: float = 0.15
const OVERCROWDING_SPACE_PENALTY_RATE: float = 0.3
const OVERCROWDING_SOCIAL_PENALTY_RATE: float = 0.2
const COMFORT_EPSILON: float = 1.0e-6
const DEFAULT_CREATURE_PREFS_TEMPERATURE: float = 0.5
const DEFAULT_CREATURE_PREFS_SOCIAL: float = 0.5

# Internal habitat data structure.
# Each habitat: { id, capacity, zones: Dictionary[StringName, float], creatures: Array[int], weights: Dictionary[StringName, float] }
var _habitats: Dictionary = {}

# Mapping from creature_id -> habitat_id for fast reverse lookup.
var _creature_habitat: Dictionary = {}

# Default weights for the 4 comfort dimensions (sum = 1.0).
# Override per-habitat via the optional weights parameter in add_habitat().
var _default_weights: Dictionary = {
	&"temperature": 0.25,
	&"space": 0.25,
	&"enrichment": 0.25,
	&"social": 0.25,
}

# Valid zone names (StringName for fast dictionary keys).
static var _VALID_ZONES: Array[StringName] = [&"temperature", &"space", &"enrichment", &"social"]

# Minimum comfort improvement required to suggest migration.
# Tunable via set_migration_margin().
var _migration_margin: float = DEFAULT_MIGRATION_MARGIN

# Initialize a new habitat with given id and capacity.
# Zones default to default_zone_quality. Optional weights override default weights.
# Emits comfort_changed for each zone when first set if values differ from default.
func add_habitat(id: String, capacity: int, weights: Dictionary = {}) -> void:
	if id in _habitats:
		push_error("HabitatManager.add_habitat: habitat with id '%s' already exists" % id)
		return
	if capacity <= 0:
		push_error("HabitatManager.add_habitat: capacity must be > 0, got %d" % capacity)
		return
	var habitat_zones: Dictionary = {}
	for zone in _VALID_ZONES:
		habitat_zones[zone] = default_zone_quality
	var effective_weights: Dictionary = _default_weights.duplicate()
	for k in weights:
		if k in _VALID_ZONES:
			effective_weights[k] = weights[k]
		else:
			push_warning("HabitatManager.add_habitat: unknown weight key '%s' ignored" % k)
	# Normalize weights to sum to 1.0
	var weight_sum: float = 0.0
	for w in effective_weights.values():
		weight_sum += float(w)
	if weight_sum > 0.0:
		for k in effective_weights.keys():
			effective_weights[k] = float(effective_weights[k]) / weight_sum
	else:
		effective_weights = _default_weights.duplicate()
	_habitats[id] = {
		"id": id,
		"capacity": capacity,
		"zones": habitat_zones,
		"creatures": [],
		"weights": effective_weights,
	}
	# Emit initial comfort_changed for all zones (from implicit 0.0 to default_zone_quality)
	for zone in _VALID_ZONES:
		comfort_changed.emit(id, zone, default_zone_quality)

# Spawn a creature into the best habitat matching its preferences.
# This is the primary API for CreatureRuntimeSpawner integration (SANCTUARY-022).
# creature_id: unique identifier for the creature
# species_id: logical species identifier (e.g., &"emberling", &"splashling")
# creature_prefs: optional Dictionary of zone preferences for habitat selection
# Returns the habitat_id where the creature was spawned, or "" if no habitat available.
func spawn(creature_id: int, species_id: StringName, creature_prefs: Dictionary = {}) -> String:
	# Use default preferences if none provided
	var prefs: Dictionary = creature_prefs.duplicate()
	if not prefs.has(&"temperature"):
		prefs[&"temperature"] = DEFAULT_CREATURE_PREFS_TEMPERATURE
	if not prefs.has(&"social"):
		prefs[&"social"] = DEFAULT_CREATURE_PREFS_SOCIAL
	
	# Find best habitat with available capacity
	var best_habitat: String = get_best_habitat(prefs)
	if best_habitat == "":
		push_error("HabitatManager.spawn: no suitable habitat found for creature %d (species: %s)" % [creature_id, species_id])
		return ""
	
	# Register and assign the creature
	if not register_creature(creature_id):
		push_warning("HabitatManager.spawn: creature %d already registered" % creature_id)
	
	var success: bool = assign_creature(creature_id, best_habitat)
	if not success:
		push_error("HabitatManager.spawn: failed to assign creature %d to habitat %s" % [creature_id, best_habitat])
		return ""
	
	# Emit spawn signal for external systems (CreatureSpawner, HUD, etc.)
	creature_spawned.emit(creature_id, best_habitat, species_id)
	return best_habitat

# Register a creature with the manager (no habitat assignment yet).
# Returns true if registered, false if already registered.
func register_creature(creature_id: int) -> bool:
	if creature_id in _creature_habitat:
		return false
	_creature_habitat[creature_id] = ""
	return true

# Assign a creature to a habitat (alias for external API clarity).
# Returns true on success, false if habitat full or invalid.
# A creature can only be in one habitat; reassigning moves them (emits migrated).
func assign_to_enclosure(creature_id: int, habitat_id: String) -> bool:
	return assign_creature(creature_id, habitat_id)

# Internal assignment logic shared by assign_to_enclosure and migration logic.
func assign_creature(creature_id: int, habitat_id: String) -> bool:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.assign_creature: habitat '%s' not found" % habitat_id)
		return false
	var habitat: Dictionary = _habitats[habitat_id]
	if habitat.creatures.size() >= habitat.capacity:
		return false
	# If creature already assigned elsewhere, move them
	var current_habitat_id: String = _creature_habitat.get(creature_id, "")
	if current_habitat_id != "" and current_habitat_id != habitat_id:
		_remove_creature_from_habitat(creature_id, current_habitat_id)
		habitat.creatures.append(creature_id)
		_creature_habitat[creature_id] = habitat_id
		migrated.emit(creature_id, current_habitat_id, habitat_id)
		return true
	elif current_habitat_id == habitat_id:
		# Already in this habitat
		return true
	else:
		# New assignment
		habitat.creatures.append(creature_id)
		_creature_habitat[creature_id] = habitat_id
		migrated.emit(creature_id, "", habitat_id)
		return true

# Set the quality of a specific zone for a habitat. Value clamped to 0..1.
# Emits comfort_changed(habitat_id, zone, value).
func set_zone_quality(habitat_id: String, zone: StringName, value: float) -> void:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.set_zone_quality: habitat '%s' not found" % habitat_id)
		return
	if not (zone in _VALID_ZONES):
		push_error("HabitatManager.set_zone_quality: invalid zone '%s'" % zone)
		return
	var clamped: float = clampf(value, 0.0, 1.0)
	var habitat: Dictionary = _habitats[habitat_id]
	var old: float = float(habitat.zones[zone])
	if absf(old - clamped) < COMFORT_EPSILON:
		return
	habitat.zones[zone] = clamped
	comfort_changed.emit(habitat_id, zone, clamped)

# Get the weighted comfort score for a habitat (0..1).
# Uses the habitat's zone qualities and weights.
func get_comfort(habitat_id: String) -> float:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.get_comfort: habitat '%s' not found" % habitat_id)
		return 0.0
	var habitat: Dictionary = _habitats[habitat_id]
	var comfort: float = 0.0
	for zone in _VALID_ZONES:
		comfort += float(habitat.zones[zone]) * float(habitat.weights[zone])
	return comfort

# Get the best habitat for a creature given its dimension preferences.
# creature_prefs: Dictionary with StringName keys (subset of _VALID_ZONES) and float weights (importance).
# Returns the habitat_id with highest weighted comfort, or "" if no habitats exist.
# Only considers habitats with available capacity.
func get_best_habitat(creature_prefs: Dictionary) -> String:
	if _habitats.is_empty():
		return ""
	var best_id: String = ""
	var best_score: float = -1.0
	for habitat_id in _habitats:
		var habitat: Dictionary = _habitats[habitat_id]
		if habitat.creatures.size() >= habitat.capacity:
			continue
		var score: float = 0.0
		var total_pref_weight: float = 0.0
		for zone in _VALID_ZONES:
			var pref_weight: float = 0.0
			if zone in creature_prefs:
				pref_weight = float(creature_prefs[zone])
			# If no explicit preference, use the habitat's own weight as fallback importance
			if pref_weight == 0.0:
				pref_weight = float(habitat.weights[zone])
			score += float(habitat.zones[zone]) * pref_weight
			total_pref_weight += pref_weight
		if total_pref_weight > 0.0:
			score /= total_pref_weight
		if score > best_score:
			best_score = score
			best_id = habitat_id
	return best_id

# Get the number of creatures currently assigned to a habitat.
func creature_count(habitat_id: String) -> int:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.creature_count: habitat '%s' not found" % habitat_id)
		return 0
	return _habitats[habitat_id].creatures.size()

# Get total number of habitats currently registered.
func get_habitat_count() -> int:
	return _habitats.size()

# Suggest a better habitat for a creature if current comfort is below threshold.
# Returns habitat_id of better habitat, or "" if no migration suggested.
# Logic: if creature's current habitat comfort < migration_threshold AND there exists
# another habitat with comfort > current + _migration_margin AND has capacity, suggest it.
# This integrates with CreatureNeeds (class_name CreatureNeeds): low social zone quality
# in current habitat correlates with declining CreatureNeeds.get_social(). External systems
# should feed habitat comfort into the creature's social need. Migration helps restore it.
func migration_suggestion(creature_id: int) -> String:
	var current_habitat_id: String = _creature_habitat.get(creature_id, "")
	if current_habitat_id == "":
		return ""
	var current_comfort: float = get_comfort(current_habitat_id)
	if current_comfort >= migration_threshold:
		return ""
	var best_alternative: String = ""
	var best_comfort: float = current_comfort
	for habitat_id in _habitats:
		if habitat_id == current_habitat_id:
			continue
		var habitat: Dictionary = _habitats[habitat_id]
		if habitat.creatures.size() >= habitat.capacity:
			continue
		var comfort: float = get_comfort(habitat_id)
		if comfort > best_comfort + _migration_margin:
			best_comfort = comfort
			best_alternative = habitat_id
	return best_alternative

# Set the migration comfort threshold (default 0.4). Below this, migration is considered.
func set_migration_threshold(threshold: float) -> void:
	migration_threshold = clampf(threshold, 0.0, 1.0)

# Set the minimum comfort improvement margin for migration (default 0.15).
func set_migration_margin(margin: float) -> void:
	_migration_margin = clampf(margin, 0.0, 1.0)

# Get the current habitat assignment for a creature, or "" if unassigned.
func get_creature_habitat(creature_id: int) -> String:
	return _creature_habitat.get(creature_id, "")

# Remove a creature from its current habitat (if any). Returns true if was assigned.
func remove_creature(creature_id: int) -> bool:
	var current_habitat_id: String = _creature_habitat.get(creature_id, "")
	if current_habitat_id == "":
		return false
	_remove_creature_from_habitat(creature_id, current_habitat_id)
	_creature_habitat.erase(creature_id)
	return true

# Internal helper to remove creature from a specific habitat's creature list.
func _remove_creature_from_habitat(creature_id: int, habitat_id: String) -> void:
	if not (habitat_id in _habitats):
		return
	var habitat: Dictionary = _habitats[habitat_id]
	var idx: int = habitat.creatures.find(creature_id)
	if idx != -1:
		habitat.creatures.remove_at(idx)

# Get all habitat IDs.
func get_habitat_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _habitats:
		ids.append(id)
	return ids

# Get zone qualities for a habitat (copy).
func get_zone_qualities(habitat_id: String) -> Dictionary:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.get_zone_qualities: habitat '%s' not found" % habitat_id)
		return {}
	return _habitats[habitat_id].zones.duplicate()

# Get weights for a habitat (copy).
func get_weights(habitat_id: String) -> Dictionary:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.get_weights: habitat '%s' not found" % habitat_id)
		return {}
	return _habitats[habitat_id].weights.duplicate()

# Set weights for a habitat (normalized to sum 1.0).
func set_weights(habitat_id: String, weights: Dictionary) -> void:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.set_weights: habitat '%s' not found" % habitat_id)
		return
	var effective_weights: Dictionary = _habitats[habitat_id].weights.duplicate()
	for k in weights:
		if k in _VALID_ZONES:
			effective_weights[k] = weights[k]
		else:
			push_warning("HabitatManager.set_weights: unknown weight key '%s' ignored" % k)
	var weight_sum: float = 0.0
	for w in effective_weights.values():
		weight_sum += float(w)
	if weight_sum > 0.0:
		for k in effective_weights.keys():
			effective_weights[k] = float(effective_weights[k]) / weight_sum
	_habitats[habitat_id].weights = effective_weights

# Clear all habitats and creature assignments.
func clear() -> void:
	_habitats.clear()
	_creature_habitat.clear()

# Get capacity for a habitat.
func get_capacity(habitat_id: String) -> int:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.get_capacity: habitat '%s' not found" % habitat_id)
		return 0
	return _habitats[habitat_id].capacity

# Get available capacity (capacity - current creatures) for a habitat.
func get_available_capacity(habitat_id: String) -> int:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.get_available_capacity: habitat '%s' not found" % habitat_id)
		return 0
	var habitat: Dictionary = _habitats[habitat_id]
	return habitat.capacity - habitat.creatures.size()

# Check if a habitat has available capacity.
func has_capacity(habitat_id: String) -> bool:
	return get_available_capacity(habitat_id) > 0

# Get all creatures in a habitat (copy of array).
func get_creatures_in_habitat(habitat_id: String) -> Array[int]:
	if not (habitat_id in _habitats):
		push_error("HabitatManager.get_creatures_in_habitat: habitat '%s' not found" % habitat_id)
		return []
	return _habitats[habitat_id].creatures.duplicate()

# Tick simulation: update comfort based on time, overcrowding, etc.
# delta: time step in seconds.
func tick(delta: float) -> void:
	# Apply overcrowding penalty to comfort zones
	for habitat_id in _habitats:
		var habitat: Dictionary = _habitats[habitat_id]
		var current_count: int = habitat.creatures.size()
		if current_count > habitat.capacity:
			var overcrowding: float = float(current_count - habitat.capacity) / float(habitat.capacity)
			# Penalize space and social zones proportionally
			var space_penalty: float = overcrowding * OVERCROWDING_SPACE_PENALTY_RATE
			var social_penalty: float = overcrowding * OVERCROWDING_SOCIAL_PENALTY_RATE
			var new_space: float = max(0.0, float(habitat.zones[&"space"]) - space_penalty * delta)
			var new_social: float = max(0.0, float(habitat.zones[&"social"]) - social_penalty * delta)
			if absf(new_space - float(habitat.zones[&"space"])) > COMFORT_EPSILON:
				habitat.zones[&"space"] = new_space
				comfort_changed.emit(habitat_id, &"space", new_space)
			if absf(new_social - float(habitat.zones[&"social"])) > COMFORT_EPSILON:
				habitat.zones[&"social"] = new_social
				comfort_changed.emit(habitat_id, &"social", new_social)