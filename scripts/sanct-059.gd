The user wants a creature trading system for the Bluu Ink Studios Galage project. Let me review the reference library to reuse existing autoloads and classes.

Existing relevant references:
- `Creature` global class
- `CreatureGenome` global class
- `CreatureCodex` global class
- `EnergySystem` autoload (for trade currency)
- `GameState` autoload
- `EventBus` autoload
- `Inventory` global class
- `CreatureBonding` global class

I need to build a creature trading layer that:
1. Values a creature (based on genome, rarity, bonding) so trades can be fair
2. Proposes a trade between two creatures
3. Executes the trade, transferring ownership
4. Integrates with EnergySystem for optional currency trades

Tunability: trade fees, value multipliers, bonding thresholds, trade cooldown.

Design:
- `CreatureValue` — a scorer that values a creature from its genome + bonding
- `TradeOffer` — Resource describing a proposed trade (creature-for-creature, creature-for-energy, or both)
- `CreatureTrade` — the transaction manager that validates and executes trades, with cooldown and fee

I'll write this as a single file `creature_trade.gd` with the scorer, offer, and manager, since they're tightly coupled.

Let me write it properly with Godot 4 idioms, @export tunables, EventBus signals, and integration with the existing Creature/CreatureGenome/EnergySystem/GameState.
</think>

