# CreatureCaptureMinigame.gd
# Bait/trap minigame to capture wild creatures.
# Builds on: Creature class, EventBus, GameState, Inventory (if present).
# Adds: strategic bait/trap resource management, timing-based capture, and
# creature variety to the sanctuary experience.
class_name CreatureCaptureMinigame
extends Node

# --- Tunables (one-place difficulty/feel settings) ---
const MAX_BAIT := 5          # Max bait items player can hold
const MAX_TRAPS := 3         # Max trap items player can hold
const BAIT_COST := 1         # Cost in bait items per placement
const TRAP_COST := 1         # Cost in trap items per attempt
const BAIT_PLACEMENT_DELAY := 2.0   # Seconds before creature appears
const CAPTURE_WINDOW := 1.5         # Seconds the trap is active
const CAPTURE_SUCCESS_BASE := 0.6   # Base success chance if timing is perfect
const CAPTURE_SUCCESS_FALLOFF := 0.2 # Chance reduction per 0.1s off target
const CREATURE_SPAWN_RANGE := Vector2(100, 100) # Random offset for creature spawn

# --- Signals ---
signal capture_started
signal bait_placed(position: Vector2)
signal creature_appeared(creature: Creature)
signal trap_armed
signal capture_attempted(success: bool, creature: Creature)
signal capture_succeeded(creature: Creature)
signal capture_failed(creature: Creature)
signal resources_changed(bait: int, traps: int)

# --- State ---
enum State { IDLE, BAIT_PLACED, CREATURE_APPEARED, TRAP_ARMED, CAPTURE_ATTEMPT, RESULT }
var state: State = State.IDLE

# --- Resources ---
var bait_count: int = MAX_BAIT
var trap_count: int = MAX_TRAPS

# --- Runtime ---
var current_creature: Creature
var bait_position: Vector2
var trap_timer: Timer
var capture_timer: Timer
var capture_target_time: float
var capture_start_time: float

# --- References ---
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var game_state: GameState = get_node("/root/GameState")
@onready var inventory: Inventory = get_node("/root/Inventory") if get_node_or_null("/root/Inventory") else null

func _ready() -> void:
	# Initialize timers
	trap_timer = Timer.new()
	trap_timer.one_shot = true
	trap_timer.wait_time = BAIT_PLACEMENT_DELAY
	trap_timer.timeout.connect(_on_creature_appear_timeout)
	add_child(trap_timer)
	
	capture_timer = Timer.new()
	capture_timer.one_shot = true
	capture_timer.wait_time = CAPTURE_WINDOW
	capture_timer.timeout.connect(_on_capture_window_timeout)
	add_child(capture_timer)
	
	# Connect to EventBus for external triggers
	event_bus.connect("creature_capture_requested", _on_capture_requested)
	emit_signal("resources_changed", bait_count, trap_count)

# --- Public API ---
func start_minigame() -> void:
	if state != State.IDLE:
		push_warning("Minigame already in progress")
		return
	state = State.IDLE
	emit_signal("capture_started")

func place_bait(target_position: Vector2) -> bool:
	if state != State.IDLE:
		push_warning("Cannot place bait in current state")
		return false
	if bait_count < BAIT_COST:
		emit_signal("capture_failed", null)  # No bait left
		return false
	bait_count -= BAIT_COST
	bait_position = target_position
	emit_signal("resources_changed", bait_count, trap_count)
	emit_signal("bait_placed", bait_position)
	state = State.BAIT_PLACED
	trap_timer.start()
	return true

func arm_trap() -> bool:
	if state != State.CREATURE_APPEARED:
		push_warning("Cannot arm trap before creature appears")
		return false
	if trap_count < TRAP_COST:
		emit_signal("capture_failed", current_creature)
		return false
	trap_count -= TRAP_COST
	emit_signal("resources_changed", bait_count, trap_count)
	emit_signal("trap_armed")
	state = State.TRAP_ARMED
	capture_start_time = Time.get_ticks_msec() / 1000.0
	capture_timer.start()
	return true

func trigger_trap() -> void:
	if state != State.TRAP_ARMED:
		push_warning("Trap not armed")
		return
	var elapsed = (Time.get_ticks_msec() / 1000.0) - capture_start_time
	var time_off = abs(elapsed - (CAPTURE_WINDOW / 2.0))  # Perfect timing at midpoint
	var success_chance = CAPTURE_SUCCESS_BASE - (time_off * CAPTURE_SUCCESS_FALLOFF)
	success_chance = clampf(success_chance, 0.0, 1.0)
	var success = randf() < success_chance
	_finish_capture(success)

# --- Internal ---
func _on_capture_requested() -> void:
	start_minigame()

func _on_creature_appear_timeout() -> void:
	if state != State.BAIT_PLACED:
		return
	# Spawn a random creature near bait
	var creature = _spawn_random_creature()
	if creature == null:
		emit_signal("capture_failed", null)
		state = State.IDLE
		return
	current_creature = creature
	creature.global_position = bait_position + Vector2(randf_range(-CREATURE_SPAWN_RANGE.x, CREATURE_SPAWN_RANGE.x), randf_range(-CREATURE_SPAWN_RANGE.y, CREATURE_SPAWN_RANGE.y))
	get_parent().add_child(creature)
	emit_signal("creature_appeared", creature)
	state = State.CREATURE_APPEARED

func _on_capture_window_timeout() -> void:
	if state == State.TRAP_ARMED:
		_finish_capture(false)

func _finish_capture(success: bool) -> void:
	capture_timer.stop()
	if success and current_creature:
		# Add creature to sanctuary via EventBus
		event_bus.emit_signal("creature_captured", current_creature)
		emit_signal("capture_succeeded", current_creature)
	else:
		emit_signal("capture_failed", current_creature)
	# Cleanup
	if current_creature and not success:
		current_creature.queue_free()
	current_creature = null
	state = State.IDLE

func _spawn_random_creature() -> Creature:
	# Use existing Creature class to create a new instance
	# In a real project, this would load a creature scene or use a factory.
	# For now, we create a placeholder Creature with random traits.
	var creature = Creature.new()
	creature.creature_name = _generate_random_name()
	creature.rarity = _get_random_rarity()
	# Set other properties as needed
	return creature

func _generate_random_name() -> String:
	# Simple placeholder; could use ProcGenNames autoload if available
	return "Wild_" + str(randi_range(1000, 9999))

func _get_random_rarity() -> int:
	# Rarity tiers: 0=common, 1=uncommon, 2=rare, 3=epic
	var roll = randf()
	if roll < 0.5:
		return 0
	elif roll < 0.8:
		return 1
	elif roll < 0.95:
		return 2
	else:
		return 3

# --- Resource management ---
func add_bait(amount: int) -> void:
	bait_count = clampi(bait_count + amount, 0, MAX_BAIT)
	emit_signal("resources_changed", bait_count, trap_count)

func add_trap(amount: int) -> void:
	trap_count = clampi(trap_count + amount, 0, MAX_TRAPS)
	emit_signal("resources_changed", bait_count, trap_count)

func get_bait_count() -> int:
	return bait_count

func get_trap_count() -> int:
	return trap_count