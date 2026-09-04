# CreatureGenome — Sanctuary (Taming pet-evolution)
# SANCTUARY-013: Creature Breeding & Genetic Inheritance system
# RefCounted class holding traits/alleles with Mendelian inheritance, mutation, and phenotype computation.

class_name CreatureGenome
extends RefCounted

## ---- Trait definitions -----------------------------------------------------
## Each trait has possible alleles with dominance values (higher = more dominant).
## The expressed phenotype takes the highest-dominance allele (ties broken randomly).
const TRAIT_ALLELES := {
	"element": [
		{"name": "ember", "dominance": 2},
		{"name": "splash", "dominance": 2},
		{"name": "verdant", "dominance": 1},
		{"name": "gale", "dominance": 1},
	],
	"coat": [
		{"name": "solid", "dominance": 3},
		{"name": "spotted", "dominance": 2},
		{"name": "striped", "dominance": 1},
	],
	"size": [
		{"name": "small", "dominance": 2},
		{"name": "large", "dominance": 1},
	],
	"temper": [
		{"name": "calm", "dominance": 2},
		{"name": "energetic", "dominance": 1},
		{"name": "shy", "dominance": 1},
	],
	"pattern": [
		{"name": "plain", "dominance": 2},
		{"name": "mottled", "dominance": 1},
		{"name": "banded", "dominance": 1},
	],
}

## Shiny allele - rare variant with maximum dominance
const SHINY_ALLELE_NAME := "shiny"
const SHINY_DOMINANCE := 4
const SHINY_MUTATION_CHANCE := 0.002  # ~1/500 per allele

## Default mutation rate when breeding (per allele per locus)
const DEFAULT_MUTATION_RATE := 0.05

## Stat mutation span: ±20% random deviation around blended parent stats
const STAT_MUTATION_SPAN := 0.2

## Base stat names used by creatures
const STAT_NAMES := ["hp", "attack", "defense", "speed", "special"]

## Trait names the breeding engine carries forward
static func get_trait_names() -> Array[String]:
	var keys: Array = TRAIT_ALLELES.keys()
	var result: Array[String] = []
	for k in keys:
		result.append(k)
	return result

## ---- Allele inner class ----------------------------------------------------
## Represents a single allele at a locus: trait_id, variant name, dominance, shiny flag
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

	func to_dict() -> Dictionary:
		return {"trait_id": trait_id, "name": name, "dominance": dominance, "shiny": shiny}

	static func from_dict(d: Dictionary) -> Allele:
		return Allele.new(d["trait_id"], d["name"], d["dominance"], d.get("shiny", false))

## ---- Locus inner class -----------------------------------------------------
## A diploid locus: two alleles for one trait. Phenotype = highest-dominance allele.
class Locus:
	var trait_id: String
	var alleles: Array[Allele] = []  # [Allele, Allele]

	func _init(t: String, a1: Allele, a2: Allele) -> void:
		trait_id = t
		alleles = [a1, a2]

	func phenotype(rng: RandomNumberGenerator) -> Dictionary:
		"""Returns expressed trait: {name, shiny}. Ties broken randomly via RNG."""
		var a0 := alleles[0]
		var a1 := alleles[1]
		if a0.dominance > a1.dominance:
			return {"name": a0.name, "shiny": a0.shiny}
		if a1.dominance > a0.dominance:
			return {"name": a1.name, "shiny": a1.shiny}
		# Tie -> pick one via RNG
		var pick := a0 if rng.randf() < 0.5 else a1
		return {"name": pick.name, "shiny": pick.shiny}

	func to_dict() -> Dictionary:
		return {"trait_id": trait_id, "alleles": [alleles[0].to_dict(), alleles[1].to_dict()]}

	static func from_dict(d: Dictionary) -> Locus:
		var a1 := Allele.from_dict(d["alleles"][0])
		var a2 := Allele.from_dict(d["alleles"][1])
		return Locus.new(d["trait_id"], a1, a2)

## ---- CreatureGenome container ----------------------------------------------
## Complete genome: diploid loci for every trait + base stat potentials (0.0..1.0)
var loci: Dictionary[String, Locus] = {}
var stats: Dictionary[String, float] = {}
var generation: int = 0
var species: String = "base"
var lineage: Dictionary = {"parent_ids": [], "generation": 0}

