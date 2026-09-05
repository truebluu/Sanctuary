class_name CreatureGarden extends Node
## Garden of plantable decorations that grow over time and grant mood/health buffs
## to resident creatures. Builds on CreatureNeedsEngine for buffs and EventBus for
## garden events.

# --- Tunables (one-setting changes) ---
const MAX_DECORATIONS: int = 12               # hard cap on concurrent garden items
const GROWTH_TICK_INTERVAL: float = 0.5        # seconds between growth checks
const GROWTH_PER_TICK: float = 0.08             # fraction of max growth per tick
const MOOD_BUFF_AMOUNT: float = 0.12            # mood boost per grown decoration
const HEALTH_BUFF_AMOUNT: float = 0.06          # health boost per grown decoration
const BUFF_DURATION: float = 180.0              # seconds a creature holds a buff

# --- State ---
var _decorations: Array[Dictionary] = []       # {id, type, planted_at, growth}
var _grow_timer: float = 0.0
var _creature_refs: Array[Node] = []           # creatures that receive buffs
var _active_buffs: Dictionary = {}             # creature -> remaining seconds

signal decoration_planted(id: String, type: String)
signal decoration_grown(id: String, type: String, growth: float)
signal buff_applied(creature: Node, mood: float, health: float)
signal garden_full()

func _ready() -> void:
    # Listen for creatures that want to join the garden.
    pass
    # Creatures are added via add_creature(); no EventBus signal exists for garden join.
    # (removed invalid EventBus singleton access)
    # (removed invalid signal connection)

func _process(delta: float) -> void:
    if _decorations.is_empty():
        return
    _grow_timer += delta
    if _grow_timer < GROWTH_TICK_INTERVAL:
        return
    _grow_timer = 0.0
    for dec in _decorations:
        var growth: float = dec.growth + GROWTH_PER_TICK
        dec.growth = min(growth, 1.0)
        if growth >= 1.0:
            _on_decoration_grown(dec)
            decoration_grown.emit(dec.id, dec.type, growth)

func _on_decoration_grown(dec: Dictionary) -> void:
    var mood: float = MOOD_BUFF_AMOUNT * dec.growth
    var health: float = HEALTH_BUFF_AMOUNT * dec.growth
    for c in _creature_refs:
        if not c.is_node_in_tree():
            continue
        var remaining: float = _active_buffs.get(c, 0.0)
        remaining += BUFF_DURATION
        _active_buffs[c] = remaining
        if remaining >= BUFF_DURATION:
            buff_applied.emit(c, mood, health)
    if _decorations.size() >= MAX_DECORATIONS:
        garden_full.emit()

func plant_decoration(id: String, type: String) -> bool:
    if _decorations.size() >= MAX_DECORATIONS:
        return false
    var dec: Dictionary = {
        "id": id,
        "type": type,
        "planted_at": Time.get_unix_time_from_system(),
        "growth": 0.0,
    }
    _decorations.append(dec)
    decoration_planted.emit(id, type)
    return true

func add_creature(creature: Node) -> void:
    if creature and creature.has_method("apply_mood_buff") and creature.has_method("apply_health_buff"):
        _creature_refs.append(creature)

func _on_creature_joined(creature: Node) -> void:
    add_creature(creature)

func get_active_buff_seconds(creature: Node) -> float:
    return _active_buffs.get(creature, 0.0)

func get_decoration_count() -> int:
    return _decorations.size()

func get_total_growth() -> float:
    var total: float = 0.0
    for dec in _decorations:
        total += dec.growth
    return total