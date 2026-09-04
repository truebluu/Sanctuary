extends Node
class_name BreedingCooldown

## Cooldown gate for creature breeding. Prevents infinite offspring by enforcing
## a rest period after each breeding event. Per-creature tracking so one busy
## creature does not block others.

signal cooldown_started(creature_id: StringName, duration: float)
signal cooldown_expired(creature_id: StringName)

# Seconds a creature must rest after breeding before it can breed again.
@export var cooldown_seconds: float = 45.0
# If true, cooldowns persist across scene reloads (stored in the creature save).
@export var persist_across_loads: bool = true

# creature_id -> seconds remaining. Empty entry means no active cooldown.
var _remaining: Dictionary = {}
var _accum: float = 0.0

func _process(delta: float) -> void:
    if _remaining.is_empty():
        return
    var expired: Array[StringName] = []
    for id in _remaining.keys():
        var left: float = _remaining[id] - delta
        if left <= 0.0:
            expired.append(id)
            _remaining.erase(id)
            cooldown_expired.emit(id)
        else:
            _remaining[id] = left

## Returns true when the creature is free to breed.
func can_breed(creature_id: StringName) -> bool:
    return !_remaining.has(creature_id)

## Begins the cooldown for a creature that just bred.
func start_cooldown(creature_id: StringName) -> void:
    _remaining[creature_id] = cooldown_seconds
    cooldown_started.emit(creature_id, cooldown_seconds)

## How many seconds until this creature can breed again. 0 if available.
func time_remaining(creature_id: StringName) -> float:
    return _remaining.get(creature_id, 0.0)

## Fraction of the cooldown already elapsed (0..1). 1.0 means ready.
func cooldown_progress(creature_id: StringName) -> float:
    if can_breed(creature_id):
        return 1.0
    var left: float = time_remaining(creature_id)
    return 1.0 - (left / cooldown_seconds)

## Instantly clear a cooldown (e.g. a breeding-boost powerup).
func clear_cooldown(creature_id: StringName) -> void:
    if _remaining.erase(creature_id):
        cooldown_expired.emit(creature_id)

## Global snapshot for HUD / save serialization.
func get_active_cooldowns() -> Dictionary:
    var out: Dictionary = {}
    for id in _remaining.keys():
        out[id] = _remaining[id]
    return out

## Restore a previously saved cooldown state.
func restore_state(snapshot: Dictionary) -> void:
    _remaining.clear()
    for id in snapshot.keys():
        var v: float = snapshot[id]
        if v > 0.0:
            _remaining[id] = v

# Feel: per-creature cooldown stops the player from spam-breeding one creature
# into an army, forcing them to rotate a small roster and care for each one.
# Builds on the existing BreedingManager/BreedingGeneticsManager pipeline —
# BreedingManager asks can_breed() before allowing a pairing.