# CreatureFeedingUI.gd
# Interactive feeding interface with food selection.
# Builds on the existing CreatureNeeds system and the sanctuary feeding minigame.
# Feel: gives the player agency over which food to give, making each feeding choice
# meaningful (hunger vs happiness vs cost). Integrates with the sanctuary UI layer.
# Tunables are grouped at the top for one-setting changes.

extends Control
class_name CreatureFeedingUI

## --- Tunables (one-setting changes) ---
const DEFAULT_FOOD_ICON := "res://art/repair_kit_px.png"  # Placeholder; real icons per food type
const MAX_FOOD_ITEMS := 6  # Hard limit on selectable food options per UI open
const FEED_COOLDOWN := 0.5  # Seconds between feed actions to prevent spam

## --- Exports (designer-facing) ---
@export var creature_group := "creature"  # Group the target creature belongs to
@export var food_items: Array[Dictionary] = [
	{
		"id": "basic_pellets",
		"name": "Basic Pellets",
		"hunger_restore": 20,
		"happiness_restore": 5,
		"cost": 0,
		"icon": "res://art/repair_kit_px.png"
	},
	{
		"id": "premium_blend",
		"name": "Premium Blend",
		"hunger_restore": 40,
		"happiness_restore": 15,
		"cost": 10,
		"icon": "res://art/powerup_weapon_px.png"
	},
	{
		"id": "gourmet_meal",
		"name": "Gourmet Meal",
		"hunger_restore": 60,
		"happiness_restore": 30,
		"cost": 25,
		"icon": "res://art/score_multiplier_px.png"
	}
]  # Each entry: id, name, hunger_restore, happiness_restore, cost, icon

## --- Internal state ---
var _creature: Node = null
var _selected_food: Dictionary = {}
var _last_feed_time := 0.0

## --- UI references (set via scene) ---
@onready var _food_list: VBoxContainer = $FoodList
@onready var _status_label: Label = $StatusLabel
@onready var _feed_button: Button = $FeedButton
@onready var _close_button: Button = $CloseButton

## --- Signals ---
signal food_selected(food: Dictionary)
signal feeding_completed(creature: Node, food: Dictionary)
signal feeding_failed(reason: String)

func _ready() -> void:
	# Connect UI signals
	_feed_button.pressed.connect(_on_feed_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	# Find the creature in the group (assumes one creature per UI instance)
	var creatures := get_tree().get_nodes_in_group(creature_group)
	if creatures.is_empty():
		_status_label.text = "No creature found"
		_feed_button.disabled = true
		return
	_creature = creatures[0]
	# Populate food list
	_populate_food_list()
	# Update status
	_update_status()
	# Connect to creature's needs changes if available
	if _creature.has_signal("needs_changed"):
		_creature.needs_changed.connect(_update_status)

func _populate_food_list() -> void:
	# Clear existing children (except the first if it's a template)
	for child in _food_list.get_children():
		child.queue_free()
	# Add food buttons
	var count := 0
	for food in food_items:
		if count >= MAX_FOOD_ITEMS:
			break
		var btn := Button.new()
		btn.text = food.get("name", "Unknown")
		btn.tooltip_text = "Restores %d hunger, %d happiness" % [food.get("hunger_restore", 0), food.get("happiness_restore", 0)]
		btn.pressed.connect(_on_food_button_pressed.bind(food))
		_food_list.add_child(btn)
		count += 1
	# If no food items, show a message
	if count == 0:
		var label := Label.new()
		label.text = "No food available"
		_food_list.add_child(label)

func _on_food_button_pressed(food: Dictionary) -> void:
	_selected_food = food
	food_selected.emit(food)
	_update_status()

func _on_feed_pressed() -> void:
	if _selected_food.is_empty():
		feeding_failed.emit("No food selected")
		_status_label.text = "Select a food first"
		return
	# Cooldown check
	if Time.get_ticks_msec() - _last_feed_time < FEED_COOLDOWN * 1000.0:
		feeding_failed.emit("Feeding too fast")
		_status_label.text = "Too fast! Wait a moment."
		return
	# Validate creature
	if _creature == null or not is_instance_valid(_creature):
		feeding_failed.emit("Creature not available")
		_status_label.text = "Creature missing"
		return
	# Check if creature can be fed (hunger not full)
	if _creature.has_method("is_hungry") and not _creature.is_hungry():
		feeding_failed.emit("Creature is not hungry")
		_status_label.text = "Creature is not hungry"
		return
	# Attempt to feed
	if _creature.has_method("feed"):
		var result = _creature.feed(_selected_food)
		if result is bool and result:
			_last_feed_time = Time.get_ticks_msec()
			feeding_completed.emit(_creature, _selected_food)
			_status_label.text = "Fed %s!" % _selected_food.get("name", "food")
			# Optionally deduct cost from GameState if needed
			_deduct_cost(_selected_food.get("cost", 0))
		else:
			feeding_failed.emit("Feeding failed")
			_status_label.text = "Feeding failed"
	else:
		feeding_failed.emit("Creature has no feed method")
		_status_label.text = "Creature cannot be fed"

func _deduct_cost(cost: int) -> void:
	if cost <= 0:
		return
	# Use GameState if it has a currency system; otherwise ignore
	if GameState.has_method("spend_currency"):
		GameState.spend_currency(cost)
	elif GameState.has_method("add_currency"):
		# If only add exists, we can't deduct; log warning
		push_warning("GameState has no spend_currency method; cost not deducted")
	else:
		push_warning("No currency system found; cost not deducted")

func _update_status() -> void:
	if _creature == null:
		return
	var hunger_text := "N/A"
	var happiness_text := "N/A"
	if _creature.has_method("get_hunger"):
		hunger_text = str(_creature.get_hunger())
	if _creature.has_method("get_happiness"):
		happiness_text = str(_creature.get_happiness())
	var selected_text := "None"
	if not _selected_food.is_empty():
		selected_text = _selected_food.get("name", "Unknown")
	_status_label.text = "Hunger: %s | Happiness: %s | Selected: %s" % [hunger_text, happiness_text, selected_text]

func _on_close_pressed() -> void:
	queue_free()