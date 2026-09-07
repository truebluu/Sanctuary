# BreedingManager — Taming (The Sanctuary)
# SANCTUARY-006: Creature Breeding & Genetics System.
# Pure-logic class (RefCounted) providing a simple breed(parent_a, parent_b) -> CreatureData API.
# Combines parent genes (traits, colors, stats) producing offspring with mutation chance.

class_name BreedingManager
extends RefCounted

## Default mutation rate for traits (chance per allele per locus).
const DEFAULT_MUTATION_RATE := 0.05

## Default mutation span for stats (±span around the blended value).
const DEFAULT_STAT_MUTATION_SPAN := 0.2

## Trait compatibility matrix: which elements can breed with which.
const ELEMENT_COMPATIBILITY := {
	"ember": ["ember", "verdant"],
	"splash": ["splash", "gale"],
	"verdant": ["verdant", "ember"],
	"gale": ["gale", "splash"],
}

## Minimum shared trait categories required for compatibility.
const MIN_SHARED_TRAIT_CATEGORIES := 1

var rng: RandomNumberGenerator
var mutation_rate: float = DEFAULT_MUTATION_RATE
var stat_mutation_span: float = DEFAULT_STAT_MUTATION_SPAN

func _init(p_rng: RandomNumberGenerator = null, p_mutation_rate: float = DEFAULT_MUTATION_RATE, p_stat_mutation_span: float = DEFAULT_STAT_MUTATION_SPAN) -> void:
	rng = p_rng if p_rng else RandomNumberGenerator.new()
	rng.randomize()
	mutation_rate = p_mutation_rate
	stat_mutation_span = p_stat_mutation_span

## Breed two parent CreatureData into an offspring CreatureData.
## parent_a, parent_b: Dictionaries with keys: id (int/string), traits (Dict), stats (Dict), lineage (Dict, optional)
## Returns offspring CreatureData Dictionary with keys: traits, stats, lineage {parent_ids, generation}
func breed(parent_a: Dictionary, parent_b: Dictionary) -> Dictionary:
	if not _is_compatible(parent_a, parent_b):
		push_error("BreedingManager.breed: parents are not compatible")
		return {}
	
	# Build Genetics.PetGenome objects from parent dictionaries
	var genome_a := _dict_to_pet_genome(parent_a)
	var genome_b := _dict_to_pet_genome(parent_b)
	
	# Use the Genetics engine to breed
	var genetics_engine := Genetics.new(rng, mutation_rate)
	var child_genome: Genetics.PetGenome = genetics_engine.breed(genome_a, genome_b)
	
	# Determine generation: max(parent generations) + 1
	var gen_a: int = _get_generation(parent_a)
	var gen_b: int = _get_generation(parent_b)
	var child_generation: int = max(gen_a, gen_b) + 1
	
	# Build offspring dictionary with lineage
	var offspring := {
		"traits": _pet_genome_to_traits_dict(child_genome),
		"stats": _pet_genome_to_stats_dict(child_genome),
		"lineage": {
			"parent_ids": [_get_id(parent_a), _get_id(parent_b)],
			"generation": child_generation
		}
	}
	
	return offspring

## Check if two creature genomes are compatible for breeding.
func _is_compatible(a: Dictionary, b: Dictionary) -> bool:
	if not a or not b:
		return false
	if not a.has("traits") or not b.has("traits"):
		return false
	
	var a_traits: Dictionary = a.traits
	var b_traits: Dictionary = b.traits
	
	# Check element compatibility
	var a_element: String = ""
	var b_element: String = ""
	
	if a_traits.has("element") and a_traits["element"].has("name"):
		a_element = a_traits["element"]["name"]
	if b_traits.has("element") and b_traits["element"].has("name"):
		b_element = b_traits["element"]["name"]
	
	if not ELEMENT_COMPATIBILITY.has(a_element) or not ELEMENT_COMPATIBILITY.has(b_element):
		return false
	
	var compatible_elements: Array = ELEMENT_COMPATIBILITY[a_element]
	if not compatible_elements.has(b_element):
		return false
	
	# Count shared trait categories
	var shared_count: int = 0
	for trait_name in Genetics.TRAIT_ALLELES.keys():
		if a_traits.has(trait_name) and b_traits.has(trait_name):
			shared_count += 1
	
	return shared_count >= MIN_SHARED_TRAIT_CATEGORIES

