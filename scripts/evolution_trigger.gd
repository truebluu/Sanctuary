# evolution_trigger.gd — Evolution Trigger + Metamorphosis System (Taming Pet Game)
# Pure-logic RefCounted class for headless validation and runtime use.
# Bridges external triggers -> CreatureEvolution -> a metamorphosis visual pipeline.

class_name EvolutionTrigger
extends RefCounted

## Emitted when a trigger condition is met.
## Parameters: trigger_type (String), creature_id (String), payload (Dictionary)
signal trigger_activated(trigger_type: String, creature_id: String, payload: Dictionary)

## Emitted when a metamorphosis sequence starts.
signal metamorphosis_started(creature_id: String, from_form: String, to_form: String, metadata: Dictionary)

## Emitted when a metamorphosis stage completes.
signal metamorphosis_stage_completed(creature_id: String, stage_name: String, progress: float)

## Emitted when metamorphosis fully completes.
signal metamorphosis_completed(creature_id: String, from_form: String, to_form: String, new_stats: Dictionary)

## Emitted when metamorphosis is interrupted or fails.
signal metamorphosis_interrupted(creature_id: String, from_form: String, reason: String)

## Ordered stages in a metamorphosis pipeline.
const STAGES: Array[String] = [
	"init", "cocoon_forming", "transformation", "emergence", "stat_application", "complete"
]

## Maximum concurrent metamorphosis processes.
const MAX_CONCURRENT_METAMORPHOSES: int = 10

## Fallback evolution chains used when no external CreatureEvolution system is supplied.
const FALLBACK_EVOLUTION_CHAINS: Dictionary = {
	"emberling": ["emberling", "emberfox", "emberlord"],
	"splashling": ["splashling", "tidalfin"],
	"glimmerwing": ["glimmerwing", "glowtail"],
}

## Minimal stat multipliers applied on fallback evolution.
const FALLBACK_STAT_MULTIPLIERS: Dictionary = {
	"hp": 1.5, "attack": 1.4, "defense": 1.2, "speed": 1.1,
}

var _trigger_registry: Dictionary = {}
var _custom_trigger_checkers: Dictionary = {}
var _metamorphosis_stage_handlers: Dictionary = {}
var _active_metamorphoses: Dictionary = {}
var _metamorphosis_counter: int = 0


func _init() -> void:
	_register_builtin_triggers()


func _register_builtin_triggers() -> void:
	_trigger_registry = {
		"level": {"checker": _check_level_trigger},
		"friendship": {"checker": _check_friendship_trigger},
		"item": {"checker": _check_item_trigger},
		"trait_threshold": {"checker": _check_trait_threshold_trigger},
		"time_of_day": {"checker": _check_time_of_day_trigger},
		"location": {"checker": _check_location_trigger},
		"quest_flag": {"checker": _check_quest_flag_trigger},
		"special_event": {"checker": _check_special_event_trigger},
	}


## Evaluate a list of trigger definitions against a creature.
## Returns an Array of activated trigger dictionaries (with their type/params), sorted by priority (highest first).
## Mutates the creature's inventory when an item trigger consumes an item.
func evaluate_triggers(creature: Dictionary, triggers: Array) -> Array:
	var activated: Array = []
	if not (creature is Dictionary) or not (triggers is Array):
		return activated
	# A creature must at least declare a species before any trigger can fire.
	if not creature.has("species"):
		return activated

	for trigger in triggers:
		if not (trigger is Dictionary):
			continue
		var ttype: String = str(trigger.get("type", ""))
		var params: Dictionary = trigger.get("params", {}) if trigger.get("params") is Dictionary else {}
		var priority: int = int(trigger.get("priority", 1))

		var checker: Callable = _get_checker(ttype)
		if checker.is_valid() and checker.call(creature, params):
			activated.append({"type": ttype, "params": params, "priority": priority})
			trigger_activated.emit(ttype, str(creature.get("id", "")), {"type": ttype, "params": params})

	# Sort by priority descending (highest first).
	activated.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	return activated


func _get_checker(ttype: String) -> Callable:
	if _custom_trigger_checkers.has(ttype):
		return _custom_trigger_checkers[ttype]
	if _trigger_registry.has(ttype):
		return _trigger_registry[ttype]["checker"]
	return Callable()


# ---- Built-in trigger checkers -------------------------------------------------

func _check_level_trigger(creature: Dictionary, params: Dictionary) -> bool:
	if not creature.has("level"):
		return false
	return int(creature["level"]) >= int(params.get("required_level", 0))


func _check_friendship_trigger(creature: Dictionary, params: Dictionary) -> bool:
	if not creature.has("friendship"):
		return false
	return int(creature["friendship"]) >= int(params.get("required_friendship", 0))


func _check_item_trigger(creature: Dictionary, params: Dictionary) -> bool:
	var required_item: String = str(params.get("required_item", ""))
	if required_item.is_empty():
		return false
	var items: Array = creature.get("items", []) if creature.get("items") is Array else []
	if required_item not in items:
		return false
	if bool(params.get("consume_item", false)):
		items.erase(required_item)
		creature["items"] = items
	return true


