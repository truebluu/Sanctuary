# Genetics — Taming (The Sanctuary)
# SANCT-001 "Design pet genetics/inheritance system" + SANCT-186 "Breeding &
# genetics blend". A pure-logic (RefCounted) engine implementing Mendelian
# inheritance over diploid loci:
#
#   - A PetGenome is a set of traits, each a diploid locus carrying two alleles.
#   - Each allele has a dominance rank. The expressed PHENOTYPE is the allele
#     with the highest dominance at that locus (ties broken toward a random one).
#   - Breeding crosses two genomes: the child gets one allele per locus from each
#     parent (random choice), then a mutation may replace one allele with a fresh
#     random one (mutation_rate).
#   - Stats (the creature's raw potential numbers) blend: offspring inherit 50%
#     of each parent's stats, plus a random mutation delta, so runs stay varied.
#
# This class is deterministic-safe: callers may pass a RandomNumberGenerator to
# seed a run (see daily-challenge / fixed-seed requirements in the boards).
class_name Genetics
extends RefCounted

## ---- Trait definitions -----------------------------------------------------
## The full trait table the studio's creature archetypes use. Each entry lists
## the possible allele variants and their dominance (higher = more dominant).
## These map to visual + behavioral traits on a pet (see pet.gd).
const TRAIT_ALLELES := {
	"element":   [{"name": "ember", "dominance": 2}, {"name": "splash", "dominance": 2},
		{"name": "verdant", "dominance": 1}, {"name": "gale", "dominance": 1}],
	"coat":      [{"name": "solid", "dominance": 3}, {"name": "spotted", "dominance": 2},
		{"name": "striped", "dominance": 1}],
	"size":      [{"name": "small", "dominance": 2}, {"name": "large", "dominance": 1}],
	"temper":    [{"name": "calm", "dominance": 2}, {"name": "energetic", "dominance": 1},
		{"name": "shy", "dominance": 1}],
}

## Rarity gate for the shiny variant (SANCT-007). 1/512 base chance per allele
## during mutation — kept high enough to feel rare but testable at scale.
const SHINY_ALLELE_NAME := "shiny"
const SHINY_DOMINANCE := 4              # above all normal alleles -> always expressed
const SHINY_MUTATION_CHANCE := 0.003    # ~1/333 per mutated allele

## Default mutation rate when not specified.
const DEFAULT_MUTATION_RATE := 0.05

## Each stat's random deviation range added to the 50% blend on breeding.
const STAT_MUTATION_SPAN := 0.2         # ±20%


# ===========================================================================
#  Genome
# ===========================================================================

## A single allele: which trait it belongs to, its variant name, and dominance.
class Allele:
	var trait_id: String
	var name: String
	var dominance: int
	var shiny: bool

	func _init(t: String, n: String, d: int, s: bool = false) -> void:
		trait_id = t
		name = n
		dominance = d
		shiny = s

## A diploid locus: two alleles for one trait. Phenotype = higher-dominance one.
class Locus:
	var trait_id: String
	var alleles: Array = []   # [Allele, Allele]

	func _init(t: String, a1: Allele, a2: Allele) -> void:
		trait_id = t
		alleles = [a1, a2]

	## Expressed trait name (ties broken toward the random side passed in).
	func phenotype(rand: RandomNumberGenerator) -> Dictionary:
		var a0: Allele = alleles[0]
		var a1: Allele = alleles[1]
		if a0.dominance > a1.dominance:
			return {"name": a0.name, "shiny": a0.shiny}
		if a1.dominance > a0.dominance:
			return {"name": a1.name, "shiny": a1.shiny}
		# Tie -> pick one deterministically-ish via the rng.
		var pick: Allele = a0 if rand.randf() < 0.5 else a1
		return {"name": pick.name, "shiny": pick.shiny}


# ===========================================================================
#  Genome container
# ===========================================================================

