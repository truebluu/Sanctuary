# DecorationSystem.gd
# Manages placement of decorations in the sanctuary and applies mood effects to nearby creatures.
# Builds on: CreatureNeedsEngine (mood), HabitatSystem (spatial), EventBus (signals).
# Feel: Adds a layer of player agency – decorating the sanctuary directly influences creature well-being,
# making the sanctuary feel alive and responsive to player choices.

extends Node
class_name DecorationSystem

# --- Tunables (one-place changes) ---
const DEFAULT_MOOD_BONUS := 5.0          # Base mood increase per decoration within radius
const DEFAULT_MOOD_RADIUS := 150.0       # Distance in pixels for mood effect
const MAX_DECORATIONS := 20              # Hard cap on placed decorations
const MOOD_UPDATE_INTERVAL := 2.0        # Seconds between periodic mood checks

# --- Exports (designer adjustable) ---
@export var decoration_scene: PackedScene   # Scene to instantiate for each decoration
@export var mood_bonus: float = DEFAULT_MOOD_BONUS
@export var mood_radius: float = DEFAULT_MOOD_RADIUS
@export var max_decorations: int = MAX_DECORATIONS

# --- Internal state ---
var _decorations: Array[Node2D] = []       # All placed decoration instances
var _mood_timer: Timer

# --- Signals ---
signal decoration_placed(decoration: Node2D, position: Vector2)
signal decoration_removed(decoration: Node2D)
signal mood_affected(creature: Node, amount: float)

func _ready() -> void:
	# Validate required dependencies
	assert(decoration_scene != null, "DecorationSystem: decoration_scene must be assigned")
	assert(EventBus != null, "DecorationSystem: EventBus autoload missing")
	assert(CreatureNeedsEngine != null, "DecorationSystem: CreatureNeedsEngine autoload missing")
	
	# Set up periodic mood updates
	_mood_timer = Timer.new()
	_mood_timer.wait_time = MOOD_UPDATE_INTERVAL
	_mood_timer.autostart = true
	_mood_timer.timeout.connect(_apply_mood_effects)
	add_child(_mood_timer)
	
	# Register with group for easy access
	add_to_group("decoration_system")

# --- Public API ---

## Place a decoration at the given world position.
## Returns the placed decoration instance, or null if cap reached or invalid position.
func place_decoration(world_position: Vector2) -> Node2D:
	if _decorations.size() >= max_decorations:
		push_warning("DecorationSystem: Max decorations reached (%d)" % max_decorations)
		return null
	
	var decoration = decoration_scene.instantiate() as Node2D
	if decoration == null:
		push_error("DecorationSystem: decoration_scene is not a Node2D")
		return null
	
	# Add to scene tree and position
	get_tree().current_scene.add_child(decoration)
	decoration.global_position = world_position
	decoration.add_to_group("decorations")
	_decorations.append(decoration)
	
	# Emit signal
	decoration_placed.emit(decoration, world_position)
	EventBus.emit_signal("sanctuary_decoration_placed", decoration, world_position)
	
	# Immediate mood effect for nearby creatures
	_apply_mood_effects()
	
	return decoration

## Remove a decoration instance.
func remove_decoration(decoration: Node2D) -> void:
	if decoration in _decorations:
		_decorations.erase(decoration)
		decoration.queue_free()
		decoration_removed.emit(decoration)
		EventBus.emit_signal("sanctuary_decoration_removed", decoration)
		# Re-evaluate mood after removal
		_apply_mood_effects()

## Get all currently placed decorations.
func get_decorations() -> Array[Node2D]:
	return _decorations.duplicate()

## Clear all decorations (e.g., when loading a new sanctuary).
func clear_all_decorations() -> void:
	for decoration in _decorations:
		decoration.queue_free()
	_decorations.clear()
	_apply_mood_effects()

# --- Internal methods ---

## Apply mood bonuses to all creatures within radius of any decoration.
func _apply_mood_effects() -> void:
	# Get all creatures in the sanctuary (group "creatures")
	var creatures = get_tree().get_nodes_in_group("creatures")
	if creatures.is_empty():
		return
	
	for creature in creatures:
		var total_bonus := 0.0
		for decoration in _decorations:
			var distance = creature.global_position.distance_to(decoration.global_position)
			if distance <= mood_radius:
				# Linear falloff: full bonus at center, zero at radius edge
				var falloff = 1.0 - (distance / mood_radius)
				total_bonus += mood_bonus * falloff
		
		if total_bonus > 0.0:
			# Apply mood change via CreatureNeedsEngine
			var applied = CreatureNeedsEngine.adjust_mood(creature, total_bonus)
			if applied:
				mood_affected.emit(creature, total_bonus)
				EventBus.emit_signal("creature_mood_changed", creature, total_bonus)

# --- Lifecycle ---
func _exit_tree() -> void:
	# Clean up timer
	if _mood_timer:
		_mood_timer.stop()
		_mood_timer.queue_free()