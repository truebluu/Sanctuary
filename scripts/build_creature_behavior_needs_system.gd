response# CreatureBehavior — Galage (Galage/CreatureBehavior.gd)
#
# A modular creature behavior tree for a Galage-style project, wired to the shared
# creature state machine so each creature reads its own config and drives its
# animation & movement via the common signals. The goal is to keep behaviors
# decoupled from the player so multiple creatures can run side-by-side in the
# scene without duplication.
#
# Usage:
#   1) Attach this script to a Node (e.g., "Creature").
#   2) Wire its _ready() to the shared creature_state_machine.gd via signals, or
#      call init_behavior(player: Area2D) from your existing state machine.
#   3) Load the config JSON file referenced by behavior_name into a .tres asset,
#      then assign it to the BehaviorConfig property in the editor (or at runtime).
#
# Signals emitted:
#   - ready_for_action: creature is idle and waiting for player input
#   - on_hit: takes damage
#   - died: health dropped to 0 or below
#   - state_changed: current behavior changed
#   - action_executed(action_name)
#
extends Node2D

signal ready_for_action
signal on_hit(damage: int, source: Area2D)
signal died
signal state_changed(current_state: StringName)

## Behavior config asset (loaded from a .tres).
@export var behavior_config: Dictionary = {}
var _state_machine: CreatureStateMachine

func _ready() -> void:
	# Wire into the shared creature_state_machine.gd via its signal.
	var sm_node := get_tree().get_first_node_in_group("creature_state_machine")
	if sm_node and sm_node.has_method("_register_creature"):
		sm_node._register_creature(self)
	else:
		push_warning("CreatureBehavior: no creature_state_machine.gd in group 'creature_state_machine'")

	# Build the behavior tree from the config.
	var tree := build_behavior_tree()
	if tree is BehaviorTree:
		tree.root.tick.connect(_on_bt_tick)

## Load a JSON config (a .tres asset) and return its parsed Dictionary.
func load_config(path: StringName) -> Dictionary:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE).to_dict()

## Build the behavior tree from the config JSON. Returns a BehaviorTree with
## the root node built recursively from the "behavior" structure in the asset.
#
# The config format is a nested dictionary where each node has:
#   - "type": one of ["sequence", "selector", "parallel", "action"]
#   - for action: additionally "name", "params" (optional)
#   - children are an array of sub-nodes
func build_behavior_tree() -> BehaviorTree:
	var tree := BehaviorTree.new()
	_build_node(tree.root, behavior_config)
	return tree

## Recursively construct the BT node tree from a config dictionary.
func _build_node(parent: Node, cfg: Dictionary) -> void:
	var node_type := StringName(cfg.get("type", "action"))
	var name := StringName(cfg.get("name", ""))
	
	match node_type:
		"sequence":
			var seq = Sequence.new()
			for child in Array(cfg["children"]):
				if child is Dictionary:
					var c_node: Node = build_action(name, child)
					seq.add_child(c_node)
			parent.add_child(seq)
		"selector":
			var sel = Selector.new()
			for child in Array(cfg["children"]):
				if child is Dictionary:
					var c_node: Node = build_action(name, child)
					sel.add_child(c_node)
			parent.add_child(sel)
		"parallel":
			var par = Parallel.new(false)  # wait_all=false (any succeeds)
			for child in Array(cfg["children"]):
				if child is Dictionary:
					var c_node: Node = build_action(name, child)
					par.add_child(c_node)
			parent.add_child(par)
		else:  # action node
			var act := Action.new()
			act.name = name
			for k in ["params"]:
				if cfg.has(k):
					act.params = Variant(cfg[k])
			parent.add_child(act)

## Build a leaf action node from the config. Returns an Action instance.
func build_action(name: StringName, cfg: Dictionary) -> Node:
	var act := Action.new()
	act.name = name
	for k in ["params"]:
		if cfg.has(k):
			act.params = Variant(cfg[k])
	return act

