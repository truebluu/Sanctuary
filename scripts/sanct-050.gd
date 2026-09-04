extends Node2D
# TUNABILITY CONSTANTS
# Limits and base values for bobbing and idle timing
const MAX_BOB_AMPLITUDE_PX: float = 10.0          # Maximum vertical bob offset in pixels
const BOB_BASE_FREQUENCY: float = 1.0           # Base frequency multiplier for bob motion
const IDLE_MIN_SECONDS: float = 1.0             # Minimum idle timeout duration
const IDLE_MAX_SECONDS: float = 5.0             # Maximum idle timeout duration

# Exported tunables – all difficulty‑relevant values are exposed here for one‑place editing
@export var bob_amplitude: float = 5.0 setget _clamp_bob_amplitude   # Vertical bob amplitude (px)
@export var bob_frequency: float = 1.5 setget _clamp_bob_frequency   # Bob oscillation frequency (Hz)
@export var idle_timeout_min: float = IDLE_MIN_SECONDS setget _clamp_idle_min
@export var idle_timeout_max: float = IDLE_MAX_SECONDS setget _clamp_idle_max

# Node references (auto‑loaded by scene hierarchy)
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var idle_timer: Timer = Timer.new()

# Internal state
var _bob_phase: float = 0.0
var _idle_timer_active: bool = false

# Signal for other systems that idle animation has begun
signal idle_started

func _ready() -> void:
    # Defensive checks – fail fast if required nodes are missing
    if sprite == null:
        push_error("CreatureIdleAnimation: Sprite2D node not found.")
        return
    if anim_player == null:
        push_error("CreatureIdleAnimation: AnimationPlayer node not found.")
        return

    # Configure idle timer with a random duration within designer‑set bounds
    idle_timer.one_shot = true
    idle_timer.wait_time = randf_range(idle_timeout_min, idle_timeout_max)
    idle_timer.timeout.connect(_on_idle_timeout)
    idle_timer.start()
    _idle_timer_active = true

    # Start bobbing loop
    set_process(true)

    # Emit signal for design‑tool awareness
    emit_signal("idle_started")

# -------------------------------------------------------------------------
# Exported variable clamping – guarantees tunable values stay within safe bounds
func _clamp_bob_amplitude(value: float) -> float:
    return clamp(value, 0.0, MAX_BOB_AMPLITUDE_PX)

func _clamp_bob_frequency(value: float) -> float:
    return clamp(value, BOB_BASE_FREQUENCY * 0.5, BOB_BASE_FREQUENCY * 2.0)

func _clamp_idle_min(value: float) -> float:
    return max(value, IDLE_MIN_SECONDS)

func _clamp_idle_max(value: float) -> float:
    return clamp(value, idle_timeout_min, idle_timeout_max)

# -------------------------------------------------------------------------
# Bobbing logic – runs every frame while idle timer is active
func _process(delta: float) -> void:
    # Update phase based on frequency and delta time
    _bob_phase += bob_frequency * delta * 2 * PI
    # Compute vertical offset using sine wave
    var offset_y: float = sin(_bob_phase) * bob_amplitude
    # Apply offset to sprite (preserve horizontal position)
    sprite.position = Vector2(sprite.position.x, sprite.position.y + offset_y)

# -------------------------------------------------------------------------
# Timeout handler – stops bobbing and plays the idle animation
func _on_idle_timeout() -> void:
    # Stop per‑frame bobbing updates
    set_process(false)
    # Ensure sprite returns to base position (no residual offset)
    sprite.position = sprite.position.snapped(Vector2(0, 0))
    # Play the predefined "idle" animation (must exist in the AnimationPlayer)
    if anim_player.has_animation("idle"):
        anim_player.play("idle")
    else:
        push_warning("CreatureIdleAnimation: Animation 'idle' not found in AnimationPlayer.")
    # Emit secondary signal for systems that react to idle ending
    emit_signal("idle_ended")

# -------------------------------------------------------------------------
# Utility – reset animation for testing or post‑event recovery
func reset_animation() -> void:
    _bob_phase = 0.0
    sprite.position = sprite.position.snapped(Vector2(0, 0))
    anim_player.stop()
    if anim_player.has_animation("idle"):
        anim_player.play("idle")
    set_process(true)  # resume bobbing if needed

# -------------------------------------------------------------------------
# Signal definitions for external listeners
# (re‑declared here for IDE auto‑completion; no extra code needed)