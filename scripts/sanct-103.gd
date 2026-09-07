extends Node
class_name CreatureGardenExpansion

# Expands the sanctuary garden with themed zones and growable plants.
# Each zone holds plant slots; plants grow through stages and grant
# passive bonuses to creatures resting in that zone.
# Builds on SanctuaryController / SanctuaryHabitatZones.

signal zone_created(zone_id: StringName, zone: GardenZone)
signal zone_unlocked(zone_id: StringName, zone: GardenZone)
signal plant_planted(zone_id: StringName, plant: GardenPlant)
signal plant_grew(plant: GardenPlant, new_stage: int)
signal plant_harvested(plant: GardenPlant, bonus: Dictionary)
signal garden_bonus_changed(zone_id: StringName, bonuses: Dictionary)

# --- Tunable constants (one place to retune garden feel) ---
const MAX_ZONES: int = 8
const DEFAULT_PLANT_SLOTS_PER_ZONE: int = 4
const GROWTH_TICK_INTERVAL: float = 2.0          # seconds between growth checks
const BASE_GROWTH_SPEED: float = 1.0             # multiplier on plant growth
const ENERGY_COST_PER_PLANT: int = 5             # EnergySystem cost to plant
const ENERGY_COST_PER_ZONE: int = 20             # EnergySystem cost to unlock a zone
const MAX_STAGE: int = 3                         # 0=seed, 1=sprout, 2=bloom, 3=ripe

# Zone themes available to unlock (in order of progression).
# Each entry: {id, name, theme, slots, unlock_energy, plant_bonus}
const ZONE_DEFS: Array[Dictionary] = [
	{
		"id": &"meadow",
		"name": "Sunlit Meadow",
		"theme": "grass",
		"slots": 4,
		"unlock_energy": 0,
		"plant_bonus": {"mood": 0.1},
	},
	{
		"id": &"flower_grove",
		"name": "Flower Grove",
		"theme": "flowers",
		"slots": 5,
		"unlock_energy": 30,
		"plant_bonus": {"charm": 0.15},
	},
	{
		"id": &"crystal_garden",
		"name": "Crystal Garden",
		"theme": "crystal",
		"slots": 4,
		"unlock_energy": 60,
		"plant_bonus": {"vitality": 0.2},
	},
	{
		"id": &"moonlight_glade",
		"name": "Moonlight Glade",
		"theme": "moon",
		"slots": 6,
		"unlock_energy": 100,
		"plant_bonus": {"calm": 0.25},
	},
]

# Plant types the player can grow. Each has per-stage effects.
const PLANT_DEFS: Dictionary = {
	&"sunbloom": {
		"name": "Sunbloom",
		"grow_time": 12.0,
		"stages": {
			0: {"effect": "mood", "value": 0.05},
			1: {"effect": "mood", "value": 0.1},
			2: {"effect": "mood", "value": 0.18},
			3: {"effect": "mood", "value": 0.25, "harvestable": true},
		},
	},
	&"starvine": {
		"name": "Starvine",
		"grow_time": 18.0,
		"stages": {
			0: {"effect": "charm", "value": 0.05},
			1: {"effect": "charm", "value": 0.12},
			2: {"effect": "charm", "value": 0.2},
			3: {"effect": "charm", "value": 0.3, "harvestable": true},
		},
	},
	&"crystal_moss": {
		"name": "Crystal Moss",
		"grow_time": 24.0,
		"stages": {
			0: {"effect": "vitality", "value": 0.05},
			1: {"effect": "vitality", "value": 0.1},
			2: {"effect": "vitality", "value": 0.18},
			3: {"effect": "vitality", "value": 0.28, "harvestable": true},
		},
	},
	&"moonpetal": {
		"name": "Moonpetal",
		"grow_time": 30.0,
		"stages": {
			0: {"effect": "calm", "value": 0.05},
			1: {"effect": "calm", "value": 0.12},
			2: {"effect": "calm", "value": 0.2},
			3: {"effect": "calm", "value": 0.35, "harvestable": true},
		},
	},
}

# --- Inner data classes ---

