extends Node
class_name TrainingManager

## Signals
signal training_session_started(creature_id: String, trick_id: String)
signal training_session_ended(creature_id: String, trick_id: String, success: bool, bond_change: float)
signal trick_unlocked(creature_id: String, trick_id: String)
signal bond_changed(creature_id: String, old_bond: float, new_bond: float)
signal progression_exported(file_path: String)
signal error_occurred(message: String)

## Enums
enum TrainingState {
	IDLE,
	WAITING_FOR_CLICK,
	CLICKED,
	REWARDING,
	COOLDOWN,
	SESSION_COMPLETE
}

enum TrickCategory {
	BASIC,
	INTERMEDIATE,
	ADVANCED,
	EXPERT,
	MASTER
}

## Constants
const CLICK_WINDOW_SECONDS: float = 1.5
const REWARD_WINDOW_SECONDS: float = 2.0
const COOLDOWN_SECONDS: float = 3.0
const MAX_SESSION_DURATION: float = 300.0
const BASE_SUCCESS_RATE: float = 0.3
const BOND_INFLUENCE_WEIGHT: float = 0.4
const NEEDS_INFLUENCE_WEIGHT: float = 0.3
const FATIGUE_PENALTY_PER_SESSION: float = 0.05
const MIN_BOND_FOR_ADVANCED: float = 0.3
const MIN_BOND_FOR_EXPERT: float = 0.6
const MIN_BOND_FOR_MASTER: float = 0.85

## Trick Definition Schema
## {
##   "id": "sit",
##   "name": "Sit",
##   "category": "BASIC",
##   "prerequisites": [],
##   "base_difficulty": 0.2,
##   "bond_reward": 0.02,
##   "energy_cost": 5.0,
##   "hunger_cost": 2.0,
##   "fun_gain": 3.0
## }

## Progression Export Schema
## {
##   "version": "1.0",
##   "timestamp": "ISO8601",
##   "creatures": [
##     {
##       "creature_id": "creature_001",
##       "species": "dog",
##       "bond_level": 0.75,
##       "tricks_learned": [
##         {
##           "trick_id": "sit",
##           "mastery_level": 0.9,
##           "sessions_to_master": 12,
##           "total_attempts": 15,
##           "successful_attempts": 13,
##           "first_learned_timestamp": "ISO8601",
##           "mastered_timestamp": "ISO8601"
##         }
##       ],
##       "training_stats": {
##         "total_sessions": 45,
##         "total_successful_sessions": 38,
##         "average_session_duration": 45.2,
##         "favorite_trick_category": "BASIC"
##       }
##     }
##   ]
## }

@export_group("Configuration")
@export var trick_database_path: String = "res://data/tricks/trick_database.json"
@export var progression_export_path: String = "user://training_progression.json"
@export var max_concurrent_sessions: int = 5
@export var enable_headless_mode: bool = false
@export var headless_tick_rate: float = 60.0

@export_group("Runtime State (Read-Only)")
@export var active_sessions: Array[Dictionary] = []
@export var creature_bonds: Dictionary = {}
@export var creature_trick_progress: Dictionary = {}
@export var unlocked_tricks_per_creature: Dictionary = {}
@export var session_history: Array[Dictionary] = []

var _trick_database: Dictionary = {}
var _state_timers: Dictionary = {}
var _session_counter: int = 0
var _is_processing: bool = false
var _headless_test_creatures: Array[Object] = []
var _behavior_tree_ref: Object = null
var _needs_system_ref: Object = null

func _init() -> void:
	_load_trick_database()
	_initialize_state_timers()

func _ready() -> void:
	# Register with training_manager group for EvolutionController integration
	add_to_group("training_manager")

func _initialize_state_timers() -> void:
	_state_timers = {
		TrainingState.WAITING_FOR_CLICK: CLICK_WINDOW_SECONDS,
		TrainingState.REWARDING: REWARD_WINDOW_SECONDS,
		TrainingState.COOLDOWN: COOLDOWN_SECONDS
	}

func _load_trick_database() -> void:
	var file = FileAccess.open(trick_database_path, FileAccess.READ)
	if not file:
		push_error("Trick database not found at: %s" % trick_database_path)
		_create_default_trick_database()
		return
	
	var content = file.get_as_text()
	file.close()
	
	var parse_result = JSON.parse_string(content)
	if parse_result.error != OK:
		push_error("Failed to parse trick database: %s" % parse_result.error_string)
		_create_default_trick_database()
		return
	
	_trick_database = parse_result.result
	_validate_trick_database()

