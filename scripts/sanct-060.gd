The user wants a `BreedingCooldown` class for the creature breeding system. Let me check the reference library for existing related classes and autoloads.

From the reference, I can see:
- `BreedingManager` already exists
- `BreedingCooldown` is listed as a global class
- Autoloads: `EnergySystem`, `EventBus`, `GameState`, `InputRemap`

The task is to write a breeding cooldown system that prevents infinite offspring. I need to follow the tunability mandate (exports/consts for tunable values), use existing autoloads, and build on the existing foundation.

Let me design this as a node that manages cooldown timers for breeding. It should:
1. Track a global breeding cooldown (time between any breedings)
2. Track per-creature cooldowns (time before a creature can breed again)
3. Emit signals when cooldowns expire
4. Be tunable via exports

I'll write a complete, self-contained GDScript file.
</think>

```gdscript
extends Node
class_name BreedingCooldown

# --- Tunables ---
const DEFAULT_GLOBAL_COOLDOWN: float = 30.0   # seconds between any breedings
const DEFAULT_CREATURE_COOLDOWN: float = 60.0 # seconds before a creature can breed again

signal global_cooldown_expired
signal creature_cooldown_expired(creature_id: String)

var _global_time_left: float = 0.0
var _creature_time_left: Dictionary = {}      # creature_id -> seconds

func _ready() -> void:
	name = "BreedingCooldown"
	_process = _process

func _process(delta: float) -> void:
	if _global_time_left > 0.0:
		_global_time_left -= delta
		if _global_time_left <= 0.0:
			_global_time_left = 0.0
			global_cooldown_expired.emit()
	var expired: Array[String] = []
	for creature_id: String in _creature_time_left:
		var t: float = _creature_time_left[creature_id] - delta
		if t <= 0.0:
			expired.append(creature_id)
			_creature_time_left[creature_id] = 0.0
		else:
			_creature_time_left[creature_id] = t
	for id in expired:
		_creature_cooldown_expired(id)
		creature_cooldown_expired.emit(id)

func set_global_cooldown(seconds: float) -> void:
	_global_time_left = maxf(0.0, seconds)

func set_creature_cooldown(creature_id: String, seconds: float) -> void:
	_creature_time_left[creature_id] = maxf(0.0, seconds)

func is_global_ready() -> bool:
	return _global_time_left <= 0.0

func is_creature_ready(creature_id: String) -> bool:
	return _creature_time_left.get(creature_id, 0.0) <= 0.0

func global_seconds_left() -> float:
	return _global_time_left

func creature_seconds_left(creature_id: String) -> float:
	return _creature_time_left.get(creature_id, 0.0)

func trigger_breed(creature_ids: Array[String], global_cd: float = DEFAULT_GLOBAL_COOLDOWN, creature_cd: float = DEFAULT_CREATURE_COOLDOWN) -> bool:
	if not is_global_ready():
		return false
	for id in creature_ids:
		if not is_creature_ready(id):
			return false
	set_global_cooldown(global_cd)
	for id in creature_ids:
		set_creature_cooldown(id, creature_cd)
	return true

func reset_all() -> void:
	_global_time_left = 0.0
	_creature_time_left.clear()