```gdscript
## Creature trading: value creatures, propose and execute trades.
## Builds on Creature, CreatureGenome, EnergySystem, GameState, EventBus.
## Feel added: meaningful creature economy — every creature has a visible value
## derived from its genome and bond, so trades feel consequential, not arbitrary.
extends Node
class_name CreatureTrade

signal trade_proposed(offer: TradeOffer)
signal trade_completed(offer: TradeOffer, value_gained: int)
signal trade_failed(offer: TradeOffer, reason: String)
signal value_updated(creature: Creature, value: int)

# --- Tunables ---
@export var trade_fee_percent: float = 0.05          # % of value taken as fee
@export var trade_cooldown_sec: float = 3.0          # seconds between trades
@export var min_trade_value: int = 10                # creatures below this are not tradeable
@export var bonding_value_mult: float = 1.4           # extra value for bonded creatures
@export var rarity_base_value: int = 50               # base value per rarity tier
@export var trait_value_bonus: int = 8                # value per expressed trait
@export var energy_per_value: float = 0.5             # Energy gained per value traded

var _last_trade_time: float = -9999.0

# ---- CreatureValue: scores a single creature ----
## Returns a value integer. Higher = more desirable.
static func value_of(creature: Creature) -> int:
    if creature == null:
        return 0
    var v: int = 0
    # Rarity tier is the backbone.
    var rarity: int = creature.get_rarity() if creature.has_method("get_rarity") else 0
    v += rarity * rarity_base_value
    # Genome traits add up.
    var genome := creature.get_genome()
    if genome != null and genome.has_method("get_trait_count"):
        v += int(genome.get_trait_count()) * trait_value_bonus
    # Bonded creatures are worth more (player attachment).
    var bonded: bool = creature.get_bonded() if creature.has_method("get_bonded") else false
    if bonded:
        v = int(v * bonding_value_mult)
    return max(v, 0)

# ---- TradeOffer: a Resource describing a proposed trade ----
extends Resource
class_name TradeOffer

enum Kind { CREATURE_FOR_CREATURE, CREATURE_FOR_ENERGY, ENERGY_FOR_CREATURE }

@export var kind: int = Kind.CREATURE_FOR_CREATURE
@export var my_creature: Creature = null
@export var their_creature: Creature = null
@export var energy_cost: int = 0
@export var energy_gain: int = 0
@export var my_value: int = 0
@export var their_value: int = 0

func is_fair(tolerance: float = 0.35) -> bool:
    var hi: int = max(my_value, their_value)
    var lo: int = min(my_value, their_value)
    if hi <= 0:
        return true
    return (float(hi - lo) / float(hi)) <= tolerance

func description() -> String:
    return "Trade offer (kind=%d, my_val=%d, their_val=%d, fair=%s)" % [
        kind, my_value, their_value, str(is_fair())]

# ---- Manager methods (live on the CreatureTrade Node) ----

func can_trade_now() -> bool:
    return (Time.get_ticks_msec() / 1000.0) - _last_trade_time >= trade_cooldown_sec

func is_tradeable(creature: Creature) -> bool:
    if creature == null:
        return false
    return value_of(creature) >= min_trade_value

## Propose a creature-for-creature trade. Returns the TradeOffer.
func propose_creature_trade(my_creature: Creature, their_creature: Creature) -> TradeOffer:
    var offer := TradeOffer.new()
    offer.kind = TradeOffer.Kind.CREATURE_FOR_CREATURE
    offer.my_creature = my_creature
    offer.their_creature = their_creature
    offer.my_value = value_of(my_creature)
    offer.their_value = value_of(their_creature)
    trade_proposed.emit(offer)
    return offer

## Propose trading a creature for Energy.
func propose_creature_for_energy(my_creature: Creature) -> TradeOffer:
    var value: int = value_of(my_creature)
    var offer := TradeOffer.new()
    offer.kind = TradeOffer.Kind.CREATURE_FOR_ENERGY
    offer.my_creature = my_creature
    offer.my_value = value
    offer.energy_gain = int(value * energy_per_value)
    trade_proposed.emit(offer)
    return offer

func execute(offer: TradeOffer) -> bool:
    if offer == null:
        trade_failed.emit(offer, "null offer")
        return false
    if not can_trade_now():
        trade_failed.emit(offer, "trade cooldown active")
        return false
    if offer.kind == TradeOffer.Kind.CREATURE_FOR_CREATURE:
        if not is_tradeable(offer.my_creature) or not is_tradeable(offer.their_creature):
            trade_failed.emit(offer, "creature below tradeable value")
            return false
        var fee: int = int((offer.my_value + offer.their_value) * trade_fee_percent)
        _last_trade_time = Time.get_ticks_msec() / 1000.0
        _swap_ownership(offer.my_creature, offer.their_creature)
        if fee > 0 and EnergySystem != null:
            EnergySystem.spend(fee, "trade_fee")
        var gained: int = offer.their_value - offer.my_value
        trade_completed.emit(offer, gained)
        return true
    elif offer.kind == TradeOffer.Kind.CREATURE_FOR_ENERGY:
        if not is_tradeable(offer.my_creature):
            trade_failed.emit(offer, "creature below tradeable value")
            return false
        var fee: int = int(offer.my_value * trade_fee_percent)
        _last_trade_time = Time.get_ticks_msec() / 1000.0
        if EnergySystem != null:
            EnergySystem.add(offer.energy_gain, "creature_trade")
            if fee > 0:
                EnergySystem.spend(fee, "trade_fee")
        _release_creature(offer.my_creature)
        trade_completed.emit(offer, offer.energy_gain)
        return true
    trade_failed.emit(offer, "unsupported offer kind")
    return false

func _swap_ownership(a: Creature, b: Creature) -> void:
    # Ownership swap: each creature's owner/holder is exchanged.
    if a.has_method("set_owner"):
        a.set_owner(b.get_owner() if b.has_method("get_owner") else null)
    if b.has_method("set_owner"):
        b.set_owner(a.get_owner() if a.has_method("get_owner") else null)
    if GameState != null and GameState.has_method("on_creature_traded"):
        GameState.on_creature_traded(a, b)
    if EventBus != null:
        EventBus.emit("creature_traded", a, b)

func _release_creature(creature: Creature) -> void:
    # Creature traded away for energy: unbind and free.
    if creature.has_method("set_owner"):
        creature.set_owner(null)
    if creature.has_method("set_bonded"):
        creature.set_bonded(false)
    if GameState != null and GameState.has_method("on_creature_released"):
        GameState.on_creature_released(creature)