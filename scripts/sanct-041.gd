extends Object
class_name CreatureTraitInheritance

# Tunable constants – single source of truth for designer tweaks.
const MAX_TRAITS: int = 10
const DEFAULT_MUTATION_CHANCE: float = 0.05
const MUTATION_STRENGTH: float = 0.2

@export var mutation_chance: float = DEFAULT_MUTATION_CHANCE
@export var max_offspring_per_pair: int = 2

# Use the globally registered EventBus to broadcast inheritance events.
signal traits_inherited offspring_traits, parent_a_traits, parent_b_traits

# Internal helper – safely clones a dictionary to avoid reference side‑effects.
static func _clone_traits(traits: Dictionary) -> Dictionary:
    var copy: Dictionary = {}
    for key, value in traits.entries():
        copy[key] = value
    return copy

# Core function: compute offspring trait values from two parent trait dictionaries.
# Builds on the existing Creature trait system and BreedingManager.
static func inherit_traits(parent_a_traits: Dictionary, parent_b_traits: Dictionary) -> Dictionary:
    var offspring: Dictionary = {}

    # Union of all trait keys present in either parent.
    var all_keys: Array = parent_a_traits.keys() + parent_b_traits.keys()
    for key in all_keys:
        var val_a: Variant = parent_a_traits.get(key, 0)
        var val_b: Variant = parent_b_traits.get(key, 0)

        # Simple average blending.
        var blended: float = (val_a + val_b) / 2.0

        # Apply mutation if random chance rolls.
        if randf() < mutation_chance:
            var offset: float = (randf() * 2.0 - 1.0) * MUTATION_STRENGTH
            blended += offset

        # Clamp numeric traits to [0, 1] to keep them sane.
        blended = blended.clamp(0.0, 1.0)

        offspring[key] = blended

    # Emit a signal so UI, analytics, or other systems can react.
    EventBus.emit_signal("traits_inherited", offspring, parent_a_traits, parent_b_traits)
    # Also emit our own signal for any listeners attached to this class.
    emit_signal("traits_inherited", offspring, parent_a_traits, parent_b_traits)

    return offspring

# Feel: adds genetic variation that forces players to adapt their strategy each wave,
# building on the existing Creature trait system and BreedingManager.