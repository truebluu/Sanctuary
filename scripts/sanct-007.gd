# BaitTrapCapture.gd
# Implements a bait/trap minigame for capturing wild creatures in the sanctuary.
# Builds on existing CreatureSpawner, EventBus, GameState, and Creature classes.
# This is a new layer that adds an alternative capture method to the existing capture minigame.
# Tunables are grouped at the top for one-setting changes.

extends Node
## Bait/Trap Capture Minigame
## Allows the player to place bait, attract a wild creature, set a trap, and trigger it
## within a timing window to capture the creature. Adds variety to sanctuary gameplay.

# --- Tunables (grouped for easy designer adjustment) ---
const DEFAULT_BAIT_EFFECT := 0.1          # Base attraction bonus per bait type
const DEFAULT_TRAP_BONUS := 0.2           # Base capture chance bonus per trap type
const DEFAULT_BASE_CAPTURE_CHANCE := 0.5  # Base chance to capture without bonuses
const DEFAULT_CAPTURE_WINDOW := 2.0       # Seconds to trigger trap after creature approaches
const DEFAULT_CREATURE_APPROACH_TIME := 3.0 # Seconds for creature to reach bait
const MAX_BAIT_TYPES := 5                 # Hard limit on distinct bait types
const MAX_TRAP_TYPES := 5                 # Hard limit on distinct trap types

# --- Signals ---
signal bait_placed(bait_type: String)
signal creature_spotted(creature: Creature)
signal trap_set(trap_type: String)
signal capture_attempted(creature: Creature, success: bool)
signal creature_captured(creature: Creature)
signal capture_failed(creature: Creature)

# --- Exports (designer tunable per instance) ---
@export var bait_types: Dictionary = {
	"berry": 0.1,
	"fish": 0.15,
	"insect": 0.2,
	"meat": 0.25,
	"crystal": 0.3
} # Bait name -> attraction bonus (adds to base capture chance)
@export var trap_types: Dictionary = {
	"basic": 0.1,
	"net": 0.2,
	"cage": 0.3,
	"shock": 0.4,
	"golden": 0.5
} # Trap name -> capture bonus (adds to base capture chance)
@export var base_capture_chance: float = DEFAULT_BASE_CAPTURE_CHANCE
@export var capture_window: float = DEFAULT_CAPTURE_WINDOW
@export var creature_approach_time: float = DEFAULT_CREATURE_APPROACH_TIME

# --- Internal state ---
var _current_bait: String = ""
var _current_trap: String = ""
var _current_creature: Creature = null
var _capture_timer: Timer = null
var _approach_timer: Timer = null
var _state: String = "idle" # idle, bait_placed, creature_approaching, trap_set, capture_attempt

# --- References to autoloads (injected for testability) ---
var _event_bus: Node = null
var _game_state: Node = null
var _creature_spawner: Node = null

func _ready() -> void:
	# Get autoloads
	_event_bus = get_node("/root/EventBus")
	_game_state = get_node("/root/GameState")
	_creature_spawner = get_node("/root/CreatureSpawner") # Assuming autoload exists; if not, we'll use a group
	
	# Validate exports
	if bait_types.size() > MAX_BAIT_TYPES:
		push_warning("Too many bait types; truncating to %d" % MAX_BAIT_TYPES)
		var keys = bait_types.keys()
		for i in range(MAX_BAIT_TYPES, keys.size()):
			bait_types.erase(keys[i])
	if trap_types.size() > MAX_TRAP_TYPES:
		push_warning("Too many trap types; truncating to %d" % MAX_TRAP_TYPES)
		var keys = trap_types.keys()
		for i in range(MAX_TRAP_TYPES, keys.size()):
			trap_types.erase(keys[i])
	
	# Setup timers
	_capture_timer = Timer.new()
	_capture_timer.one_shot = true
	_capture_timer.wait_time = capture_window
	_capture_timer.timeout.connect(_on_capture_timeout)
	add_child(_capture_timer)
	
	_approach_timer = Timer.new()
	_approach_timer.one_shot = true
	_approach_timer.wait_time = creature_approach_time
	_approach_timer.timeout.connect(_on_approach_timeout)
	add_child(_approach_timer)

# --- Public methods ---

