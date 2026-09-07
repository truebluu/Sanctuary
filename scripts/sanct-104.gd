class_name CreatureDaycare
extends Node

# Tunables — one-setting changes (designer-editable via @export)
@export var max_creatures: int = 8
@export var shift_duration_sec: float = 120.0
@export var rest_interval_sec: float = 300.0
@export var feed_amount: float = 25.0
@export var play_duration_sec: float = 60.0
@export var energy_cost_per_shift: float = 5.0

# Resource limits (hard caps, never inline)
const _MAX_CONCURRENT_SHIFTS: int = 4

signal creature_shift_changed(creature_id: String, shift_start: float, shift_end: float)
signal creature_care_event(creature_id: String, event_type: String, detail: Variant)
signal daycare_full()

var _creatures: Dictionary = {}   # creature_id -> care metrics dictionary
var _active_shifts: Dictionary = {}   # shift_index -> shift data
var _next_shift_index: int = 0
var _energy_system: EnergySystem

func _ready() -> void:
    _energy_system = EnergySystem
    if _energy_system == null:
        _energy_system = EnergySystem

func register_creature(creature_id: String, initial_idle: float = 0.0) -> void:
    if _creatures.has(creature_id):
        return
    _creatures[creature_id] = {
        "idle_time": initial_idle,
        "rest_time": 0.0,
        "fed_amount": 0.0,
        "play_time": 0.0,
        "energy_spent": 0.0,
    }

func start_shift(creature_id: String, duration: float = -1.0) -> bool:
    if not _creatures.has(creature_id):
        return false
    var dur: float = duration if duration > 0.0 else shift_duration_sec
    var start: float = _next_shift_index * shift_duration_sec
    var end: float = start + dur
    _active_shifts[_next_shift_index] = {
        "creature_id": creature_id,
        "start_sec": start,
        "end_sec": end,
    }
    _creatures[creature_id]["energy_spent"] += energy_cost_per_shift
    if _energy_system != null:
        _energy_system.spend_energy(energy_cost_per_shift)
    EventBus.creature_shift_changed.emit(creature_id, start, end)
    creature_shift_changed.emit(creature_id, start, end)
    _next_shift_index += 1
    if _next_shift_index >= max_creatures:
        daycare_full.emit()
    return true

func end_shift(creature_id: String, shift_index: int) -> bool:
    var shift: Dictionary = _active_shifts.get(shift_index, {})
    if shift.creature_id != creature_id:
        return false
    var end: float = shift.end_sec
    var start: float = shift.start_sec
    var dur: float = end - start
    var data: Dictionary = _creatures[creature_id]
    data["rest_time"] += dur
    data["idle_time"] += dur
    _active_shifts.erase(shift_index)
    creature_care_event.emit(creature_id, "shift_ended", {"duration": dur, "shift": shift_index})
    return true

func feed_creature(creature_id: String, amount: float = -1.0) -> void:
    var data: Dictionary = _creatures[creature_id]
    var fed: float = amount if amount > 0.0 else feed_amount
    data["fed_amount"] += fed
    data["idle_time"] = 0.0
    creature_care_event.emit(creature_id, "fed", {"amount": fed})

func play_with_creature(creature_id: String, duration: float = -1.0) -> void:
    var data: Dictionary = _creatures[creature_id]
    var play_dur: float = duration if duration > 0.0 else play_duration_sec
    data["play_time"] += play_dur
    data["idle_time"] = 0.0
    creature_care_event.emit(creature_id, "play", {"duration": play_dur})

func _process(delta: float) -> void:
    for creature_id in _creatures:
        var data: Dictionary = _creatures[creature_id]
        data["idle_time"] += delta
        if data["idle_time"] >= rest_interval_sec:
            data["rest_time"] += delta
            data["idle_time"] = 0.0
            creature_care_event.emit(creature_id, "rest_started")

func get_care_summary() -> Dictionary:
    var summary: Dictionary = {"creatures": []}
    for creature_id in _creatures:
        var data: Dictionary = _creatures[creature_id]
        summary["creatures"].append({
            "id": creature_id,
            "idle_time": data["idle_time"],
            "rest_time": data["rest_time"],
            "fed_amount": data["fed_amount"],
            "play_time": data["play_time"],
            "energy_spent": data["energy_spent"],
        })
    return summary