## Apply mutation to an existing CreatureData genome dictionary.
## genome: Dictionary with traits and stats keys.
## rate: mutation rate (0.0 to 1.0) per allele per locus.
## Returns mutated genome Dictionary (new object, original unchanged).
func mutate(genome: Dictionary, rate: float) -> Dictionary:
	var mutated_genome := _dict_to_pet_genome(genome)
	var genetics_engine := Genetics.new(rng, rate)
	
	# Mutate each locus
	for trait_id in mutated_genome.loci.keys():
		var locus: Genetics.Locus = mutated_genome.loci[trait_id]
		var variants: Array = Genetics.TRAIT_ALLELES[trait_id]
		
		# Each allele has a chance to mutate
		for i in range(2):
			if rng.randf() < rate:
				locus.alleles[i] = Genetics._random_allele(trait_id, variants, rng)
	
	# Mutate stats
	for stat_name in mutated_genome.stats.keys():
		var val: float = mutated_genome.stats[stat_name]
		var mutated_val := val * rng.randf_range(1.0 - stat_mutation_span, 1.0 + stat_mutation_span)
		mutated_genome.stats[stat_name] = clampf(mutated_val, 0.0, 1.0)
	
	return {
		"traits": _pet_genome_to_traits_dict(mutated_genome),
		"stats": _pet_genome_to_stats_dict(mutated_genome),
		"lineage": genome.lineage if genome.has("lineage") else {"parent_ids": [], "generation": 0}
	}

## Get lineage information from a CreatureData genome dictionary.
## Returns Dictionary with parent_ids (Array) and generation (int).
func get_lineage(genome: Dictionary) -> Dictionary:
	if not genome.has("lineage"):
		return {"parent_ids": [], "generation": 0}
	return genome.lineage.duplicate(true)

## Create a random parent CreatureData for testing.
static func create_random_parent(p_rng: RandomNumberGenerator, p_id: Variant, p_generation: int = 0) -> Dictionary:
	var traits: Array = Genetics.TRAIT_ALLELES.keys()
	var stat_names: Array = ["str", "spd", "res", "int", "cha"]
	var genome := Genetics.PetGenome.randomize(p_rng, traits, stat_names)
	
	return {
		"id": p_id,
		"traits": _pet_genome_to_traits_dict_static(genome, p_rng),
		"stats": _pet_genome_to_stats_dict_static(genome),
		"lineage": {
			"parent_ids": [],
			"generation": p_generation
		}
	}

## ===========================================================================
## Internal Helpers
## ===========================================================================

func _get_id(parent: Dictionary) -> Variant:
	return parent.get("id", 0)

func _get_generation(parent: Dictionary) -> int:
	if parent.has("lineage") and parent.lineage.has("generation"):
		return int(parent.lineage.generation)
	return 0

## Convert a parent dictionary to a Genetics.PetGenome
func _dict_to_pet_genome(data: Dictionary) -> Genetics.PetGenome:
	var g := Genetics.PetGenome.new()
	
	# Build loci from traits dict
	if data.has("traits"):
		for trait_id in data.traits:
			var trait_data: Dictionary = data.traits[trait_id]
			var allele_name: String = trait_data.get("name", "")
			var shiny: bool = trait_data.get("shiny", false)
			
			# Find dominance from TRAIT_ALLELES
			var dominance: int = 1
			if Genetics.TRAIT_ALLELES.has(trait_id):
				for v in Genetics.TRAIT_ALLELES[trait_id]:
					if v["name"] == allele_name:
						dominance = v["dominance"]
						break
			
			# For homozygous representation, use same allele twice
			var allele: Genetics.Allele = Genetics.Allele.new(trait_id, allele_name, dominance, shiny)
			g.loci[trait_id] = Genetics.Locus.new(trait_id, allele, allele)
	
	# Copy stats
	if data.has("stats"):
		for stat_name in data.stats:
			g.stats[stat_name] = float(data.stats[stat_name])
	
	return g

## Convert Genetics.PetGenome to traits dictionary (expressed phenotype)
func _pet_genome_to_traits_dict(genome: Genetics.PetGenome) -> Dictionary:
	var out := {}
	var ph := genome.phenotype(rng)
	for t in ph:
		out[t] = ph[t]
	return out

## Convert Genetics.PetGenome to stats dictionary
func _pet_genome_to_stats_dict(genome: Genetics.PetGenome) -> Dictionary:
	var out := {}
	for s in genome.stats:
		out[s] = genome.stats[s]
	return out

## Static version for creating random parents
static func _pet_genome_to_traits_dict_static(genome: Genetics.PetGenome, use_rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	var ph := genome.phenotype(use_rng)
	for t in ph:
		out[t] = ph[t]
	return out

static func _pet_genome_to_stats_dict_static(genome: Genetics.PetGenome) -> Dictionary:
	var out := {}
	for s in genome.stats:
		out[s] = genome.stats[s]
	return out