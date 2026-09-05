class_name CreatureStoryCircle
extends Node

## Creature Story Circle — shared stories grant XP bonuses to participants.
## Builds on EventBus for XP events and GameState for session tracking.

# --- Tunables (one-setting changes) ---
const MAX_CONCURRENT_STORIES: int = 8            # cap stories in one circle
const BASE_XP_PER_STORY: int = 50                # XP awarded per story shared
const STORY_COOLDOWN_SEC: float = 3.0            # min time between stories
const STORY_RARITY_WEIGHT: Dictionary = {
    "legendary": 1.0, "epic": 0.8, "rare": 0.5, "common": 0.3,
}
const STORY_XP_MULTIPLIER: float = 1.0            # scaled by difficulty profile

signal story_shared(story_id: StringName, xp_granted: int)
signal circle_completed(stories_collected: int)

var _active_stories: Array[Dictionary] = []
var _cooldown_timer: float = 0.0

func _ready() -> void:
    pass

func _process(delta: float) -> void:
    if _cooldown_timer > 0.0:
        _cooldown_timer = max(_cooldown_timer - delta, 0.0)

func can_share_story() -> bool:
    return _active_stories.size() < MAX_CONCURRENT_STORIES and _cooldown_timer <= 0.0

func share_story(story_id: StringName, rarity: String = "common") -> int:
    if not can_share_story():
        return 0
    _cooldown_timer = STORY_COOLDOWN_SEC
    var weight: float = STORY_RARITY_WEIGHT.get(rarity, 0.3)
    var xp: int = int(BASE_XP_PER_STORY * weight * STORY_XP_MULTIPLIER)
    var entry: Dictionary = {
        "id": story_id,
        "rarity": rarity,
        "xp": xp,
        "time": Time.get_ticks_msec(),
    }
    _active_stories.append(entry)
    story_shared.emit(story_id, xp)
    return xp

func clear_stories() -> void:
    _active_stories.clear()

func stories_in_circle() -> int:
    return _active_stories.size()

func total_xp_granted() -> int:
    var total: int = 0
    for entry in _active_stories:
        total += int(entry["xp"])
    return total

func is_complete() -> bool:
    return _active_stories.size() >= MAX_CONCURRENT_STORIES