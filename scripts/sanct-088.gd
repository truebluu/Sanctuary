class_name CreaturePackBehavior
extends Node

# Social creatures form packs that share resources and influence each other's mood.
# Builds on the existing EventBus for pack events and GameState for global state.
# Feel: bonding, shared resource pooling, mood‑driven spawn aggression.

# --- Tunables (one‑setting changes) ---
const _MAX_PACK_SIZE: int = 8                # hard cap on concurrent pack members
const _BONDING_THRESHOLD: float = 0.6        # mood above this counts as bonded
const _RESOURCE_SHARING_CHANCE: float = 0.4  # chance a creature shares a resource
const _MOOD_INFLUENCE_STRENGTH: float = 0.3  # how much pack mood scales spawn aggression
const _PACK_REGEN_INTERVAL: float = 12.0     # seconds between resource pool replenish

@export var pack_members: Array[Node] = []
@export var pack_leader: Node = null
@export var pack_mood: float = 0.5
@export var pack_resource_pool: float = 0.0

var _regeneration_timer: float = 0.0

func _ready() -> void:
    add_to_group("creature_pack")
    pack_leader = get_node_or_null("PackLeader")
    if pack_leader != null:
        pack_leader.tree_exited.connect(_on_leader_left)
    _regeneration_timer = _PACK_REGEN_INTERVAL

func add_member(member: Node) -> void:
    if pack_members.size() >= _MAX_PACK_SIZE:
        return
    pack_members.append(member)
    member.tree_exited.connect(_on_member_left.bind(member))
    _recalculate_mood()

func _on_member_left(member: Node) -> void:
    pack_members.erase(member)
    if member == pack_leader:
        pack_leader = null
    _recalculate_mood()

func _on_leader_left() -> void:
    pack_leader = null
    _recalculate_mood()

func _recalculate_mood() -> void:
    var avg_mood: float = 0.5
    for member in pack_members:
        var mood: float = member.get("mood", 0.5) if member.has_method("get_mood") else 0.5
        avg_mood += mood
    # Normalize against pack size so larger packs average out
    avg_mood = avg_mood / (1.0 + float(pack_members.size())) if pack_members.size() > 0 else 0.5
    pack_mood = avg_mood

func share_resource(amount: float) -> float:
    # A bonded member may share part of its resource with the pack
    var shared: float = 0.0
    if randf() < _RESOURCE_SHARING_CHANCE:
        shared = amount * 0.5
        pack_resource_pool = maxf(pack_resource_pool - shared, 0.0)
    return shared

func influence_spawn(profile: Dictionary) -> Dictionary:
    # Pack mood steers spawn interval and aggression, making bonded packs more aggressive
    var mood_factor: float = 1.0 + pack_mood * _MOOD_INFLUENCE_STRENGTH
    var spawn_interval: float = profile.get("spawn_interval", 2.0) / mood_factor
    var aggression: float = profile.get("aggression", 0.5) * mood_factor
    profile["spawn_interval"] = clampf(spawn_interval, 0.5, 10.0)
    profile["aggression"] = clampf(aggression, 0.0, 1.0)
    return profile

func _process(delta: float) -> void:
    _regeneration_timer -= delta
    if _regeneration_timer <= 0.0:
        _regeneration_timer = _PACK_REGEN_INTERVAL
        _attempt_replenish()

func _attempt_replenish() -> void:
    if pack_resource_pool < 1.0 and pack_members.size() > 0:
        var gain: float = 0.2
        pack_resource_pool = minf(pack_resource_pool + gain, 1.0)
        EventBus.pack_resource_changed.emit(pack_resource_pool)

func get_pack_summary() -> Dictionary:
    return {
        "size": pack_members.size(),
        "leader": pack_leader,
        "mood": pack_mood,
        "resource": pack_resource_pool,
    }