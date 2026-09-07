class_name SanctuaryHabitatZones
extends Node

# Tunables — one-setting changes
const MAX_ZONES: int = 6
@export var happiness_per_zone: float = 5.0
@export var evolution_boost_per_zone: float = 0.05
@export var zone_cooldown_seconds: float = 2.0
@export var happiness_decay_per_second: float = 0.5

signal zone_added(zone_id: String)
signal zone_removed(zone_id: String)
signal happiness_changed(total: float)
signal evolution_boost_changed(boost: float)

var _zones: Dictionary = {}
var _total_happiness: float = 0.0
var _evolution_boost: float = 0.0
var _cooldown_timer: float = 0.0
var _profile: Dictionary = {}

func _ready() -> void:
    _profile = GameState.profile if GameState.has_method("get_profile") else {}
    _cooldown_timer = 0.0

func _process(delta: float) -> void:
    if _cooldown_timer > 0.0:
        _cooldown_timer = max(0.0, _cooldown_timer - delta)

func add_zone(zone_id: String, happiness: float = -1.0) -> bool:
    if _cooldown_timer > 0.0:
        return false
    if _zones.size() >= MAX_ZONES:
        return false
    var h: float = happiness if happiness >= 0.0 else happiness_per_zone
    _zones[zone_id] = h
    _total_happiness += h
    _evolution_boost = _total_happiness * 0.01
    EventBus.happiness_changed.emit(_total_happiness)
    EventBus.evolution_boost_changed.emit(_evolution_boost)
    zone_added.emit(zone_id)
    _cooldown_timer = zone_cooldown_seconds
    return true

func remove_zone(zone_id: String) -> bool:
    var h: float = _zones.get(zone_id, 0.0)
    _zones.erase(zone_id)
    _total_happiness -= h
    _evolution_boost = _total_happiness * 0.01
    EventBus.happiness_changed.emit(_total_happiness)
    EventBus.evolution_boost_changed.emit(_evolution_boost)
    zone_removed.emit(zone_id)
    return true

func get_happiness() -> float:
    return _total_happiness

func get_evolution_boost() -> float:
    return _evolution_boost

func get_zone_count() -> int:
    return _zones.size()

func get_zone_ids() -> Array[String]:
    return _zones.keys()

func set_profile(profile: Dictionary) -> void:
    _profile = profile