## Place bait to attract a wild creature. Returns true if successful.
func place_bait(bait_type: String) -> bool:
	if _state != "idle":
		return false
	if not bait_types.has(bait_type):
		push_warning("Unknown bait type: %s" % bait_type)
		return false
	# Check inventory via GameState (assumes method has_item)
	if not _game_state.has_item(bait_type):
		push_warning("Player does not have bait: %s" % bait_type)
		return false
	
	_current_bait = bait_type
	_state = "bait_placed"
	_event_bus.emit_signal("bait_placed", bait_type)
	# Spawn a wild creature near the bait
	var creature = _spawn_wild_creature()
	if creature == null:
		_state = "idle"
		return false
	_current_creature = creature
	# Connect to creature's approach signal (if any)
	if creature.has_signal("approached_bait"):
		creature.approached_bait.connect(_on_creature_approached)
	# Start approach timer
	_approach_timer.start()
	_event_bus.emit_signal("creature_spotted", creature)
	return true

## Set a trap at the bait location. Returns true if successful.
func set_trap(trap_type: String) -> bool:
	if _state != "bait_placed" and _state != "creature_approaching":
		return false
	if not trap_types.has(trap_type):
		push_warning("Unknown trap type: %s" % trap_type)
		return false
	# Check inventory
	if not _game_state.has_item(trap_type):
		push_warning("Player does not have trap: %s" % trap_type)
		return false
	
	_current_trap = trap_type
	_state = "trap_set"
	_event_bus.emit_signal("trap_set", trap_type)
	return true

## Trigger the trap to attempt capture. Must be called during the capture window.
func trigger_trap() -> bool:
	if _state != "trap_set":
		return false
	if _current_creature == null:
		return false
	# Calculate capture chance
	var chance = base_capture_chance
	chance += bait_types.get(_current_bait, 0.0)
	chance += trap_types.get(_current_trap, 0.0)
	# Clamp to [0,1]
	chance = clamp(chance, 0.0, 1.0)
	# Roll
	var success = randf() < chance
	_capture_timer.stop()
	_state = "capture_attempt"
	_event_bus.emit_signal("capture_attempted", _current_creature, success)
	if success:
		_capture_creature()
	else:
		_fail_capture()
	return true

# --- Internal methods ---

func _spawn_wild_creature() -> Creature:
	# Use CreatureSpawner to spawn a random wild creature
	if _creature_spawner and _creature_spawner.has_method("spawn_wild"):
		return _creature_spawner.spawn_wild()
	else:
		# Fallback: create a basic Creature instance (for testing)
		var creature = Creature.new()
		creature.creature_name = "Wild " + str(randi() % 100)
		return creature

func _on_creature_approached(creature: Creature) -> void:
	_approach_timer.stop()
	_state = "creature_approaching"
	# If trap is already set, start capture window
	if _state == "trap_set":
		_capture_timer.start()
	# Otherwise, wait for player to set trap

func _on_approach_timeout() -> void:
	# Creature got bored and left
	_reset_minigame()
	_event_bus.emit_signal("capture_failed", _current_creature)

func _on_capture_timeout() -> void:
	# Trap window expired
	_fail_capture()

func _capture_creature() -> void:
	# Add creature to sanctuary via GameState or CreatureManager
	if _game_state.has_method("add_creature"):
		_game_state.add_creature(_current_creature)
	else:
		push_warning("GameState does not have add_creature method")
	# Emit success
	_event_bus.emit_signal("creature_captured", _current_creature)
	_reset_minigame()

func _fail_capture() -> void:
	_event_bus.emit_signal("capture_failed", _current_creature)
	# Creature escapes
	_reset_minigame()

func _reset_minigame() -> void:
	_current_bait = ""
	_current_trap = ""
	_current_creature = null
	_state = "idle"
	_capture_timer.stop()
	_approach_timer.stop()
	# Disconnect creature signal if needed
	# (We'll rely on the creature being freed or leaving)

# --- Utility: check if player has item (fallback if GameState lacks method) ---
func _has_item(item_name: String) -> bool:
	if _game_state.has_method("has_item"):
		return _game_state.has_item(item_name)
	# Fallback: assume player has all items (for testing)
	return true