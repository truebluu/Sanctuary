# Reputation — Taming (The Sanctuary)
# SANCT-732: Sanctuary Reputation system. Pure logic (RefCounted) implementing
# tiered reputation with XP-based progression, per-tier perks, daily decay,
# signals, and save/load. No scene-tree dependencies; headlessly testable.
# Integrates with: Pet system (genetics.gd, pet.gd), BuildingSystem (building_system.gd),
# Inventory (inventory.gd), SeasonalCycle (seasonal_cycle.gd) via event bus or direct calls.
class_name Reputation
extends RefCounted

signal reputation_changed(old_tier: String, new_tier: String, xp: int, tier_xp: int)
signal tier_reached(tier: String, xp: int)
signal perk_unlocked(perk_name: String, tier: String)

## Reputation tiers in ascending order. Thresholds are cumulative XP required to reach each tier.
const TIER_ORDER := ["Stranger", "Acquaintance", "Friend", "Trusted", "Cherished"]
const TIER_THRESHOLDS := {
	"Stranger": 0,
	"Acquaintance": 100,
	"Friend": 300,
	"Trusted": 700,
	"Cherished": 1500,
}

## Per-tier perk table. A perk is unlocked when the current tier >= the tier it belongs to.
## Format: perk_name -> { "tier": tier_name, "description": "..." }
const PERKS := {
	"pet_greeting": {"tier": "Acquaintance", "description": "Pets greet you when you enter the sanctuary"},
	"extra_treat_slot": {"tier": "Friend", "description": "Unlock an additional treat slot in the feeding UI"},
	"trusted_discount": {"tier": "Trusted", "description": "Receive 10% discount on sanctuary upgrades"},
	"cherished_gift": {"tier": "Cherished", "description": "Receive a unique weekly gift from your pets"},
	"breeding_priority": {"tier": "Trusted", "description": "Priority access to breeding slots"},
	"exclusive_toys": {"tier": "Cherished", "description": "Unlock exclusive toy variants for pets"},
}

## Daily XP decay when idle (no XP gained). Applied once per day via apply_daily_decay().
@export var daily_decay_amount: int = 10
## Minimum XP floor — decay never drops XP below this.
@export var decay_floor: int = 0
## Multiplier applied to all XP gains (for events, boosts, etc.)
@export var xp_multiplier: float = 1.0

var _xp: int = 0
var _last_tier: String = "Stranger"

func _init() -> void:
	_last_tier = _tier_from_xp(_xp)

## Add XP and emit reputation_changed if tier changes.
## Returns the new tier name (may be unchanged).
func add_xp(amount: int) -> String:
	if amount <= 0:
		return get_tier()
	var gained: int = int(float(amount) * xp_multiplier)
	var old_tier: String = _last_tier
	var old_xp: int = _xp
	_xp = max(0, _xp + gained)
	var new_tier: String = _tier_from_xp(_xp)
	_last_tier = new_tier
	if new_tier != old_tier:
		reputation_changed.emit(old_tier, new_tier, _xp, TIER_THRESHOLDS[new_tier])
		tier_reached.emit(new_tier, _xp)
		# Emit perk_unlocked for any newly unlocked perks
		for name in PERKS.keys():
			var perk = PERKS[name]
			var required_tier: String = perk["tier"]
			var required_idx: int = TIER_ORDER.find(required_tier)
			var old_idx: int = TIER_ORDER.find(old_tier)
			if required_idx <= TIER_ORDER.find(new_tier) and required_idx > old_idx:
				perk_unlocked.emit(name, new_tier)
	return new_tier

## Get current total XP.
func get_xp() -> int:
	return _xp

## Get current reputation tier name.
func get_tier() -> String:
	return _last_tier

## Get XP required for the next tier (0 if at max tier).
func get_xp_to_next_tier() -> int:
	var current_tier: String = get_tier()
	var idx: int = TIER_ORDER.find(current_tier)
	if idx == -1 or idx >= TIER_ORDER.size() - 1:
		return 0
	var next_tier: String = TIER_ORDER[idx + 1]
	return max(0, TIER_THRESHOLDS[next_tier] - _xp)

## Get XP threshold for a specific tier.
func get_tier_threshold(tier: String) -> int:
	return TIER_THRESHOLDS.get(tier, 0)

## Check if a perk is unlocked at the current tier.
func is_perk_unlocked(perk_name: String) -> bool:
	var perk = PERKS.get(perk_name)
	if not perk:
		return false
	var required_tier: String = perk["tier"]
	var current_idx: int = TIER_ORDER.find(get_tier())
	var required_idx: int = TIER_ORDER.find(required_tier)
	return current_idx >= required_idx

## Get all perk names unlocked at the current tier.
func get_unlocked_perks() -> Array[String]:
	var out := []
	for name in PERKS.keys():
		if is_perk_unlocked(name):
			out.append(name)
	return out

## Get all perks with their unlock status for the current tier.
func get_perk_status() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for name in PERKS.keys():
		var p: Dictionary = PERKS[name].duplicate()
		p["name"] = name
		p["unlocked"] = is_perk_unlocked(name)
		out.append(p)
	return out

## Apply daily decay to idle XP. Call once per in-game day.
## Returns true if XP changed, false if already at floor.
func apply_daily_decay() -> bool:
	if _xp <= decay_floor:
		return false
	var old_tier: String = _last_tier
	var old_xp: int = _xp
	_xp = max(decay_floor, _xp - daily_decay_amount)
	var new_tier: String = _tier_from_xp(_xp)
	_last_tier = new_tier
	if new_tier != old_tier or _xp != old_xp:
		reputation_changed.emit(old_tier, new_tier, _xp, TIER_THRESHOLDS[new_tier])
	return _xp != old_xp

## Serialize state for save/load.
## Returns a Dictionary with all persistent data.
func get_state() -> Dictionary:
	return {
		"xp": _xp,
		"tier": _last_tier,
		"daily_decay_amount": daily_decay_amount,
		"decay_floor": decay_floor,
		"xp_multiplier": xp_multiplier,
	}

## Load state from a Dictionary (as returned by get_state()).
func set_state(data: Dictionary) -> void:
	_xp = int(data.get("xp", 0))
	_last_tier = _tier_from_xp(_xp)
	daily_decay_amount = int(data.get("daily_decay_amount", daily_decay_amount))
	decay_floor = int(data.get("decay_floor", decay_floor))
	xp_multiplier = float(data.get("xp_multiplier", xp_multiplier))
	# Optionally emit signal on load to sync UI — callers can decide.
	# reputation_changed.emit("Stranger", _last_tier, _xp, TIER_THRESHOLDS[_last_tier])

## Get the current XP multiplier.
func get_xp_multiplier() -> float:
	return xp_multiplier

## Set the XP multiplier (clamped to >= 0).
func set_xp_multiplier(mult: float) -> void:
	xp_multiplier = max(0.0, mult)

## Internal: determine tier from XP using thresholds.
func _tier_from_xp(xp: int) -> String:
	for i in range(TIER_ORDER.size() - 1, -1, -1):
		var tier: String = TIER_ORDER[i]
		if xp >= TIER_THRESHOLDS[tier]:
			return tier
	return "Stranger"

## Reset to initial state (Stranger, 0 XP).
func reset() -> void:
	_xp = 0
	_last_tier = "Stranger"