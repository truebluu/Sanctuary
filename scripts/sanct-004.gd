# EvolutionPreviewUI.gd
# Shows the next evolution stage silhouette before the player confirms evolution.
# Builds on the existing CreatureEvolution / EvolutionController systems.
# This UI is a modal overlay that displays the silhouette, name, and a confirm button.
# It emits `evolution_confirmed` when the player accepts, and `evolution_cancelled` when dismissed.
# Tunables are exported so a designer can adjust layout/feel without touching logic.

class_name EvolutionPreviewUI
extends Control

## Emitted when the player confirms the evolution.
signal evolution_confirmed(creature: Node)
## Emitted when the player cancels the preview.
signal evolution_cancelled(creature: Node)

# --- Tunables (one place to adjust UI feel) ---
@export var silhouette_scale: float = 1.0
@export var preview_fade_time: float = 0.2
@export var confirm_button_text: String = "Evolve"
@export var cancel_button_text: String = "Not Yet"

# --- Node references (set via scene or code) ---
@onready var silhouette_rect: TextureRect = $MarginContainer/VBoxContainer/SilhouetteRect
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var confirm_button: Button = $MarginContainer/VBoxContainer/Buttons/ConfirmButton
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/Buttons/CancelButton
@onready var background: ColorRect = $Background

var _creature: Node = null
var _next_stage: Dictionary = {}

func _ready() -> void:
	# Connect button signals
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	# Start hidden
	visible = false
	modulate.a = 0.0
	set_process(false)

## Shows the preview for a given creature.
## If the creature has no next evolution stage, the UI stays hidden.
func show_preview(creature: Node) -> void:
	if creature == null:
		push_warning("EvolutionPreviewUI: creature is null, cannot show preview.")
		return
	_creature = creature
	# Get next stage from the creature's evolution component
	var evolution: Node = creature.get("evolution") as Node
	if evolution == null:
		# Try to find via group or child
		evolution = creature.find_child("Evolution", true, false)
	if evolution == null:
		push_warning("EvolutionPreviewUI: creature has no evolution component.")
		return
	# Use the existing EvolutionController or CreatureEvolution API
	# We assume there's a method get_next_stage() returning a Dictionary with keys: name, description, silhouette_texture
	if evolution.has_method("get_next_stage"):
		_next_stage = evolution.get_next_stage()
	else:
		# Fallback: try to read from a property
		_next_stage = evolution.get("next_stage") as Dictionary
	if _next_stage.is_empty():
		push_warning("EvolutionPreviewUI: no next stage data available.")
		return
	# Populate UI
	var silhouette_texture: Texture2D = _next_stage.get("silhouette_texture", null)
	if silhouette_texture:
		silhouette_rect.texture = silhouette_texture
		silhouette_rect.scale = Vector2.ONE * silhouette_scale
	else:
		silhouette_rect.texture = null
		silhouette_rect.visible = false
	name_label.text = _next_stage.get("name", "Unknown")
	description_label.text = _next_stage.get("description", "")
	# Show and fade in
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, preview_fade_time)
	set_process(true)

## Hides the preview without confirming.
func hide_preview() -> void:
	visible = false
	set_process(false)
	_creature = null
	_next_stage.clear()

func _on_confirm_pressed() -> void:
	if _creature:
		evolution_confirmed.emit(_creature)
	hide_preview()

func _on_cancel_pressed() -> void:
	if _creature:
		evolution_cancelled.emit(_creature)
	hide_preview()

func _process(delta: float) -> void:
	# Optional: add subtle animation to silhouette (e.g., breathing)
	if silhouette_rect.visible and silhouette_rect.texture:
		var t: float = Time.get_ticks_msec() / 1000.0
		silhouette_rect.scale = Vector2.ONE * silhouette_scale * (1.0 + 0.02 * sin(t * 2.0))