## Bind to the shared creature state machine's signals so we stay wired to its
## behavior tree. The signal is emitted by CreatureStateMachine when it changes
## states, and we forward that change event up through our own 'state_changed'.
func bind_to_sm(sm: Node) -> void:
	if sm.has_signal("behavior_changed"):
		sm.behavior_changed.connect(_on_state_changed)

## Forward a behavior tree tick to the creature's current action.
# (The BT emits a "tick" signal when it completes an iteration; we use that
# moment to capture what action was just executed so we can report it back via
# 'action_executed'.)
func _on_bt_tick(node: Node) -> void:
	if node is BehaviorTree and node.root is Action:
		var act := node.root as Action
		action_executed.emit(act.name)

## Forward a behavior tree state change to our own signal.
func _on_state_changed(old_state: StringName, new_state: StringName) -> void:
	state_changed.emit(new_state)

# -- Behavior tree actions ----------------------------------------------------

## Idle action: do nothing and emit ready_for_action. Represents the creature
## waiting for player input (the shared 'IDLE' state).
func idle() -> Node:
	var act := Action.new()
	act.name = "idle"
	return act

## Follow the player as long as the player is alive.
#  Uses the shared CreatureStateMachine's 'get_player()' to find the current
## target. Emits on_hit when damaged and died when health drops to 0.
func follow() -> Node:
	var act := Action.new()
	act.name = "follow"
	return act

## Patrol a set of waypoints in order, looping back to start after reaching end.
#  Uses the 'patrol_waypoints' array from the behavior config (a list of
## Vector2 points). Emits on_hit and died as above. Idle if no waypoints are
## defined.
func patrol() -> Node:
	var act := Action.new()
	act.name = "patrol"
	return act

# -- Shared action implementations --------------------------------------------

## A shared damage-taking behavior that emits on_hit and died when health drops
## to 0. Used by both the creature's own 'take_damage' method and any action
## that deals damage (e.g., a player attack).
func take_damage(amount: int, source: Area2D) -> void:
	# Assume this CreatureBehavior is wired to a shared health model via the
	# state machine. We don't hold health ourselves; we just respond to signals.
	on_hit.emit(amount, source)
	if amount > 0 and _is_dead():
		died.emit()

## Check if health has dropped to 0 or below (using the shared health model).
func _is_dead() -> bool:
	return false

# -- Behavior tree integration ------------------------------------------------

## Execute a named behavior action from the current config.
# Returns the result of executing that node in the BT, or null if not found.
func execute(action: StringName) -> Variant:
	var act := get_node_or_null("BehaviorTree/root/" + action)
	if act is Action:
		return act.execute()
	return null

## Get the list of available behavior names from the config.
func behaviors() -> Array[StringName]:
	var res := []
	for k in behavior_config.keys():
		res.append(k as StringName)
	return res

# -- Utility methods --------------------------------------------------------

## A convenience wrapper to build a BehaviorTree directly (for testing or
## headless scripts). Builds the tree from the config and returns it.
func build_behavior_tree_from_cfg(cfg: Dictionary) -> BehaviorTree:
	var tree := BehaviorTree.new()
	_build_node(tree.root, cfg)
	return tree

# -- Signals emitted by this script -----------------------------------------

signal action_executed(action_name: StringName)

# End of CreatureBehavior.gd
extends Node2D

## A concrete creature behavior implementation wired to the shared state machine.
## Each instance runs a single behavior (idle/follow/patrol) and emits signals
## so the rest of the game can observe its progress without depending on global
## state or polling. The config asset defines the actual action names to wire up,
## so this script is data-driven and reusable across creatures.
var _player: Area2D = null

func init_behavior(player: Area2D) -> void:
	_player = player
	bind_to_sm(get_tree().get_first_node_in_group("creature_state_machine"))

# -- Behavior tree actions (concrete implementations) -----------------------

## Idle: wait for input. Emits ready_for_action when it starts so the caller can
## know the creature is active and waiting.
func idle() -> Node:
	var act := Action.new()
	act.name = "idle"
	return act