## Create a randomized base genome (generation 0)
## rng: seeded RNG for reproducibility
## stat_baseline: center value for stats (0.0..1.0)
## stat_span: random deviation range around baseline
static func create_random_base_genome(rng: RandomNumberGenerator, stat_baseline: float = 0.5, stat_span: float = 0.4, p_species: String = "base") -> CreatureGenome:
	var g := CreatureGenome.new()
	g.species = p_species
	g.generation = 0
	g.lineage = {"parent_ids": [], "generation": 0}
	
	var traits := get_trait_names()
	for t in traits:
		var variants: Array = TRAIT_ALLELES[t]
		g.loci[t] = Locus.new(t, _random_allele(t, variants, rng), _random_allele(t, variants, rng))
	
	for s in STAT_NAMES:
		g.stats[s] = clampf(stat_baseline + rng.randf_range(-stat_span, stat_span), 0.0, 1.0)
	
	return g

## Breed two parent genomes into an offspring genome
## parent_a, parent_b: CreatureGenome instances
## mutation_rate: chance per allele per locus to mutate (default DEFAULT_MUTATION_RATE)
## rng: optional seeded RNG for deterministic results
static func breed(parent_a: CreatureGenome, parent_b: CreatureGenome, mutation_rate: float = DEFAULT_MUTATION_RATE, p_rng: RandomNumberGenerator = null) -> CreatureGenome:
	var use_rng := p_rng if p_rng else RandomNumberGenerator.new()
	if not p_rng:
		use_rng.randomize()
	
	var child := CreatureGenome.new()
	child.species = parent_a.species
	child.generation = max(parent_a.generation, parent_b.generation) + 1
	child.lineage = {
		"parent_ids": [parent_a.get_instance_id(), parent_b.get_instance_id()],
		"generation": child.generation
	}
	
	# Per-trait allele inheritance
	for t in get_trait_names():
		var a_loc := parent_a.loci[t]
		var b_loc := parent_b.loci[t]
		
		# Inherit one random allele from each parent
		var allele_a := a_loc.alleles[use_rng.randi_range(0, 1)]
		var allele_b := b_loc.alleles[use_rng.randi_range(0, 1)]
		
		# Mutation: replace inherited allele with fresh random one
		if use_rng.randf() < mutation_rate:
			allele_a = _random_allele(t, TRAIT_ALLELES[t], use_rng)
		if use_rng.randf() < mutation_rate:
			allele_b = _random_allele(t, TRAIT_ALLELES[t], use_rng)
		
		child.loci[t] = Locus.new(t, allele_a, allele_b)
	
	# Stat inheritance: 50% blend + mutation span
	for stat in STAT_NAMES:
		var base_a: float = parent_a.stats.get(stat, 0.5)
		var base_b: float = parent_b.stats.get(stat, 0.5)
		var blend: float = 0.5 * base_a + 0.5 * base_b
		var mutated: float = blend * use_rng.randf_range(1.0 - STAT_MUTATION_SPAN, 1.0 + STAT_MUTATION_SPAN)
		child.stats[stat] = clampf(mutated, 0.0, 1.0)
	
	return child

