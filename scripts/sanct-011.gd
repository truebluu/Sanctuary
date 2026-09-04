class_name FeedingMinigame
extends Control
## Timing-based feeding minigame for happiness boost.
## Builds on the existing Creature hunger/happiness systems (SANCT-011).
## The player must press the input action when the moving bar is inside the target zone.
## Success grants a happiness boost; failure grants a small consolation boost.
## All tunables are @export so a designer can retune without touching logic.

signal minigame_finished(success: bool, happiness_boost: float)

# --- Tunables (one place to adjust feel) ---
@export var minigame_duration: float = 3.0          # Total time for the bar to sweep back and forth.
@export var target_zone_width: float = 0.2           # Fraction of the bar width that counts as success.
@export var happiness_boost_success: float = 20.0   # Happiness gained on a successful feed.
@export var happiness_boost_fail: float = 5.0        # Happiness gained on a failed feed (consolation).
@export var input_action: StringName = &"ui_accept" # Action that triggers the feed attempt.
@export var bar_speed_curve: Curve = null            # Optional curve to vary bar speed over time.

# --- Internal state ---
var _creature: Node = null
var _bar_value: float = 0.0          # 0..1, ping-pongs.
var _bar_direction: int = 1         # 1 = increasing, -1 = decreasing.
var _target_center: float = 0.5      # Center of the target zone (0..1).
var _target_width: float = 0.2       # Width of the target zone (fraction of bar).
var _is_running: bool = false
var _has_triggered: bool = false    # Prevents multiple presses.
var _time_elapsed: float = 0.0

# --- Node references (set up in scene) ---
@onready var _bar: ProgressBar = $Bar
@onready var _target_zone: ColorRect = $TargetZone
@onready var _result_label: Label = $ResultLabel

func _ready() -> void:
	# Hide by default; the minigame is shown when started.
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect to input via _input, but we'll also use _process for bar movement.

func start_minigame(creature: Node) -> void:
	"""Begin the feeding minigame for the given creature."""
	if _is_running:
		return
	if creature == null:
		push_error("FeedingMinigame: Cannot start with null creature.")
		return
	_creature = creature
	# Reset state
	_bar_value = 0.0
	_bar_direction = 1
	_time_elapsed = 0.0
	_has_triggered = false
	_is_running = true
	visible = true
	# Randomize target zone position for variety (but keep it within bounds).
	_target_width = target_zone_width
	_target_center = randf_range(_target_width * 0.5, 1.0 - _target_width * 0.5)
	_update_ui()
	# Optionally pause the game? We'll keep it running; the minigame is an overlay.

func cancel_minigame() -> void:
	"""Abort the minigame (e.g., player closes the UI)."""
	if not _is_running:
		return
	_is_running = false
	visible = false
	# Emit a failure with zero boost? Or just cancel silently.
	# We'll emit a failure with zero boost to keep the flow predictable.
	minigame_finished.emit(false, 0.0)
	_creature = null

func _process(delta: float) -> void:
	if not _is_running:
		return
	_time_elapsed += delta
	# Move the bar back and forth.
	var speed = 1.0 / minigame_duration
	if bar_speed_curve:
		speed *= bar_speed_curve.sample(_time_elapsed / minigame_duration)
	_bar_value += _bar_direction * speed * delta
	# Reverse at bounds.
	if _bar_value >= 1.0:
		_bar_value = 1.0
		_bar_direction = -1
	elif _bar_value <= 0.0:
		_bar_value = 0.0
		_bar_direction = 1
	_update_ui()
	# Timeout check: if we've gone past the duration without a press, fail.
	if _time_elapsed >= minigame_duration:
		_finish(false)

func _input(event: InputEvent) -> void:
	if not _is_running or _has_triggered:
		return
	if event.is_action_pressed(input_action):
		_has_triggered = true
		# Check if the bar is within the target zone.
		var lower = _target_center - _target_width * 0.5
		var upper = _target_center + _target_width * 0.5
		var success = _bar_value >= lower and _bar_value <= upper
		_finish(success)

func _finish(success: bool) -> void:
	"""End the minigame and apply the happiness boost."""
	if not _is_running:
		return
	_is_running = false
	visible = false
	var boost = happiness_boost_success if success else happiness_boost_fail
	# Apply to the creature if it still exists.
	if is_instance_valid(_creature) and _creature.has_method("apply_happiness"):
		_creature.apply_happiness(boost)
	# Show result briefly? We'll emit the signal; the caller can show feedback.
	minigame_finished.emit(success, boost)
	_creature = null

func _update_ui() -> void:
	"""Update the bar and target zone visuals."""
	if not _bar or not _target_zone:
		return
	_bar.value = _bar_value * 100.0  # ProgressBar uses 0-100.
	# Position the target zone as a fraction of the bar's width.
	var bar_rect = _bar.get_global_rect()
	var zone_width = bar_rect.size.x * _target_width
	var zone_left = bar_rect.position.x + bar_rect.size.x * (_target_center - _target_width * 0.5)
	_target_zone.position = Vector2(zone_left, _target_zone.position.y)
	_target_zone.size = Vector2(zone_width, _target_zone.size.y)
	# Optionally update a label with instructions.
	if _result_label:
		_result_label.text = "Press %s when the bar is in the green zone!" % input_action