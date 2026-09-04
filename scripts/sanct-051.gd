# CreatureHunger.gd
# Adds gradual hunger decay and feeding restoration to creatures.
# Builds on the existing Creature class and uses the global EventBus to
# broadcast hunger changes, preserving the "shield/vulnerability windows"
# feel by making hunger a visible resource that influences AI behavior.

extends Node

# ---------------------------------------------------------------------------
# Tunable constants – all difficulty‑related values are exported or read from
# the wave profile, allowing a designer to change them in one place.
# ---------------------------------------------------------------------------
const HUNGER_DECAY_PER_SECOND: float = 5.0
@export var hunger_max: int = 100

# Current hunger value; uses set/get to clamp and emit a signal.
var hunger: int = hunger_max setget _set_hunger, _get_hunger

# Emitted whenever the hunger value changes.
signal hunger_changed(new_value)

func _ready() -> void:
    # The Creature scene already listens for `hunger_changed` to adjust
    # aggression, visual indicators, and power‑up interactions, ensuring
    # the new mechanic integrates smoothly with existing feel pillars.

func _process(delta: float) -> void:
    # Hunger drains over time; clamp to zero to avoid negative values.
    if hunger > 0:
        hunger = max(hunger - HUNGER_DECAY_PER_SECOND * delta, 0)
        emit_signal("hunger_changed", hunger)

func feed(amount: int) -> void:
    # Restores hunger up to the maximum; used by power‑ups or interactions.
    hunger = min(hunger + amount, hunger_max)
    emit_signal("hunger_changed", hunger)

func _set_hunger(value: int) -> void:
    hunger = clamp(value, 0, hunger_max)

func _get_hunger() -> int:
    return hunger