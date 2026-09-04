extends Node
class_name CreatureTrading

## Creature trading service — trade sanctuary creatures with NPCs or other players.
## Builds on: Creature, CreatureCodex, Inventory, CreatureSaveLoad, EventBus.
## Feel: meaningful exchange that rewards collection depth; each trade reshapes the sanctuary.

signal trade_proposed(offer: TradeOffer)
signal trade_completed(offer: TradeOffer, gained: Creature, lost: Creature)
signal trade_failed(reason: String)
signal trade_value_changed(creature: Creature, value: int)

# --- Tunable constants (one place to retune trade economy) ---
const VALUE_PER_LEVEL: int = 10          # base value scales with creature level
const VALUE_PER_TRAIT: int = 5           # each trait adds value
const VALUE_EVOLVED_BONUS: int = 25      # evolved creatures trade for more
const VALUE_BONDED_BONUS: int = 15       # bonded creatures carry sentimental value
const MIN_TRADE_VALUE: int = 5           # creatures below this cannot be traded
const VALUE_BALANCE_RATIO: float = 1.4   # max allowed value gap between sides of a trade
const MAX_OFFERS_PER_NPC: int = 8        # how many deals one NPC can present

## A single tradeable deal.
class TradeOffer:
    extends RefCounted
    var id: StringName = &""
    var npc_name: String = ""
    var offered_creature: Creature = null   # what the NPC gives
    var requested_creature: Creature = null # what the NPC wants
    var offered_value: int = 0
    var requested_value: int = 0
    var is_player_trade: bool = false       # true = player-to-player negotiation
    var one_time_only: bool = false         # consumable deal
    var completed: bool = false

    func _init(p_id: StringName, p_npc: String, p_offered: Creature, p_requested: Creature, p_one_time: bool = false) -> void:
        id = p_id
        npc_name = p_npc
        offered_creature = p_offered
        requested_creature = p_requested
        one_time_only = p_one_time
        offered_value = _value_of(p_offered)
        requested_value = _value_of(p_requested)

    func is_fair() -> bool:
        var higher: int = max(offered_value, requested_value)
        var lower: int = min(offered_value, requested_value)
        return higher <= int(round(lower * VALUE_BALANCE_RATIO))

    func _value_of(c: Creature) -> int:
        if c == null:
            return 0
        var v: int = VALUE_PER_LEVEL * max(c.level, 1)
        if c.has_trait(&"evolved"):
            v += VALUE_EVOLVED_BONUS
        if c.bond_level > 0:
            v += VALUE_BONDED_BONUS
        v += VALUE_PER_TRAIT * c.traits.size()
        return max(v, MIN_TRADE_VALUE)

# --- State ---
var _npc_offers: Array[TradeOffer] = []
var _completed_ids: Array[StringName] = []
var _player_inventory: Inventory = null

func set_inventory(inv: Inventory) -> void:
    _player_inventory = inv

## Register an NPC trade offer.
func add_npc_offer(offer: TradeOffer) -> void:
    if _npc_offers.size() >= MAX_OFFERS_PER_NPC:
        trade_failed.emit("NPC has reached maximum active offers")
        return
    if not offer.is_fair():
        trade_failed.emit("Offer value gap too wide — not fair trade")
        return
    _npc_offers.append(offer)
    trade_proposed.emit(offer)

## All currently available NPC offers.
func get_available_offers() -> Array[TradeOffer]:
    var result: Array[TradeOffer] = []
    for o in _npc_offers:
        if not o.completed and not _completed_ids.has(o.id):
            result.append(o)
    return result

## Validate that the player can fulfill a trade: owns the requested creature and it is tradable.
func can_fulfill(offer: TradeOffer) -> bool:
    if offer.completed:
        return false
    if _player_inventory == null:
        return false
    var target: Creature = offer.requested_creature
    if target == null:
        return true
    if not _player_inventory.has_creature(target.id):
        return false
    var owned: Creature = _player_inventory.get_creature(target.id)
    return owned != null and _value_of(owned) >= MIN_TRADE_VALUE

func _value_of(c: Creature) -> int:
    if c == null:
        return 0
    var v: int = VALUE_PER_LEVEL * max(c.level, 1)
    if c.has_trait(&"evolved"):
        v += VALUE_EVOLVED_BONUS
    if c.bond_level > 0:
        v += VALUE_BONDED_BONUS
    v += VALUE_PER_TRAIT * c.traits.size()
    return max(v, MIN_TRADE_VALUE)

## Execute the trade. Transfers creatures and persists the change.
func execute_trade(offer: TradeOffer) -> bool:
    if not can_fulfill(offer):
        trade_failed.emit("Cannot fulfill — missing or untradable creature")
        return false
    var lost: Creature = _player_inventory.get_creature(offer.requested_creature.id)
    var gained: Creature = offer.offered_creature
    # Remove the creature the player gives away.
    if lost != null:
        _player_inventory.remove_creature(lost.id)
    # Add the creature the player receives.
    if gained != null:
        _player_inventory.add_creature(gained)
    # Mark the deal done.
    offer.completed = true
    if offer.one_time_only:
        _completed_ids.append(offer.id)
    # Persist the sanctuary state.
    if CreatureSaveLoad != null:
        CreatureSaveLoad.save_sanctuary(_player_inventory.get_creatures())
    trade_completed.emit(offer, gained, lost)
    EventBus.emit_signal("creature_traded", {"gained": gained, "lost": lost})
    return true

## Propose a player-to-player trade (both sides negotiate).
func propose_player_trade(my_creature: Creature, their_creature: Creature) -> TradeOffer:
    var offer: TradeOffer = TradeOffer.new(
        StringName("player_trade_%d" % my_creature.id),
        "Player Trade",
        their_creature,
        my_creature,
        false
    )
    offer.is_player_trade = true
    if not offer.is_fair():
        trade_failed.emit("Player trade value gap too wide — renegotiate")
        return null
    trade_proposed.emit(offer)
    return offer

func reset_completed() -> void:
    _completed_ids.clear()
    for o in _npc_offers:
        o.completed = false
        o.one_time_only = false
    _npc_offers.clear()