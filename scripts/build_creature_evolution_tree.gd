response# CreatureEvolutionTree — Galage (The Forge)
# FORGE-128 Creature Evolution Tree: modular data-driven tree with state machine,
# behavior trees, and a shared Creature interface so any creature type can plug in.
#
# This is the evolution logic. It builds an evolving creature from:
#   - A JSON definition that describes each stage (name, stats, abilities),
#   - An EvolutionTree node that tracks current stage + exp progression,
#   - A BehaviorTree that selects actions based on stage/state,
#   - And a Creature interface implemented by the player/enemy so the tree
#     can drive evolution without knowing creature internals.
#
# Structure:
#   1) CreatureEvolution — the core tree. Exposes evolve(), current_stage(),
#      get_abilities_for_stage(), and an "evolved" signal.
#   2) EvolutionStage — a single stage in the tree (name, stats, abilities).
#   3) BehaviorTree — a simple BT that reads from the tree to select actions
#      ("attack", "defend", etc.) based on current stage/state.
#   4) CreatureEvolutionDemo — an example integration: a node that owns a
#      tree and updates it, plus a demo creature that implements Creature so
#      the tree can drive its evolution without knowing its concrete type.
#
# Usage in-game:
#   - Each creature (player/enemy) gets one EvolutionTree instance.
#   - The tree is driven by exp gained from combat. When enough exp is earned,
#     evolve() advances to the next stage and grants that stage's abilities.
#   - BehaviorTree selects actions each frame based on current stage/state so
#     higher-stage creatures act smarter (e.g., a boss might "dash" at low health).
extends Node2D

## Evolution tree data. Each stage defines its name, base stats, and abilities.
class_name EvolutionStage
@export var name: String = ""
@export var max_hp: int = 10
@export var attack_power: float = 5.0
@export var defense_multiplier: float = 1.0
## Abilities available at this stage (e.g., ["attack", "dash"]).
@export var abilities: Array[String] = []

## Current experience toward the next stage.
var _exp: int = 0

func get_exp() -> int:
	return _exp

func set_exp(value: int):
	_exp = value
	if _exp >= EXP_PER_STAGE and has_stage_after():
		evolve()

const EXP_PER_STAGE := 100

## True if there is a next stage in the tree.
func has_stage_after() -> bool:
	return _stages.size() > index + 1

## The current EvolutionStage instance (null if not initialized).
var _stage: Dictionary = {}
var _tree: Array[Dictionary] = []

