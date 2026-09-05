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
const CreatureNamingSystemScript = preload("res://scripts/sanct-005.gd")
const CreatureCodexScript = preload("res://scripts/sanct-010.gd")
const CreatureMoodIndicatorScript = preload("res://scripts/sanct-019.gd")

class SimpleCreature extends Node2D:
	signal happiness_changed(value: float)
	signal hunger_changed(value: float)
	signal sickness_changed(value: float)
	var happiness: float = 50.0
	func get_happiness() -> float:
		return happiness
	func set_happiness(value: float) -> void:
		happiness = value
		happiness_changed.emit(value)

func _ready() -> void:
	breed_button.pressed.connect(_on_breed)
	reroll_button.pressed.connect(_on_reroll)
	GameState.parents_changed.connect(_on_parents_changed)
	GameState.offspring_bred.connect(_on_offspring_bred)
	_on_reroll()
	var idle_anim := CreatureIdleAnimation.new()
	var idle_sprite := Sprite2D.new()
	idle_anim.add_child(idle_sprite)
	add_child(idle_anim)
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
	var art_gallery := CreatureArtGallery.new()
	add_child(art_gallery)
	var gallery_button := Button.new()
	gallery_button.text = "Show Art Gallery"
	gallery_button.position = Vector2(10, 240)
	gallery_button.pressed.connect(_on_gallery_pressed.bind(art_gallery))
	add_child(gallery_button)
	var story_circle := CreatureStoryCircle.new()
	add_child(story_circle)
	story_circle.story_shared.connect(_on_story_shared)
	var story_button := Button.new()
	story_button.text = "Share a Story"
	story_button.position = Vector2(10, 280)
	story_button.pressed.connect(_on_share_story_pressed.bind(story_circle))
	add_child(story_button)
	var healing_touch := CreatureHealingTouch.new()
	add_child(healing_touch)
	healing_touch.creature_healed.connect(_on_creature_healed)
	healing_touch.heal_pulse.connect(_on_heal_pulse)
	var heal_button := Button.new()
	heal_button.text = "Toggle Healing Zone"
	heal_button.position = Vector2(10, 320)
	heal_button.pressed.connect(_on_heal_zone_pressed.bind(healing_touch))
	add_child(heal_button)
	var naming_system := CreatureNamingSystemScript.new()
	add_child(naming_system)
	naming_system.creature_named.connect(_on_creature_named)
	var name_button := Button.new()
	name_button.text = "Name Parent A"
	name_button.position = Vector2(10, 360)
	name_button.pressed.connect(_on_name_pressed.bind(naming_system))
	add_child(name_button)
	var codex := CreatureCodexScript.new()
	add_child(codex)
	codex.creature_discovered.connect(_on_codex_creature_discovered)
	codex.creature_updated.connect(_on_codex_creature_updated)
	codex.codex_cleared.connect(_on_codex_cleared)
	var codex_button := Button.new()
	codex_button.text = "Register Parent A in Codex"
	codex_button.position = Vector2(10, 400)
	codex_button.pressed.connect(_on_codex_pressed.bind(codex))
	add_child(codex_button)
	var friendship := CreatureFriendship.new()
	add_child(friendship)
	friendship.friendship_changed.connect(func(current: int, max_val: int) -> void: stats_label.text = "Friendship: %d/%d" % [current, max_val])
	friendship.tier_changed.connect(func(new_tier: int, old_tier: int) -> void: stats_label.text = "Friendship tier %d (was %d)" % [new_tier, old_tier])
	friendship.ability_unlocked.connect(func(ability_id: String) -> void: stats_label.text = "Unlocked ability: %s" % ability_id)
	friendship.evolution_path_unlocked.connect(func(path_id: String) -> void: stats_label.text = "Unlocked evolution path: %s" % path_id)
	var friendship_button := Button.new()
	friendship_button.text = "Increase Friendship"
	friendship_button.position = Vector2(10, 440)
	friendship_button.pressed.connect(func() -> void: friendship.add_friendship(10))
	add_child(friendship_button)
	var trait_button := Button.new()
	trait_button.text = "Inherit Traits"
	trait_button.position = Vector2(10, 480)
	trait_button.pressed.connect(_on_trait_inherit_pressed)
	add_child(trait_button)
	var mood_creature := SimpleCreature.new()
	mood_creature.name = "MoodCreature"
	add_child(mood_creature)
	var mood_indicator := CreatureMoodIndicatorScript.new()
	mood_creature.add_child(mood_indicator)
	mood_indicator.mood_changed.connect(_on_mood_changed)
	var mood_button := Button.new()
	mood_button.text = "Toggle Mood (Happy/Sad)"
	mood_button.position = Vector2(10, 520)
	mood_button.pressed.connect(func() -> void:
		if mood_creature.happiness >= 70.0:
			mood_creature.set_happiness(30.0)
		else:
			mood_creature.set_happiness(80.0)
	)
	add_child(mood_button)

