# DecorationSystem — Sanctuary (Bluu Ink Studios)
# Config-driven decoration registry for creature habitats.
# Places decorative items that boost creature mood within range.
# Pure logic (RefCounted), headless-testable, no SceneTree dependencies.
class_name DecorationSystem
extends RefCounted

## Emitted when a decoration is successfully placed.
## Args: decoration_id (StringName), instance_id (String), position (Vector2), decoration_type (String)
signal decoration_placed(decoration_id: StringName, instance_id: String, position: Vector2, decoration_type: String)

## Emitted when a decoration is removed.
## Args: instance_id (String), decoration_type (String)
signal decoration_removed(instance_id: String, decoration_type: String)

## Emitted when a creature receives a mood boost from a decoration.
## Args: creature_id (String), mood_bonus (float), source_instance_id (String), decoration_type (String)
signal mood_boosted(creature_id: String, mood_bonus: float, source_instance_id: String, decoration_type: String)

# ============================================================================
# EXPORTED CONFIGURATION
# ============================================================================

## Habitat grid dimensions in tiles.
@export var grid_width: int = 12
@export var grid_height: int = 12

## Available currency for placing decorations.
@export var currency: float = 1000.0

## Maximum decorations allowed in habitat (space limit).
@export var max_decorations: int = 50

## Default mood bonus falloff per tile distance.
@export var mood_falloff_per_tile: float = 0.15

## Minimum mood bonus threshold to apply (below this, no effect).
@export var min_mood_bonus_threshold: float = 0.01

# ============================================================================
# INTERNAL STATE
# ============================================================================

## Decoration type registry: id -> {name, mood_bonus, cost, category, footprint_w, footprint_h, range}
var _decoration_catalog: Dictionary = {}

## Placed decoration instances: instance_id -> {type_id, grid_x, grid_y, rotation, placed_time}
var _placements: Dictionary = {}

## Grid occupancy: cell -> instance_id (or empty string)
var _grid: Array = []

## Instance counter for unique IDs
var _instance_counter: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(w: int = 12, h: int = 12, starting_currency: float = 1000.0) -> void:
	grid_width = maxi(1, w)
	grid_height = maxi(1, h)
	currency = starting_currency
	max_decorations = maxi(1, max_decorations)
	
	# Initialize empty grid
	_grid.clear()
	for _y in range(grid_height):
		var row: Array = []
		for _x in range(grid_width):
			row.append("")
		_grid.append(row)
	
	# Register default decoration types
	_register_default_decorations()

func _register_default_decorations() -> void:
	# Format: id -> {name, mood_bonus, cost, category, footprint_w, footprint_h, range}
	_decoration_catalog = {
		"cozy_bed": {
			"name": "Cozy Bed",
			"mood_bonus": 0.3,
			"cost": 50.0,
			"category": "comfort",
			"footprint_w": 2,
			"footprint_h": 1,
			"range": 3.0
		},
		"food_bowl": {
			"name": "Food Bowl",
			"mood_bonus": 0.25,
			"cost": 30.0,
			"category": "feeding",
			"footprint_w": 1,
			"footprint_h": 1,
			"range": 2.0
		},
		"toy_ball": {
			"name": "Toy Ball",
			"mood_bonus": 0.2,
			"cost": 20.0,
			"category": "enrichment",
			"footprint_w": 1,
			"footprint_h": 1,
			"range": 2.5
		},
		"scratching_post": {
			"name": "Scratching Post",
			"mood_bonus": 0.35,
			"cost": 80.0,
			"category": "enrichment",
			"footprint_w": 1,
			"footprint_h": 2,
			"range": 3.0
		},
		"water_fountain": {
			"name": "Water Fountain",
			"mood_bonus": 0.15,
			"cost": 60.0,
			"category": "comfort",
			"footprint_w": 1,
			"footprint_h": 1,
			"range": 4.0
		},
		"sun_lamp": {
			"name": "Sun Lamp",
			"mood_bonus": 0.4,
			"cost": 120.0,
			"category": "comfort",
			"footprint_w": 2,
			"footprint_h": 2,
			"range": 5.0
		},
		"climbing_tree": {
			"name": "Climbing Tree",
			"mood_bonus": 0.5,
			"cost": 200.0,
			"category": "enrichment",
			"footprint_w": 2,
			"footprint_h": 3,
			"range": 4.0
		},
		"soft_blanket": {
			"name": "Soft Blanket",
			"mood_bonus": 0.15,
			"cost": 15.0,
			"category": "comfort",
			"footprint_w": 1,
			"footprint_h": 1,
			"range": 1.5
		},
	}

