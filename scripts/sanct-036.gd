extends Node
class_name CreatureSocialBonds

## Social bond system for sanctuary creatures.
## Creatures form bonds with each other over time, granting passive sanctuary bonuses.
## Builds on Creature, CreatureNeeds, and the existing sanctuary foundation.

signal bond_formed(creature_a: StringName, creature_b: StringName, bond: int)
signal bond_broken(creature_a: StringName, creature_b: StringName)
signal sanctuary_bonus_changed(bonus: Dictionary)

# --- Tunable constants (one place to change feel) ---
const BOND_CHECK_INTERVAL: float = 12.0        # seconds between bond-roll checks
const BOND_FORM_CHANCE: float = 0.18           # per check, chance a new bond forms
const BOND_STRENGTHEN_CHANCE: float = 0.35     # per check, chance an existing bond deepens
const BOND_DECAY_CHANCE: float = 0.04          # per check, chance a weak bond fades
const MAX_BOND_LEVEL: int = 5                  # highest bond tier
const BOND_REQUIRE_HAPPY: bool = true          # both creatures must be happy to bond

# Bond tier definitions: level -> sanctuary bonus applied
const BOND_TIERS: Dictionary = {
	1: {"name": "Acquaintances", "bonus": {"score_mult": 0.02}},
	2: {"name": "Friends", "bonus": {"score_mult": 0.05, "drop_chance": 0.03}},
	3: {"name": "Close Friends", "bonus": {"score_mult": 0.08, "drop_chance": 0.05, "heal_chance": 0.02}},
	4: {"name": "Best Friends", "bonus": {"score_mult": 0.12, "drop_chance": 0.08, "heal_chance": 0.04}},
	5: {"name": "Soulbound", "bonus": {"score_mult": 0.18, "drop_chance": 0.12, "heal_chance": 0.06, "shield_chance": 0.03}},
}

# --- State ---
var _bonds: Dictionary = {}            # "id_a:id_b" -> {"level": int, "time": float}
var _timer: float = 0.0
var _sanctuary_bonus: Dictionary = {}

func _ready() -> void:
	_process_bonds = false
	_sanitize_bonds()

func _process(delta: float) -> void:
	if not _process_bonds:
		return
	_timer += delta
	if _timer < BOND_CHECK_INTERVAL:
		return
	_timer = 0.0
	_run_bond_cycle()

func _run_bond_cycle() -> void:
	var creatures: Array = _gather_bondable_creatures()
	if creatures.size() < 2:
		return
	# Roll for new bonds among un-bonded pairs
	for i in range(creatures.size()):
		for j in range(i + 1, creatures.size()):
			var a: Node = creatures[i]
			var b: Node = creatures[j]
			var key: String = _bond_key(a, b)
			if _bonds.has(key):
				_eval_existing_bond(a, b, key)
			elif randf() < BOND_FORM_CHANCE:
				_attempt_form_bond(a, b, key)

func _gather_bondable_creatures() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("creature"):
		if node.has_method("is_happy") and node.has_method("get_creature_id"):
			if not BOND_REQUIRE_HAPPY or node.is_happy():
				result.append(node)
	return result

func _bond_key(a: Node, b: Node) -> String:
	var id_a: StringName = a.get_creature_id()
	var id_b: StringName = b.get_creature_id()
	# Canonical ordering so the key is direction-independent
	if id_a < id_b:
		return "%s:%s" % [id_a, id_b]
	return "%s:%s" % [id_b, id_a]

func _attempt_form_bond(a: Node, b: Node, key: String) -> void:
	if BOND_REQUIRE_HAPPY and (not a.is_happy() or not b.is_happy()):
		return
	_bonds[key] = {"level": 1, "time": 0.0}
	var id_a: StringName = a.get_creature_id()
	var id_b: StringName = b.get_creature_id()
	bond_formed.emit(id_a, id_b, 1)
	_recalc_sanctuary_bonus()

func _eval_existing_bond(a: Node, b: Node, key: String) -> void:
	var bond: Dictionary = _bonds[key]
	if randf() < BOND_DECAY_CHANCE and bond["level"] <= 2:
		_bonds.erase(key)
		bond_broken.emit(a.get_creature_id(), b.get_creature_id())
		_recalc_sanctuary_bonus()
		return
	if bond["level"] < MAX_BOND_LEVEL and randf() < BOND_STRENGTHEN_CHANCE:
		bond["level"] += 1
		bond_formed.emit(a.get_creature_id(), b.get_creature_id(), bond["level"])
		_recalc_sanctuary_bonus()

func _recalc_sanctuary_bonus() -> void:
	var bonus: Dictionary = {"score_mult": 0.0, "drop_chance": 0.0, "heal_chance": 0.0, "shield_chance": 0.0}
	for key in _bonds:
		var level: int = _bonds[key]["level"]
		if BOND_TIERS.has(level):
			var tier: Dictionary = BOND_TIERS[level]
			for stat in tier["bonus"]:
				bonus[stat] = bonus.get(stat, 0.0) + tier["bonus"][stat]
	_sanctuary_bonus = bonus
	sanctuary_bonus_changed.emit(bonus)

func get_bond_level(id_a: StringName, id_b: StringName) -> int:
	var key: String = _bond_key_from_ids(id_a, id_b)
	if _bonds.has(key):
		return _bonds[key]["level"]
	return 0

func _bond_key_from_ids(id_a: StringName, id_b: StringName) -> String:
	if id_a < id_b:
		return "%s:%s" % [id_a, id_b]
	return "%s:%s" % [id_b, id_a]

func get_sanctuary_bonus() -> Dictionary:
	return _sanctuary_bonus.duplicate()

func _sanitize_bonds() -> void:
	# Remove bonds referencing creatures no longer in the sanctuary
	var stale: Array = []
	for key in _bonds:
		var ids: PackedStringArray = key.split(":")
		var found: bool = false
		for node in get_tree().get_nodes_in_group("creature"):
			if node.has_method("get_creature_id") and (node.get_creature_id() == ids[0] or node.get_creature_id() == ids[1]):
				found = true
				break
		if not found:
			stale.append(key)
	for key in stale:
		_bonds.erase(key)

# --- Public API for the sanctuary to drive the system ---
func enable_bonds() -> void:
	_process_bonds = true

func disable_bonds() -> void:
	_process_bonds = false

func is_bonded(id_a: StringName, id_b: StringName) -> bool:
	return _bonds.has(_bond_key_from_ids(id_a, id_b))

func reset_all_bonds() -> void:
	_bonds.clear()
	_recalc_sanctuary_bonus()

# Feel note: Social bonds add emergent sanctuary depth — creatures you keep together
# grow closer and passively buff your combat run. Builds on Creature needs (happiness
# gates bonding) and feeds bonuses into the player's score/drop/heal chances.