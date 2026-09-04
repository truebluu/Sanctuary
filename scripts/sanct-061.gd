The task asks for a Sanctuary expansion cost system where expansions require currency earned from creature activities. Looking at the reference library, I see `SanctuaryPanel`, `CreatureNeeds`, `CreatureBonding`, and `Inventory` are relevant existing classes. I need to create a system that tracks currency, defines expansion costs, and processes purchases.

Key design considerations:
1. Currency should be earned from creature activities (needs/bonding/training)
2. Expansions should have tunable costs (Tunability Mandate)
3. Must integrate with existing systems (SanctuaryPanel, Creature systems)
4. Should use GameState/EventBus for state management
5. Costs should be grouped as named constants/exports for easy tuning

I'll create a `SanctuaryExpansion` class that manages currency and expansion purchases, integrating with the existing Sanctuary system.
</think>

class_name SanctuaryExpansion
extends Node

# Currency earned from creature activities, spent on sanctuary expansions.

signal currency_changed(amount: int, source: String)
signal expansion_purchased(expansion_id: String, cost: int)
signal expansion_failed(expansion_id: String, reason: String)

# --- Tunable constants (one place to change difficulty/economy) ---
const CURRENCY_PER_NEED_FULFILLED: int = 5
const CURRENCY_PER_BONDING_ACTION: int = 8
const CURRENCY_PER_TRAINING_SESSION: int = 12
const CURRENCY_PER_PHOTO_MODE: int = 3

# Base cost to unlock the first expansion slot
const BASE_EXPANSION_COST: int = 50
# Cost multiplier per expansion already owned
const COST_SCALE_FACTOR: float = 1.4

# --- Expansion definitions ---
const EXPANSION_SLOTS: Dictionary = {
    "wing_1": {"name": "Wing 1", "base_cost": 50, "description": "Extra creature housing"},
    "playground": {"name": "Playground", "base_cost": 80, "description": "Boosts bonding gains"},
    "healing_garden": {"name": "Healing Garden", "base_cost": 100, "description": "Passive sickness recovery"},
    "breeding_lounge": {"name": "Breeding Lounge", "base_cost": 130, "description": "Unlocks advanced genetics"},
    "observatory": {"name": "Observatory", "base_cost": 160, "description": "Photo mode bonus currency"},
}

var _currency: int = 0
var _owned_expansions: Array[String] = []

func _ready() -> void:
    CreatureNeedsEngine.need_fulfilled.connect(_on_need_fulfilled)
    CreatureBonding.bonding_action_completed.connect(_on_bonding_action)
    if Engine.has_singleton("TrainingManager"):
        var tm = Engine.get_singleton("TrainingManager")
        if tm.has_signal("training_completed"):
            tm.training_completed.connect(_on_training_completed)

func get_currency() -> int:
    return _currency

func add_currency(amount: int, source: String) -> void:
    if amount <= 0:
        return
    _currency += amount
    currency_changed.emit(_currency, source)

func can_afford(cost: int) -> bool:
    return _currency >= cost

func get_expansion_cost(expansion_id: String) -> int:
    var slot: Dictionary = EXPANSION_SLOTS.get(expansion_id, {})
    var base: int = int(slot.get("base_cost", BASE_EXPANSION_COST))
    # Scale cost by how many expansions are already owned
    var scaled: float = base * pow(COST_SCALE_FACTOR, _owned_expansions.size())
    return int(round(scaled))

func is_owned(expansion_id: String) -> bool:
    return _owned_expansions.has(expansion_id)

func purchase(expansion_id: String) -> bool:
    if is_owned(expansion_id):
        expansion_failed.emit(expansion_id, "Already owned")
        return false
    if not EXPANSION_SLOTS.has(expansion_id):
        expansion_failed.emit(expansion_id, "Unknown expansion")
        return false
    var cost: int = get_expansion_cost(expansion_id)
    if not can_afford(cost):
        expansion_failed.emit(expansion_id, "Not enough currency")
        return false
    _currency -= cost
    _owned_expansions.append(expansion_id)
    currency_changed.emit(_currency, "purchase")
    expansion_purchased.emit(expansion_id, cost)
    return true

func get_owned_count() -> int:
    return _owned_expansions.size()

# --- Creature activity hooks (currency sources) ---
func _on_need_fulfilled(_creature_id: String, _need_type: String) -> void:
    add_currency(CURRENCY_PER_NEED_FULFILLED, "need_fulfilled")

func _on_bonding_action(_creature_id: String, _action: String) -> void:
    add_currency(CURRENCY_PER_BONDING_ACTION, "bonding")

func _on_training_completed(_creature_id: String) -> void:
    add_currency(CURRENCY_PER_TRAINING_SESSION, "training")

func grant_photo_bonus() -> void:
    if is_owned("observatory"):
        add_currency(CURRENCY_PER_PHOTO_MODE, "photo_observatory_bonus")

# --- Persistence support ---
func serialize() -> Dictionary:
    return {
        "currency": _currency,
        "owned": _owned_expansions,
    }

func deserialize(data: Dictionary) -> void:
    _currency = int(data.get("currency", 0))
    _owned_expansions = Array(data.get("owned", []))
    if _currency > 0:
        currency_changed.emit(_currency, "loaded")

# Feel note: currency flows from creature care (needs/bonding/training) into
# expansion purchases, building on CreatureNeedsEngine and CreatureBonding.
# Costs scale with owned count so later expansions feel earned, tuned via
# BASE_EXPANSION_COST and COST_SCALE_FACTOR.