class_name EvolutionPreview
extends Control
## Evolution Preview UI
## Shows a silhouette of the next evolution stage before the player confirms.
## Builds on CreatureEvolution and EventBus to give the player agency and anticipation.
## Feel: adds a moment of choice and visual clarity before a permanent change.

signal evolution_confirmed(creature: Creature)
signal evolution_cancelled(creature: Creature)

@export var silhouette_texture: Texture2D
@export var stage_name_label: Label
@export var confirm_button: Button
@export var cancel_button: Button

var _current_creature: Creature

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	hide()

## Call this when a creature becomes ready to evolve.
func show_preview(creature: Creature) -> void:
	if not creature or not creature.has_method("get_evolution"):
		push_warning("EvolutionPreview: creature missing evolution reference")
		return
	var evolution: CreatureEvolution = creature.get_evolution()
	if not evolution:
		push_warning("EvolutionPreview: creature has no evolution component")
		return
	var next_stage: EvolutionStage = evolution.get_next_stage()
	if not next_stage:
		push_warning("EvolutionPreview: no next stage available")
		return
	_current_creature = creature
	# Use the stage's silhouette texture if provided, else fallback to exported one.
	var tex: Texture2D = next_stage.silhouette_texture if next_stage.silhouette_texture else silhouette_texture
	if tex:
		# Assuming a TextureRect child named "Silhouette" – adjust to your scene.
		var tex_rect: TextureRect = get_node_or_null("Silhouette") as TextureRect
		if tex_rect:
			tex_rect.texture = tex
	if stage_name_label:
		stage_name_label.text = next_stage.display_name
	show()

func hide_preview() -> void:
	hide()
	_current_creature = null

func _on_confirm_pressed() -> void:
	if _current_creature:
		evolution_confirmed.emit(_current_creature)
	hide_preview()

func _on_cancel_pressed() -> void:
	if _current_creature:
		evolution_cancelled.emit(_current_creature)
	hide_preview()