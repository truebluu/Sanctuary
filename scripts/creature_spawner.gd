# CreatureSpawner — Sanctuary (SANCTUARY-019)
# Runtime spawner for creatures with habitat binding and weighted spawn tables.
# Extends Node for SceneTree access; attach to a SpawnerManager node in your scene.
class_name CreatureSpawner
extends Node

## Emitted when a creature is successfully spawned and bound to a habitat.
## Args: creature (Node), habitat (Node), species_id (StringName), spawn_index (int)
signal creature_spawned(creature: Node, habitat: Node, species_id: StringName, spawn_index: int)

## Emitted when a spawn attempt fails (e.g., invalid habitat, missing scene, pool exhausted).
## Args: habitat (Node), species_id (StringName), reason (String)
signal spawn_failed(habitat: Node, species_id: StringName, reason: String)

## Emitted when the active population changes (creature added/removed).
## Args: current_count (int), max_population (int)
signal population_changed(current_count: int, max_population: int)

# ============================================================================
# EXPORTED CONFIGURATION
# ============================================================================

## Weighted spawn table: Array of Dictionaries with keys:
##   - scene (PackedScene): The creature scene to instantiate.
##   - species_id (StringName): Logical identifier for registry/population tracking.
##   - weight (float): Relative spawn probability (higher = more likely).
##   - habitat_tags (Array[String]): Optional tags; creature only spawns in habitats with matching tag.
##   - max_per_habitat (int): Max instances of this species per habitat (0 = unlimited).
##   - spawn_offset (Vector2): Local offset from habitat origin.
@export var spawn_table: Array[Dictionary] = [
	{
		"scene": null,
		"species_id": &"emberling",
		"weight": 1.0,
		"habitat_tags": ["fire", "volcanic"],
		"max_per_habitat": 3,
		"spawn_offset": Vector2(0, 0)
	},
	{
		"scene": null,
		"species_id": &"splashling",
		"weight": 1.0,
		"habitat_tags": ["water", "aquatic"],
		"max_per_habitat": 3,
		"spawn_offset": Vector2(0, 0)
	},
	{
		"scene": null,
		"species_id": &"glimmerwing",
		"weight": 0.7,
		"habitat_tags": ["air", "mystical"],
		"max_per_habitat": 2,
		"spawn_offset": Vector2(0, -16)
	},
	{
		"scene": null,
		"species_id": &"verdant_sprite",
		"weight": 1.2,
		"habitat_tags": ["nature", "forest"],
		"max_per_habitat": 4,
		"spawn_offset": Vector2(0, 0)
	}
]

## Global maximum creatures across all habitats (0 = unlimited).
@export var max_global_population: int = 50

## Default habitat node name/path to search if none provided to spawn_creature().
@export var default_habitat_path: NodePath = %HabitatRoot

## Whether to auto-assign a CreatureNeedsEngine instance to spawned creatures (if they have the property).
@export var auto_attach_needs_engine: bool = true

## Randomize spawn position within habitat bounds (requires habitat to have a 'bounds' Rect2 property).
@export var randomize_within_bounds: bool = true

# ============================================================================
# INTERNAL STATE
# ============================================================================

## Registry of all spawned creatures: species_id -> Array[Node]
var _creature_registry: Dictionary = {}

## Active habitat bindings: habitat (Node) -> Array[Node] of creatures in that habitat
var _habitat_bindings: Dictionary = {}

## Running spawn index for unique identification
var _spawn_index_counter: int = 0

## Cached total weight for weighted random selection
var _total_weight: float = 0.0
var _weights_dirty: bool = true

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_recalculate_weights()
	# Register with creature groups for integration
	add_to_group("creature_registry")
	add_to_group("creature")
	# Validate spawn table entries
	for i in range(spawn_table.size()):
		var entry = spawn_table[i]
		if entry.scene == null:
			push_warning("CreatureSpawner: spawn_table[%d] has null scene; spawns will fail for species '%s'" % [i, entry.species_id])
		if entry.weight <= 0.0:
			push_warning("CreatureSpawner: spawn_table[%d] has non-positive weight (%f); entry will never be selected" % [i, entry.weight])

func _recalculate_weights() -> void:
	_total_weight = 0.0
	for entry in spawn_table:
		var w: float = float(entry.get("weight", 0.0))
		if w > 0.0:
			_total_weight += w
	_weights_dirty = false

# ============================================================================
# PUBLIC API: SPAWNING
# ============================================================================

