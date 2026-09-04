# CreatureIdleAnimation.gd
# Adds idle/bob animation states to creature sprites.
# Builds on the existing Creature class and its sprite node.
# Feel: gives creatures a living, breathing presence in the sanctuary.
# Tunables are grouped at the top for one-setting changes.

extends Node
class_name CreatureIdleAnimation

## --- Tunables (one-setting changes) ---
@export var bob_amplitude: float = 2.0          # How many pixels the sprite bobs up/down.
@export var bob_period: float = 2.0             # Seconds for one full bob cycle.
@export var blink_interval: float = 3.0         # Average seconds between blinks.
@export var blink_duration: float = 0.15        # How long a blink lasts.
@export var blink_scale_y: float = 0.1          # Scale Y during blink (0.1 = nearly closed).
@export var enable_blink: bool = true           # Toggle blink animation.
@export var enable_bob: bool = true             # Toggle bob animation.

## --- Internal state ---
var _sprite: Sprite2D
var _original_position: Vector2
var _original_scale: Vector2
var _tween: Tween
var _blink_timer: float = 0.0
var _is_blinking: bool = false

func _ready() -> void:
	# Find the sprite node – assume it's a child named "Sprite" or the first Sprite2D.
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		# Fallback: search children for a Sprite2D.
		for child in get_children():
			if child is Sprite2D:
				_sprite = child
				break
	if _sprite == null:
		push_warning("CreatureIdleAnimation: No Sprite2D found – idle animation disabled.")
		return

	_original_position = _sprite.position
	_original_scale = _sprite.scale
	_blink_timer = randf_range(0.0, blink_interval)  # Randomize initial blink delay.

	# Start the bob loop.
	if enable_bob:
		_start_bob()

	# Blink is handled in _process.

func _process(delta: float) -> void:
	if _sprite == null or not enable_blink:
		return

	_blink_timer -= delta
	if _blink_timer <= 0.0 and not _is_blinking:
		_start_blink()
		_blink_timer = blink_interval + randf_range(-0.5, 0.5)  # Slight randomness.

func _start_bob() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_property(_sprite, "position:y", _original_position.y + bob_amplitude, bob_period / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_sprite, "position:y", _original_position.y, bob_period / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_blink() -> void:
	_is_blinking = true
	var blink_tween = create_tween()
	blink_tween.tween_property(_sprite, "scale:y", blink_scale_y, blink_duration / 2.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	blink_tween.tween_property(_sprite, "scale:y", _original_scale.y, blink_duration / 2.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	blink_tween.tween_callback(func(): _is_blinking = false)

## Optional: stop animation when creature is not visible or paused.
func set_idle_enabled(enabled: bool) -> void:
	if enabled:
		if enable_bob and _tween == null:
			_start_bob()
	else:
		if _tween:
			_tween.kill()
			_tween = null
		# Reset sprite to original state.
		if _sprite:
			_sprite.position = _original_position
			_sprite.scale = _original_scale