# ============================================================================
# DECORATION CATALOG API
# ============================================================================

## Register a new decoration type in the catalog.
## id: unique identifier, name: display name, mood_bonus: base mood boost (0..1),
## cost: currency cost, category: string category, w/h: footprint in tiles, range: effect radius in tiles.
func register_decoration_type(
	id: String,
	name: String,
	mood_bonus: float,
	cost: float,
	category: String,
	w: int = 1,
	h: int = 1,
	effect_range: float = 2.0
) -> void:
	var data: Dictionary = {
		"name": name,
		"mood_bonus": clampf(mood_bonus, 0.0, 1.0),
		"cost": maxf(0.0, cost),
		"category": category,
		"footprint_w": maxi(1, w),
		"footprint_h": maxi(1, h),
		"range": maxf(0.0, effect_range)
	}
	_decoration_catalog[id] = data

func has_decoration_type(id: String) -> bool:
	return _decoration_catalog.has(id)

func get_decoration_type(id: String) -> Dictionary:
	if _decoration_catalog.has(id):
		return _decoration_catalog[id].duplicate(true)
	return {}

func get_decoration_types_by_category(category: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for id in _decoration_catalog.keys():
		var data = _decoration_catalog[id]
		if data["category"] == category:
			var entry = data.duplicate(true)
			entry["id"] = id
			results.append(entry)
	return results

func get_all_decoration_types() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for id in _decoration_catalog.keys():
		var entry = _decoration_catalog[id].duplicate(true)
		entry["id"] = id
		results.append(entry)
	return results

# ============================================================================
# GRID & PLACEMENT VALIDATION
# ============================================================================

## Check if a grid position is within bounds.
func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < grid_width and y < grid_height

## Get the instance_id occupying a cell, or empty string if empty/out of bounds.
func cell_occupant(x: int, y: int) -> String:
	if not in_bounds(x, y):
		return ""
	return _grid[y][x]

## Check if a decoration footprint at (x,y) is completely free.
func footprint_clear(type_id: String, x: int, y: int) -> bool:
	if not _decoration_catalog.has(type_id):
		return false
	var tpl = _decoration_catalog[type_id]
	for dy in range(int(tpl["footprint_h"])):
		for dx in range(int(tpl["footprint_w"])):
			var gx := x + dx
			var gy := y + dy
			if not in_bounds(gx, gy):
				return false
			if _grid[gy][gx] != "":
				return false
	return true

## Check if a decoration can be placed (valid type, footprint free, affordable, space available).
func can_place(type_id: String, x: int, y: int) -> bool:
	if not _decoration_catalog.has(type_id):
		return false
	if not footprint_clear(type_id, x, y):
		return false
	var cost: float = float(_decoration_catalog[type_id]["cost"])
	if currency < cost:
		return false
	if _placements.size() >= max_decorations:
		return false
	return true

# ============================================================================
# PLACEMENT & REMOVAL
# ============================================================================

## Place a decoration at grid position (x, y).
## Returns the instance_id (e.g., "toy_ball@3,5") or empty string on failure.
func place_decoration(type_id: String, x: int, y: int) -> String:
	if not can_place(type_id, x, y):
		return ""
	
	var tpl = _decoration_catalog[type_id]
	currency -= float(tpl["cost"])
	
	_instance_counter += 1
	var instance_id := "%s@%d,%d#%d" % [type_id, x, y, _instance_counter]
	
	# Track placement
	_placements[instance_id] = {
		"type_id": type_id,
		"grid_x": x,
		"grid_y": y,
		"rotation": 0,
		"placed_time": Time.get_ticks_msec() / 1000.0
	}
	
	# Mark grid cells occupied
	for dy in range(int(tpl["footprint_h"])):
		for dx in range(int(tpl["footprint_w"])):
			_grid[y + dy][x + dx] = instance_id
	
	# Emit signal with world position (center of footprint in tile units)
	var world_pos := Vector2(x + tpl["footprint_w"] * 0.5, y + tpl["footprint_h"] * 0.5)
	decoration_placed.emit(StringName(type_id), instance_id, world_pos, tpl["category"])
	
	return instance_id

## Place a decoration using a Vector2 position (snaps to grid).
func place_decoration_at_position(type_id: String, position: Vector2) -> String:
	var x := int(floor(position.x))
	var y := int(floor(position.y))
	return place_decoration(type_id, x, y)

## Remove a decoration by instance_id. Refunds a fraction of cost.
func remove_decoration(instance_id: String, refund_fraction: float = 0.5) -> bool:
	if not _placements.has(instance_id):
		return false
	
	var placement = _placements[instance_id]
	var type_id: String = placement["type_id"]
	var tpl = _decoration_catalog[type_id]
	var x: int = placement["grid_x"]
	var y: int = placement["grid_y"]
	
	# Clear grid footprint
	for dy in range(int(tpl["footprint_h"])):
		for dx in range(int(tpl["footprint_w"])):
			var gx := x + dx
			var gy := y + dy
			if in_bounds(gx, gy) and _grid[gy][gx] == instance_id:
				_grid[gy][gx] = ""
	
	# Refund
	var refund := float(tpl["cost"]) * clampf(refund_fraction, 0.0, 1.0)
	currency += refund
	
	# Remove from placements
	_placements.erase(instance_id)
	
	decoration_removed.emit(instance_id, tpl["category"])
	return true

## Remove all decorations of a specific type.
func remove_decorations_of_type(type_id: String, refund_fraction: float = 0.5) -> int:
	var removed: int = 0
	var to_remove: Array[String] = []
	for inst_id in _placements.keys():
		if _placements[inst_id]["type_id"] == type_id:
			to_remove.append(inst_id)
	for inst_id in to_remove:
		if remove_decoration(inst_id, refund_fraction):
			removed += 1
	return removed

## Clear all decorations (with optional refund).
func clear_all_decorations(refund_fraction: float = 0.5) -> int:
	var count: int = _placements.size()
	var to_remove: Array[String] = []
	for inst_id in _placements.keys():
		to_remove.append(inst_id)
	for inst_id in to_remove:
		remove_decoration(inst_id, refund_fraction)
	return count

# ============================================================================
# MOOD CONTRIBUTION CALCULATION
# ============================================================================

## Calculate total mood bonus for a creature at a given world position.
## Iterates all placed decorations, computes distance falloff, sums contributions.
## Returns the total mood boost (0..1 scale, can exceed 1 but typically clamped by caller).
func get_mood_boost(creature_position: Vector2) -> float:
	var total_boost: float = 0.0
	
	for instance_id in _placements.keys():
		var placement = _placements[instance_id]
		var type_id: String = placement["type_id"]
		var tpl = _decoration_catalog[type_id]
		
		# Decoration world position (center of footprint)
		var deco_x: float = placement["grid_x"] + tpl["footprint_w"] * 0.5
		var deco_y: float = placement["grid_y"] + tpl["footprint_h"] * 0.5
		var deco_pos := Vector2(deco_x, deco_y)
		
		# Distance in tiles
		var distance: float = creature_position.distance_to(deco_pos)
		var effect_range: float = tpl["range"]
		
		if distance <= effect_range:
			# Linear falloff: full bonus at distance 0, zero at effect_range
			var falloff_factor: float = 1.0 - (distance / effect_range)
			var bonus: float = float(tpl["mood_bonus"]) * falloff_factor
			
			if bonus >= min_mood_bonus_threshold:
				total_boost += bonus
	
	return total_boost

## Mood contribution for a specific creature at a position.
## This is an alias for get_mood_boost for API clarity with creature systems.
## creature_id: identifier for the creature (used in signals)
## position: world position of the creature
## Returns mood bonus applied, emits mood_boosted signal if > 0.
func mood_contribution(creature_id: String, position: Vector2) -> float:
	var boost: float = get_mood_boost(position)
	if boost > 0.0:
		# Find the nearest decoration that contributed for signal context
		var nearest_id: String = ""
		var nearest_dist: float = INF
		for instance_id in _placements.keys():
			var placement = _placements[instance_id]
			var type_id: String = placement["type_id"]
			var tpl = _decoration_catalog[type_id]
			var deco_pos := Vector2(
				placement["grid_x"] + tpl["footprint_w"] * 0.5,
				placement["grid_y"] + tpl["footprint_h"] * 0.5
			)
			var dist := position.distance_to(deco_pos)
			if dist < nearest_dist and dist <= tpl["range"]:
				nearest_dist = dist
				nearest_id = instance_id
		mood_boosted.emit(creature_id, boost, nearest_id, _placements[nearest_id]["type_id"] if nearest_id != "" else "")
	return boost

## Get mood boost breakdown by decoration type for a position.
## Returns Dictionary: type_id -> boost_amount
func get_mood_boost_breakdown(position: Vector2) -> Dictionary:
	var breakdown: Dictionary = {}
	for instance_id in _placements.keys():
		var placement = _placements[instance_id]
		var type_id: String = placement["type_id"]
		var tpl = _decoration_catalog[type_id]
		
		var deco_pos := Vector2(
			placement["grid_x"] + tpl["footprint_w"] * 0.5,
			placement["grid_y"] + tpl["footprint_h"] * 0.5
		)
		var distance: float = position.distance_to(deco_pos)
		var effect_range: float = tpl["range"]
		
		if distance <= effect_range:
			var falloff_factor: float = 1.0 - (distance / effect_range)
			var bonus: float = float(tpl["mood_bonus"]) * falloff_factor
			if bonus >= min_mood_bonus_threshold:
				breakdown[type_id] = breakdown.get(type_id, 0.0) + bonus
	return breakdown

# ============================================================================
# QUERY & INSPECTION
# ============================================================================

## Get all placed decoration instances.
func get_placed_decorations() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for inst_id in _placements.keys():
		var p = _placements[inst_id]
		var tpl = _decoration_catalog[p["type_id"]]
		var entry = p.duplicate(true)
		entry["instance_id"] = inst_id
		entry["name"] = tpl["name"]
		entry["category"] = tpl["category"]
		entry["mood_bonus"] = tpl["mood_bonus"]
		entry["world_position"] = Vector2(
			p["grid_x"] + tpl["footprint_w"] * 0.5,
			p["grid_y"] + tpl["footprint_h"] * 0.5
		)
		results.append(entry)
	return results

## Get count of placed decorations.
func get_placed_count() -> int:
	return _placements.size()

## Get count of decorations by category.
func get_count_by_category(category: String) -> int:
	var count: int = 0
	for p in _placements.values():
		var tpl = _decoration_catalog[p["type_id"]]
		if tpl["category"] == category:
			count += 1
	return count

## Check if an instance exists.
func has_decoration(instance_id: String) -> bool:
	return _placements.has(instance_id)

## Get decoration instance data.
func get_decoration_instance(instance_id: String) -> Dictionary:
	if _placements.has(instance_id):
		return _placements[instance_id].duplicate(true)
	return {}

## Get current currency.
func get_currency() -> float:
	return currency

## Add currency (e.g., from gameplay rewards).
func add_currency(amount: float) -> void:
	currency += maxf(0.0, amount)

## Spend currency directly (returns true if successful).
func spend_currency(amount: float) -> bool:
	if currency >= amount:
		currency -= amount
		return true
	return false

## Serialize state for saving.
func serialize() -> Dictionary:
	var placements_data: Array[Dictionary] = []
	for inst_id in _placements.keys():
		var p = _placements[inst_id]
		placements_data.append({
			"instance_id": inst_id,
			"type_id": p["type_id"],
			"grid_x": p["grid_x"],
			"grid_y": p["grid_y"],
			"rotation": p["rotation"],
			"placed_time": p["placed_time"]
		})
	return {
		"grid_width": grid_width,
		"grid_height": grid_height,
		"currency": currency,
		"max_decorations": max_decorations,
		"placements": placements_data,
		"instance_counter": _instance_counter
	}

## Deserialize state from save data.
func deserialize(data: Dictionary) -> void:
	grid_width = data.get("grid_width", grid_width)
	grid_height = data.get("grid_height", grid_height)
	currency = data.get("currency", currency)
	max_decorations = data.get("max_decorations", max_decorations)
	_instance_counter = data.get("instance_counter", _instance_counter)
	
	# Rebuild grid
	_grid.clear()
	for _y in range(grid_height):
		var row: Array = []
		for _x in range(grid_width):
			row.append("")
		_grid.append(row)
	
	_placements.clear()
	
	var placements_data = data.get("placements", [])
	for p_data in placements_data:
		var inst_id: String = p_data["instance_id"]
		var type_id: String = p_data["type_id"]
		var x: int = p_data["grid_x"]
		var y: int = p_data["grid_y"]
		
		if not _decoration_catalog.has(type_id):
			continue
		
		var tpl = _decoration_catalog[type_id]
		
		# Verify footprint still fits
		var fits: bool = true
		for dy in range(int(tpl["footprint_h"])):
			for dx in range(int(tpl["footprint_w"])):
				var gx := x + dx
				var gy := y + dy
				if not in_bounds(gx, gy) or _grid[gy][gx] != "":
					fits = false
					break
			if not fits:
				break
		
		if not fits:
			continue
		
		# Place it
		_placements[inst_id] = {
			"type_id": type_id,
			"grid_x": x,
			"grid_y": y,
			"rotation": p_data.get("rotation", 0),
			"placed_time": p_data.get("placed_time", 0.0)
		}
		
		for dy in range(int(tpl["footprint_h"])):
			for dx in range(int(tpl["footprint_w"])):
				_grid[y + dy][x + dx] = inst_id