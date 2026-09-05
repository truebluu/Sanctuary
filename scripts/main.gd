# main.gd — Sanctuary demo controller
# Breeding Lab: shows two parent creatures, a Breed button, and the offspring
# with its expressed phenotype + computed stats. Exercises the real
# CreatureGenome genetics (Mendelian inheritance + mutation + phenotype).
extends Control

@onready var parent_a_label: Label = $ParentA/ParentALabel
@onready var parent_b_label: Label = $ParentB/ParentBLabel
@onready var offspring_label: Label = $Offspring/OffspringLabel
@onready var stats_label: Label = $StatsLabel
@onready var breed_button: Button = $BreedButton
@onready var reroll_button: Button = $RerollButton
@onready var gen_label: Label = $GenLabel

const BASE_STATS := {"hp": 100, "attack": 50, "defense": 50, "speed": 60, "special": 40}

func _ready() -> void:
	breed_button.pressed.connect(_on_breed)
	reroll_button.pressed.connect(_on_reroll)
	GameState.parents_changed.connect(_on_parents_changed)
	GameState.offspring_bred.connect(_on_offspring_bred)
	_on_reroll()
	var habitat_zone := SanctuaryHabitatZone.new()
	habitat_zone.zone_type = SanctuaryHabitatZone.ZoneType.GARDEN
	habitat_zone.growth_multiplier = 1.2
	add_child(habitat_zone)
	var grooming_ritual := CreatureGroomingRitual.new()
	add_child(grooming_ritual)
	grooming_ritual.ritual_started.connect(_on_grooming_started)
	grooming_ritual.ritual_completed.connect(_on_grooming_completed)
	grooming_ritual.ritual_failed.connect(_on_grooming_failed)
	var groom_button := Button.new()
	groom_button.text = "Groom Parent A"
	groom_button.position = Vector2(10, 200)
	groom_button.pressed.connect(_on_groom_pressed.bind(grooming_ritual))
	add_child(groom_button)

func _on_groom_pressed(ritual: CreatureGroomingRitual) -> void:
	if GameState.parent_a != null:
		ritual.start(GameState.parent_a)

func _on_grooming_started(creature: CreatureGenome) -> void:
	stats_label.text = "Grooming %s..." % creature.describe(GameState.rng)

func _on_grooming_completed(trust_gained: int, energy_spent: int) -> void:
	stats_label.text = "Grooming complete: +%d trust, -%d energy" % [trust_gained, energy_spent]

func _on_grooming_failed(reason: String) -> void:
	stats_label.text = "Grooming failed: %s" % reason

func _on_reroll() -> void:
	var a := GameState.new_random_parent("drake")
	var b := GameState.new_random_parent("drake")
	GameState.set_parents(a, b)

func _on_parents_changed(a: CreatureGenome, b: CreatureGenome) -> void:
	parent_a_label.text = "Parent A (gen %d)\n%s" % [a.generation, a.describe(GameState.rng)]
	parent_b_label.text = "Parent B (gen %d)\n%s" % [b.generation, b.describe(GameState.rng)]
	offspring_label.text = "Press BREED to create offspring"
	stats_label.text = ""
	gen_label.text = ""

func _on_breed() -> void:
	var child := GameState.breed()
	if child == null:
		return
	_on_offspring_bred(child)

func _on_offspring_bred(child: CreatureGenome) -> void:
	offspring_label.text = "Offspring (gen %d)\n%s" % [child.generation, child.describe(GameState.rng)]
	var power := child.compute_stat_power(BASE_STATS, GameState.rng)
	var lines := []
	for s in CreatureGenome.STAT_NAMES:
		lines.append("%s: %d" % [s.capitalize(), power.get(s, 0)])
	stats_label.text = "\n".join(lines)
	gen_label.text = "Generation %d" % child.generation