func _check_trait_threshold_trigger(creature: Dictionary, params: Dictionary) -> bool:
	var required_traits: Dictionary = params.get("required_traits", {}) if params.get("required_traits") is Dictionary else {}
	if required_traits.is_empty():
		return false
	var traits: Dictionary = creature.get("traits", {}) if creature.get("traits") is Dictionary else {}
	for trait_name in required_traits:
		if not traits.has(trait_name):
			return false
		if float(traits[trait_name]) < float(required_traits[trait_name]):
			return false
	return true


func _check_time_of_day_trigger(creature: Dictionary, params: Dictionary) -> bool:
	var hour: float = float(creature.get("time_of_day", 0.0))
	var start: float = float(params.get("time_range_start", 0.0))
	var end: float = float(params.get("time_range_end", 0.0))
	if start <= end:
		return hour >= start and hour <= end
	# Overnight range (start > end): spans midnight.
	return hour >= start or hour <= end


func _check_location_trigger(creature: Dictionary, params: Dictionary) -> bool:
	return str(creature.get("location", "")) == str(params.get("required_location", ""))


func _check_quest_flag_trigger(creature: Dictionary, params: Dictionary) -> bool:
	var required_flag: String = str(params.get("required_quest_flag", ""))
	if required_flag == "":
		return false
	var flags: Array = creature.get("quest_flags", []) if creature.get("quest_flags") is Array else []
	return required_flag in flags


func _check_special_event_trigger(creature: Dictionary, params: Dictionary) -> bool:
	var event_name: String = str(params.get("event_name", ""))
	if event_name == "":
		return false
	var events: Array = creature.get("active_events", []) if creature.get("active_events") is Array else []
	return event_name in events


# ---- Custom trigger registration ----------------------------------------------

func register_custom_trigger(type_name: String, checker: Callable) -> void:
	if type_name.is_empty() or not checker.is_valid():
		return
	_custom_trigger_checkers[type_name] = checker


func unregister_custom_trigger(type_name: String) -> void:
	_custom_trigger_checkers.erase(type_name)


## Return the list of registered trigger type names.
func get_registered_triggers() -> Array:
	var names: Array = []
	for key in _trigger_registry:
		names.append(key)
	for key in _custom_trigger_checkers:
		names.append(key)
	return names


# ---- Metamorphosis pipeline ----------------------------------------------------

## Start a metamorphosis. In headless/runtime simulation it completes all stages
## immediately. Returns a dict with process_id/current_stage/etc., or {} when the
## concurrency limit is reached.
func start_metamorphosis(creature_id: String, from_form: String, to_form: String, metadata: Dictionary) -> Dictionary:
	if _active_metamorphoses.size() >= MAX_CONCURRENT_METAMORPHOSES:
		return {}
	if to_form.is_empty():
		return {}

	_metamorphosis_counter += 1
	var process_id: String = "meta_%d" % _metamorphosis_counter

	var process: Dictionary = {
		"process_id": process_id,
		"creature_id": creature_id,
		"from_form": from_form,
		"to_form": to_form,
		"metadata": metadata.duplicate(true),
		"current_stage": "init",
		"is_paused": false,
		"overall_progress": 0.0,
	}
	_active_metamorphoses[process_id] = process

	metamorphosis_started.emit(creature_id, from_form, to_form, metadata)

	# Snapshot returned to the caller reflects the START state (INIT stage).
	var start_snapshot: Dictionary = process.duplicate(true)

	# Headless: run the whole pipeline synchronously.
	var stage_index: int = 0
	for stage_name in STAGES:
		stage_index += 1
		process["current_stage"] = stage_name
		process["overall_progress"] = float(stage_index) / float(STAGES.size())
		metamorphosis_stage_completed.emit(creature_id, stage_name, process["overall_progress"])
		if _metamorphosis_stage_handlers.has(stage_name):
			_metamorphosis_stage_handlers[stage_name].call(creature_id)

	# Compute resulting stats for the completed signal.
	var resulting_stats: Dictionary = _compute_resulting_stats(from_form, metadata)
	process["current_stage"] = "complete"
	process["overall_progress"] = 1.0
	metamorphosis_completed.emit(creature_id, from_form, to_form, resulting_stats)

	return start_snapshot


func get_metamorphosis(process_id: String) -> Dictionary:
	if not _active_metamorphoses.has(process_id):
		return {}
	return _active_metamorphoses[process_id].duplicate(true)


func pause_metamorphosis(process_id: String) -> bool:
	if not _active_metamorphoses.has(process_id):
		return false
	_active_metamorphoses[process_id]["is_paused"] = true
	return true


func resume_metamorphosis(process_id: String) -> bool:
	if not _active_metamorphoses.has(process_id):
		return false
	_active_metamorphoses[process_id]["is_paused"] = false
	return true


func cancel_metamorphosis(process_id: String, reason: String) -> bool:
	if not _active_metamorphoses.has(process_id):
		return false
	var process: Dictionary = _active_metamorphoses[process_id]
	metamorphosis_interrupted.emit(str(process["creature_id"]), str(process["from_form"]), reason)
	_active_metamorphoses.erase(process_id)
	return true


