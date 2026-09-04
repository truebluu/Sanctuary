class_name CreatureEvolution
extends Node
## Creature evolution trigger.
## Listens to a creature's level and happiness changes and evolves it when
## both thresholds are met. Builds on the existing Creature, CreatureNeeds,
## and EvolutionController systems. Adds a clear progression milestone for
## sanctuary creatures, rewarding the player for raising both stats.

## --- Tunables (one-place design) ---
@export var level_threshold: int = 5
@export var happiness_threshold: float = 0.8
@export var evolution_stage_name: String = "next_stage"  # fallback if not set

## --- Internal state ---
var _creature: Node = null
var _evolved: bool = false

## --- Signals ---
signal evolution_triggered(creature: Node, stage_name: String)
signal evolution_failed(creature: Node, reason: String)

func _ready() -> void:
	# If not explicitly assigned, try to get the parent as the creature.
	if _creature == null:
		_creature = get_parent()
	if _creature == null:
		push_error("CreatureEvolution: No creature assigned.")
		return
	_connect_signals()

func _connect_signals() -> void:
	if _creature.has_signal("level_changed"):
		_creature.level_changed.connect(_on_level_changed)
	if _creature.has_signal("happiness_changed"):
		_creature.happiness_changed.connect(_on_happiness_changed)
	# Also check on ready in case thresholds are already met.
	_check_evolution()

func _on_level_changed(_new_level: int) -> void:
	_check_evolution()

func _on_happiness_changed(_new_happiness: float) -> void:
	_check_evolution()

func _check_evolution() -> void:
	if _evolved:
		return
	if _creature == null:
		return
	var level: int = _creature.get("level") if _creature.get("level") != null else 0
	var happiness: float = _creature.get("happiness") if _creature.get("happiness") != null else 0.0
	if level >= level_threshold and happiness >= happiness_threshold:
		_trigger_evolution()

func _trigger_evolution() -> void:
	_evolved = true
	# Use the EvolutionController if available, else fallback to a direct call.
	var evolution_controller = get_node_or_null("/root/EvolutionController")
	if evolution_controller and evolution_controller.has_method("evolve_creature"):
		var result = evolution_controller.evolve_creature(_creature, evolution_stage_name)
		if result is bool and result:
			evolution_triggered.emit(_creature, evolution_stage_name)
			EventBus.emit_signal("creature_evolved", _creature, evolution_stage_name)
		else:
			_evolved = false  # allow retry if evolution failed
			evolution_failed.emit(_creature, "evolution_controller_rejected")
	else:
		# Fallback: directly call a method on the creature if it exists.
		if _creature.has_method("evolve"):
			_creature.evolve(evolution_stage_name)
			evolution_triggered.emit(_creature, evolution_stage_name)
			EventBus.emit_signal("creature_evolved", _creature, evolution_stage_name)
		else:
			_evolved = false
			evolution_failed.emit(_creature, "no_evolution_method")