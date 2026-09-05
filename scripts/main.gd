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
var breeding_cooldown: BreedingCooldown

const BASE_STATS := {"hp": 100, "attack": 50, "defense": 50, "speed": 60, "special": 40}
const CreatureNamingSystemScript = preload("res://scripts/sanct-005.gd")
const CreatureCodexScript = preload("res://scripts/sanct-010.gd")
const CreatureMoodIndicatorScript = preload("res://scripts/sanct-019.gd")
const CreatureNamePersistenceScript = preload("res://scripts/sanct-024.gd")
const SanctuaryWeatherEffectsScript = preload("res://scripts/sanct-029.gd")
const CreatureSanctuaryGardenScript = preload("res://scripts/sanct-069.gd")
const Sanct071Script = preload("res://scripts/sanct-071.gd")

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
	var type_chart_button := Button.new()
	type_chart_button.text = "Show Type Chart"
	type_chart_button.position = Vector2(10, 560)
	type_chart_button.pressed.connect(_on_type_chart_pressed)
	add_child(type_chart_button)
	var name_persistence := CreatureNamePersistenceScript.new()
	add_child(name_persistence)
	var hunger_decay_script := preload("res://scripts/sanct-026.gd")
	var hunger_decay := hunger_decay_script.new()
	mood_creature.add_child(hunger_decay)
	hunger_decay.hunger_changed.connect(_on_hunger_changed)
	var feed_button := Button.new()
	feed_button.text = "Feed Creature"
	feed_button.position = Vector2(10, 600)
	feed_button.pressed.connect(func() -> void: hunger_decay.feed(20.0))
	add_child(feed_button)
	var weather_effects := SanctuaryWeatherEffectsScript.new()
	add_child(weather_effects)
	var weather_button := Button.new()
	weather_button.text = "Toggle Rain/Sun"
	weather_button.position = Vector2(10, 640)
	weather_button.pressed.connect(func() -> void:
		if weather_effects._current_weather == "rain":
			weather_effects._on_weather_changed("sun")
		else:
			weather_effects._on_weather_changed("rain")
	)
	add_child(weather_button)
	var breeding_cooldown_node := BreedingCooldown.new()
	breeding_cooldown = breeding_cooldown_node
	add_child(breeding_cooldown_node)
	breeding_cooldown_node.cooldown_started.connect(func(creature_id: StringName, duration: float) -> void:
		stats_label.text = "Cooldown started for %s (%.1fs)" % [creature_id, duration]
	)
	breeding_cooldown_node.cooldown_expired.connect(func(creature_id: StringName) -> void:
		stats_label.text = "Cooldown expired for %s" % creature_id
	)
	# Sanctuary Expansion Cost wiring
	var expansion_cost := SanctuaryExpansionCost.new()
	expansion_cost.balance_changed.connect(_on_expansion_balance_changed)
	expansion_cost.tier_unlocked.connect(_on_expansion_tier_unlocked)
	expansion_cost.expansion_blocked.connect(_on_expansion_blocked)
	var award_credits_button := Button.new()
	award_credits_button.text = "Award Activity Credits"
	award_credits_button.position = Vector2(10, 680)
	award_credits_button.pressed.connect(func() -> void: expansion_cost.award_activity_credits(true))
	add_child(award_credits_button)
	var expand_button := Button.new()
	expand_button.text = "Expand Sanctuary"
	expand_button.position = Vector2(10, 720)
	expand_button.pressed.connect(func() -> void: expansion_cost.expand())
	add_child(expand_button)
	var stagger_dummy := RigidBody2D.new()
	stagger_dummy.name = "StaggerDummy"
	add_child(stagger_dummy)
	var stagger := EnemyStagger.new()
	stagger_dummy.add_child(stagger)
	stagger.flinch_started.connect(_on_stagger_flinch_started)
	stagger.flinch_ended.connect(_on_stagger_flinch_ended)
	var stagger_button := Button.new()
	stagger_button.text = "Stagger Burst"
	stagger_button.position = Vector2(10, 760)
	stagger_button.pressed.connect(func() -> void: stagger.register_damage(20.0))
	add_child(stagger_button)
	var energy := CreatureEnergy.new()
	add_child(energy)
	energy.energy_changed.connect(func(current: int, maximum: int) -> void: stats_label.text = "Energy: %d/%d" % [current, maximum])
	energy.energy_depleted.connect(func() -> void: stats_label.text = "Creature exhausted!")
	energy.energy_restored.connect(func(amount: int) -> void: stats_label.text = "Energy restored +%d" % amount)
	energy.battle_readiness_changed.connect(func(readiness: float) -> void: stats_label.text = "Battle readiness: %.0f%%" % (readiness * 100.0))
	var energy_spend_button := Button.new()
	energy_spend_button.text = "Spend Energy"
	energy_spend_button.position = Vector2(10, 800)
	energy_spend_button.pressed.connect(func() -> void: energy.spend_energy())
	add_child(energy_spend_button)
	var nap_button := Button.new()
	nap_button.text = "Take Nap"
	nap_button.position = Vector2(10, 840)
	nap_button.pressed.connect(func() -> void: energy.take_nap())
	add_child(nap_button)
	var garden := CreatureGarden.new()
	add_child(garden)
	garden.decoration_planted.connect(_on_garden_decoration_planted)
	garden.decoration_grown.connect(_on_garden_decoration_grown)
	garden.buff_applied.connect(_on_garden_buff_applied)
	garden.garden_full.connect(_on_garden_full)
	var garden_button := Button.new()
	garden_button.text = "Plant Garden Decoration"
	garden_button.position = Vector2(10, 880)
	garden_button.pressed.connect(func() -> void: garden.plant_decoration("flower_%d" % garden.get_decoration_count(), "flower"))
	add_child(garden_button)
	var sanctuary_garden := CreatureSanctuaryGardenScript.new()
	add_child(sanctuary_garden)
	sanctuary_garden.plant_grown.connect(_on_sanctuary_plant_grown)
	sanctuary_garden.creature_resting.connect(_on_sanctuary_creature_resting)
	sanctuary_garden.bonding_started.connect(_on_sanctuary_bonding_started)
	var sanctuary_garden_button := Button.new()
	sanctuary_garden_button.text = "Plant Sanctuary Seed"
	sanctuary_garden_button.position = Vector2(10, 960)
	sanctuary_garden_button.pressed.connect(func() -> void: sanctuary_garden.plant_seed())
	add_child(sanctuary_garden_button)
	var social_bonds := CreatureSocialBonds.new()
	add_child(social_bonds)
	social_bonds.bond_changed.connect(func(a: StringName, b: StringName, level: int) -> void: stats_label.text = "Bond %s-%s reached level %d" % [a, b, level])
	social_bonds.bond_bonus_applied.connect(func(creature: StringName, delta: float) -> void: stats_label.text = "Bond bonus: %s happiness +%.2f" % [creature, delta])
	var bond_button := Button.new()
	bond_button.text = "Show Social Bond"
	bond_button.position = Vector2(10, 920)
	bond_button.pressed.connect(func() -> void:
		var level := social_bonds.get_bond_level(&"parent_a", &"parent_b")
		stats_label.text = "Social bond level: %d" % level
	)
	add_child(bond_button)
	var sanct_071 := Sanct071Script.new()
	add_child(sanct_071)
	stats_label.text = "%s | %s" % [sanct_071.TITLE_1, sanct_071.TITLE_2]
	var format_validator := preload("res://scripts/sanct-073.gd").new()
	add_child(format_validator)
	format_validator.line_validated.connect(func(line_index: int, title: String, description: String, ok: bool) -> void:
		stats_label.text = "Line %d validated: %s - %s" % [line_index, title, description]
	)
	format_validator.validation_failed.connect(func(line_index: int, reason: String) -> void:
		stats_label.text = "Validation failed on line %d: %s" % [line_index, reason]
	)
	var validate_button := Button.new()
	validate_button.text = "Validate Format Line"
	validate_button.position = Vector2(10, 1000)
	validate_button.pressed.connect(func() -> void:
		var test_line := "TITLE | description"
		format_validator.validate_line(test_line, 0)
	)
	add_child(validate_button)

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
	if not breeding_cooldown.can_breed("parent_a") or not breeding_cooldown.can_breed("parent_b"):
		stats_label.text = "Breeding on cooldown. Wait for parents to rest."
		return
	var child := GameState.breed()
	if child == null:
		return
	breeding_cooldown.start_cooldown("parent_a")
	breeding_cooldown.start_cooldown("parent_b")
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

