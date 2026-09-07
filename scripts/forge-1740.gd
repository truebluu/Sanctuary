class_name GeneticTraitInheritance
extends RefCounted

# Inheritance tunables — change one number to retune genetics.
const BLEND_FACTOR: float = 0.55        # how much offspring inherits from each parent
const MUTATION_CHANCE: float = 0.12     # per-stat chance of a random mutation
const MUTATION_STDDEV: float = 0.10     # spread of a mutation
const STAT_MAX: int = 9999              # hard cap on any single stat
const STAT_MIN: int = 1                 # floor
const TRAIT_ALLELE_DOMINANCE: float = 0.6 # dominance weight in allele blend

var _rng: RandomNumberGenerator

func _init() -> void:
    _rng = RandomNumberGenerator.new()
    _rng.randomize()

# Compute offspring stat from two parents. Each stat blends toward the higher
# parent, then mutates. Returns a Dictionary of stat -> int.
func inherit_stats(parent_a: Dictionary, parent_b: Dictionary) -> Dictionary:
    var offspring: Dictionary = {}
    for key in parent_a.keys():
        var a: int = int(parent_a[key])
        var b: int = int(parent_b.get(key, a))
        var blend: float = BLEND_FACTOR
        # Higher parent pulls the blend toward it.
        if a > b:
            blend = 1.0 - BLEND_FACTOR * (float(b) / float(a))
        elif b > a:
            blend = BLEND_FACTOR * (float(a) / float(b))
        var blended: int = int(round(a * (1.0 - blend) + b * blend))
        blended = _clamp_stat(blended)
        # Mutation.
        if _rng.randf() < MUTATION_CHANCE:
            var delta: float = _rng.gauss(0.0, MUTATION_STDDEV)
            blended = int(round(blended * (1.0 + delta)))
            blended = _clamp_stat(blended)
        offspring[key] = blended
    return offspring

# Trait alleles: each trait has two alleles (dominant/recessive). Offspring
# inherits a random allele from each parent, then expresses the dominant.
func inherit_trait(allele_a: String, allele_b: String) -> String:
    var dominant: String = allele_a if _rng.randf() < TRAIT_ALLELE_DOMINANCE else allele_b
    var recessive: String = allele_b if dominant == allele_a else allele_a
    # 25% chance of a mutation to a brand-new trait name.
    if _rng.randf() < 0.25:
        return _rng.pick(["spiky", "glowing", "camouflaged", "nocturnal", "social"])
    return dominant

func _clamp_stat(value: int) -> int:
    return clamp(value, STAT_MIN, STAT_MAX)

# Register a trait expression event for analytics / UI.
func emit_trait_expression(creature_id: String, stats: Dictionary) -> void:
    EventBus.emit("CreatureTraitExpression", creature_id, stats)