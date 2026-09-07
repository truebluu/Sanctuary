class_name PetTraining
extends RefCounted

## Pet training commands system for Taming pet-evolution game.
## Tracks command mastery (0.0-1.0) via reward-based learning.

@export var learning_rate: float = 0.15
@export var max_mastery: float = 1.0
@export var min_reward: float = 0.1
@export var mastery_decay_per_session: float = 0.02

var _command_mastery: Dictionary = {}
var _known_commands: Array[String] = ["sit", "follow", "stay"]
var _training_sessions: int = 0

func _init() -> void:
	reset_training()

func teach_command(command_id: String, reward_amount: float) -> void:
	## Teach a command via reward loop. Increases mastery based on reward.
	if not _known_commands.has(command_id):
		push_error("Unknown command: %s" % command_id)
		return
	
	if reward_amount < min_reward:
		push_warning("Reward amount %f below minimum %f, clamping" % [reward_amount, min_reward])
		reward_amount = min_reward
	
	var current_mastery: float = _command_mastery.get(command_id, 0.0)
	var mastery_gain: float = reward_amount * learning_rate
	var new_mastery: float = min(current_mastery + mastery_gain, max_mastery)
	
	_command_mastery[command_id] = new_mastery
	_training_sessions += 1

func get_mastery(command_id: String) -> float:
	## Get mastery level for a command (0.0-1.0). Returns 0.0 if unknown.
	if not _known_commands.has(command_id):
		push_error("Unknown command: %s" % command_id)
		return 0.0
	return _command_mastery.get(command_id, 0.0)

func get_known_commands() -> Array[String]:
	## Return list of all known command IDs.
	return _known_commands.duplicate()

func is_command_known(command_id: String) -> bool:
	## Check if a command ID is in the known commands list.
	return _known_commands.has(command_id)

func get_obedience_level() -> float:
	## Calculate overall obedience as average mastery across all known commands.
	if _known_commands.is_empty():
		return 0.0
	
	var total: float = 0.0
	for cmd in _known_commands:
		total += _command_mastery.get(cmd, 0.0)
	
	return total / _known_commands.size()

func reset_training() -> void:
	## Reset all command mastery to 0.0 and clear training sessions.
	_command_mastery.clear()
	for cmd in _known_commands:
		_command_mastery[cmd] = 0.0
	_training_sessions = 0

func apply_mastery_decay() -> void:
	## Apply decay to all masteries (call between training sessions).
	for cmd in _known_commands:
		var current: float = _command_mastery.get(cmd, 0.0)
		_command_mastery[cmd] = max(current - mastery_decay_per_session, 0.0)

func test() -> bool:
	## Self-test: teach commands, verify mastery increases, return true on success.
	reset_training()
	
	# Test initial state
	assert(get_mastery("sit") == 0.0)
	assert(get_mastery("follow") == 0.0)
	assert(get_mastery("stay") == 0.0)
	assert(get_obedience_level() == 0.0)
	assert(is_command_known("sit") == true)
	assert(is_command_known("invalid") == false)
	
	# Teach sit command
	teach_command("sit", 1.0)
	var sit_mastery_after_first: float = get_mastery("sit")
	assert(sit_mastery_after_first > 0.0)
	assert(sit_mastery_after_first <= max_mastery)
	# Teach sit again - mastery should increase
	teach_command("sit", 1.0)
	var sit_mastery_after_second: float = get_mastery("sit")
	assert(sit_mastery_after_second > sit_mastery_after_first)
	# Teach other commands
	teach_command("follow", 0.5)
	teach_command("stay", 0.8)
	
	# Verify all have mastery > 0
	assert(get_mastery("follow") > 0.0)
	assert(get_mastery("stay") > 0.0)
	
	# Verify obedience level is average
	var obedience: float = get_obedience_level()
	assert(obedience > 0.0)
	assert(obedience <= 1.0)
	# Verify known commands list
	var commands: Array = get_known_commands()
	assert(commands.size() == 3)
	assert(commands.has("sit"))
	assert(commands.has("follow"))
	assert(commands.has("stay"))
	
	# Test error handling for unknown command
	teach_command("unknown", 1.0)  # Should not crash, just warn/error
	assert(get_mastery("unknown") == 0.0)
	
	# Test reset
	reset_training()
	assert(get_mastery("sit") == 0.0)
	assert(get_mastery("follow") == 0.0)
	assert(get_mastery("stay") == 0.0)
	assert(get_obedience_level() == 0.0)
	
	return true
