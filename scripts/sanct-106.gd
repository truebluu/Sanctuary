extends Node2D
class_name CreatureHealingTouch

## Touch-based healing zone. Creatures overlapping this area are restored
## over time at a steady rate. Builds on the existing CreatureHealthSystem.

signal creature_healed(creature: Node, amount: float)
signal heal_pulse(creature: Node)

# --- Tunables (one place to retune healing feel) ---
@export var heal_per_second: float = 8.0          # HP restored per second per creature
@export var max_healing_targets: int = 4          # concurrent creatures healed at once
@export var heal_radius: float = 96.0              # detection radius
@export var require_contact: bool = true           # true = must be touching, false = aura
@export var heal_visual_strength: float = 0.6      # glow intensity of the heal pulse

@onready var _area: Area2D = $HealArea
@onready var _shape: CircleShape2D = $HealArea/CollisionShape2D.shape as CircleShape2D

var _active_targets: Array[Node] = []
var _accum: float = 0.0

func _ready() -> void:
    _shape.radius = heal_radius
    _area.body_entered.connect(_on_body_entered)
    _area.body_exited.connect(_on_body_exited)
    _area.monitorable = true
    _area.monitor = true
    visible = false  # hidden by default; enable when a sanctuary healer is active

func _process(delta: float) -> void:
    if _active_targets.is_empty():
        return
    _accum += delta * heal_per_second
    while _accum >= 1.0:
        _accum -= 1.0
        _apply_heal_burst()

func _apply_heal_burst() -> void:
    for creature in _active_targets:
        if not is_instance_valid(creature):
            continue
        var healed: float = _heal_one(creature)
        if healed > 0.0:
            creature_healed.emit(creature, healed)
            heal_pulse.emit(creature)

func _heal_one(creature: Node) -> float:
    # Route through the creature's own health system if it has one.
    if creature.has_method("heal"):
        return creature.heal(heal_per_second)
    if creature.has_node("Health"):
        var hp: Node = creature.get_node("Health")
        if hp.has_method("heal"):
            return hp.heal(heal_per_second)
    return 0.0

func _on_body_entered(body: Node) -> void:
    if not _is_healable(body):
        return
    if _active_targets.size() < max_healing_targets:
        _active_targets.append(body)

func _on_body_exited(body: Node) -> void:
    _active_targets.erase(body)

func _is_healable(body: Node) -> bool:
    # Only living creatures that can actually gain health count.
    if not body.is_in_group("creature"):
        return false
    if body.has_method("is_alive") and not body.is_alive():
        return false
    return true

func set_active(active: bool) -> void:
    visible = active
    _area.monitor = active

func get_active_count() -> int:
    return _active_targets.size()