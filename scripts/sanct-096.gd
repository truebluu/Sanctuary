class_name SanctuaryEggHatch
extends Node

# Tunables — one-setting changes
const HATCH_TIME_SECONDS: float = 12.0
const MINIGAME_INTERACTIONS_REQUIRED: int = 3
const HATCH_SUCCESS_CHANCE: float = 0.85
const HATCH_FAILED_REPAIR_KIT_COST: int = 1

signal hatch_started(egg_id: String)
signal hatch_progress(seconds_remaining: float)
signal hatch_completed(creature_id: String, creature_type: String)
signal hatch_failed(egg_id: String, reason: String)

@export var egg_id: String = ""
@export var creature_type: String = "unknown"
@export var hatch_timer: float = HATCH_TIME_SECONDS
@export var interactions_needed: int = MINIGAME_INTERACTIONS_REQUIRED

var _time_left: float = 0.0
var _interactions_done: int = 0
var _active: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    _time_left = hatch_timer

func start_hatch(egg_id: String, creature_type: String) -> void:
    egg_id = egg_id
    creature_type = creature_type
    _interactions_done = 0
    _time_left = hatch_timer
    _active = true
    hatch_started.emit(egg_id)

func _process(delta: float) -> void:
    if not _active:
        return
    _time_left -= delta
    if _time_left <= 0.0:
        _attempt_hatch()
        _emit_progress()

func _attempt_hatch() -> void:
    var success: bool = _rng.randf() < HATCH_SUCCESS_CHANCE
    if success:
        _active = false
        hatch_completed.emit(egg_id, creature_type)
        EventBus.hatch_completed.emit(egg_id, creature_type)
    else:
        _active = false
        hatch_failed.emit(egg_id, "success_chance_missed")
        EventBus.hatch_failed.emit(egg_id, "success_chance_missed")

func interact() -> bool:
    if not _active:
        return false
    _interactions_done += 1
    if _interactions_done >= interactions_needed:
        _active = false
        hatch_completed.emit(egg_id, creature_type)
        EventBus.hatch_completed.emit(egg_id, creature_type)
        return true
    _emit_progress()
    return false

func get_progress_ratio() -> float:
    if _time_left <= 0.0:
        return 0.0
    return _time_left / hatch_timer

func get_time_remaining() -> float:
    return _time_left

func is_active() -> bool:
    return _active

func _emit_progress() -> void:
    hatch_progress.emit(_time_left)