func _create_default_trick_database() -> void:
	_trick_database = {
		"sit": {
			"id": "sit", "name": "Sit", "category": "BASIC",
			"prerequisites": [], "base_difficulty": 0.15,
			"bond_reward": 0.025, "energy_cost": 3.0, "hunger_cost": 1.0, "fun_gain": 2.0
		},
		"stay": {
			"id": "stay", "name": "Stay", "category": "BASIC",
			"prerequisites": ["sit"], "base_difficulty": 0.25,
			"bond_reward": 0.03, "energy_cost": 5.0, "hunger_cost": 2.0, "fun_gain": 3.0
		},
		"lie_down": {
			"id": "lie_down", "name": "Lie Down", "category": "BASIC",
			"prerequisites": ["sit"], "base_difficulty": 0.2,
			"bond_reward": 0.025, "energy_cost": 4.0, "hunger_cost": 1.5, "fun_gain": 2.5
		},
		"shake_paw": {
			"id": "shake_paw", "name": "Shake Paw", "category": "INTERMEDIATE",
			"prerequisites": ["sit"], "base_difficulty": 0.35,
			"bond_reward": 0.04, "energy_cost": 6.0, "hunger_cost": 3.0, "fun_gain": 4.0
		},
		"roll_over": {
			"id": "roll_over", "name": "Roll Over", "category": "INTERMEDIATE",
			"prerequisites": ["lie_down"], "base_difficulty": 0.45,
			"bond_reward": 0.05, "energy_cost": 8.0, "hunger_cost": 4.0, "fun_gain": 5.0
		},
		"play_dead": {
			"id": "play_dead", "name": "Play Dead", "category": "ADVANCED",
			"prerequisites": ["roll_over", "stay"], "base_difficulty": 0.6,
			"bond_reward": 0.06, "energy_cost": 10.0, "hunger_cost": 5.0, "fun_gain": 6.0
		},
		"fetch": {
			"id": "fetch", "name": "Fetch", "category": "INTERMEDIATE",
			"prerequisites": ["stay"], "base_difficulty": 0.4,
			"bond_reward": 0.045, "energy_cost": 12.0, "hunger_cost": 6.0, "fun_gain": 8.0
		},
		"spin": {
			"id": "spin", "name": "Spin", "category": "BASIC",
			"prerequisites": [], "base_difficulty": 0.3,
			"bond_reward": 0.03, "energy_cost": 5.0, "hunger_cost": 2.0, "fun_gain": 3.0
		},
		"jump_through_hoop": {
			"id": "jump_through_hoop", "name": "Jump Through Hoop", "category": "ADVANCED",
			"prerequisites": ["fetch", "stay"], "base_difficulty": 0.65,
			"bond_reward": 0.07, "energy_cost": 15.0, "hunger_cost": 8.0, "fun_gain": 10.0
		},
		"backflip": {
			"id": "backflip", "name": "Backflip", "category": "EXPERT",
			"prerequisites": ["jump_through_hoop", "spin"], "base_difficulty": 0.8,
			"bond_reward": 0.08, "energy_cost": 20.0, "hunger_cost": 10.0, "fun_gain": 12.0
		},
		"dance": {
			"id": "dance", "name": "Dance", "category": "EXPERT",
			"prerequisites": ["spin", "shake_paw", "stay"], "base_difficulty": 0.75,
			"bond_reward": 0.075, "energy_cost": 18.0, "hunger_cost": 9.0, "fun_gain": 11.0
		},
		"obstacle_course": {
			"id": "obstacle_course", "name": "Obstacle Course", "category": "MASTER",
			"prerequisites": ["jump_through_hoop", "fetch", "stay", "roll_over"], "base_difficulty": 0.9,
			"bond_reward": 0.1, "energy_cost": 25.0, "hunger_cost": 15.0, "fun_gain": 15.0
		}
	}
	_save_trick_database()

func _save_trick_database() -> void:
	var dir = trick_database_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var file = FileAccess.open(trick_database_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_trick_database, "\t"))
		file.close()

func _validate_trick_database() -> void:
	for trick_id in _trick_database:
		var trick = _trick_database[trick_id]
		if not trick.has("id") or not trick.has("category") or not trick.has("prerequisites"):
			push_error("Invalid trick entry: %s" % trick_id)
		for prereq in trick.prerequisites:
			if not _trick_database.has(prereq):
				push_error("Trick %s references missing prerequisite: %s" % [trick_id, prereq])