func _on_share_story_pressed(circle: CreatureStoryCircle) -> void:
	var xp := circle.share_story(&"the_drake_legend", "epic")
	if xp > 0:
		stats_label.text = "Story shared! + %d XP (circle: %d/%d)" % [xp, circle.stories_in_circle(), CreatureStoryCircle.MAX_CONCURRENT_STORIES]
	else:
		stats_label.text = "Story circle is full or on cooldown."

func _on_story_shared(story_id: StringName, xp_granted: int) -> void:
	stats_label.text = "Story '%s' shared for %d XP!" % [story_id, xp_granted]

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

func _on_gallery_pressed(gallery: CreatureArtGallery) -> void:
	if GameState.parent_a != null:
		gallery.display_creature()

func _on_heal_zone_pressed(healing: CreatureHealingTouch) -> void:
	var active: bool = not healing.visible
	healing.set_active(active)
	stats_label.text = "Healing Zone: %s (targets: %d)" % ["ON" if active else "OFF", healing.get_active_count()]

func _on_creature_healed(creature: Node, amount: float) -> void:
	stats_label.text = "Healed a creature for %.1f HP!" % amount

func _on_heal_pulse(creature: Node) -> void:
	pass

func _on_name_pressed(naming) -> void:
	if GameState.parent_a != null:
		var id := "parent_a"
		var new_name := "Buddy"
		if naming.set_creature_name(id, new_name):
			stats_label.text = "Named %s: %s" % [id, naming.get_creature_name(id)]
		else:
			stats_label.text = "Could not name %s" % id

func _on_creature_named(creature_id: String, new_name: String) -> void:
	stats_label.text = "Creature %s named %s" % [creature_id, new_name]

func _on_codex_pressed(codex) -> void:
	if GameState.parent_a != null:
		var data := {
			"name": "Parent A",
			"species": "drake",
			"stats": {"hp": 100, "attack": 50, "defense": 50, "speed": 60, "special": 40},
			"lore": "Discovered in the Breeding Lab."
		}
		codex.register_creature("parent_a", data)

func _on_codex_creature_discovered(creature_id: String, data: Dictionary) -> void:
	stats_label.text = "Codex: discovered %s (%s)" % [creature_id, data.get("name", creature_id)]

func _on_codex_creature_updated(creature_id: String, data: Dictionary) -> void:
	stats_label.text = "Codex: updated %s" % creature_id

func _on_codex_cleared() -> void:
	stats_label.text = "Codex cleared."

func _on_trait_inherit_pressed() -> void:
	if GameState.parent_a == null or GameState.parent_b == null:
		stats_label.text = "Need two parents to inherit traits."
		return
	var child := TraitInheritance.inherit_traits(GameState.parent_a, GameState.parent_b)
	if child == null:
		stats_label.text = "Trait inheritance failed."
		return
	GameState.offspring = child
	GameState.offspring_bred.emit(child)
	_on_offspring_bred(child)

func _on_mood_changed(new_mood: int) -> void:
	var mood_name: String
	match new_mood:
		CreatureMoodIndicatorScript.Mood.HAPPY:
			mood_name = "Happy"
		CreatureMoodIndicatorScript.Mood.SAD:
			mood_name = "Sad"
		CreatureMoodIndicatorScript.Mood.ANGRY:
			mood_name = "Angry"
	stats_label.text = "Mood changed to %s" % mood_name
