# CreatureIdleAnimation.gd
# ============================================================================
# Idle/bob animation for creature sprites.
# Builds on the existing Creature system (SANCT-025) and adds a gentle
# up/down bob when the creature is idle, making the sanctuary feel alive.
# Tunables are exposed as @export vars so a designer can adjust the feel
# in one place without touching code.
# ============================================================================
extends Node2D
class_name CreatureIdleAnimation

# --- Tunables (one-setting changes) -----------------------------------------
@export var bob_amplitude: float = 4.0      # Max vertical offset in pixels
@export var bob_speed: float = 2.0         # Oscillations per second (Hz)
@export var bob_phase_offset: float = 0.0  # Radians, to desync multiple creatures

# --- State ------------------------------------------------------------------
enum State { IDLE, MOVING, SLEEPING, EATING }  # Extend as needed
var current_state: State = State.IDLE

# --- Internal ---------------------------------------------------------------
var _base_position: Vector2
var _time: float = 0.0
var _is_processing: bool = true

func _ready() -> void:
	_base_position = position
	# If the parent is a Creature, connect to its movement signals if they exist.
	# We don't assume they do; the state can be set externally via set_state().
	# This keeps the script decoupled and reusable.
	pass

func _process(delta: float) -> void:
	if not _is_processing:
		return
	_time += delta
	match current_state:
		State.IDLE:
			# Gentle sine bob
			var offset = sin(_time * TAU * bob_speed + bob_phase_offset) * bob_amplitude
			position.y = _base_position.y + offset
		_:
			# For non-idle states, return to base position smoothly
			position.y = lerp(position.y, _base_position.y, delta * 5.0)

# --- Public API -------------------------------------------------------------
func set_state(new_state: State) -> void:
	current_state = new_state
	if new_state != State.IDLE:
		# Reset time so the bob restarts cleanly when returning to idle
		_time = 0.0

func set_processing(enabled: bool) -> void:
	_is_processing = enabled
	if not enabled:
		# Snap back to base when disabled
		position = _base_position

# --- Optional: sync with Creature's movement if it exposes a signal ---------
# Uncomment and adapt if the Creature class emits a "movement_changed" signal.
# func _on_creature_movement_changed(is_moving: bool) -> void:
#     set_state(State.MOVING if is_moving else State.IDLE)