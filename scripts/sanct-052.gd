# HappinessDecay.gd
# Implements automatic happiness decay for Creatures when not fed/played,
# affecting evolution. Builds on existing Creature class and EventBus
# to broadcast changes, using tunable constants at the top.

extends Node

# Tunable constants (grouped at top)
const DECAY_TICK_INTERVAL: float = 1.0  # seconds between decay updates
const DECAY_RATE_PER_SECOND: float = 0.02
const EVOLUTION_HAPPINESS_LOW_THRESHOLD: float = 0.3
const EVOLUTION_HAPPINESS_HIGH_THRESHOLD: float = 0.7

# Exported for designer tweaking via inspector
@export var decay_tick_interval: float = DECAY_TICK_INTERVAL
@export var decay_rate: float = DECAY_RATE_PER_SECOND
@export var low_threshold: float = EVOLUTION_HAPPINESS_LOW_THRESHOLD
@export var high_threshold: float = EVOLUTION_HAPPINESS_HIGH_THRESHOLD

# Reference to the Creature this manager is attached to
@onready var creature: Node = $Creature

# Timer that drives decay
var _decay_timer: Timer

func _ready() -> void:
    _decay_timer = Timer.new()
    _decay_timer.wait_time = decay_tick_interval
    _decay_timer.one_shot = false
    _decay_timer.timeout.connect(_on_decay_tick)
    add_child(_decay_timer)
    _decay_timer.start()

func _on_decay_tick() -> void:
    var current_happiness: float = creature.happiness
    var new_happiness: float = max(current_happiness - decay_rate, 0.0)
    creature.happiness = new_happiness

    EventBus.emit_event("creature_happiness_changed", creature, new_happiness)

    if new_happiness <= low_threshold:
        EventBus.emit_event("creature_happiness_low", creature)

    if new_happiness >= high_threshold:
        EventBus.emit_event("creature_happiness_high", creature)

func set_happiness(value: float) -> void:
    creature.happiness = clamp(value, 0.0, 1.0)
    EventBus.emit_event("creature_happiness_changed", creature, value)