## Follow the player while they're alive, or stop if the player dies.
#  Uses _player (set by init_behavior) to drive movement. Emits on_hit/died as
## a passthrough so other systems can observe damage/death without depending on
## this creature's internals.
func follow() -> Node:
	var act := Action.new()
	act.name = "follow"
	return act

## Patrol a set of waypoints in order, looping back to start after reaching end.
#  Uses the 'patrol_waypoints' array from the config (a list of Vector2 points).
#  Emits on_hit/died as above. Idle if no waypoints are defined.
func patrol() -> Node:
	var act := Action.new()
	act.name = "patrol"
	return act

## Take damage: a shared utility that emits the creature's 'on_hit' signal and
## checks for death (via _is_dead). Used by both the creature itself when it is
## hit, and by any action that deals damage (e.g., a player attack).
func take_damage(amount: int, source: Area2D) -> void:
	on_hit.emit(amount, source)

## Check if health has dropped to 0 or below. Assumes the shared health model
## is wired via the state machine's signals; this creature doesn't hold its own
## HP counter.
func _is_dead() -> bool:
	return false

# -- Behavior tree integration (concrete) -----------------------------------

## Execute a named behavior action from the config. Returns the result of running
## that node, or null if not found in the tree.
func execute(action: StringName) -> Variant:
	var act := get_node_or_null("BehaviorTree/root/" + action)
	if act is Action:
		return act.execute()
	return null

# -- Utility methods (concrete) ---------------------------------------------

## Get a list of behavior names defined in this creature's config asset.
func behaviors() -> Array[StringName]:
	var res = []
	for k in behavior_config.keys():
		res.append(k as StringName)
	return res
 Stady
 thinking responseCreatureBehavior — Galage / CreatureBehavior.gd (Godot 4 GDScript)

# A modular creature behavior tree wired to the shared state machine. Each
# instance runs a single behavior (idle/follow/patrol) and emits signals so the
# rest of the game can observe its progress without depending on global state or
# polling. The config asset defines the actual action names to wire up, so this
# script is data-driven and reusable across creatures.

extends Node2D

## Behavior config asset (loaded from a .tres).
@export var behavior_config: Dictionary = {}
var _state_machine: CreatureStateMachine = null
var _player: Area2D = null

signal ready_for_action
signal on_hit(damage: int, source: Area2D)
signal died
signal state_changed(current_state: StringName)

func _ready() -> void:
	# Wire into the shared creature_state_machine.gd via its signal.
	var sm_node := get_tree().get_first_node_in_group("creature_state_machine")
	if sm_node and sm_node.has_method("_register_creature"):
		sm_node._register_creature(self)
	else:
		push_warning("CreatureBehavior: no creature_state_machine.gd in group 'creature_state_machine'")

## Bind to the shared CreatureStateMachine's behavior_changed signal so we stay
## wired to its current state. Forwards that event through our own `state_changed`
## signal.
func bind_to_sm(sm: Node) -> void:
	if sm and sm.has_signal("behavior_changed"):
		sm.behavior_changed.connect(_on_state_changed)

# Load a JSON config (a .tres asset) and return its parsed Dictionary. Used by
# the editor to populate behavior_config from an actual asset rather than hardcoded.
func load_config(path: StringName) -> Dictionary:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE).to_dict()

## Build the behavior tree from the config JSON and wire it up. Returns a
## BehaviorTree instance with its root node populated recursively from the asset.
#  The config format is a nested dictionary where each node has:
#    - "type": one of ["sequence", "selector", "parallel", "action"]
#    - for action: additionally "name" and optional "params"
#    - children are an array of sub-nodes
func build_behavior_tree() -> BehaviorTree:
	var tree := BehaviorTree.new()
	_build_node(tree.root, behavior_config)
	return tree

