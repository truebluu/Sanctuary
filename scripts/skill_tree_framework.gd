# SkillTreeFramework — Sanctuary (Bluu Ink Studios)
# SANCTUARY-012: Modular Creature Skill Tree framework for the taming subsystem.
# Pure logic (RefCounted) — headless-testable, serializable, wired to personality traits.
class_name SkillTreeFramework
extends RefCounted

## Emitted when a skill node is unlocked (creature_id, node_id, stat_modifiers_applied).
signal skill_unlocked(creature_id: String, node_id: String, stat_modifiers: Dictionary)
## Emitted when XP is granted to a creature (creature_id, xp_granted, total_xp).
signal xp_granted(creature_id: String, xp_granted: int, total_xp: int)
## Emitted when a skill becomes available (prerequisites met, creature has enough XP).
signal skill_available(creature_id: String, node_id: String)

## A single skill node in the tree.
class SkillNode:
	var id: String
	var display_name: String
	var unlock_conditions: Dictionary      # e.g. {"min_bond": 0.5, "trait:boldness": 0.6}
	var xp_cost: int
	var stat_modifiers: Dictionary         # e.g. {"hp": 10, "atk": 5, "element_power": 0.15}
	var prerequisites: Array               # other node ids that must be learned first
	var category: String                   # e.g. "combat", "utility", "social", "elemental"
	var learned: bool = false              # runtime state per creature

	func _init(p_id: String, p_display_name: String, p_unlock_conditions: Dictionary,
			p_xp_cost: int, p_stat_modifiers: Dictionary, p_prerequisites: Array,
			p_category: String) -> void:
		id = p_id
		display_name = p_display_name
		unlock_conditions = p_unlock_conditions
		xp_cost = p_xp_cost
		stat_modifiers = p_stat_modifiers
		prerequisites = p_prerequisites
		category = p_category

## Internal storage
var _nodes: Dictionary = {}                    # node_id -> SkillNode
var _creature_xp: Dictionary = {}              # creature_id -> accumulated XP (int)
var _creature_learned: Dictionary = {}         # creature_id -> Set[node_id] (learned nodes)
var _creature_trait_expressions: Dictionary = {} # creature_id -> CreatureTraitExpression

## Load a skill tree from a dictionary (resource format).
## Expected schema:
## {
##   "nodes": {
##     "node_id": {
##       "display_name": "...",
##       "unlock_conditions": {...},
##       "xp_cost": 100,
##       "stat_modifiers": {...},
##       "prerequisites": ["other_node_id"],
##       "category": "combat"
##     },
##     ...
##   }
## }
func load_tree(tree_data: Dictionary) -> void:
	_nodes.clear()
	if not tree_data.has("nodes"):
		push_error("SkillTreeFramework.load_tree: missing 'nodes' key")
		return
	for node_id in tree_data.nodes:
		var nd: Dictionary = tree_data.nodes[node_id]
		var preqs: Array[String] = []
		for p in (nd.get("prerequisites", []) as Array):
			preqs.append(str(p))
		var node = SkillNode.new(
			node_id,
			nd.get("display_name", node_id),
			nd.get("unlock_conditions", {}),
			int(nd.get("xp_cost", 0)),
			nd.get("stat_modifiers", {}),
			preqs,
			nd.get("category", "general")
		)
		_nodes[node_id] = node

