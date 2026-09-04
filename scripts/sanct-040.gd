class_name EnemyStagger
extends Node
## Burst-damage flinch system. When an enemy takes >= stagger_threshold damage
## within stagger_window seconds, it flinches: briefly stunned (invuln, frozen)
## for flinch_duration, then recovers. Rewards burst play, synergizes with
## Time Dilation and the player's dash. Builds on the existing Enemy/Player
## damage pipeline and the feel pillar of vulnerability windows.

# --- Tunables (one place to retune) ---
@export var stagger_threshold: float = 18.0   # damage in a window needed to flinch
@export var stagger_window: float = 0.6       # seconds to accumulate burst damage
@export var flinch_duration: float = 0.35      # how long the enemy is stunned
@export var flinch_knockback: float = 120.0    # pushback applied during flinch
@export var flash_frames: int = 6              # visual flash count during flinch

signal flinch_started(target: Node)
signal flinch_ended(target: Node)

var _parent: Node = null
var _damage_buffer: Array[float] = []
var _buffer_timer: float = 0.0
var _is_flinching: bool = false
var _flinch_left: float = 0.0
var _flash_count: int = 0
var _flash_timer: float = 0.0

func _ready() -> void:
	_parent = get_parent()
	if _parent == null:
		push_error("EnemyStagger must be a child of the enemy node")

func _process(delta: float) -> void:
	if _is_flinching:
		_flinch_tick(delta)
	else:
		_buffer_tick(delta)

## Call this whenever the enemy takes damage. Pass the raw damage amount.
func register_damage(amount: float) -> void:
	if _is_flinching:
		return  # already stunned; damage still counts but no re-stagger mid-flinch
	_damage_buffer.append(amount)
	_buffer_timer = stagger_window
	var total: float = _damage_buffer.reduce(func(a, b): return a + b, 0.0)
	if total >= stagger_threshold:
		_trigger_flinch()

func _buffer_tick(delta: float) -> void:
	if _damage_buffer.is_empty():
		return
	_buffer_timer -= delta
	if _buffer_timer <= 0.0:
		_damage_buffer.clear()
		_buffer_timer = 0.0

func _trigger_flinch() -> void:
	_is_flinching = true
	_flinch_left = flinch_duration
	_damage_buffer.clear()
	_buffer_timer = 0.0
	_flash_count = flash_frames
	_flash_timer = flinch_duration / maxf(flash_frames, 1)
	_apply_knockback()
	flinch_started.emit(_parent)

func _flinch_tick(delta: float) -> void:
	_flinch_left -= delta
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_count -= 1
		_flash_timer = flinch_duration / maxf(flash_frames, 1)
	if _flinch_left <= 0.0:
		_is_flinching = false
		_flinch_left = 0.0
		_flash_count = 0
		flinch_ended.emit(_parent)

func _apply_knockback() -> void:
	var body: Node2D = _parent as Node2D
	if body == null:
		return
	var dir: Vector2 = Vector2.UP
	if _parent.has_method("get_knockback_dir"):
		dir = _parent.get_knockback_dir()
	body.apply_central_impulse(dir * flinch_knockback)

## True while the enemy is stunned and cannot act/fire.
func is_stunned() -> bool:
	return _is_flinching

## 0..1 flash intensity for the enemy's sprite (blink on/off).
func flash_intensity() -> float:
	return 1.0 if _flash_count > 0 else 0.0

## Remaining stun time (for UI/telegraphing).
func flinch_time_left() -> float:
	return _flinch_left

## Accumulated burst damage in the current window (for debugging/telemetry).
func buffered_damage() -> float:
	return _damage_buffer.reduce(func(a, b): return a + b, 0.0)