# trait_inheritance.gd
# Creature trait inheritance: offspring inherit traits from parents with mutation chance.
# Builds on the canonical CreatureGenome system (Mendelian inheritance via diploid loci).
#
# REUSE-FIRST FIX (2026-09-07): the previous hand-rolled trait loop called
# CreatureGenome.get_trait()/set_traits(), which do NOT exist (only static
# get_trait_names()), producing a guaranteed runtime crash on the "Inherit Traits"
# button. CreatureGenome.breed() already implements the real trait inheritance
# (one random allele per parent per locus + mutation). This class is now a thin
# factory facade over that canonical API so the button wiring keeps working.

class_name TraitInheritance
extends RefCounted

# Inherit traits from two parents, producing a child genome.
# parent_a, parent_b: CreatureGenome instances.
# mutation_chance: override default mutation chance (0.0 to 1.0); maps to
#   CreatureGenome.breed()'s mutation_rate.
# Returns a new CreatureGenome with combined traits (or null if parents invalid).
static func inherit_traits(parent_a: CreatureGenome, parent_b: CreatureGenome, mutation_chance: float = 0.1) -> CreatureGenome:
	if parent_a == null or parent_b == null:
		push_error("TraitInheritance: Both parents must be non-null.")
		return null
	# Delegate to the canonical Mendelian breeder (real diploid loci + mutation).
	return CreatureGenome.breed(parent_a, parent_b, mutation_chance)