## Compute expressed phenotype from this genome
## rng: RNG for tie-breaking (use same seed for deterministic phenotype)
## Returns: Dictionary trait_id -> {name, shiny}
func compute_phenotype(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for t in loci:
		out[t] = loci[t].phenotype(rng)
	return out

## Compute stat power from genome (phenotype multipliers applied to base stats)
## base_stats: Dictionary of raw base values e.g. {"hp": 100, "attack": 50, ...}
## rng: RNG for phenotype resolution
## Returns: Dictionary with final computed stats
func compute_stat_power(base_stats: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var phenotype := compute_phenotype(rng)
	var out := {}
	
	# Trait-based multipliers
	var multipliers := {
		"hp": {"low": 0.7, "normal": 1.0, "high": 1.3, "very_high": 1.6, "shiny": 2.0},
		"attack": {"low": 0.7, "normal": 1.0, "high": 1.3, "very_high": 1.6, "shiny": 2.0},
		"defense": {"low": 0.7, "normal": 1.0, "high": 1.3, "very_high": 1.6, "shiny": 2.0},
		"speed": {"low": 0.7, "normal": 1.0, "high": 1.3, "very_high": 1.6, "shiny": 2.0},
		"special": {"low": 0.7, "normal": 1.0, "high": 1.3, "very_high": 1.6, "shiny": 2.0},
	}
	
	# Size multiplier from size trait
	var size_mult := 1.0
	if phenotype.has("size"):
		match phenotype["size"]["name"]:
			"small": size_mult = 0.8
			"large": size_mult = 1.2
			"shiny": size_mult = 1.5
	
	for stat in STAT_NAMES:
		var base: int = base_stats.get(stat, 50)
		var stat_mult := 1.0
		
		# Element affinity affects special stat
		if stat == "special" and phenotype.has("element"):
			var elem: String = phenotype["element"]["name"]
			if elem in ["ember", "splash", "verdant", "gale"]:
				stat_mult *= 1.15
			if phenotype["element"]["shiny"]:
				stat_mult *= 1.5
		
		# Coat pattern affects defense
		if stat == "defense" and phenotype.has("coat"):
			match phenotype["coat"]["name"]:
				"solid": stat_mult *= 1.1
				"spotted": stat_mult *= 1.05
				"shiny": stat_mult *= 1.3
		
		# Temper affects speed
		if stat == "speed" and phenotype.has("temper"):
			match phenotype["temper"]["name"]:
				"energetic": stat_mult *= 1.2
				"calm": stat_mult *= 0.95
				"shiny": stat_mult *= 1.3
		
		# Pattern affects hp
		if stat == "hp" and phenotype.has("pattern"):
			match phenotype["pattern"]["name"]:
				"plain": stat_mult *= 1.0
				"mottled": stat_mult *= 1.05
				"banded": stat_mult *= 1.1
				"shiny": stat_mult *= 1.3
		
		var final_val := int(base * stat_mult * size_mult)
		out[stat] = final_val
	
	return out

## Serialize genome to dictionary (for saving/networking)
func to_dict() -> Dictionary:
	var out := {
		"species": species,
		"generation": generation,
		"lineage": lineage,
		"loci": {},
		"stats": stats,
	}
	for t in loci:
		out["loci"][t] = loci[t].to_dict()
	return out

## Deserialize genome from dictionary
static func from_dict(d: Dictionary) -> CreatureGenome:
	var g := CreatureGenome.new()
	g.species = d.get("species", "base")
	g.generation = d.get("generation", 0)
	g.lineage = d.get("lineage", {"parent_ids": [], "generation": 0})
	g.stats = d.get("stats", {})
	
	for t in d.get("loci", {}):
		g.loci[t] = Locus.from_dict(d["loci"][t])
	
	return g

## Human-readable description of expressed traits
func describe(rng: RandomNumberGenerator) -> String:
	var ph := compute_phenotype(rng)
	var parts := []
	for t in loci:
		var p: Dictionary = ph[t]
		var s := "%s=%s" % [t, p["name"]]
		if p["shiny"]:
			s += "[shiny]"
		parts.append(s)
	return ", ".join(parts)

## ---- Helpers ---------------------------------------------------------------

## Pick a random allele for a trait, with rare shiny chance
static func _random_allele(trait_id: String, variants: Array, rng: RandomNumberGenerator) -> Allele:
	if rng.randf() < SHINY_MUTATION_CHANCE:
		return Allele.new(trait_id, SHINY_ALLELE_NAME, SHINY_DOMINANCE, true)
	var v: Dictionary = variants[rng.randi_range(0, variants.size() - 1)]
	return Allele.new(trait_id, v["name"], v["dominance"])

## Mutate this genome in place (for evolution events, radiation, etc.)
func mutate(rate: float = DEFAULT_MUTATION_RATE, p_rng: RandomNumberGenerator = null) -> void:
	var use_rng := p_rng if p_rng else RandomNumberGenerator.new()
	use_rng.randomize()
	
	for t in loci:
		var variants: Array = TRAIT_ALLELES[t]
		for i in range(2):
			if use_rng.randf() < rate:
				loci[t].alleles[i] = _random_allele(t, variants, use_rng)
	
	for s in stats:
		var val: float = stats[s]
		var mutated: float = val * use_rng.randf_range(1.0 - STAT_MUTATION_SPAN, 1.0 + STAT_MUTATION_SPAN)
		stats[s] = clampf(mutated, 0.0, 1.0)