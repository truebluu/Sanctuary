class_name EvolutionTrigger

# Tunables --------------------------------------------------------------
# Minimum creature level required for evolution.
const EVOLUTION_LEVEL_THRESHOLD: int = 10
# Minimum happiness percentage (0‑100) required for evolution.
const EVOLUTION_HAPPINESS_THRESHOLD: float = 75.0

# Emitted when this trigger successfully evolves the creature.
signal evolved(evolved_creature)

@export var target_creature: NodePath

func _ready() -> void:
    if target_creature.is_empty():
        push_error("EvolutionTrigger: target_creature export is empty.")
        return
    var creature = get_node_or_null(target_creature)
    if not creature:
        push_error("EvolutionTrigger: target_creature %s not found." % target_creature)
        return
    _creature = creature

    # Connect to expected stats signals.
    if _creature.has_signal("level_up"):
        _creature.connect("level_up", Callable(self, "_on_level_up"))
    if _creature.has_signal("happiness_changed"):
        _creature.connect("happiness_changed", Callable(self, "_on_happiness_changed"))

    # Initial check in case thresholds are already satisfied.
    _check_evolution()

func _on_level_up() -> void:
    _check_evolution()

func _on_happiness_changed(_new_happiness: float) -> void:
    _check_evolution()

func _check_evolution() -> void:
    if not _creature:
        return

    var current_level: int = 0
    var current_happiness: float = 0.0

    # Retrieve level; creature may expose `level` property or `get_level()` method.
    if _creature.has_method("get_level"):
        current_level = _creature.call("get_level",)
    elif _creature.has_property("level"):
        current_level = _creature.level
    else:
        push_warning("EvolutionTrigger: creature %s does not expose level." % _creature)
        return

    # Retrieve happiness; creature may expose `happiness` property or `get_happiness()` method.
    if _creature.has_method("get_happiness"):
        current_happiness = _creature.call("get_happiness",)
    elif _creature.has_property("happiness"):
        current_happiness = _creature.happiness
    else:
        push_warning("EvolutionTrigger: creature %s does not expose happiness." % _creature)
        return

    if current_level >= EVOLUTION_LEVEL_THRESHOLD and current_happiness >= EVOLUTION_HAPPINESS_THRESHOLD:
        _perform_evolution()

func _perform_evolution() -> void:
    # Notify listeners.
    emit_signal("evolved", _creature)

    # Broadcast globally via EventBus.
    if EventBus:
        EventBus.emit_signal("creature_evolved", _creature)

    # Invoke creature's own evolution logic.
    if _creature.has_method("evolve"):
        _creature.call("evolve")
    else:
        push_warning("EvolutionTrigger: creature %s does not have an `evolve` method." % _creature)