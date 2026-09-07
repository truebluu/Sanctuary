# AutoFeeder — Sanctuary (Bluu Ink Studios)
# Automatically feeds creatures in the 'creature' group when their hunger
# drops below a threshold. Pulls food from the Inventory node in the
# 'inventory' group. Emits creature_fed on each successful feed.
class_name AutoFeeder
extends Node

## Emitted when a creature is successfully fed.
signal creature_fed(creature_name: String, food_used: int)

## Seconds between feeding checks.
@export var feeding_interval: float = 5.0
## Only feed creatures whose hunger is at or below this (0..1 scale).
@export var min_hunger_to_feed: float = 0.35
## Amount of food item to consume per feed action.
@export var food_amount: int = 1
## Food item id to consume from inventory (snake_case, e.g. "raw_fish").
@export var food_item_id: String = "raw_fish"

var _timer_accumulator: float = 0.0
var _inventory: Object = null
var _is_active: bool = true

func _ready() -> void:
	# Locate the inventory singleton/group member.
	# Uses get_first_node_in_group for compatibility with autoload or scene-placed Inventory.
	var inv_nodes := get_tree().get_nodes_in_group("inventory")
	if inv_nodes.size() > 0:
		_inventory = inv_nodes[0]
	else:
		push_warning("AutoFeeder: no node in group 'inventory' found; feeding will fail until one exists")
	
	# If a Timer node is present as a child, connect its timeout for an alternative trigger.
	# This allows designers to drive feeding via a Timer instead of _process accumulation.
	var timer_node: Timer = get_node_or_null("FeedTimer")
	if timer_node:
		timer_node.timeout.connect(_on_feed_timer_timeout)
		# Ensure timer interval matches our exported setting.
		timer_node.wait_time = feeding_interval
		timer_node.autostart = true

func _process(delta: float) -> void:
	if not _is_active:
		return
	
	# Guard against massive dt spikes (e.g., debugger pause, focus loss).
	# Clamp delta to a sane max so we don't run hundreds of feed cycles in one frame.
	delta = min(delta, 0.5)
	
	_timer_accumulator += delta
	if _timer_accumulator >= feeding_interval:
		_timer_accumulator = fmod(_timer_accumulator, feeding_interval)
		_run_feeding_cycle()

func _run_feeding_cycle() -> void:
	"""Find hungry creatures and attempt to feed each one."""
	var hungry_creatures := _find_hungry_creatures()
	for creature in hungry_creatures:
		# _feed_creature returns true only if food was actually consumed.
		_feed_creature(creature)

func _find_hungry_creatures() -> Array:
	"""
	Returns all nodes in the 'creature' group that have a CreatureNeeds component
	and whose current hunger is at or below min_hunger_to_feed.
	"""
	var result: Array = []
	var creatures := get_tree().get_nodes_in_group("creature")
	
	for c in creatures:
		# Safely check for CreatureNeeds (RefCounted) via get_node or duck-typed method.
		var needs: Object = _get_creature_needs(c)
		
		if needs and _get_hunger(needs) <= min_hunger_to_feed:
			result.append(c)
	
	return result

func _get_creature_needs(node: Node) -> Object:
	"""Helper to find CreatureNeeds on a creature node. Returns null if not found."""
	# Case 1: CreatureNeeds is a child node named "CreatureNeeds" or "Needs".
	if node.has_node("CreatureNeeds"):
		var child := node.get_node("CreatureNeeds")
		if _is_creature_needs(child):
			return child
	elif node.has_node("Needs"):
		var child := node.get_node("Needs")
		if _is_creature_needs(child):
			return child
	# Case 2: The node itself has the CreatureNeeds script (duck type via has_method).
	elif node.has_method("get_hunger") and _is_creature_needs(node):
		return node
	return null

func _is_creature_needs(obj: Object) -> bool:
	"""Runtime check if object is a CreatureNeeds instance."""
	return obj is CreatureNeeds

func _get_hunger(needs: Object) -> float:
	"""Safely call get_hunger on a CreatureNeeds object."""
	if needs and needs.has_method("get_hunger"):
		return needs.get_hunger()
	return 1.0  # Default to full if something is wrong

func _feed_creature(creature: Node) -> bool:
	"""
	Attempts to feed a single creature.
	Returns true if food was consumed from inventory and creature was fed.
	"""
	# Null guard.
	if not creature:
		return false
	
	# Resolve the CreatureNeeds instance.
	var needs: Object = _get_creature_needs(creature)
	
	if not needs:
		push_warning("AutoFeeder: creature '%s' has no CreatureNeeds; skipping" % creature.name)
		return false
	
	# Double-check hunger (may have changed since _find_hungry_creatures ran).
	if _get_hunger(needs) > min_hunger_to_feed:
		return false
	
	# Ensure we have inventory and food.
	if not _inventory:
		_refill_inventory()
		if not _inventory:
			return false
	
	# Check if inventory has the food (using duck typing for has method).
	if not _inventory.has_method("has") or not _inventory.has(food_item_id, food_amount):
		# Not enough food; could auto-refill here if a supplier exists.
		return false
	
	# Consume food from inventory (duck typing for remove method).
	if not _inventory.has_method("remove"):
		return false
	var removed: int = _inventory.remove(food_item_id, food_amount)
	if removed <= 0:
		return false
	
	# Feed the creature (raises hunger + trust) - duck typing for feed method.
	if needs.has_method("feed"):
		needs.feed()
	
	# Emit signal for HUD/logging.
	creature_fed.emit(creature.name, removed)
	return true

func _refill_inventory() -> void:
	"""
	Attempts to (re)locate the Inventory node in the 'inventory' group.
	Call this if _inventory is null or was freed.
	"""
	var inv_nodes := get_tree().get_nodes_in_group("inventory")
	if inv_nodes.size() > 0:
		var inv_obj := inv_nodes[0]
		# Use has_method check as a runtime duck-type guard since static analyzer
		# doesn't recognize Inventory class_name from get_nodes_in_group return type.
		if inv_obj.has_method("has") and inv_obj.has_method("remove"):
			_inventory = inv_obj
		else:
			_inventory = null
			push_warning("AutoFeeder: _refill_inventory found 'inventory' group member but not an Inventory instance")
	else:
		_inventory = null
		push_warning("AutoFeeder: _refill_inventory found no 'inventory' group members")

func _on_feed_timer_timeout() -> void:
	"""Callback when a child Timer node fires; runs one feeding cycle."""
	_run_feeding_cycle()

## Public API

func set_active(active: bool) -> void:
	"""Enable or disable automatic feeding."""
	_is_active = active

func is_active() -> bool:
	return _is_active

func force_feed_all() -> int:
	"""Immediately run a feeding cycle and return number of creatures fed."""
	var count: int = 0
	var hungry := _find_hungry_creatures()
	for c in hungry:
		if _feed_creature(c):
			count += 1
	return count

func get_inventory() -> Object:
	return _inventory