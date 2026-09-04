class_name SanctuaryExpansionCost
extends RefCounted

## Cost tiers for sanctuary expansion. Each tier unlocks more space/creatures.
## Currency is earned from creature activities and spent to expand.

## Named constants — every tunable lives here, never inline.
const CURRENCY_NAME: String = "Sanctuary Credits"
const BASE_EXPANSION_COST: int = 100
## Cost multiplier applied per tier (cost = base * tier_mult).
const COST_PER_TIER_MULT: float = 1.8
const MAX_TIER: int = 8
## Credits a creature earns per completed activity cycle.
const CREDITS_PER_ACTIVITY: int = 10
## Bonus credits for a creature at max happiness during an activity.
const HAPPINESS_BONUS_CREDITS: int = 5
## Fraction of activity credits kept as a tax for upkeep (0.0 = none).
const UPTAKE_TAX: float = 0.05

var _balance: int = 0
var _current_tier: int = 0
var _spent_this_run: int = 0

signal balance_changed(new_balance: int)
signal tier_unlocked(new_tier: int, cost_paid: int)
signal expansion_blocked(reason: String)

func _init() -> void:
    _balance = 0
    _current_tier = 0
    _spent_this_run = 0

func get_balance() -> int:
    return _balance

func get_current_tier() -> int:
    return _current_tier

func get_max_tier() -> int:
    return MAX_TIER

## Cost to move from the current tier to the next.
func next_tier_cost() -> int:
    if _current_tier >= MAX_TIER:
        return -1
    return int(round(BASE_EXPANSION_COST * pow(COST_PER_TIER_MULT, _current_tier)))

func can_afford_next() -> bool:
    var cost: int = next_tier_cost()
    return cost >= 0 and _balance >= cost

func is_maxed() -> bool:
    return _current_tier >= MAX_TIER

## Creature completed an activity. Returns credits actually added (after upkeep tax).
func award_activity_credits(creature_happy: bool) -> int:
    var earned: int = CREDITS_PER_ACTIVITY
    if creature_happy:
        earned += HAPPINESS_BONUS_CREDITS
    var taxed: int = int(round(earned * UPTAKE_TAX))
    var net: int = earned - taxed
    _balance += net
    balance_changed.emit(_balance)
    return net

func expand() -> bool:
    if is_maxed():
        expansion_blocked.emit("Sanctuary is fully expanded")
        return false
    var cost: int = next_tier_cost()
    if _balance < cost:
        expansion_blocked.emit("Need %d more credits (have %d)" % [cost - _balance, _balance])
        return false
    _balance -= cost
    _spent_this_run += cost
    _current_tier += 1
    balance_changed.emit(_balance)
    tier_unlocked.emit(_current_tier, cost)
    return true

func reset() -> void:
    _balance = 0
    _current_tier = 0
    _spent_this_run = 0
    balance_changed.emit(_balance)

## Feel: expansion cost scales exponentially via COST_PER_TIER_MULT so early tiers are cheap
## and rewarding, while late tiers require real creature-activity investment — builds on the
## existing Sanctuary expansion foundation and Creature activity systems.