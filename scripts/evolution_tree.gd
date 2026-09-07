class_name EvolutionTree
extends RefCounted

## Emitted whenever a creature successfully evolves to its next stage.
## Carries the previous species name and the new evolved species name so
## callers (HUD, save system, Sanctuary UI) can react to the change.
signal evolved(species: String, new_species: String)
## Emitted when a creature is blocked from evolving (level/affection unmet).
signal evolution_blocked(species: String, level: int, affection: int, reason: String)
## Emitted when an evolution path is queried for a species with no data.
signal unknown_species(species: String)

## Species that are terminal (no further stage) — used for fast checks.
const TERMINAL_SPECIES: Array[String] = ["emberlord", "tidewyrm", "glimmersovereign"]
## Default group creatures are expected to be registered under.
const CREATURE_GROUP: String = "sanctuary_creatures"

const EVOLUTION_PATHS: Dictionary = {
	"emberling": [
		{
			"name": "emberling",
			"required_level": 10,
			"required_affection": 20,
			"evolves_to": "emberfox"
		},
		{
			"name": "emberfox",
			"required_level": 25,
			"required_affection": 50,
			"evolves_to": "emberlord"
		},
		{
			"name": "emberlord",
			"required_level": 0,
			"required_affection": 0,
			"evolves_to": ""
		}
	],
	"splashling": [
		{
			"name": "splashling",
			"required_level": 12,
			"required_affection": 25,
			"evolves_to": "tidalfin"
		},
		{
			"name": "tidalfin",
			"required_level": 28,
			"required_affection": 55,
			"evolves_to": "tidewyrm"
		},
		{
			"name": "tidewyrm",
			"required_level": 0,
			"required_affection": 0,
			"evolves_to": ""
		}
	],
	"glimmerwing": [
		{
			"name": "glimmerwing",
			"required_level": 8,
			"required_affection": 15,
			"evolves_to": "glimmerhawk"
		},
		{
			"name": "glimmerhawk",
			"required_level": 22,
			"required_affection": 45,
			"evolves_to": "glimmersovereign"
		},
		{
			"name": "glimmersovereign",
			"required_level": 0,
			"required_affection": 0,
			"evolves_to": ""
		}
	]
}


func get_evolution_path(species: String) -> Array:
	if EVOLUTION_PATHS.has(species):
		return EVOLUTION_PATHS[species]
	unknown_species.emit(species)
	return []


func is_terminal(species: String) -> bool:
	return species in TERMINAL_SPECIES


func _find_stage_index(path: Array, species: String) -> int:
	for i in range(path.size()):
		if path[i]["name"] == species:
			return i
	return -1


func can_evolve(species: String, level: int, affection: int) -> bool:
	var path: Array = get_evolution_path(species)
	if path.is_empty():
		evolution_blocked.emit(species, level, affection, "no path")
		return false

	var index: int = _find_stage_index(path, species)
	if index == -1:
		evolution_blocked.emit(species, level, affection, "stage not found")
		return false

	if index >= path.size() - 1:
		evolution_blocked.emit(species, level, affection, "terminal")
		return false

	var next_stage: Dictionary = path[index + 1]
	var level_ok: bool = level >= int(next_stage["required_level"])
	var affection_ok: bool = affection >= int(next_stage["required_affection"])
	if not level_ok or not affection_ok:
		var reason := "level" if not level_ok else "affection"
		evolution_blocked.emit(species, level, affection, reason)
		return false
	return true


func get_next_evolution(species: String, level: int, affection: int) -> String:
	if not can_evolve(species, level, affection):
		return ""
	
	var path: Array = get_evolution_path(species)
	var index: int = _find_stage_index(path, species)
	if index == -1 or index >= path.size() - 1:
		return ""
	
	return path[index + 1]["evolves_to"]


func evolve(species: String, level: int, affection: int) -> String:
	if not can_evolve(species, level, affection):
		return species

	var next_species: String = get_next_evolution(species, level, affection)
	evolved.emit(species, next_species)
	return next_species


# -- integration helpers ---------------------------------------------------

## Notify any live creatures in the scene (by group) that a creature evolved.
## Loose-coupling via the sanctuary_creatures group; safe if none present.
static func notify_group_evolved(tree: SceneTree, species: String, new_species: String) -> void:
	if tree == null:
		return
	var creature := tree.get_first_node_in_group(CREATURE_GROUP)
	if creature != null and creature.has_method("_on_evolution_applied"):
		creature.call("_on_evolution_applied", species, new_species)


## Feed a stage-up into a ScoreMultiplier if one is wired into the scene.
## Returns the bounty awarded (0 if no multiplier present).
static func award_evolution_bounty(tree: SceneTree, base: int = 50) -> int:
	if tree == null:
		return 0
	var score_mult := tree.get_first_node_in_group("score_multiplier") as Node
	if score_mult != null and score_mult.has_method("on_evolution"):
		score_mult.call("on_evolution", base)
		return base
	return 0


static func _smoke_test() -> void:
	var tree: EvolutionTree = EvolutionTree.new()

	# Verify the evolved signal fires with the correct species transition.
	var last_evolved: Array = []
	tree.evolved.connect(func(species: String, new_species: String) -> void:
		last_evolved = [species, new_species]
	)

	assert(tree.get_evolution_path("emberling").size() == 3)
	assert(tree.get_evolution_path("unknown") == [])
	
	assert(tree.can_evolve("emberling", 10, 20) == true)
	assert(tree.can_evolve("emberling", 9, 20) == false)
	assert(tree.can_evolve("emberling", 10, 19) == false)
	assert(tree.can_evolve("emberlord", 100, 100) == false)
	
	assert(tree.get_next_evolution("emberling", 10, 20) == "emberfox")
	assert(tree.get_next_evolution("emberfox", 25, 50) == "emberlord")
	assert(tree.get_next_evolution("emberlord", 100, 100) == "")
	
	assert(tree.evolve("emberling", 10, 20) == "emberfox")
	assert(tree.evolve("emberling", 9, 20) == "emberling")
	assert(tree.evolve("emberfox", 25, 50) == "emberlord")
	assert(tree.evolve("emberlord", 100, 100) == "emberlord")
	
	assert(tree.can_evolve("splashling", 12, 25) == true)
	assert(tree.evolve("splashling", 12, 25) == "tidalfin")
	assert(tree.evolve("tidalfin", 28, 55) == "tidewyrm")
	
	assert(tree.can_evolve("glimmerwing", 8, 15) == true)
	assert(tree.evolve("glimmerwing", 8, 15) == "glimmerhawk")
	assert(tree.evolve("glimmerhawk", 22, 45) == "glimmersovereign")
	
	print("EvolutionTree: OK")