## Spawn a creature of the given species (or random weighted) into the specified habitat.
## habitat: Node with optional 'tags' Array[String] and 'bounds' Rect2 properties.
## species_id: StringName to force a specific species; if empty, picks from weighted table.
## Returns the spawned creature Node, or null on failure.
func spawn_creature(habitat: Node, species_id: StringName = &"") -> Node:
	if not is_instance_valid(habitat):
		spawn_failed.emit(habitat, species_id, "invalid_habitat")
		return null

	# Resolve spawn entry
	var entry: Dictionary
	if species_id != &"":
		entry = _find_entry_by_species(species_id)
		if entry == null:
			spawn_failed.emit(habitat, species_id, "species_not_in_spawn_table")
			return null
	else:
		entry = _pick_weighted_entry(habitat)
		if entry == null:
			spawn_failed.emit(habitat, &"", "no_valid_entries_for_habitat")
			return null

	# Check global population cap
	if max_global_population > 0 and get_global_population() >= max_global_population:
		spawn_failed.emit(habitat, entry.species_id, "global_population_cap_reached")
		return null

	# Check per-habitat cap for this species
	var max_per_habitat: int = int(entry.get("max_per_habitat", 0))
	if max_per_habitat > 0:
		var habitat_creatures = _habitat_bindings.get(habitat, [])
		var count_same_species = 0
		for c in habitat_creatures:
			if c.get_meta("__species_id", "") == entry.species_id:
				count_same_species += 1
		if count_same_species >= max_per_habitat:
			spawn_failed.emit(habitat, entry.species_id, "habitat_species_cap_reached")
			return null

	# Validate scene
	var scene: PackedScene = entry.scene
	if scene == null:
		spawn_failed.emit(habitat, entry.species_id, "missing_scene")
		return null

	# Instantiate
	var creature: Node = scene.instantiate()
	if creature == null:
		spawn_failed.emit(habitat, entry.species_id, "instantiation_failed")
		return null

	# Position creature
	var spawn_pos: Vector2 = _calculate_spawn_position(habitat, entry)
	if creature is Node2D:
		creature.global_position = spawn_pos
	elif creature is Node3D:
		creature.global_position = Vector3(spawn_pos.x, 0, spawn_pos.y)

	# Attach metadata for tracking
	creature.set_meta("__species_id", entry.species_id)
	creature.set_meta("__spawn_index", _spawn_index_counter)
	creature.set_meta("__habitat", habitat)
	_spawn_index_counter += 1

	# Optionally attach CreatureNeedsEngine
	if auto_attach_needs_engine and creature.has_method("set_needs_engine"):
		var needs_engine = CreatureNeedsEngine.new() if CreatureNeedsEngine != null else null
		if needs_engine != null:
			creature.set_needs_engine(needs_engine)

	# Register
	_register_creature(creature, habitat, entry.species_id)

	# Emit signal
	creature_spawned.emit(creature, habitat, entry.species_id, creature.get_meta("__spawn_index"))
	population_changed.emit(get_global_population(), max_global_population)

	return creature

## Spawn multiple creatures at once (convenience batch).
## Returns array of successfully spawned creatures.
func spawn_batch(habitat: Node, count: int, species_id: StringName = &"") -> Array[Node]:
	var results: Array[Node] = []
	for i in range(count):
		var c = spawn_creature(habitat, species_id)
		if c != null:
			results.append(c)
		else:
			break  # Stop on first failure (cap reached, etc.)
	return results

## Despawn a specific creature instance, cleaning up registry and habitat binding.
func despawn_creature(creature: Node) -> bool:
	if not is_instance_valid(creature):
		return false

	var species_id: StringName = creature.get_meta("__species_id", &"")
	var habitat: Node = creature.get_meta("__habitat", null)
	var spawn_index: int = creature.get_meta("__spawn_index", -1)

	# Remove from registry
	if _creature_registry.has(species_id):
		var arr = _creature_registry[species_id]
		arr.erase(creature)
		if arr.is_empty():
			_creature_registry.erase(species_id)

	# Remove from habitat binding
	if habitat != null and _habitat_bindings.has(habitat):
		var h_arr = _habitat_bindings[habitat]
		h_arr.erase(creature)
		if h_arr.is_empty():
			_habitat_bindings.erase(habitat)

	creature.queue_free()
	population_changed.emit(get_global_population(), max_global_population)
	return true

## Despawn all creatures in a specific habitat.
func despawn_habitat(habitat: Node) -> int:
	if not _habitat_bindings.has(habitat):
		return 0
	var creatures = _habitat_bindings[habitat].duplicate()
	var count = 0
	for c in creatures:
		if despawn_creature(c):
			count += 1
	return count

## Despawn all creatures globally.
func despawn_all() -> int:
	var total = 0
	for habitat in _habitat_bindings.keys():
		total += despawn_habitat(habitat)
	return total

# ============================================================================
# PUBLIC API: REGISTRY & POPULATION
# ============================================================================

