extends Node
class_name CreatureEvolutionTrigger

## Monitors a creature's level and happiness, fires evolution when both thresholds are met.
## Builds on CreatureNeeds (happiness) and the existing CreatureEvolution pipeline.

signal evolution_triggered(creature: Node, next_stage: StringName)
signal evolution_blocked(reason: String)

# Thresholds — one place to tune evolution gating.
@export var required_level: int = 5
@export var required_happiness: float = 0.85
@export var cooldown_seconds: float = 12.0

var _creature: Node = null
var _on_cooldown: bool = false
var _cooldown_timer: SceneTreeTimer = null

func setup(target: Node) -> void:
	_creature = target
	if _creature == null:
		push_error("CreatureEvolutionTrigger: no creature target set")

func set_thresholds(level: int, happiness: float) -> void:
	required_level = level
	required_happiness = happiness

func _read_level() -> int:
	if _creature != null and _creature.has("level"):
		return int(_creature.get("level"))
	return 0

func _read_happiness() -> float:
	if _creature != null and _creature.has("happiness"):
		return float(_creature.get("happiness"))
	return 0.0

func _process(_delta: float) -> void:
	if _creature == null or _on_cooldown:
		return
	var level: int = _read_level()
	var happiness: float = _read_happiness()
	if level >= required_level and happiness >= required_happiness:
		_attempt_evolve()

func _attempt_evolve() -> void:
	var stage: StringName = _creature.get("evolution_stage") if _creature.has("evolution_stage") else &"base"
	if stage == &"final":
		evolution_blocked.emit("Creature is already at final evolution stage")
		return
	var next: StringName = _resolve_next_stage(stage)
	if next == &"":
		evolution_blocked.emit("No further evolution path defined")
		return
	_start_cooldown()
	evolution_triggered.emit(_creature, next)
	EventBus.emit("creature_evolution_triggered", _creature, next)

func _resolve_next_stage(current: StringName) -> StringName:
	var stages: Array = _creature.get("evolution_stages") if _creature.has("evolution_stages") else []
	if stages is Array and not stages.is_empty():
		var idx: int = stages.find(current)
		if idx >= 0 and idx + 1 < stages.size():
			return StringName(stages[idx + 1])
	return &""

func _start_cooldown() -> void:
	_on_cooldown = true
	_cooldown_timer = get_tree().create_timer(cooldown_seconds)
	_cooldown_timer.timeout.connect(_on_cooldown_end)

func _on_cooldown_end() -> void:
	_on_cooldown = false
	_cooldown_timer = null

func is_ready() -> bool:
	if _creature == null or _on_cooldown:
		return false
	var level: int = _read_level()
	var happiness: float = _read_happiness()
	return level >= required_level and happiness >= required_happiness

func get_block_reason() -> String:
	if _creature == null:
		return "No creature target"
	if _on_cooldown:
		return "Evolution cooldown active"
	var level: int = _read_level()
	var happiness: float = _read_happiness()
	if level < required_level:
		return "Level %d/%d" % [level, required_level]
	if happiness < required_happiness:
		return "Happiness %.0f%%/%.0f%%" % [happiness * 100.0, required_happiness * 100.0]
	return ""
# Feel: evolution is gated on BOTH level and happiness, so players must care for the creature, not just grind. Builds on CreatureNeeds for the happiness signal and CreatureEvolution for the stage pipeline.
# Fix: replaced creature.get("key", default) (2-arg, invalid in GD4) with has()/get() guards via _read_level/_read_happiness; aligned signal emit names (evolution_triggered/evolution_blocked) to their declarations.