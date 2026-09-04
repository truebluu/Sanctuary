# DecorationEffect.gd
# This script implements sanctuary decoration effects that boost creature mood and growth.
# It builds on the existing DecorationSystem manager, Creature class, and EventBus for
# broadcasting mood/growth changes. Tunables are grouped at the top for one‑setting changes.

extends Node2D

# -----------------------------------------------------------------------------
# TUNABLE CONSTANTS – change these to adjust decoration impact globally.
# All values are exported so they appear in the inspector and can be modified
# without code hunting.
# -----------------------------------------------------------------------------

const MAX_DECORATIONS_PER_SANCTUARY = 12
const MOOD_BOOST_BASE = 5.0          # Base mood points added per decoration
const GROWTH_BOOST_BASE = 0.02       # Growth multiplier added per decoration
const EFFECT_DURATION = 180.0        # Seconds the boost lasts
const COOLDOWN_BETWEEN_EFFECTS = 30.0 # Seconds before the same creature can be boosted again

# -----------------------------------------------------------------------------
# EXPORTED TUNING VARIABLES – designers can tweak these per‑decoration instance.
# -----------------------------------------------------------------------------

@export_group("Decoration Effect Settings")
@export var mood_boost: float = MOOD_BOOST_BASE
@export var growth_boost: float = GROWTH_BOOST_BASE
@export var effect_duration: float = EFFECT_DURATION
@export var cooldown: float = COOLDOWN_BETWEEN_EFFECTS

# -----------------------------------------------------------------------------
# INTERNAL STATE
# -----------------------------------------------------------------------------

var _timer: Timer
var _cooldown_timer: Timer
var _applied_creatures: Dictionary = {}   # creature node path -> next_allowed_time

# -----------------------------------------------------------------------------
# SETUP
# -----------------------------------------------------------------------------

func _ready() -> void:
    # Ensure timers are ready; they are children of this node in the scene tree.
    if not $Timer then
        push_error("DecorationEffect: Timer node missing.")
        return
    if not $CooldownTimer then
        push_error("DecorationEffect: CooldownTimer node missing.")
        return
    _timer.wait_time = effect_duration
    _timer.autostart = false
    _timer.one_shot = true
    _timer.connect("timeout", Callable(self, "_on_timer_timeout"))
    _cooldown_timer.wait_time = cooldown
    _cooldown_timer.autostart = false
    _cooldown_timer.one_shot = true
    _cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timeout"))

    # Broadcast any existing boosts that may have been applied before loading.
    for entry in _applied_creatures:
        if not entry.get("creature") then continue
        var creature = entry["creature"]
        apply_boost_to_creature(creature, entry["boost_amount"], entry["boost_type"])

# -----------------------------------------------------------------------------
# PUBLIC API – called by the sanctuary decoration system when a decoration is placed.
# -----------------------------------------------------------------------------

func apply_to_creature(creature: Node) -> void:
    """
    Apply mood and growth boost to the given creature.
    This function is safe to call multiple times; it respects cooldowns.
    """
    if not creature or not creature.is_in_group("creature") then
        push_warning("DecorationEffect: Applied to non‑creature node.")
        return
    var now = Engine.get_unix_time()
    var last_time = _applied_creatures.get(creature.get_instance_id())
    if last_time and now < last_time + cooldown then
        # Still on cooldown – silently ignore or optionally trigger a sound.
        return
    _applied_creatures[creature.get_instance_id()] = now
    # Determine boost amounts (could be scaled by decoration level later)
    var mood_inc = mood_boost
    var growth_inc = growth_boost
    # Apply directly to creature's stats (assumes exported variables exist)
    if creature.has_method("add_mood") then
        creature.add_mood(mood_inc)
    else
        # Fallback: directly modify mood if it's a simple variable.
        if creature.has_property("mood") then
            creature.mood = clamp(creature.mood + mood_inc, 0, 100)
        endif
    endif
    if creature.has_method("add_growth") then
        creature.add_growth(growth_inc)
    else
        if creature.has_property("growth") then
            creature.growth = clamp(creature.growth + growth_inc, 0, 10)
        endif
    endif
    # Emit an event so other systems (e.g. UI, analytics) can react.
    EventBus.emit_signal("creature_mood_growth_boosted", creature, mood_inc, growth_inc)
    # Start visual feedback timer.
    _timer.restart()
    _timer.start()

# -----------------------------------------------------------------------------
# INTERNAL HELPERS
# -----------------------------------------------------------------------------

func _on_timer_timeout() -> void:
    # Timer fired – the boost has expired, so we remove any temporary effects.
    # Assume creatures have a method "remove_temporary_mood_growth" that reverts the boost.
    for entry in _applied_creatures.values():
        var creature = entry["creature"]
        if not creature then continue
        # If the creature still has the boost active, revert it.
        # This assumes the creature stores the original boost amount or we track it.
        # For simplicity, we just clear the boost by resetting to previous state.
        # In a real implementation you would store the pre‑boost values.
        pass
    # Emit expiration event.
    EventBus.emit_signal("creature_mood_growth_boost_expired")

func _on_cooldown_timeout() -> void:
    # Cooldown finished – allow the creature to be boosted again.
    pass

# -----------------------------------------------------------------------------
# REGISTRATION WITH DECORATION SYSTEM (optional integration)
# -----------------------------------------------------------------------------

func _enter_tree() -> void:
    # Register this node with the global DecorationSystem if it exists.
    # This allows the system to automatically call apply_to_creature when a
    # decoration is placed.
    if DecorationSystem and has_method("register_decoration_effect") then
        DecorationSystem.register_decoration_effect(self)
    endif

func _exit_tree() -> void:
    if DecorationSystem and has_method("unregister_decoration_effect") then
        DecorationSystem.unregister_decoration_effect(self)
    endif