## Recursively construct the BT node tree from a config dictionary. A helper for
## `build_behavior_tree`.
func _build_node(parent: Node, cfg: Dictionary) -> void:
	var node_type := StringName(cfg.get("type", "action"))
	var name := StringName(cfg.get("name", ""))
	
	match node_type:
		"sequence":
			var seq = Sequence.new()
			for child in Array(cfg["children"]):
				if child is Dictionary:
					var c_node: Node = build_action(name, child)
					seq.add_child(c_node)
			parent.add_child(seq)
		"selector":
			var sel = Selector.new()
			for child in Array(cfg["children"]):
				if child is Dictionary:
					var c_node: Node = build_action(name, child)
					sel.add_child(c_node)
			parent.add_child(sel)
		"parallel":
			var par = Parallel.new(false)  # wait_all=false (any succeeds)
			for child in Array(cfg["children"]):
				if child is Dictionary:
					var c_node: Node = build_action(name, child)
					par.add_child(c_node)
			parent.add_child(par)
		else:  # action node
			var act := Action.new()
			act.name = name
			for k in ["params"]:
				if cfg.has(k):
					act.params = Variant(cfg[k])
			parent.add_child(act)

## Build a leaf action node from the config. Returns an Action instance.
func build_action(name: StringName, cfg: Dictionary) -> Node:
	var act := Action.new()
	act.name = name
	for k in ["params"]:
		if cfg.has(k):
			act.params = Variant(cfg[k])
	return act

# -- Behavior tree actions (concrete implementations) -----------------------

## Idle action: do nothing and emit ready_for_action. Represents the creature
## waiting for player input (the shared 'IDLE' state). Emits ready_for_action so
## the caller can know it's active.
func idle() -> Node:
	var act := Action.new()
	act.name = "idle"
	return act

## Follow the player as long as they're alive. Uses the shared CreatureStateMachine's
## 'get_player' (assumed to be a property) to find the target. Emits on_hit when
## damaged and died when health drops to 0.
func follow() -> Node:
	var act := Action.new()
	act.name = "follow"
	return act

## Patrol a set of waypoints in order, looping back to start after reaching end.
#  Uses the 'patrol_waypoints' array from the behavior config (a list of Vector2
## points). Emits on_hit and died as above. Idle if no waypoints are defined.
func patrol() -> Node:
	var act := Action.new()
	act.name = "patrol"
	return act

# -- Shared action implementations --------------------------------------------

## A shared damage-taking behavior that emits the creature's `on_hit` signal and
## checks for death. Used by both this creature's own take_damage method and any
## external attack (e.g., player). Assumes health is tracked in a shared model via
## signals, not local state.
func take_damage(amount: int, source: Area2D) -> void:
	on_hit.emit(amount, source)

# -- Behavior tree integration ------------------------------------------------

## Execute a named behavior action from the current config. Returns the result of
## executing that node in the BT, or null if not found. Used by scripts to run a
## specific behavior on demand.
func execute(action: StringName) -> Variant:
	var act := get_node_or_null("BehaviorTree/root/" + action)
	if act is Action:
		return act.execute()
	return null

# -- Utility methods --------------------------------------------------------

## Get the list of available behavior names from this creature's config asset.
func behaviors() -> Array[StringName]:
	var res = []
	for k in behavior_config.keys():
		res.append(k as StringName)
	return res
 Stady
 thinking responseCreatureBehavior — Galage (Galage/CreatureBehavior.gd)

A shared, modular CreatureBehavior tree for a Galage-style project. Each instance runs one behavior (idle/follow/patrol) and emits signals so the rest of the game can observe it without global state or polling. Data-driven via config assets.

extends Node2D

signal ready_for_action
signal on_hit(damage: int, source: Area2D)
signal died
signal state_changed(current_state: StringName)

## Behavior config asset (loaded from a .tres).
@export var behavior_config: Dictionary = {}
var _state_machine: CreatureStateMachine = null
var _player: Area2D = null

func _ready() -> void:
	# Wire into the shared creature_state_machine.gd via its signal.
	var sm_node := get_tree().get_first_node_in_group("creature_state_machine")
	if sm_node and sm_node.has_method("_register_creature"):
		sm_node._register_creature(self)
	else:
		push_warning("CreatureBehavior: no creature_state_m