func init(stages: Array) -> void:
	_tree = stages
	if _tree.is_empty():
		push_error("EvolutionTree: no stages provided")
		return
	_stage = _tree[_exp // EXP_PER_STAGE]
	name = _stage.get("name", "Stage 1")

## Advance to the next stage (called when exp reaches a threshold).
func evolve() -> void:
	if not has_stage_after():
		push_warning("EvolutionTree: already at max stage")
		return
	index += 1
	_stage = _tree[index]
	_exp = 0

## Current stage name.
func current_stage_name() -> String:
	return _stage.name if _stage.has("name") else "Stage %d" % (index + 1)

## Return the stats for the current stage (HP, attack, defense).
func get_current_stats() -> Dictionary:
	var s: Dictionary = {}
	if _stage.has("max_hp"):
		s["hp"] = int(_stage.max_hp)
	else:
		s["hp"] = max_hp
	if _stage.has("attack_power"):
		s["attack"] = float(_stage.attack_power)
	else:
		s["attack"] = attack_power
	if _stage.has("defense_multiplier"):
		s["defense"] = float(_stage.defense_multiplier)
	else:
		s["defense"] = defense_multiplier
	return s

## Abilities available at the current stage (read-only copy).
func get_abilities_for_stage() -> Array[String]:
	var a: Array[String] = []
	if _stage.has("abilities"):
		a = _stage.abilities.clone()
	return a

signal evolved(stage_name: String)

## True if this creature is currently evolving to a new stage.
var _is_evolving: bool = false
signal is_evolving_changed(is_evolving: bool)
func get_is_evolving() -> bool:
	return _is_evolving

## Behavior tree for the current stage. Selects actions based on state (HP, exp).
class_name BehaviorTree extends RefCounted
extends Node2D

var _tree: EvolutionStage = null

signal behavior_changed(action: String)

func init(tree: EvolutionStage) -> void:
	_tree = tree

## Tick the BT and return the selected action for this frame.
## Uses the stage's abilities + basic state (HP, exp).
#   - If HP < 25% and "heal" is available, use it first.
#   - Else if EXP >= next threshold and evolving, signal evolved.
#   - Else pick a random ability from the current stage.
func tick(dt: float) -> String:
	if not _tree or _tree.abilities.is_empty():
		return ""
	var s := get_current_stats()
	var hp_pct: float = float(s["hp"]) / float(get_max_hp())
	## Heal when low HP and heal ability exists (stage 2+).
	if hp_pct < 0.25 and has_ability("heal"):
		return "heal"
	## Evolve when exp threshold reached.
	var next_stage_idx: int = _exp // EXP_PER_STAGE + 1
	if next_stage_idx * EXP_PER_STAGE <= _tree.exp:
		evolved.emit(_tree.name)
		is_evolving_changed.emit(true)
		return "evolve"
	## Otherwise pick a random ability from current stage.
	var idx: int = randi() % _tree.abilities.size()
	return _tree.abilities[idx]

func has_ability(ability_name: String) -> bool:
	if not _tree or not _tree.has("abilities"):
		return false
	for a in _tree.abilities:
		if a == ability_name:
			return true
	return false

## Get the max HP for the current stage.
func get_max_hp() -> int:
	var s := get_current_stats()
	if "hp" in s:
		return int(s["hp"])
	return 20

## Shared Creature interface so the tree can drive any creature without knowing its type.
class_name Creature
@export var max_health: int = 100
@export var current_health: int = 50
var _abilities: Array[String] = []
signal health_changed(health: int)
signal died

func init(max_hp: int, abilities: Array) -> void:
	max_health = max_hp
	current_health = max_hh
	_abilities = abilities.clone()

## Take damage. Returns true if the creature dies.
func take_damage(amount: int) -> bool:
	var old: int = current_health
	current_health -= amount
	if current_health < 0:
		current_health = 0
	health_changed.emit(current_health)
	return died(old)

## Heal for a given amount. Clamped to max health.
func heal(amount: int) -> void:
	var old: int = current_health
	current_health += amount
	if current_health > max_health:
		current_health = max_health
	health_changed.emit(current_health)

signal ability_used(ability_name: String)
## Cast an ability. Returns true if the creature has it.
func cast(ability_name: String) -> bool:
	if not _abilities.contains(ability_name):
		return false
	ability_used.emit(ability_name)
	var s := get_current_stats()
	if "attack_power" in s and ability_name == "attack":
		s["attack"] *= 1.5
	return true

func has_ability(name: String) -> bool:
	return _abilities.contains(name)

## Get all abilities.
func get_abilities() -> Array[String]:
	var c := _abilities.clone()
	c.sort()
	return c

## Current health as a percentage (0..1).
func get_hp_pct() -> float:
	return float(current_health) / float(max_health)
# Godot CreatureEvolutionTree — The Forge (FORGE-128)
extends Node2D

class_name CreatureEvolutionDemo
## Example creature implementing the shared Creature interface.
var _creature: Creature = null
var _tree: EvolutionTree = null

func _ready() -> void:
	# A simple demo creature that implements the Creature interface so the tree
	# can drive its evolution without knowing it's a real Godot character node.
	var stages: Array[Dictionary] = [
		{
			"name": "Hatchling",
			"max_hp": 20,
			"attack_power": 3.0,
			"abilities": ["peck", "dash"],
		},
		{
			"name": "Juvenile",
			"max_hp": 40,
			"attack_power": 6.5,
			"abilities": ["bite", "wing_flap", "sprint"],
		},
		{
			"name": "Adult",
			"max_hp": 80,
			"attack_power": 12.0,
			"abilities": ["claw_slash", "feather_shield", "enrage"],
		},
	]
	# Build the tree from our stages.
	var tree: EvolutionTree = EvolutionTree.new()
	tree.init(stages)
	_tree = tree
	creature_evolved(tree)

## Drive evolution by gaining exp. Called each frame or on exp gain.
func tick(dt: float) -> void:
	if not _tree or not _creature:
		return
	var s := _tree.get_current_stats()
	# Simulate combat: take damage and gain some exp per second.
	var dmg: int = 2 + randi() % 3
	_creature.take_damage(dmg)
	var gained: int = 1 + randi() % 4
	gained = _tree.gain_exp(gained)

## Hook the tree's evolved signal so we can show a stage-up UI.
func creature_evolved(tree: EvolutionTree) -> void:
	tree.evolved.connect(_on_tree_evolved)
	_creature.health_changed.connect(_on_creature_hp_changed)

func _on_tree_evolved(stage_name: String) -> void:
	print("EvolutionDemo: evolved to %s!" % stage_name)
	var s := tree.get_current_stats()
	print("  HP:", int(s["hp"]), "Attack:", float(s["attack"]))

## Handle the creature's health change (show a visual indicator).
func _on_creature_hp_changed(health: int) -> void:
	if health <= 0:
		died()

signal died

# CreatureEvolutionTree — unit tests.
class_name EvolutionTreeTest extends Object
extends TestCase

var tree: EvolutionTree = null

func test_init() -> void:
	tree = EvolutionTree.new()
	check(tree != null)
	var stages: Array[Dictionary] = [
		{"name": "A", "max_hp": 10, "attack_power": 5.0},
	]
	tree.init(stages)
	check(tree._tree.size() == 2)

func test_gain_exp_evolve() -> void:
	tree = EvolutionTree.new()
	var stages: Array[Dictionary] = [
		{"name": "B", "max_hp": 15, "attack_power": 7.0},
	]
	tree.init(stages)
	check(tree._exp == 0)
	for i in range(9):
		tree.gain_exp(10)
	check(tree._exp == 90)
	var s: Dictionary = tree.get_current_stats()
	check(int(s["hp"]) == 15)

func test_evolve() -> void:
	tree = EvolutionTree.new()
	var stages: Array[Dictionary] = [
		{"name": "C", "max_hp": 20, "attack_power": 9.0},
	]
	tree.init(stages)
	check(tree._exp == 0)
	for i in range(11):
		tree.gain_exp(10)
	var s: Dictionary = tree.get_current_stats()
	check(int(s["hp"]) == 20)

func test_creature_compatibility() -> void:
	var c: Creature = Creature.new()
	c.init(50, ["attack", "defend"])
	tree = EvolutionTree.new()
	var stages: Array[Dictionary] = [
		{"name": "D", "max_hp": 100, "attack_power": 20.0},
	]
	tree.init(stages)
	check(tree.gain_exp(300) == true)

func _run() -> void:
	test_init()
	test_gain_exp_evolve()
	test_evolve()
	test_creature_compatibility()

# Run the tests when this script is executed directly (for standalone testing).
func main() -> void:
	var t: EvolutionTreeTest = EvolutionTreeTest.new()
	t._run()
extends Node2D

var creature: Creature = null
var tree: EvolutionTree = null

## The shared Creature interface. Any class implementing this can be driven by the evolution tree.
class_name Creature
@export var max_health: int = 100
@export var current_health: int = 50
var _abilities: Array[String] = []
signal health_changed(health: int)
signal died

func init(max_hp: int, abilities: Array) -> void:
	max_health = max_hp
	current_health = max_hp
	_abilities = abilities.clone()

## Take damage. Returns true if the creature dies.
func take_damage(amount: int) -> bool:
	var old: int = current_health
	current_health -= amount
	if current_health < 0:
		current_health = 0
	health_changed.emit(current_health)
	return died(old)

## Heal for a given amount. Clamped to max health.
func heal(amount: int) -> void:
	var old: int = current_health
	current_health += amount
	if current_health > max_health:
		current_health = max_health
	health_changed.emit(current_health)

signal ability_used(ability_name: String)
## Cast an ability. Returns true if the creature has it.
func cast(ability_name: String) -> bool:
	if not _abilities.contains(ability_name):
		return false
	ability_used.emit(ability_name)
	var s := get_current_stats()
	if "attack_power" in s and ability_name == "attack":
		s["attack"] *= 1.5
	return true

func has_ability(name: String) -> bool:
	return _abilities.contains(name)

## Get all abilities.
func get_abilities() -> Array[String]:
	var c := _abilities.clone()
	c.sort()
	return c

signal ability_cooldown_changed(cooldown: float)
## Start a cooldown for an ability. Returns true if the creature can start it (not on cooldown).
func start_cooldown(ability_name: String, duration: float) -> bool:
	if not _abilities.contains(ability_name):
		return false
	var cds := get_cooldowns()
	for cd in cds:
		if cd.name == ability_name and cd.duration > 0.0:
			return false
	add_cooldown(AbilityCooldown.new(ability_name, duration))
	return true

## Get the current cooldown for an ability.
func get_cooldown_duration(name: String) -> float:
	var cds := get_cooldowns()
	for cd in cds:
		if cd.name == name:
			return cd.duration
	return 0.0

signal cooldown_ended(cooldown_name: String)
## Tick all active cooldowns and return a map of ability names to their remaining time.
func tick(dt: float) -> Dictionary:
	var changed := false
	for i in range(get_cooldown_count() - 1, -1, -1):
		var cd := get_cooldown(i)
		if cd.duration > 0.0:
			cd.duration -= dt
			set_cooldown(i, cd)
			changed = true
			if cd.duration <= 0.0:
				remove_cooldown(i)
				cooldown_ended.emit(cd.name)
	return get_active_cooldowns()

## Get a list of all currently active cooldowns (name -> duration).
func get_active_cooldowns() -> Dictionary:
	var result: Dictionary = {}
	for i in range(get_cooldown_count()):
		var cd := get_cooldown(i)
		if cd.duration > 0.0:
			result[cd.name] = float(cd.duration)
	return result

## Add a new cooldown.
func add_cooldown(cooldown: AbilityCooldown) -> void:
	add_child(cooldown)

signal ability_ready_changed(ability_name: String, ready: bool)
## Is an ability currently on cooldown?
func is_on_cooldown(name: String) -> bool:
	var cds := get_active_cooldowns()
	return cds.has(name)

var _tree: EvolutionTree = null
var _creature: Creature = null

signal tree_evolved(stage_name: String)
signal creature_health_changed(health: int, max_hp: int)
signal ability_used(ability_name: String)
signal cooldown_started(ability_name: String, duration: float)

func _ready() -> void:
	# Build a sample evolution tree with 3 stages.
	var stages: Array[Dictionary] = [
		{"name": "Hatchling", "max_hp": 20, "attack_power": 4.0, "abilities": ["peck"]},
		{
			"name": "Juvenile",
			"max_hp": 50,
			"attack_power": 9.0,
			"abilities": ["bite", "sprint"],
		},
		{"name": "Adult", "max_hp": 120, "attack_power": 18.0, "abilities": ["claw_slash"]},
	]
	tree = EvolutionTree.new()
	tree.init(stages)
	check(tree != null)

## Drive the tree by gaining exp each frame.
func tick(dt: float) -> void:
	if not _tree or not creature:
		return
	var gained := 1 + randi() % 5
	gained = tree