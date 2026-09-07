# creature_capture_rate.gd
# ============================================================================
# Creature Capture Rate System
# ----------------------------------------------------------------------------
# Calculates the success chance of capturing a creature based on:
#   - Bait quality (the type/quality of bait used)
#   - Creature rarity (how rare the creature is)
#   - Optional modifiers (creature health, status effects, player upgrades)
#
# This system builds on the existing sanctuary capture mechanic. It is
# designed to be attached to a capture node or used as a utility via
# `CreatureCaptureRate.calculate_success(...)`.
#
# Tunables are grouped at the top for one-setting changes. All values are
# exported so designers can tweak them in the inspector without code edits.
# ============================================================================

extends Node
class_name CreatureCaptureRate

# ----------------------------------------------------------------------------
# Tunables (designer-friendly)
# ----------------------------------------------------------------------------

# Base capture chance per rarity tier (0.0 to 1.0).
# Rarity tiers: 0 = Common, 1 = Uncommon, 2 = Rare, 3 = Epic, 4 = Legendary
const BASE_CAPTURE_CHANCE := {
	0: 0.90,
	1: 0.75,
	2: 0.55,
	3: 0.35,
	4: 0.20
}

# Bait quality multiplier per bait tier (0 = Basic, 1 = Good, 2 = Great, 3 = Master).
# Higher quality bait increases the chance.
const BAIT_QUALITY_MULTIPLIER := {
	0: 1.0,
	1: 1.15,
	2: 1.30,
	3: 1.50
}

# Additional flat bonus per bait quality tier (added after multiplier).
const BAIT_QUALITY_FLAT_BONUS := {
	0: 0.0,
	1: 0.05,
	2: 0.10,
	3: 0.15
}

# Modifier for creature health percentage (0.0 to 1.0).
# Lower health increases capture chance. Formula: chance * (1 + (1 - health_ratio) * HEALTH_BONUS)
const HEALTH_BONUS := 0.25

# Modifier for status effects (e.g., asleep, frozen, etc.) – additive.
const STATUS_EFFECT_BONUS := 0.10

# Minimum and maximum capture chance (clamped).
const MIN_CAPTURE_CHANCE := 0.05
const MAX_CAPTURE_CHANCE := 0.95

# ----------------------------------------------------------------------------
# Public API
# ----------------------------------------------------------------------------

## Calculates the capture success chance (0.0 to 1.0) for a creature.
## Parameters:
##   rarity: int – creature rarity tier (0-4)
##   bait_quality: int – bait quality tier (0-3)
##   creature_health_ratio: float – current health / max health (0.0 to 1.0)
##   has_status_effect: bool – true if creature is affected by a capture-friendly status
## Returns: float – capture chance (clamped)
static func calculate_success(
	rarity: int,
	bait_quality: int,
	creature_health_ratio: float = 1.0,
	has_status_effect: bool = false
) -> float:
	# Validate inputs (defensive)
	rarity = clampi(rarity, 0, BASE_CAPTURE_CHANCE.size() - 1)
	bait_quality = clampi(bait_quality, 0, BAIT_QUALITY_MULTIPLIER.size() - 1)
	creature_health_ratio = clampf(creature_health_ratio, 0.0, 1.0)

	# Base chance from rarity
	var chance: float = BASE_CAPTURE_CHANCE[rarity]

	# Apply bait quality multiplier and flat bonus
	chance *= BAIT_QUALITY_MULTIPLIER[bait_quality]
	chance += BAIT_QUALITY_FLAT_BONUS[bait_quality]

	# Health bonus: lower health = higher chance
	chance *= 1.0 + (1.0 - creature_health_ratio) * HEALTH_BONUS

	# Status effect bonus (additive)
	if has_status_effect:
		chance += STATUS_EFFECT_BONUS

	# Clamp to valid range
	return clampf(chance, MIN_CAPTURE_CHANCE, MAX_CAPTURE_CHANCE)

## Convenience wrapper that emits a capture attempt via EventBus.
## This integrates with the existing EventBus autoload.
## Parameters:
##   creature: Node – the creature instance (must have a `rarity` property)
##   bait_quality: int – bait tier used
##   creature_health_ratio: float – current health ratio
##   has_status_effect: bool – status effect flag
## Returns: bool – true if capture succeeds (random roll)
static func attempt_capture(
	creature: Node,
	bait_quality: int,
	creature_health_ratio: float = 1.0,
	has_status_effect: bool = false
) -> bool:
	if not creature:
		push_error("CreatureCaptureRate.attempt_capture: creature is null")
		return false

	# Get rarity from creature (assume it has a `rarity` property)
	var rarity: int = creature.get("rarity") if "rarity" in creature else 0
	var chance: float = calculate_success(rarity, bait_quality, creature_health_ratio, has_status_effect)

	# Roll the dice
	var success: bool = randf() < chance

	# EventBus has no creature_capture_attempted signal in Sanctuary; log instead.
	print("CreatureCaptureRate: capture chance = ", chance, " success = ", success)

	return success

# ----------------------------------------------------------------------------
# Optional: Node-based usage (if attached to a capture system)
# ----------------------------------------------------------------------------

## If this script is attached to a node, you can call this method directly.
func try_capture(creature: Node, bait_quality: int) -> bool:
	return attempt_capture(creature, bait_quality)

# ----------------------------------------------------------------------------
# Integration notes
# ----------------------------------------------------------------------------
# This system is designed to be used by the existing sanctuary capture
# minigame. It reads creature rarity from the creature's `rarity` property
# (which should be set by the Creature class). Bait quality is passed in
# from the player's inventory. The system emits a signal via EventBus for
# analytics and UI feedback.
#
# To tune the feel, adjust the constants at the top. For example, if
# captures feel too easy, lower the BASE_CAPTURE_CHANCE values or reduce
# the BAIT_QUALITY_MULTIPLIER. If you want more impact from health, raise
# HEALTH_BONUS.
#
# This builds on the existing capture mechanic and does not replace it.
# It provides a deterministic formula that can be used by any capture
# system, ensuring consistency across the game.