## Get all creatures of a specific species (across all habitats).
func get_creatures_by_species(species_id: StringName) -> Array[Node]:
	if _creature_registry.has(species_id):
		return _creature_registry[species_id].duplicate()
	return []

## Get all creatures currently in a habitat.
func get_creatures_in_habitat(habitat: Node) -> Array[Node]:
	if _habitat_bindings.has(habitat):
		return _habitat_bindings[habitat].duplicate()
	return []

## Get total global population count.
func get_global_population() -> int:
	var total = 0
	for arr in _creature_registry.values():
		total += arr.size()
	return total

## Get population count for a specific species.
func get_species_population(species_id: StringName) -> int:
	if _creature_registry.has(species_id):
		return _creature_registry[species_id].size()
	return 0

## Get population count for a specific habitat.
func get_habitat_population(habitat: Node) -> int:
	if _habitat_bindings.has(habitat):
		return _habitat_bindings[habitat].size()
	return 0

## Set maximum global population at runtime.
func set_max_global_population(new_max: int) -> void:
	max_global_population = max(0, new_max)
	population_changed.emit(get_global_population(), max_global_population)

## Get the spawn table entry for a species (read-only).
func get_spawn_entry(species_id: StringName) -> Dictionary:
	return _find_entry_by_species(species_id).duplicate()

## Add or update a spawn table entry at runtime.
## If species_id exists, updates it; otherwise appends.
func set_spawn_entry(entry: Dictionary) -> void:
	if not entry.has("species_id") or not entry.has("scene"):
		push_error("CreatureSpawner.set_spawn_entry: entry missing required keys 'species_id' and 'scene'")
		return
	var species = entry.species_id
	var idx = _find_entry_index(species)
	if idx >= 0:
		spawn_table[idx] = entry
	else:
		spawn_table.append(entry)
	_weights_dirty = true
	_recalculate_weights()

## Remove a spawn table entry by species_id.
func remove_spawn_entry(species_id: StringName) -> bool:
	var idx = _find_entry_index(species_id)
	if idx >= 0:
		spawn_table.remove_at(idx)
		_weights_dirty = true
		_recalculate_weights()
		return true
	return false

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _find_entry_by_species(species_id: StringName) -> Dictionary:
	for entry in spawn_table:
		if entry.species_id == species_id:
			return entry
	return null

func _find_entry_index(species_id: StringName) -> int:
	for i in range(spawn_table.size()):
		if spawn_table[i].species_id == species_id:
			return i
	return -1

func _pick_weighted_entry(habitat: Node) -> Dictionary:
	if _weights_dirty:
		_recalculate_weights()
	if _total_weight <= 0.0:
		return null

	var habitat_tags: Array[String] = []
	if habitat.has_method("get_tags"):
		habitat_tags = habitat.get_tags()
	elif habitat.has("tags"):
		habitat_tags = habitat.tags

	var valid_entries: Array[Dictionary] = []
	var valid_weight: float = 0.0
	for entry in spawn_table:
		var w: float = float(entry.get("weight", 0.0))
		if w <= 0.0:
			continue
		var entry_tags: Array[String] = entry.get("habitat_tags", [])
		if entry_tags.is_empty() or _tags_match(habitat_tags, entry_tags):
			valid_entries.append(entry)
			valid_weight += w

	if valid_entries.is_empty():
		return null

	var roll = randf() * valid_weight
	var accum: float = 0.0
	for entry in valid_entries:
		accum += float(entry.get("weight", 0.0))
		if roll <= accum:
			return entry
	return valid_entries[-1]

func _tags_match(habitat_tags: Array[String], required_tags: Array[String]) -> bool:
	for tag in required_tags:
		if tag in habitat_tags:
			return true
	return false

func _calculate_spawn_position(habitat: Node, entry: Dictionary) -> Vector2:
	var base_pos: Vector2 = Vector2.ZERO
	if habitat is Node2D:
		base_pos = habitat.global_position
	elif habitat is Node3D:
		base_pos = Vector2(habitat.global_position.x, habitat.global_position.z)
	else:
		base_pos = Vector2.ZERO

	var offset: Vector2 = entry.get("spawn_offset", Vector2.ZERO)
	var final_pos = base_pos + offset

	if randomize_within_bounds and habitat.has("bounds"):
		var bounds: Rect2 = habitat.bounds
		if bounds.size.x > 0 and bounds.size.y > 0:
			final_pos = Vector2(
				randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
				randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
			)

	return final_pos

func _register_creature(creature: Node, habitat: Node, species_id: StringName) -> void:
	if not _creature_registry.has(species_id):
		_creature_registry[species_id] = []
	_creature_registry[species_id].append(creature)

	if not _habitat_bindings.has(habitat):
		_habitat_bindings[habitat] = []
	_habitat_bindings[habitat].append(creature)