func _on_type_chart_pressed() -> void:
	var attacker := CreatureTypeChart.Type.FIRE
	var defender := CreatureTypeChart.Type.GRASS
	var mult := CreatureTypeChart.get_effectiveness(attacker, defender)
	stats_label.text = "%s vs %s: %.1fx" % [CreatureTypeChart.get_type_name(attacker), CreatureTypeChart.get_type_name(defender), mult]

func _on_hunger_changed(new_value: float) -> void:
	stats_label.text = "Hunger: %.1f" % new_value

func _on_expansion_balance_changed(new_balance: int) -> void:
	stats_label.text = "Sanctuary Credits: %d" % new_balance

func _on_expansion_tier_unlocked(new_tier: int, cost_paid: int) -> void:
	stats_label.text = "Sanctuary expanded to tier %d (cost %d credits)" % [new_tier, cost_paid]

func _on_expansion_blocked(reason: String) -> void:
	stats_label.text = "Expansion blocked: %s" % reason

func _on_stagger_flinch_started(target: Node) -> void:
	stats_label.text = "Enemy staggered!"

func _on_stagger_flinch_ended(target: Node) -> void:
	stats_label.text = "Enemy recovered from stagger."

func _on_garden_decoration_planted(id: String, type: String) -> void:
	stats_label.text = "Planted %s (%s)" % [id, type]

func _on_garden_decoration_grown(id: String, type: String, growth: float) -> void:
	stats_label.text = "Garden %s grew to %.0f%%" % [id, growth * 100.0]

func _on_garden_buff_applied(creature: Node, mood: float, health: float) -> void:
	stats_label.text = "Garden buff applied: +%.2f mood, +%.2f health" % [mood, health]

func _on_garden_full() -> void:
	stats_label.text = "Garden is full!"

func _on_sanctuary_plant_grown(plant_id: int) -> void:
	stats_label.text = "Sanctuary plant %d grew!" % plant_id

func _on_sanctuary_creature_resting(creature_id: String) -> void:
	stats_label.text = "%s is resting in the sanctuary garden." % creature_id

func _on_sanctuary_bonding_started(creature_id: String) -> void:
	stats_label.text = "%s started bonding in the sanctuary garden." % creature_id