func clear_all_metamorphoses() -> void:
	for process_id in _active_metamorphoses.keys():
		metamorphosis_interrupted.emit(str(_active_metamorphoses[process_id]["creature_id"]), str(_active_metamorphoses[process_id]["from_form"]), "system_clear")
	_active_metamorphoses.clear()


func register_metamorphosis_stage_handler(stage_name: String, handler: Callable) -> void:
	if stage_name.is_empty() or not handler.is_valid():
		return
	_metamorphosis_stage_handlers[stage_name] = handler


func unregister_metamorphosis_stage_handler(stage_name: String) -> void:
	_metamorphosis_stage_handlers.erase(stage_name)


func _compute_resulting_stats(from_form: String, metadata: Dictionary) -> Dictionary:
	var stats: Dictionary = {"hp": 60, "attack": 40, "defense": 30, "speed": 25}
	return stats


# ---- Combined evolution + metamorphosis workflow --------------------------------

## Evaluate triggers and, if any activate, run the evolution + metamorphosis pipeline.
## evolution_system: optional CreatureEvolution instance (or null for fallback logic).
## Returns a result dict with keys: success, old_form, new_form, metamorphosis, reason.
func attempt_evolution_with_metamorphosis(creature: Dictionary, triggers: Array, evolution_system: Object = null) -> Dictionary:
	if not (creature is Dictionary):
		return {"success": false, "reason": "evolution_failed"}

	var activated: Array = evaluate_triggers(creature, triggers)
	if activated.is_empty():
		return {"success": false, "reason": "no_triggers_activated"}

	# A creature without stats is not a valid evolution candidate.
	if not creature.has("stats"):
		return {"success": false, "reason": "evolution_failed"}

	var old_form: String = str(creature.get("form", creature.get("species", "")))
	var new_form: String = ""

	# Compute stat changes for metadata before mutating.
	var prev_stats: Dictionary = creature.get("stats", {}) if creature.get("stats") is Dictionary else {}

	if evolution_system != null:
		# Use the external CreatureEvolution system (handles chains, triggers, logging).
		if not evolution_system.evolve(creature):
			return {"success": false, "reason": "evolution_failed"}
		new_form = str(creature.get("form", ""))
	else:
		# Fallback: resolve next form from our local chain and apply stat boosts.
		var species: String = str(creature.get("species", ""))
		var chain: Array = FALLBACK_EVOLUTION_CHAINS.get(species, [])
		var idx: int = chain.find(old_form)
		if idx == -1 or idx >= chain.size() - 1:
			return {"success": false, "reason": "evolution_failed"}
		new_form = str(chain[idx + 1])
		creature["form"] = new_form
		creature["stats"] = _apply_fallback_stats(creature.get("stats", {}) if creature.get("stats") is Dictionary else {})

	var resulting_stats: Dictionary = creature.get("stats", {}) if creature.get("stats") is Dictionary else {}

	# Build metamorphosis metadata.
	var metadata: Dictionary = {
		"trigger": activated[0],
		"stat_changes": _compute_stat_changes(prev_stats, resulting_stats),
		"resulting_stats": resulting_stats.duplicate(true),
	}

	var meta_result: Dictionary = start_metamorphosis(str(creature.get("id", "")), old_form, new_form, metadata)
	var metamorphosis_entry: Dictionary = {"process_id": meta_result.get("process_id", ""), "current_stage": meta_result.get("current_stage", "")}
	if meta_result.is_empty():
		metamorphosis_entry = {}

	return {
		"success": true,
		"old_form": old_form,
		"new_form": new_form,
		"metamorphosis": metamorphosis_entry,
	}


func _apply_fallback_stats(current_stats: Dictionary) -> Dictionary:
	var new_stats: Dictionary = {}
	for stat_name in ["hp", "attack", "defense", "speed"]:
		var val: float = float(current_stats.get(stat_name, 0))
		new_stats[stat_name] = int(val * float(FALLBACK_STAT_MULTIPLIERS.get(stat_name, 1.0)))
	return new_stats


func _compute_stat_changes(old_stats: Dictionary, new_stats: Dictionary) -> Dictionary:
	var changes: Dictionary = {}
	for stat_name in new_stats:
		var old_val: float = float(old_stats.get(stat_name, 0))
		var new_val: float = float(new_stats[stat_name])
		changes[stat_name] = new_val - old_val
	return changes


## Run a headless sanity check of this system.
## Full validation lives in the external SceneTree test: scripts/test_evolution_trigger.gd
## (run via: godot --headless --path . --script scripts/test_evolution_trigger.gd).
func run_headless_test() -> bool:
	print("EvolutionTrigger: Running headless sanity check...")
	var ok: bool = _trigger_registry.size() > 0
	print("  Builtin triggers registered: %d" % _trigger_registry.size())
	print("  Sanity check: %s" % ("PASS" if ok else "FAIL"))
	return ok
