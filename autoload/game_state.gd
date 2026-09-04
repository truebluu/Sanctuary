# GameState — Sanctuary autoload
# Holds the current breeding session state: the two parent genomes and the
# offspring. Persists across scene changes so the demo can be extended.
extends Node

signal parents_changed(parent_a, parent_b)
signal offspring_bred(offspring)

var parent_a: CreatureGenome = null
var parent_b: CreatureGenome = null
var offspring: CreatureGenome = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 20260828  # deterministic demo seed

func new_random_parent(species: String = "drake") -> CreatureGenome:
	return CreatureGenome.create_random_base_genome(rng, 0.5, 0.4, species)

func set_parents(a: CreatureGenome, b: CreatureGenome) -> void:
	parent_a = a
	parent_b = b
	offspring = null
	parents_changed.emit(a, b)

func breed() -> CreatureGenome:
	if parent_a == null or parent_b == null:
		return null
	offspring = CreatureGenome.breed(parent_a, parent_b, CreatureGenome.DEFAULT_MUTATION_RATE, rng)
	offspring_bred.emit(offspring)
	return offspring
