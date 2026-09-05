extends Area2D
class_name CreatureSanctuaryHealingGarden

## A sanctuary zone that regenerates creature health over time and boosts
## happiness while creatures linger inside. Creatures enter, heal, and leave
## stronger — a recovery pillar between waves.

signal creature_healed(creature: Node, amount: float)
signal garden_depleted()
signal garden_recharged()

# --- Tunable constants (one place to retune the garden) ---
## Flat health restored per tick while a creature is inside.
@export var heal_per_tick: float = 4.0
## How often (seconds) the garden ticks healing for each creature inside.
@export var tick_interval: float = 0.5
## Happiness points granted per tick (feeds the CreatureNeeds happiness meter).
@export var happiness_per_tick: float = 1.5
## Max creatures that can heal simultaneously; excess wait outside.
@export var max_concurrent: int = 3
## If the garden has a stamina pool, how much it holds and how fast it refills.
@export var has_stamina: bool = true
@export var stamina_max: float = 100.0
@export var stamina_cost_per_tick: float = 3.0
@export var stamina_regen_per_sec: float = 8.0
## Visual pulse when a creature finishes healing inside.
@export var heal_pulse_color: Color = Color(0.3, 1.0, 0.5)

var _stamina: float = 0.0
var _tick_timer: float = 0.0
var _creatures_inside: Array[Node] = []
var _is_active: bool = true

func _ready() -> void:
	stamina_max = float(max(1, stamina_max))
	_stamina = stamina_max
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Emit recharged so the HUD can light up the garden icon.
	garden_recharged.emit()

func _process(delta: float) -> void:
	if not _is_active:
		return
	# Stamina refills continuously when the garden is idle.
	if has_stamina and _creatures_inside.is_empty():
		_stamina = min(stamina_max, _stamina + stamina_regen_per_sec * delta)
	_tick_timer += delta
	if _tick_timer < tick_interval:
		return
	_tick_timer = 0.0
	_apply_healing()

func _on_body_entered(body: Node) -> void:
	if not _is_creature(body):
		return
	if _creatures_inside.size() >= max_concurrent:
		return  # Garden is full; creature waits outside.
	_creatures_inside.append(body)

func _on_body_exited(body: Node) -> void:
	_creatures_inside.erase(body)

func _is_creature(body: Node) -> bool:
	# Accept anything that carries a CreatureNeedsEngine (the canonical needs hub).
	return body.has_method("get_needs") or body.has_node("CreatureNeedsEngine")

func _apply_healing() -> void:
	for creature in _creatures_inside.duplicate():
		if not is_instance_valid(creature):
			continue
		var cost: float = stamina_cost_per_tick if has_stamina else 0.0
		if has_stamina and _stamina < cost:
			# Not enough stamina this tick; garden is exhausted.
			garden_depleted.emit()
			continue
		if has_stamina:
			_stamina -= cost
		_heal_one(creature)

func _heal_one(creature: Node) -> void:
	var healed: float = 0.0
	# Branch on how the creature exposes its health.
	if creature.has_method("heal"):
		healed = creature.heal(heal_per_tick)
	elif creature.has_method("add_health"):
		healed = creature.add_health(heal_per_tick)
	else:
		# Fallback: look for a direct health property.
		if creature.has_node("CreatureNeedsEngine"):
			var needs: Node = creature.get_node("CreatureNeedsEngine")
			if needs.has_method("heal"):
				healed = needs.heal(heal_per_tick)
	# Boost happiness through the needs engine.
	_boost_happiness(creature, happiness_per_tick)
	creature_healed.emit(creature, healed)

func _boost_happiness(creature: Node, amount: float) -> void:
	if creature.has_node("CreatureNeedsEngine"):
		var needs: Node = creature.get_node("CreatureNeedsEngine")
		if needs.has_method("add_happiness"):
			needs.add_happiness(amount)
		elif needs.has_method("modify_need"):
			needs.modify_need("happiness", amount)

## Force-recharge the garden (e.g. from a repair kit or wave bonus).
func recharge() -> void:
	_stamina = stamina_max
	_is_active = true
	garden_recharged.emit()

## Temporarily shut the garden down (e.g. during a boss phase).
func set_active(active: bool) -> void:
	_is_active = active

func get_stamina_ratio() -> float:
	return _stamina / stamina_max if stamina_max > 0.0 else 1.0

func is_full() -> bool:
	return _creatures_inside.size() >= max_concurrent