func set_behavior_tree_reference(behavior_tree: Object) -> void:
	_behavior_tree_ref = behavior_tree

func set_needs_system_reference(needs_system: Object) -> void:
	_needs_system_ref = needs_system

func get_trick_database() -> Dictionary:
	return _trick_database.duplicate(true)

func get_available_tricks(creature_id: String) -> Array[Dictionary]:
	var available = []
	var unlocked = unlocked_tricks_per_creature.get(creature_id, [])
	var bond = creature_bonds.get(creature_id, 0.0)
	
	for trick_id in _trick_database:
		var trick = _trick_database[trick_id]
		if trick_id in unlocked:
			continue
		
		if not _check_prerequisites(creature_id, trick.prerequisites):
			continue
		
		if not _check_bond_requirement(trick.category, bond):
			continue
		
		if not _check_creature_needs_ready(creature_id, trick):
			continue
		
		available.append(trick.duplicate(true))
	
	return available

func _check_prerequisites(creature_id: String, prerequisites: Array[String]) -> bool:
	var unlocked = unlocked_tricks_per_creature.get(creature_id, [])
	for prereq in prerequisites:
		if prereq not in unlocked:
			return false
	return true

func _check_bond_requirement(category: String, bond: float) -> bool:
	match category:
		"BASIC": return true
		"INTERMEDIATE": return bond >= MIN_BOND_FOR_ADVANCED
		"ADVANCED": return bond >= MIN_BOND_FOR_ADVANCED * 1.5
		"EXPERT": return bond >= MIN_BOND_FOR_EXPERT
		"MASTER": return bond >= MIN_BOND_FOR_MASTER
		_: return false

func _check_creature_needs_ready(creature_id: String, trick: Dictionary) -> bool:
	if not _needs_system_ref or not _needs_system_ref.has_method("get_creature_needs"):
		return true
	
	var needs = _needs_system_ref.get_creature_needs(creature_id)
	if not needs:
		return true
	
	var energy = needs.get("energy", 100.0)
	var hunger = needs.get("hunger", 100.0)
	var fatigue = needs.get("fatigue", 0.0)
	
	if energy < trick.energy_cost + 10.0:
		return false
	if hunger < trick.hunger_cost + 10.0:
		return false
	if fatigue > 70.0:
		return false
	
	return true

func start_training_session(creature_id: String, trick_id: String) -> Dictionary:
	if not _trick_database.has(trick_id):
		return {"success": false, "error": "Trick not found: %s" % trick_id}
	
	if active_sessions.size() >= max_concurrent_sessions:
		return {"success": false, "error": "Max concurrent sessions reached"}
	
	for session in active_sessions:
		if session.creature_id == creature_id:
			return {"success": false, "error": "Creature already in training session"}
	
	var trick = _trick_database[trick_id]
	var bond = creature_bonds.get(creature_id, 0.0)
	
	if not _check_prerequisites(creature_id, trick.prerequisites):
		return {"success": false, "error": "Prerequisites not met"}
	
	if not _check_bond_requirement(trick.category, bond):
		return {"success": false, "error": "Insufficient bond level for this trick category"}
	
	if not _check_creature_needs_ready(creature_id, trick):
		return {"success": false, "error": "Creature needs not satisfied (energy/hunger/fatigue)"}
	
	var session = {
		"session_id": "session_%d" % _session_counter,
		"creature_id": creature_id,
		"trick_id": trick_id,
		"state": TrainingState.IDLE,
		"start_time": Time.get_unix_time_from_system(),
		"click_count": 0,
		"successful_clicks": 0,
		"attempt_count": 0,
		"session_bond_gain": 0.0,
		"state_timer": 0.0,
		"total_duration": 0.0
	}
	_session_counter += 1
	
	active_sessions.append(session)
	
	if _behavior_tree_ref and _behavior_tree_ref.has_method("set_training_mode"):
		_behavior_tree_ref.set_training_mode(creature_id, true, trick_id)
	
	_set_session_state(session, TrainingState.WAITING_FOR_CLICK)
	
	training_session_started.emit(creature_id, trick_id)
	
	return {"success": true, "session": session.duplicate(true)}

func _set_session_state(session: Dictionary, new_state: TrainingState) -> void:
	session.state = new_state
	session.state_timer = _state_timers.get(new_state, 0.0)
	
	if new_state == TrainingState.WAITING_FOR_CLICK:
		_trigger_creature_action(session.creature_id, session.trick_id)

func _trigger_creature_action(creature_id: String, trick_id: String) -> void:
	if _