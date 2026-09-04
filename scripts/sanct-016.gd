# trait_inheritance.gd
# Creature trait inheritance: offspring inherit traits from parents with mutation chance.
# Builds on BreedingGeneticsManager and CreatureGenome. Adds genetic variety to breeding,
# making each offspring unique and encouraging diverse pairings.
# Feel: adds depth to sanctuary breeding, rewarding experimentation with different parent pairs.

class_name TraitInheritance
extends RefCounted

# Tunables (one place to adjust)
const DEFAULT_MUTATION_CHANCE := 0.1  # Base chance per trait to mutate
const MUTATION_RANGE := 0.2          # How far a mutated trait can deviate from parent value (for numeric traits)
const TRAIT_KEYS := ["color", "size", "speed", "aggression"]  # Example trait keys; adjust to actual CreatureGenome traits

# Inherit traits from two parents, producing a child genome.
# parent_a, parent_b: CreatureGenome instances.
# mutation_chance: override default mutation chance (0.0 to 1.0).
# Returns a new CreatureGenome with combined traits.
static func inherit_traits(parent_a: CreatureGenome, parent_b: CreatureGenome, mutation_chance: float = DEFAULT_MUTATION_CHANCE) -> CreatureGenome:
	if parent_a == null or parent_b == null:
		push_error("TraitInheritance: Both parents must be non-null.")
		return null

	var child_traits := {}
	for trait_key in TRAIT_KEYS:
		# Choose which parent contributes the base trait (50/50)
		var source_parent: CreatureGenome = parent_a if randf() < 0.5 else parent_b
		var base_value = source_parent.get_trait(trait_key)
		if base_value == null:
			# Trait not present in source; skip or use default
			continue

		# Apply mutation chance
		if randf() < mutation_chance:
			base_value = _mutate_trait(trait_key, base_value)

		child_traits[trait_key] = base_value

	# Create a new CreatureGenome with the combined traits.
	# Assuming CreatureGenome has a constructor that accepts a dictionary of traits.
	var child_genome = CreatureGenome.new()
	child_genome.set_traits(child_traits)
	return child_genome

# Mutate a single trait value.
# For numeric traits, add a random offset within MUTATION_RANGE.
# For string/enum traits, pick a random alternative from a predefined set (if available).
static func _mutate_trait(trait_key: String, value) -> Variant:
	match trait_key:
		"color":
			# Example: pick a random color from a palette (adjust to actual game data)
			const COLORS := ["red", "green", "blue", "yellow", "purple"]
			return COLORS[randi() % COLORS.size()]
		"size", "speed", "aggression":
			# Numeric traits: add a random offset within range
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				var offset = randf_range(-MUTATION_RANGE, MUTATION_RANGE)
				return value + offset
			else:
				# Fallback: return unchanged if not numeric
				return value
		_:
			# Unknown trait: return unchanged
			return value