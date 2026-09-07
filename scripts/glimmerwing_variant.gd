# Glimmerwing Variant — Taming (The Sanctuary)
# Rare creature variant class modeling a rare Glimmerwing with spawn gating,
# stat modifiers, spawn signal, and visual shimmer description.
class_name Glimmerwing
extends RefCounted

signal on_spawned(variant_data: Dictionary)

## Spawn configuration
@export var spawn_chance: float = 0.02  # 2% base spawn chance
@export var reputation_threshold: int = 300  # Requires "Friend" tier (300 XP)

## Stat modifiers applied to CreatureNeeds when this variant is active
@export var shimmer_aura_intensity: float = 0.8
@export var bonus_trust_on_feed: float = 0.15  # Extra trust gained when feeding
@export var hunger_decay_reduction: float = 0.30  # 30% less hunger decay
@export var energy_recovery_bonus: float = 0.20  # 20% faster energy recovery

## Internal state
var _is_spawned: bool = false
var _creature_needs: CreatureNeeds = null
var _reputation: Reputation = null
var _rng: RandomNumberGenerator
var _spawn_metadata: Dictionary

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_spawn_metadata = {
		"variant_name": "Glimmerwing",
		"spawn_chance": spawn_chance,
		"reputation_threshold": reputation_threshold,
		"shimmer_aura_intensity": shimmer_aura_intensity,
		"bonus_trust_on_feed": bonus_trust_on_feed,
		"hunger_decay_reduction": hunger_decay_reduction,
		"energy_recovery_bonus": energy_recovery_bonus,
		"spawned_at": Time.get_unix_time_from_system(),
	}

## Attempt to spawn this variant given a Reputation instance.
## Returns true if spawn succeeded (rarity gates cleared), false otherwise.
func try_spawn(p_reputation: Reputation = null, p_creature_needs: CreatureNeeds = null, force: bool = false) -> bool:
	if _is_spawned:
		return false

	_reputation = p_reputation
	_creature_needs = p_creature_needs

	# Gate 1: Random chance
	var rolled: float = _rng.randf()
	if not force and rolled >= spawn_chance:
		return false

	# Gate 2: Reputation threshold
	if _reputation != null and is_instance_valid(_reputation):
		var current_xp: int = _reputation.get_xp()
		if current_xp < reputation_threshold:
			return false

	# Spawn successful
	_is_spawned = true
	_apply_stat_modifiers()
	on_spawned.emit(_spawn_metadata.duplicate())
	return true

## Force spawn (skip rarity gates) for testing or special events
func force_spawn(p_reputation: Reputation = null, p_creature_needs: CreatureNeeds = null) -> bool:
	return try_spawn(p_reputation, p_creature_needs, true)

## Apply stat modifiers to the linked CreatureNeeds
func _apply_stat_modifiers() -> void:
	if _creature_needs == null or not is_instance_valid(_creature_needs):
		return

	# Reduce hunger decay rate
	if _creature_needs.decay_rate.has(&"hunger"):
		var current_hunger_decay: float = float(_creature_needs.decay_rate[&"hunger"])
		_creature_needs.decay_rate[&"hunger"] = current_hunger_decay * (1.0 - hunger_decay_reduction)

	# Store original feed method reference for bonus trust
	# We'll hook into the feed action via a wrapper if needed
	# For now, the bonus is applied externally when feed() is called via apply_feed_bonus()

## Call this when the creature is fed to apply the bonus trust gain
## Returns the total trust gained (base + bonus)
func apply_feed_bonus() -> float:
	if not _is_spawned:
		return 0.0

	if _creature_needs != null and is_instance_valid(_creature_needs):
		_creature_needs.gain_trust(bonus_trust_on_feed)
		return bonus_trust_on_feed
	return 0.0

## Call this when the creature rests to apply energy recovery bonus
func apply_rest_bonus() -> float:
	if not _is_spawned:
		return 0.0

	if _creature_needs != null and is_instance_valid(_creature_needs):
		var current_energy: float = _creature_needs.get_energy()
		var bonus_amount: float = energy_recovery_bonus * 0.5  # Scale with base rest amount
		_creature_needs.set_energy(clampf(current_energy + bonus_amount, 0.0, 1.0))
		return bonus_amount
	return 0.0

## Get the current spawn metadata
func get_spawn_metadata() -> Dictionary:
	return _spawn_metadata.duplicate()

## Check if this variant is currently active/spawned
func is_spawned() -> bool:
	return _is_spawned

## Get a visual shimmer description for UI/tooltip rendering
func get_shimmer_description() -> String:
	if not _is_spawned:
		return "Glimmerwing: Dormant (not spawned)"

	var lines: Array[String] = []
	lines.append("✨ G L I M M E R W I N G ✨")
	lines.append("A rare variant shimmering with ethereal light.")
	lines.append("")
	lines.append("Spawn Conditions:")
	lines.append("  • Base chance: %d%%" % int(spawn_chance * 100))
	lines.append("  • Reputation: %s (%d+ XP)" % [_tier_name_from_xp(reputation_threshold), reputation_threshold])
	lines.append("")
	lines.append("Active Modifiers:")
	lines.append("  • Shimmer Aura: %.0f%% intensity" % (shimmer_aura_intensity * 100))
	lines.append("  • Bonus Trust on Feed: +%.0f%%" % (bonus_trust_on_feed * 100))
	lines.append("  • Hunger Decay Reduced: %.0f%%" % (hunger_decay_reduction * 100))
	lines.append("  • Energy Recovery Bonus: +%.0f%%" % (energy_recovery_bonus * 100))
	lines.append("")
	lines.append("Visual: Wings trail prismatic particles; body emits soft pulse.")
	lines.append("Sound: Faint chime on interaction.")
	return "\n".join(lines)

## Get a compact one-line shimmer summary for HUD/tooltip
func get_shimmer_summary() -> String:
	if not _is_spawned:
		return "Glimmerwing (dormant)"
	return "✨ Glimmerwing: Trust+%.0f%% Hunger-%.0f%% Energy+%.0f%%" % [
		bonus_trust_on_feed * 100,
		hunger_decay_reduction * 100,
		energy_recovery_bonus * 100
	]

## Internal helper: map XP threshold to tier name (mirrors Reputation.TIER_ORDER)
func _tier_name_from_xp(xp: int) -> String:
	if xp >= 1500: return "Cherished"
	if xp >= 700: return "Trusted"
	if xp >= 300: return "Friend"
	if xp >= 100: return "Acquaintance"
	return "Stranger"

## Reset variant state (for testing / re-use)
func reset() -> void:
	_is_spawned = false
	_creature_needs = null
	_reputation = null
	_rng.randomize()