## A complete pet genome: diploid loci for every trait + base stat potentials.
class PetGenome:
	var loci: Dictionary = {}      # trait_id -> Locus
	var stats: Dictionary = {}     # stat name -> float (raw potential 0..1)

	## Build a genome from per-trait chosen variants; fills any unset traits with
	## random alleles. Each trait gets two independently-chosen alleles.
	static func randomize(rng: RandomNumberGenerator, traits: Array, stat_names: Array,
			stat_baseline: float = 0.5, stat_span: float = 0.4) -> PetGenome:
		var g := PetGenome.new()
		for t in traits:
			var variants: Array = Genetics.TRAIT_ALLELES[t]
			g.loci[t] = Locus.new(t,
				Genetics._random_allele(t, variants, rng),
				Genetics._random_allele(t, variants, rng))
		for s in stat_names:
			g.stats[s] = clampf(stat_baseline + rng.randf_range(-stat_span, stat_span), 0.0, 1.0)
		return g

	## Expressed traits (trait_id -> {name, shiny}) given this genome.
	func phenotype(rng: RandomNumberGenerator) -> Dictionary:
		var out := {}
		for t in loci:
			out[t] = loci[t].phenotype(rng)
		return out


# ===========================================================================
#  Breeding
# ===========================================================================

var mutation_rate: float = DEFAULT_MUTATION_RATE
var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator = null, p_mutation_rate: float = DEFAULT_MUTATION_RATE) -> void:
	rng = p_rng if p_rng else RandomNumberGenerator.new()
	rng.randomize()
	mutation_rate = p_mutation_rate

## Trait names the breeding engine will carry forward.
func get_traits() -> Array:
	return Genetics.TRAIT_ALLELES.keys()

## Cross two genomes -> offspring genome (SANCT-186). For each trait the child
## inherits one random allele from each parent, then mutation may swap one.
func breed(a: PetGenome, b: PetGenome) -> PetGenome:
	var child := PetGenome.new()
	for t in get_traits():
		var a_loc: Locus = a.loci[t]
		var b_loc: Locus = b.loci[t]
		# One allele from each parent (random which of the parent's two).
		var allele_a: Allele = a_loc.alleles[int(rng.randi_range(0, 1))]
		var allele_b: Allele = b_loc.alleles[int(rng.randi_range(0, 1))]
		# Mutation: with some probability, replace one inherited allele entirely.
		if rng.randf() < mutation_rate:
			allele_a = _random_allele(t, TRAIT_ALLELES[t], rng)
		if rng.randf() < mutation_rate:
			allele_b = _random_allele(t, TRAIT_ALLELES[t], rng)
		child.loci[t] = Locus.new(t, allele_a, allele_b)
	# Stats: inherit ~50% of each parent's potential, then mutate the result.
	for stat in a.stats.keys():
		var blend: float = 0.5 * float(a.stats[stat]) + 0.5 * float(b.stats.get(stat, float(a.stats[stat])))
		var mutated := blend * rng.randf_range(1.0 - STAT_MUTATION_SPAN, 1.0 + STAT_MUTATION_SPAN)
		child.stats[stat] = clampf(mutated, 0.0, 1.0)
	return child


# ===========================================================================
#  Helpers
# ===========================================================================

## Pick a random allele for a trait, occasionally rolling the shiny variant.
static func _random_allele(trait_id: String, variants: Array, rng: RandomNumberGenerator) -> Allele:
	if rng.randf() < SHINY_MUTATION_CHANCE:
		return Allele.new(trait_id, SHINY_ALLELE_NAME, SHINY_DOMINANCE, true)
	var v: Dictionary = variants[rng.randi_range(0, variants.size() - 1)]
	return Allele.new(trait_id, v["name"], v["dominance"])

## Human-readable summary of a genome's expressed traits (for UI / debug).
static func describe(genome: PetGenome, rng: RandomNumberGenerator) -> String:
	var parts: Array[String] = []
	var ph := genome.phenotype(rng)
	for t in genome.loci.keys():
		var p: Dictionary = ph[t]
		var s: String = "%s=%s" % [t, p["name"]]
		if p["shiny"]:
			s += "[shiny]"
		parts.append(s)
	return ", ".join(parts)
