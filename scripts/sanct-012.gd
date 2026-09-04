# CreatureFriendship.gd
# Adds a friendship level system to creatures, unlocking abilities and evolution paths.
# Builds on existing CreatureBonding and CreatureNeeds systems.
# Feel: Rewards consistent care with tangible progression, deepening the sanctuary loop.

extends Node
class_name CreatureFriendship

## Tunables (one-place changes)
const DEFAULT_MAX_FRIENDSHIP := 100
const DEFAULT_TIER_THRESHOLDS := [0, 20, 50, 80, 100]  # Tier 0 at 0, Tier 1 at 20, etc.
const DEFAULT_GAIN_FEED := 5
const DEFAULT_GAIN_PLAY := 3
const DEFAULT_GAIN_PET := 2
const DEFAULT_LOSS_NEGLECT := -1  # Applied when needs are critically low

## Exported tunables (overridable per creature)
@export var max_friendship: int = DEFAULT_MAX_FRIENDSHIP
@export var tier_thresholds: Array[int] = DEFAULT_TIER_THRESHOLDS
@export var gain_feed: int = DEFAULT_GAIN_FEED
@export var gain_play: int = DEFAULT_GAIN_PLAY
@export var gain_pet: int = DEFAULT_GAIN_PET
@export var loss_neglect: int = DEFAULT_LOSS_NEGLECT

## Ability unlocks per tier (tier index -> array of ability IDs)
@export var abilities_by_tier: Dictionary = {
	1: ["playful_animation"],
	2: ["special_dialogue"],
	3: ["assist_in_minigame"],
	4: ["rare_evolution_hint"]
}

## Evolution paths unlocked per tier (tier index -> array of path IDs)
@export var evolution_paths_by_tier: Dictionary = {
	3: ["friendship_evolution_1"],
	4: ["friendship_evolution_2"]
}

## Current state
var current_friendship: int = 0
var current_tier: int = 0

## Signals
signal friendship_changed(current: int, max: int)
signal tier_changed(new_tier: int, old_tier: int)
signal ability_unlocked(ability_id: String)
signal evolution_path_unlocked(path_id: String)

func _ready() -> void:
	# Validate tier thresholds
	if tier_thresholds.is_empty():
		tier_thresholds = DEFAULT_TIER_THRESHOLDS
	# Ensure thresholds are sorted and start at 0
	tier_thresholds.sort()
	if tier_thresholds[0] != 0:
		tier_thresholds.insert(0, 0)
	# Initialize tier
	_update_tier()

## Add friendship points (e.g., from feeding, playing, petting)
func add_friendship(amount: int, source: String = "") -> void:
	if amount == 0:
		return
	var old_value := current_friendship
	current_friendship = clampi(current_friendship + amount, 0, max_friendship)
	if current_friendship != old_value:
		friendship_changed.emit(current_friendship, max_friendship)
		_update_tier()
	# Optional: log source for analytics (if needed)

## Remove friendship points (e.g., neglect, negative events)
func remove_friendship(amount: int, source: String = "") -> void:
	add_friendship(-amount, source)

## Called when creature is fed
func on_fed() -> void:
	add_friendship(gain_feed, "feed")

## Called when creature is played with
func on_played() -> void:
	add_friendship(gain_play, "play")

## Called when creature is petted
func on_petted() -> void:
	add_friendship(gain_pet, "pet")

## Called when creature's needs are critically low (neglect)
func on_neglect() -> void:
	add_friendship(loss_neglect, "neglect")

## Get current tier index (0-based)
func get_tier() -> int:
	return current_tier

## Get progress toward next tier (0.0 to 1.0)
func get_tier_progress() -> float:
	if current_tier >= tier_thresholds.size() - 1:
		return 1.0
	var current_threshold := tier_thresholds[current_tier]
	var next_threshold := tier_thresholds[current_tier + 1]
	var range_size := next_threshold - current_threshold
	if range_size <= 0:
		return 1.0
	return float(current_friendship - current_threshold) / float(range_size)

## Check if at max tier
func is_max_tier() -> bool:
	return current_tier >= tier_thresholds.size() - 1

## Get the friendship value needed for the next tier (or -1 if max)
func get_next_tier_threshold() -> int:
	if is_max_tier():
		return -1
	return tier_thresholds[current_tier + 1]

## Internal: update tier and emit signals if changed
func _update_tier() -> void:
	var new_tier := 0
	for i in range(tier_thresholds.size()):
		if current_friendship >= tier_thresholds[i]:
			new_tier = i
		else:
			break
	if new_tier != current_tier:
		var old_tier := current_tier
		current_tier = new_tier
		tier_changed.emit(new_tier, old_tier)
		_unlock_tier_content(new_tier)

## Unlock abilities and evolution paths for a newly reached tier
func _unlock_tier_content(tier: int) -> void:
	# Unlock abilities
	if abilities_by_tier.has(tier):
		for ability_id in abilities_by_tier[tier]:
			ability_unlocked.emit(ability_id)
	# Unlock evolution paths
	if evolution_paths_by_tier.has(tier):
		for path_id in evolution_paths_by_tier[tier]:
			evolution_path_unlocked.emit(path_id)

## Save/load support (optional, integrate with existing save system)
func to_dict() -> Dictionary:
	return {
		"current_friendship": current_friendship,
		"current_tier": current_tier
	}

func from_dict(data: Dictionary) -> void:
	if data.has("current_friendship"):
		current_friendship = clampi(data["current_friendship"], 0, max_friendship)
		_update_tier()