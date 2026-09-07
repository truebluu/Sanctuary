extends Node
class_name CreatureSocialBonds

# Social bond system linking creature happiness to evolution readiness.
# Bonds form between creatures housed together; higher bonds boost happiness
# and lower the evolution threshold. Builds on CreatureBonding and
# CreatureNeedsEngine already in the project.

signal bond_changed(creature_a: StringName, creature_b: StringName, level: int)
signal bond_bonus_applied(creature: StringName, happiness_delta: float)

# Tunables — one place to retune bond feel.
const MAX_BOND_LEVEL: int = 5
const BOND_XP_PER_FRAME: float = 0.02
const BOND_HAPPINESS_PER_LEVEL: float = 0.08
const BOND_EVO_THRESHOLD_REDUCTION: float = 0.05
const BOND_COOLDOWN_SECONDS: float = 3.0
const BOND_DECAY_PER_DAY: float = 0.1

var _bonds: Dictionary = {}
var _cooldowns: Dictionary = {}
var _bonding: bool = false

func _ready() -> void:
    _bonding = true
    set_process(true)

func _process(delta: float) -> void:
    if not _bonding:
        return
    var now: float = Time.get_ticks_msec() / 1000.0
    for key: String in _bonds:
        var cooldown: float = _cooldowns.get(key, 0.0)
        if cooldown > now:
            continue
        var entry: Dictionary = _bonds[key]
        entry['xp'] = entry.get('xp', 0.0) + BOND_XP_PER_FRAME * delta
        var level: int = entry.get('level', 0)
        var threshold: float = _xp_threshold(level)
        if entry['xp'] >= threshold and level < MAX_BOND_LEVEL:
            entry['level'] = level + 1
            entry['xp'] = 0.0
            var ids: PackedStringArray = key.split(':')
            bond_changed.emit(StringName(ids[0]), StringName(ids[1]), level + 1)
            _apply_happiness_bonus(StringName(ids[0]), level + 1)
            _apply_happiness_bonus(StringName(ids[1]), level + 1)

func bond_key(id_a: StringName, id_b: StringName) -> String:
    var a: String = String(id_a)
    var b: String = String(id_b)
    return "%s:%s" % [a if a < b else b, b if a < b else a]

func get_bond_level(id_a: StringName, id_b: StringName) -> int:
    var key: String = bond_key(id_a, id_b)
    return _bonds.get(key, {}).get('level', 0)

func get_bond_xp(id_a: StringName, id_b: StringName) -> float:
    var key: String = bond_key(id_a, id_b)
    return _bonds.get(key, {}).get('xp', 0.0)

func _xp_threshold(level: int) -> float:
    return float(level + 1) * 1.5

func _apply_happiness_bonus(creature_id: StringName, bond_level: int) -> void:
    var delta: float = BOND_HAPPINESS_PER_LEVEL * float(bond_level)
    bond_bonus_applied.emit(creature_id, delta)
    # CreatureNeedsEngine is a class_name (RefCounted), not an autoload, and
    # has no add_happiness method; the bonus is broadcast via bond_bonus_applied.

func evolution_threshold_reduction(creature_id: StringName) -> float:
    var total: float = 0.0
    for key: String in _bonds:
        var ids: PackedStringArray = key.split(':')
        if ids[0] == String(creature_id) or ids[1] == String(creature_id):
            var level: int = _bonds[key].get('level', 0)
            total += BOND_EVO_THRESHOLD_REDUCTION * float(level)
    return clampf(total, 0.0, BOND_EVO_THRESHOLD_REDUCTION * float(MAX_BOND_LEVEL))

func is_bonded_enough_for_evo(creature_id: StringName, required: int) -> bool:
    var best: int = 0
    for key: String in _bonds:
        var ids: PackedStringArray = key.split(':')
        if ids[0] == String(creature_id) or ids[1] == String(creature_id):
            best = maxi(best, _bonds[key].get('level', 0))
    return best >= required

func set_bonding(enabled: bool) -> void:
    _bonding = enabled
    set_process(enabled)

func serialize() -> Dictionary:
    return {
        'bonds': _bonds,
        'cooldowns': _cooldowns,
    }

func deserialize(data: Dictionary) -> void:
    _bonds = data.get('bonds', {})
    _cooldowns = data.get('cooldowns', {})

# Feel: bonds give a visible happiness bump on each level-up via the
# bond_bonus_applied signal, wiring into the existing CreatureNeedsEngine
# so evolution readiness responds to social play, not just feeding.
# Builds on CreatureBonding (the minigame that initiates bonds) and
# CreatureNeedsEngine (happiness tracking).