## Grant XP to a creature.
func grant_xp(creature_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var current: int = _creature_xp.get(creature_id, 0)
	_creature_xp[creature_id] = current + amount
	xp_granted.emit(creature_id, amount, _creature_xp[creature_id])
	# Check for newly available skills
	_check_availability(creature_id)

## Get total accumulated XP for a creature.
func get_xp(creature_id: String) -> int:
	return _creature_xp.get(creature_id, 0)

## Set/associate a CreatureTraitExpression for a creature (for unlock_conditions evaluation).
func set_trait_expression(creature_id: String, expression: CreatureTraitExpression) -> void:
	_creature_trait_expressions[creature_id] = expression

## Get all nodes whose prerequisites are met AND creature has enough XP.
## Returns Array[SkillNode] (copies with learned state for this creature).
func get_available_nodes(creature_id: String) -> Array:
	var available: Array = []
	var learned_set: Array = _creature_learned.get(creature_id, [])
	var xp: int = get_xp(creature_id)
	var traits: CreatureTraitExpression = _creature_trait_expressions.get(creature_id)

	for node_id in _nodes:
		var node: SkillNode = _nodes[node_id]
		if node_id in learned_set:
			continue
		if not _prerequisites_met(creature_id, node, learned_set):
			continue
		if not _unlock_conditions_met(node, traits):
			continue
		if xp < node.xp_cost:
			continue
		# Return a shallow copy with this creature's learned state
		var copy = SkillNode.new(
			node.id, node.display_name, node.unlock_conditions.duplicate(true),
			node.xp_cost, node.stat_modifiers.duplicate(true),
			node.prerequisites.duplicate(), node.category
		)
		copy.learned = false
		available.append(copy)

	return available

## Unlock a node for a creature. Applies stat modifiers, marks learned, spends XP.
## Returns true on success, false if unavailable or already learned.
func unlock(creature_id: String, node_id: String) -> bool:
	if not _nodes.has(node_id):
		push_error("SkillTreeFramework.unlock: node '%s' not found" % node_id)
		return false
	var node: SkillNode = _nodes[node_id]
	var learned_set: Array = _creature_learned.get(creature_id, [])
	if node_id in learned_set:
		return false
	if not _prerequisites_met(creature_id, node, learned_set):
		return false
	var traits: CreatureTraitExpression = _creature_trait_expressions.get(creature_id)
	if not _unlock_conditions_met(node, traits):
		return false
	var xp: int = get_xp(creature_id)
	if xp < node.xp_cost:
		return false

	# Spend XP
	_creature_xp[creature_id] = xp - node.xp_cost
	# Mark learned
	learned_set.append(node_id)
	_creature_learned[creature_id] = learned_set
	# Emit
	skill_unlocked.emit(creature_id, node_id, node.stat_modifiers.duplicate(true))
	# Check for newly available skills
	_check_availability(creature_id)
	return true

## Check if a node is already learned by a creature.
func is_learned(creature_id: String, node_id: String) -> bool:
	var learned_set: Array = _creature_learned.get(creature_id, [])
	return node_id in learned_set

## Get all learned nodes for a creature (copies with learned=true).
func get_learned_nodes(creature_id: String) -> Array:
	var learned_set: Array = _creature_learned.get(creature_id, [])
	var result: Array = []
	for node_id in learned_set:
		if _nodes.has(node_id):
			var node: SkillNode = _nodes[node_id]
			var copy = SkillNode.new(
				node.id, node.display_name, node.unlock_conditions.duplicate(true),
				node.xp_cost, node.stat_modifiers.duplicate(true),
				node.prerequisites.duplicate(), node.category
			)
			copy.learned = true
			result.append(copy)
	return result

## Get a node by id (copy).
func get_node(node_id: String) -> SkillNode:
	if not _nodes.has(node_id):
		return null
	var node: SkillNode = _nodes[node_id]
	return SkillNode.new(
		node.id, node.display_name, node.unlock_conditions.duplicate(true),
		node.xp_cost, node.stat_modifiers.duplicate(true),
		node.prerequisites.duplicate(), node.category
	)

## Get all node ids in a category.
func get_nodes_by_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for node_id in _nodes:
		if _nodes[node_id].category == category:
			result.append(node_id)
	return result

## Serialize the entire framework state (tree + creature progress) to a dictionary.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	var nodes_out: Dictionary = {}
	for node_id in _nodes:
		var node: SkillNode = _nodes[node_id]
		nodes_out[node_id] = {
			"display_name": node.display_name,
			"unlock_conditions": node.unlock_conditions.duplicate(true),
			"xp_cost": node.xp_cost,
			"stat_modifiers": node.stat_modifiers.duplicate(true),
			"prerequisites": node.prerequisites.duplicate(),
			"category": node.category
		}
	out["nodes"] = nodes_out

	var creatures_out: Dictionary = {}
	for creature_id in _creature_xp:
		creatures_out[creature_id] = {
			"xp": _creature_xp[creature_id],
			"learned": _creature_learned.get(creature_id, []).duplicate()
		}
	out["creatures"] = creatures_out
	return out

## Load framework state from a dictionary (round-trip with to_dict).
func from_dict(data: Dictionary) -> void:
	_nodes.clear()
	_creature_xp.clear()
	_creature_learned.clear()

	if data.has("nodes"):
		for node_id in data.nodes:
			var nd: Dictionary = data.nodes[node_id]
			var node = SkillNode.new(
				node_id,
				nd.get("display_name", node_id),
				nd.get("unlock_conditions", {}),
				int(nd.get("xp_cost", 0)),
				nd.get("stat_modifiers", {}),
				nd.get("prerequisites", []),
				nd.get("category", "general")
			)
			_nodes[node_id] = node

	if data.has("creatures"):
		for creature_id in data.creatures:
			var cd: Dictionary = data.creatures[creature_id]
			_creature_xp[creature_id] = int(cd.get("xp", 0))
			_creature_learned[creature_id] = cd.get("learned", []).duplicate()

## Clear all data.
func clear() -> void:
	_nodes.clear()
	_creature_xp.clear()
	_creature_learned.clear()
	_creature_trait_expressions.clear()

## Get count of registered nodes.
func get_node_count() -> int:
	return _nodes.size()

## Get count of creatures with tracked XP.
func get_creature_count() -> int:
	return _creature_xp.size()

## ===========================================================================
## Internal Helpers
## ===========================================================================

func _prerequisites_met(creature_id: String, node: SkillNode, learned_set: Array) -> bool:
	for prereq in node.prerequisites:
		if prereq not in learned_set:
			return false
	return true

func _unlock_conditions_met(node: SkillNode, traits: CreatureTraitExpression) -> bool:
	if not traits:
		# No trait expression provided; only non-trait conditions can pass
		for key in node.unlock_conditions:
			if key.begins_with("trait:"):
				return false
		return true

	for condition_key in node.unlock_conditions:
		var required: float = float(node.unlock_conditions[condition_key])
		if condition_key == "min_bond":
			# Bond is not directly in CreatureTraitExpression; could be a trait or external
			# For now, treat as expression_level threshold
			if traits.expression_level() < required:
				return false
		elif condition_key.begins_with("trait:"):
			var trait_name: StringName = condition_key.substr(6) # after "trait:"
			if traits.get_trait(trait_name) < required:
				return false
		elif condition_key == "expression_level":
			if traits.expression_level() < required:
				return false
		else:
			# Unknown condition type; conservatively fail
			push_warning("SkillTreeFramework: unknown unlock condition '%s'" % condition_key)
			return false
	return true

func _check_availability(creature_id: String) -> void:
	var available = get_available_nodes(creature_id)
	for node in available:
		skill_available.emit(creature_id, node.id)