class GardenPlant:
	var id: StringName = &""
	var zone_id: StringName = &""
	var stage: int = 0
	var grow_progress: float = 0.0
	var grow_time: float = 12.0
	var stages: Dictionary = {}
	var planted_at: float = 0.0

	func _init(p_id: StringName, p_zone: StringName, p_def: Dictionary) -> void:
		id = p_id
		zone_id = p_zone
		grow_time = p_def.get("grow_time", 12.0)
		stages = p_def.get("stages", {})
		planted_at = Time.get_ticks_msec() / 1000.0

	func is_ripe() -> bool:
		return stage >= MAX_STAGE and stages.get(stage, {}).get("harvestable", false)

	func current_bonus() -> Dictionary:
		var s: Dictionary = stages.get(stage, {})
		return {"effect": s.get("effect", "mood"), "value": s.get("value", 0.0)}

class GardenZone:
	var zone_id: StringName = &""
	var name: String = ""
	var theme: String = ""
	var slots: int = 4
	var plants: Array[GardenPlant] = []
	var unlocked: bool = false
	var plant_bonus: Dictionary = {}

	func _init(def: Dictionary) -> void:
		zone_id = StringName(def.get("id", &""))
		name = def.get("name", "Garden")
		theme = def.get("theme", "grass")
		slots = int(def.get("slots", DEFAULT_PLANT_SLOTS_PER_ZONE))
		plant_bonus = def.get("plant_bonus", {})

	func free_slots() -> int:
		return max(0, slots - plants.size())

	func add_plant(plant: GardenPlant) -> bool:
		if free_slots() <= 0:
			return false
		plants.append(plant)
		return true

	func remove_plant(plant: GardenPlant) -> void:
		plants.erase(plant)

	func aggregate_bonus() -> Dictionary:
		var result: Dictionary = {}
		for p in plants:
			var b: Dictionary = p.current_bonus()
			var eff: String = String(b.get("effect", "mood"))
			result[eff] = float(result.get(eff, 0.0)) + float(b.get("value", 0.0))
		return result

# --- State ---
var _zones: Dictionary = {}            # StringName -> GardenZone
var _all_plants: Array[GardenPlant] = []
var _growth_timer: SceneTreeTimer = null
var _growth_speed: float = BASE_GROWTH_SPEED

func _ready() -> void:
	# Seed the default meadow zone (always available).
	_unlock_zone(&"meadow")
	_start_growth_loop()

func _start_growth_loop() -> void:
	# Tick growth on a repeating timer rather than per-frame for performance.
	_growth_timer = get_tree().create_timer(GROWTH_TICK_INTERVAL)
	_growth_timer.timeout.connect(_on_growth_tick)

func _on_growth_tick() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for plant in _all_plants:
		var elapsed: float = now - plant.planted_at
		var needed: float = plant.grow_time / _growth_speed
		if elapsed >= needed and plant.stage < MAX_STAGE:
			plant.stage += 1
			plant.planted_at = now
			plant_grew.emit(plant, plant.stage)
			garden_bonus_changed.emit(plant.zone_id, _zone(plant.zone_id).aggregate_bonus())

# --- Zone management ---

func _zone(zone_id: StringName) -> GardenZone:
	return _zones.get(zone_id, null)

func get_zone(zone_id: StringName) -> GardenZone:
	return _zone(zone_id)

func get_available_zones() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in ZONE_DEFS:
		var id: StringName = StringName(def["id"])
		if not _zones.has(id):
			ids.append(id)
	return ids

func can_unlock(zone_id: StringName) -> bool:
	var def: Dictionary = _find_def(zone_id)
	if def == null:
		return false
	var cost: int = int(def.get("unlock_energy", ENERGY_COST_PER_ZONE))
	return EnergySystem.can_spend(cost)

func _find_def(zone_id: StringName) -> Dictionary:
	for def in ZONE_DEFS:
		if StringName(def["id"]) == zone_id:
			return def
	return null

func _unlock_zone(zone_id: StringName) -> void:
	var def: Dictionary = _find_def(zone_id)
	if def == null or _zones.has(zone_id):
		return
	var zone: GardenZone = GardenZone.new(def)
	zone.unlocked = true
	_zones[zone_id] = zone
	zone_created.emit(zone_id, zone)
	zone_unlocked.emit(zone_id, zone)

