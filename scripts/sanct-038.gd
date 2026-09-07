extends Node
class_name CreatureSocialBond

## Pair-bond manager. Attaches to a Creature; finds a compatible neighbor,
## forms a bond that passively boosts both creatures' happiness, and unlocks
## co-op animations while the pair stays within range.

# --- Tunables (one place to retune) ---
## How close two creatures must be to form a bond (pixels).
@export var bond_radius: float = 220.0
## Happiness bonus per bonded creature, added to the needs meter each tick.
@export var happiness_bonus: float = 4.0
## Seconds between happiness bonus ticks.
@export var tick_interval: float = 3.0
## Bond fades if the pair drifts apart longer than this (seconds).
@export var drift_grace: float = 8.0
## Cooldown before a creature can seek a new bond after one breaks.
@export var rebond_cooldown: float = 12.0

signal bond_formed(bond: CreatureSocialBond)
signal bond_broken(bond: CreatureSocialBond)
signal coop_animation_triggered(anim: StringName)

var _creature: Creature = null
var _partner: CreatureSocialBond = null
var _partner_creature: Creature = null
var _bonded: bool = false
var _tick_timer: float = 0.0
var _drift_time: float = 0.0
var _cooldown: float = 0.0
var _coop_ready: bool = false

func _ready() -> void:
	_creature = _resolve_creature()
	if _creature == null:
		push_error("CreatureSocialBond: no Creature found up the tree")
		set_process(false)

func _resolve_creature() -> Creature:
	var node: Node = get_parent()
	while node != null and !(node is Creature):
		node = node.get_parent()
	return node as Creature

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
	if not _bonded:
		if _cooldown <= 0.0:
			_try_form_bond()
		return
	# Bonded: check proximity, tick happiness, offer co-op.
	var dist: float = _creature.global_position.distance_to(_partner_creature.global_position)
	if dist <= bond_radius:
		_drift_time = 0.0
		_tick_timer += delta
		if _tick_timer >= tick_interval:
			_tick_timer = 0.0
			_apply_happiness()
		if not _coop_ready:
			_coop_ready = true
			coop_animation_triggered.emit(&"bonded_greet")
	else:
		_drift_time += delta
		if _drift_time >= drift_grace:
			_break_bond()

func _try_form_bond() -> void:
	var best: CreatureSocialBond = null
	var best_score: int = -1
	for other in _scan_neighbors():
		if other == self:
			continue
		if other._bonded or other._cooldown > 0.0:
			continue
		var score: int = _compatibility_score(other._creature)
		if score > best_score:
			best_score = score
			best = other
	if best == null or best_score <= 0:
		return
	_partner = best
	_partner_creature = best._creature
	best._partner = self
	best._partner_creature = _creature
	_bonded = true
	best._bonded = true
	_coop_ready = false
	bond_formed.emit(self)

func _scan_neighbors() -> Array[CreatureSocialBond]:
	var result: Array[CreatureSocialBond] = []
	for node in get_tree().get_nodes_in_group(&"creature_bonds"):
		if node is CreatureSocialBond:
			var b: CreatureSocialBond = node
			if b._creature != null and _creature.global_position.distance_to(b._creature.global_position) <= bond_radius:
				result.append(b)
	return result

## Compatibility: same element affinity or complementary types score high.
func _compatibility_score(other: Creature) -> int:
	var score: int = 0
	if _creature.has_method("get_element") and other.has_method("get_element"):
		if _creature.get_element() == other.get_element():
			score += 3
	if _creature.has_method("get_type") and other.has_method("get_type"):
		if _creature.get_type() != other.get_type():
			score += 2  # different species = more interesting pair
	return score

func _apply_happiness() -> void:
	if _creature.has_node("CreatureNeeds"):
		var needs: Node = _creature.get_node("CreatureNeeds")
		if needs.has_method("add_happiness"):
			needs.add_happiness(happiness_bonus)
	if _partner_creature != null and _partner_creature.has_node("CreatureNeeds"):
		var pneeds: Node = _partner_creature.get_node("CreatureNeeds")
		if pneeds.has_method("add_happiness"):
			pneeds.add_happiness(happiness_bonus)

func _break_bond() -> void:
	if not _bonded:
		return
	_bonded = false
	if _partner != null:
		_partner._bonded = false
		_partner._partner = null
		_partner._partner_creature = null
	_partner = null
	_partner_creature = null
	_coop_ready = false
	_cooldown = rebond_cooldown
	bond_broken.emit(self)

func get_partner_creature() -> Creature:
	return _partner_creature

func is_bonded() -> bool:
	return _bonded

# --- Build on CreatureBonding (existing global) to persist the pair ---
func _on_bond_changed() -> void:
	# CreatureBonding is a class_name (RefCounted), not an autoload, and has
	# no record_bond method; bond persistence is handled by the bonding node.
	pass

func _process_bonding_sync(delta: float) -> void:
	# No-op placeholder; bond state is reported via signals to CreatureBonding.
	pass
