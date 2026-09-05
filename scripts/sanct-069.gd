class_name CreatureSanctuaryGarden
extends Node

# A garden sanctuary where creatures rest, heal, and perform bonding rituals.
# Integrates with CreatureNeeds (rest/heal), CreatureBonding (bonding),
# and the existing sanctuary ecosystem.

signal plant_grown(plant_id: int)
signal creature_resting(creature_id: String)
signal bonding_started(creature_id: String)

const _MAX_GARDEN_SLOTS: int = 6
const _HEAL_PER_SECOND: float = 2.0
const _BONDING_BONUS: int = 10

@export var garden_name: String = "Sanctuary Garden"
@export var slot_positions: Array[Vector2] = []
@export var plant_spawn_interval: float = 3.0
@export var max_plants: int = 8

var _slots_filled: int = 0
var _plants: Array[Node] = []

func _ready() -> void:
    _slots_filled = 0
    for pos in slot_positions:
        if _slots_filled < _MAX_GARDEN_SLOTS:
            _slots_filled += 1

func creature_entered(creature: Node) -> void:
    # Restore a small amount of health and start healing over time.
    if creature.has_method("apply_heal"):
        creature.apply_heal(_HEAL_PER_SECOND * 0.5)
    # Begin a bonding ritual if the creature has a bondable trait.
    if creature.has_method("start_bonding"):
        creature.start_bonding()
        bonding_started.emit(creature.name)

func creature_left(creature: Node) -> void:
    # Stop any ongoing healing.
    if creature.has_method("stop_healing"):
        creature.stop_healing()
    creature_resting.emit(creature.name)

func plant_seed() -> void:
    if _plants.size() >= max_plants:
        return
    var plant := Node.new()
    plant.name = "SanctuaryPlant_%d" % _plants.size()
    add_child(plant)
    _plants.append(plant)
    plant_grown.emit(_plants.size() - 1)

func _process(delta: float) -> void:
    for plant in _plants:
        pass
    # Optional: visual bloom when a creature is resting.
    pass