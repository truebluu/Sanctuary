class_name CreatureMoodIndicator
extends Node2D
## Visual mood indicator (happy/sad/angry) for creatures.
## Builds on the existing happiness meter system (SANCT-019).
## Displays an icon above the creature that changes with its mood.

signal mood_changed(new_mood: Mood)

enum Mood { HAPPY, SAD, ANGRY }

## Tunables – adjust in one place.
@export var happy_threshold: float = 70.0   # happiness >= this => happy
@export var sad_threshold: float = 40.0    # happiness < this => angry, else sad
@export var icon_offset: Vector2 = Vector2(0, -40)  # above creature

## Icon textures for each mood. Assign in the scene or via code.
@export var happy_icon: Texture2D
@export var sad_icon: Texture2D
@export var angry_icon: Texture2D

## Fallback color if no texture is assigned.
@export var happy_color: Color = Color(0.2, 1.0, 0.2)
@export var sad_color: Color = Color(1.0, 0.8, 0.2)
@export var angry_color: Color = Color(1.0, 0.2, 0.2)

var _creature: Node
var _current_mood: Mood = Mood.HAPPY

@onready var _icon: Sprite2D = $Icon
@onready var _color_rect: ColorRect = $ColorRect  # fallback if no texture


func _ready() -> void:
	# Find the parent creature (assumes this node is a child of a Creature).
	_creature = get_parent()
	if _creature == null or not _creature.has_method("get_happiness"):
		push_error("CreatureMoodIndicator must be a child of a Creature node.")
		set_process(false)
		return

	# Connect to relevant signals if they exist.
	if _creature.has_signal("happiness_changed"):
		_creature.happiness_changed.connect(_on_happiness_changed)
	if _creature.has_signal("hunger_changed"):
		_creature.hunger_changed.connect(_on_stat_changed)
	if _creature.has_signal("sickness_changed"):
		_creature.sickness_changed.connect(_on_stat_changed)

	# Initial update.
	_update_mood()
	_update_visual()


func _on_happiness_changed(_value: float) -> void:
	_update_mood()
	_update_visual()


func _on_stat_changed(_value: float) -> void:
	# Mood may depend on hunger/sickness too; re-evaluate.
	_update_mood()
	_update_visual()


func _update_mood() -> void:
	if not _creature or not _creature.has_method("get_happiness"):
		return
	var happiness: float = _creature.get_happiness()
	var new_mood: Mood
	if happiness >= happy_threshold:
		new_mood = Mood.HAPPY
	elif happiness >= sad_threshold:
		new_mood = Mood.SAD
	else:
		new_mood = Mood.ANGRY

	if new_mood != _current_mood:
		_current_mood = new_mood
		mood_changed.emit(_current_mood)


func _update_visual() -> void:
	# Choose texture or fallback color.
	var texture: Texture2D
	var color: Color
	match _current_mood:
		Mood.HAPPY:
			texture = happy_icon
			color = happy_color
		Mood.SAD:
			texture = sad_icon
			color = sad_color
		Mood.ANGRY:
			texture = angry_icon
			color = angry_color

	if _icon and texture:
		_icon.texture = texture
		_icon.visible = true
		if _color_rect:
			_color_rect.visible = false
	elif _color_rect:
		_color_rect.color = color
		_color_rect.visible = true
		if _icon:
			_icon.visible = false
	else:
		# No visual node – draw a simple circle as last resort.
		queue_redraw()


func _draw() -> void:
	if _icon and _icon.visible:
		return
	if _color_rect and _color_rect.visible:
		return
	# Fallback: draw a colored circle.
	var radius: float = 8.0
	var color: Color
	match _current_mood:
		Mood.HAPPY:
			color = happy_color
		Mood.SAD:
			color = sad_color
		Mood.ANGRY:
			color = angry_color
	draw_circle(Vector2.ZERO, radius, color)