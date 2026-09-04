extends Resource

# TUNABLES --------------------------------------------------------------
# Central type interaction chart. Extend or modify this dictionary to adjust
# creature battle strengths without touching logic.
# Format: {"attacker_type": {"defender_type": multiplier, ...}, ...}
const TYPE_CHART: Dictionary = {
    "fire": {
        "grass": 2.0, "water": 0.5, "ice": 2.0, "rock": 0.5,
        "ground": 0.5, "electric": 1.0, "flying": 1.0, "psychic": 1.0,
        "dragon": 0.5, "metal": 1.0, "ghost": 1.0, "dark": 1.0, "fairy": 1.0,
    },
    "water": {
        "fire": 2.0, "ground": 2.0, "rock": 2.0, "dragon": 0.5,
        "steel": 0.5, "electric": 1.0, "flying": 1.0, "psychic": 1.0,
        "ice": 0.5, "ghost": 1.0, "dark": 1.0, "fairy": 1.0,
    },
    "grass": {
        "fire": 0.5, "water": 2.0, "rock": 2.0, "ground": 2.0,
        "flying": 0.5, "psychic": 1.0, "ice": 2.0, "dragon": 0.5,
        "steel": 0.5, "ghost": 1.0, "dark": 1.0, "fairy": 1.0,
    },
    "electric": {
        "water": 2.0, "flying": 2.0, "steel": 2.0, "ground": 0.0,
        "dragon": 0.5, "psychic": 1.0, "ice": 1.0, "rock": 1.0,
        "ghost": 1.0, "dark": 1.0, "fairy": 1.0,
    },
    "ice": {
        "grass": 2.0, "ground": 2.0, "flying": 2.0, "dragon": 2.0,
        "steel": 0.5, "water": 0.5, "rock": 0.5, "fire": 0.5,
        "psychic": 1.0, "ghost": 1.0, "dark": 1.0, "fairy": 1.0,
    },
    "fighting": {
        "normal": 2.0, "ice": 2.0, "poison": 2.0, "flying": 0.5,
        "psychic": 0.5, "bug": 0.5, "rock": 0.5, "ghost": 0.0,
        "dark": 2.0, "steel": 2.0, "fairy": 0.5,
    },
    "poison": {
        "grass": 2.0, "fighting": 0.5, "poison": 0.5, "ground": 0.5,
        "rock": 0.5, "ghost": 0.5, "steel": 0.0, "fairy": 2.0,
    },
    "ground": {
        "fire": 2.0, "electric": 2.0, "poison": 2.0, "rock": 2.0,
        "steel": 2.0, "grass": 0.5, "flying": 0.0, "bug": 0.5,
        "ghost": 0.5,
    },
    "flying": {
        "electric": 2.0, "grass": 2.0, "fighting": 2.0, "bug": 2.0,
        "rock": 0.5, "steel": 0.5,
    },
    "psychic": {
        "fighting": 2.0, "poison": 2.0, "psychic": 0.5, "dark": 0.5,
        "steel": 0.5,
    },
    "ghost": {
        "psychic": 2.0, "ghost": 2.0, "dark": 0.5,
    },
    "dark": {
        "fighting": 2.0, "psychic": 2.0, "ghost": 2.0, "fairy": 2.0,
    },
    "steel": {
        "ice": 2.0, "rock": 2.0, "steel": 0.5, "fire": 0.5,
        "water": 0.5, "electric": 0.5, "ghost": 1.0, "dragon": 0.5,
        "fairy": 2.0,
    },
    "dragon": {
        "dragon": 2.0, "dragon": 0.5, "steel": 0.5, "fairy": 0.0,
    },
    "fairy": {
        "fighting": 2.0, "dragon": 2.0, "dark": 2.0, "steel": 0.5,
        "poison": 0.5,
    },
}.export var type_chart: Dictionary = TYPE_CHART

# PUBLIC METHODS ---------------------------------------------------------

func get_advantage(attacker_type: String, defender_type: String) -> float:
    """
    Returns the damage multiplier for the given type interaction.
    Unknown types default to neutral (1.0).
    """
    var attacker_multipliers = type_chart.get(attacker_type, {})
    return attacker_multipliers.get(defender_type, 1.0)

# SIGNAL HELPERS ---------------------------------------------------------

signal type_advantage_calculated(attacker_type: String, defender_type: String, multiplier: float)

# EXAMPLE USAGE -----------------------------------------------------------

func evaluate_type(attacker: Creature, defender: Creature) -> void:
    """
    Calculates and broadcasts the type advantage for an attack.
    This builds on the existing Creature class and EventBus for UI feedback.
    """
    var mult = get_advantage(attacker.type, defender.type)
    type_advantage_calculated.emit(attacker.type, defender.type, mult)
    EventBus.emit_signal("creature_type_advantage", attacker.type, defender.type, mult)