func unlock_zone(zone_id: StringName) -> bool:
	if _zones.has(zone_id):
		return true
	var def: Dictionary = _find_def(zone_id)
	if def == null:
		return false
	var cost: int = int(def.get("unlock_energy", ENERGY_COST_PER_ZONE))
	if not EnergySystem.can_spend(cost):
		return false
	EnergySystem.spend(cost, "unlock_garden_zone_%s" % zone_id)
	_unlock_zone(zone_id)
	return true

# --- Plant management ---

func can_plant(zone_id: StringName, plant_id: StringName) -> bool:
	var zone: GardenZone = _zone(zone_id)
	if zone == null or not zone.unlocked:
		return false
	if not PLANT_DEFS.has(plant_id):
		return false
	if zone.free_slots() <= 0:
		return false
	return EnergySystem.can_spend(ENERGY_COST_PER_PLANT)

func plant(zone_id: StringName, plant_id: StringName) -> GardenPlant:
	if not can_plant(zone_id, plant_id):
		return null
	EnergySystem.spend(ENERGY_COST_PER_PLANT, "plant_%s" % plant_id)
	var def: Dictionary = PLANT_DEFS[plant_id]
	var plant: GardenPlant = GardenPlant.new(plant_id, zone_id, def)
	var zone: GardenZone = _zone(zone_id)
	zone.add_plant(plant)
	_all_plants.append(plant)
	plant_planted.emit(zone_id, plant)
	garden_bonus_changed.emit(zone_id, zone.aggregate_bonus())
	return plant

func harvest(plant: GardenPlant) -> Dictionary:
	if plant == null or not plant.is_ripe():
		return {}
	var bonus: Dictionary = plant.current_bonus()
	var zone: GardenZone = _zone(plant.zone_id)
	if zone != null:
		zone.remove_plant(plant)
		_all_plants.erase(plant)
		garden_bonus_changed.emit(plant.zone_id, zone.aggregate_bonus())
	plant_harvested.emit(plant, bonus)
	return bonus

func get_zone_bonus(zone_id: StringName) -> Dictionary:
	var zone: GardenZone = _zone(zone_id)
	if zone == null:
		return {}
	return zone.aggregate_bonus()

func get_all_plants() -> Array[GardenPlant]:
	return _all_plants

func get_zone_plants(zone_id: StringName) -> Array[GardenPlant]:
	var zone: GardenZone = _zone(zone_id)
	if zone == null:
		return []
	return zone.plants

# --- Persistence helpers (integrates with GameState) ---

func serialize() -> Dictionary:
	var data: Dictionary = {
		"zones": [],
		"plants": [],
		"growth_speed": _growth_speed,
	}
	for id in _zones:
		var z: GardenZone = _zones[id]
		data["zones"].append({
			"id": String(id),
			"unlocked": z.unlocked,
			"theme": z.theme,
			"slots": z.slots,
		})
	for p in _all_plants:
		data["plants"].append({
			"id": String(p.id),
			"zone_id": String(p.zone_id),
			"stage": p.stage,
			"grow_time": p.grow_time,
			"planted_at": p.planted_at,
		})
	return data

func deserialize(data: Dictionary) -> void:
	_zones.clear()
	_all_plants.clear()
	for zd in data.get("zones", []):
		var id: StringName = StringName(zd["id"])
		var def: Dictionary = _find_def(id)
		if def != null:
			var zone: GardenZone = GardenZone.new(def)
			zone.unlocked = bool(zd.get("unlocked", false))
			zone.slots = int(zd.get("slots", zone.slots))
			_zones[id] = zone
	for pd in data.get("plants", []):
		var pid: StringName = StringName(pd["id"])
		var zid: StringName = StringName(pd["zone_id"])
		if PLANT_DEFS.has(pid) and _zones.has(zid):
			var plant: GardenPlant = GardenPlant.new(pid, zid, PLANT_DEFS[pid])
			plant.stage = int(pd.get("stage", 0))
			plant.planted_at = float(pd.get("planted_at", Time.get_ticks_msec() / 1000.0))
			var zone: GardenZone = _zones[zid]
			zone.add_plant(plant)
			_all_plants.append(plant)
	_growth_speed = float(data.get("growth_speed", BASE_GROWTH_SPEED))

# --- Feel: growth speed tuning (e.g. a fertilizer powerup) ---

func set_growth_speed(multiplier: float) -> void:
	_growth_speed = max(0.1, multiplier)