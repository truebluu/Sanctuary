class_name CreatureTypeChart
## Creature battle type chart.
## Defines type advantages/disadvantages for creature battles.
## Builds on the sanctuary creature battle system (SANCT-008) by providing
## the core type-effectiveness data. This is a static utility class; no
## instance is needed. All effectiveness values are tunable constants so a
## designer can rebalance the chart in one place.

# Type identifiers (used as dictionary keys and for UI display).
enum Type {
	NORMAL,
	FIRE,
	WATER,
	GRASS,
	ELECTRIC,
	ICE,
	FIGHTING,
	POISON,
	GROUND,
	FLYING,
	PSYCHIC,
	BUG,
	ROCK,
	GHOST,
	DRAGON,
	DARK,
	STEEL,
	FAIRY
}

# Human-readable names for UI (index matches Type enum).
const TYPE_NAMES := {
	Type.NORMAL: "Normal",
	Type.FIRE: "Fire",
	Type.WATER: "Water",
	Type.GRASS: "Grass",
	Type.ELECTRIC: "Electric",
	Type.ICE: "Ice",
	Type.FIGHTING: "Fighting",
	Type.POISON: "Poison",
	Type.GROUND: "Ground",
	Type.FLYING: "Flying",
	Type.PSYCHIC: "Psychic",
	Type.BUG: "Bug",
	Type.ROCK: "Rock",
	Type.GHOST: "Ghost",
	Type.DRAGON: "Dragon",
	Type.DARK: "Dark",
	Type.STEEL: "Steel",
	Type.FAIRY: "Fairy"
}

# Effectiveness multipliers.
const EFFECT_NEUTRAL := 1.0
const EFFECT_SUPER := 2.0
const EFFECT_NOT_VERY := 0.5
const EFFECT_IMMUNE := 0.0

# Type chart: key = attacker_type, value = dictionary of defender_type -> multiplier.
# Only non-neutral entries are listed; missing pairs default to EFFECT_NEUTRAL.
const _TYPE_CHART := {
	Type.FIRE: {
		Type.GRASS: EFFECT_SUPER,
		Type.ICE: EFFECT_SUPER,
		Type.BUG: EFFECT_SUPER,
		Type.STEEL: EFFECT_SUPER,
		Type.FIRE: EFFECT_NOT_VERY,
		Type.WATER: EFFECT_NOT_VERY,
		Type.ROCK: EFFECT_NOT_VERY,
		Type.DRAGON: EFFECT_NOT_VERY
	},
	Type.WATER: {
		Type.FIRE: EFFECT_SUPER,
		Type.GROUND: EFFECT_SUPER,
		Type.ROCK: EFFECT_SUPER,
		Type.WATER: EFFECT_NOT_VERY,
		Type.GRASS: EFFECT_NOT_VERY,
		Type.DRAGON: EFFECT_NOT_VERY
	},
	Type.GRASS: {
		Type.WATER: EFFECT_SUPER,
		Type.GROUND: EFFECT_SUPER,
		Type.ROCK: EFFECT_SUPER,
		Type.FIRE: EFFECT_NOT_VERY,
		Type.GRASS: EFFECT_NOT_VERY,
		Type.POISON: EFFECT_NOT_VERY,
		Type.FLYING: EFFECT_NOT_VERY,
		Type.BUG: EFFECT_NOT_VERY,
		Type.DRAGON: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_NOT_VERY
	},
	Type.ELECTRIC: {
		Type.WATER: EFFECT_SUPER,
		Type.FLYING: EFFECT_SUPER,
		Type.ELECTRIC: EFFECT_NOT_VERY,
		Type.GRASS: EFFECT_NOT_VERY,
		Type.DRAGON: EFFECT_NOT_VERY,
		Type.GROUND: EFFECT_IMMUNE
	},
	Type.ICE: {
		Type.GRASS: EFFECT_SUPER,
		Type.GROUND: EFFECT_SUPER,
		Type.FLYING: EFFECT_SUPER,
		Type.DRAGON: EFFECT_SUPER,
		Type.FIRE: EFFECT_NOT_VERY,
		Type.WATER: EFFECT_NOT_VERY,
		Type.ICE: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_NOT_VERY
	},
	Type.FIGHTING: {
		Type.NORMAL: EFFECT_SUPER,
		Type.ICE: EFFECT_SUPER,
		Type.ROCK: EFFECT_SUPER,
		Type.DARK: EFFECT_SUPER,
		Type.STEEL: EFFECT_SUPER,
		Type.POISON: EFFECT_NOT_VERY,
		Type.FLYING: EFFECT_NOT_VERY,
		Type.PSYCHIC: EFFECT_NOT_VERY,
		Type.BUG: EFFECT_NOT_VERY,
		Type.FAIRY: EFFECT_NOT_VERY,
		Type.GHOST: EFFECT_IMMUNE
	},
	Type.POISON: {
		Type.GRASS: EFFECT_SUPER,
		Type.FAIRY: EFFECT_SUPER,
		Type.POISON: EFFECT_NOT_VERY,
		Type.GROUND: EFFECT_NOT_VERY,
		Type.ROCK: EFFECT_NOT_VERY,
		Type.GHOST: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_IMMUNE
	},
	Type.GROUND: {
		Type.FIRE: EFFECT_SUPER,
		Type.ELECTRIC: EFFECT_SUPER,
		Type.POISON: EFFECT_SUPER,
		Type.ROCK: EFFECT_SUPER,
		Type.STEEL: EFFECT_SUPER,
		Type.GRASS: EFFECT_NOT_VERY,
		Type.BUG: EFFECT_NOT_VERY,
		Type.FLYING: EFFECT_IMMUNE
	},
	Type.FLYING: {
		Type.GRASS: EFFECT_SUPER,
		Type.FIGHTING: EFFECT_SUPER,
		Type.BUG: EFFECT_SUPER,
		Type.ELECTRIC: EFFECT_NOT_VERY,
		Type.ROCK: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_NOT_VERY
	},
	Type.PSYCHIC: {
		Type.FIGHTING: EFFECT_SUPER,
		Type.POISON: EFFECT_SUPER,
		Type.PSYCHIC: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_NOT_VERY,
		Type.DARK: EFFECT_IMMUNE
	},
	Type.BUG: {
		Type.GRASS: EFFECT_SUPER,
		Type.PSYCHIC: EFFECT_SUPER,
		Type.DARK: EFFECT_SUPER,
		Type.FIRE: EFFECT_NOT_VERY,
		Type.FIGHTING: EFFECT_NOT_VERY,
		Type.POISON: EFFECT_NOT_VERY,
		Type.FLYING: EFFECT_NOT_VERY,
		Type.GHOST: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_NOT_VERY,
		Type.FAIRY: EFFECT_NOT_VERY
	},
	Type.ROCK: {
		Type.FIRE: EFFECT_SUPER,
		Type.ICE: EFFECT_SUPER,
		Type.FLYING: EFFECT_SUPER,
		Type.BUG: EFFECT_SUPER,
		Type.FIGHTING: EFFECT_NOT_VERY,
		Type.GROUND: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_NOT_VERY
	},
	Type.GHOST: {
		Type.PSYCHIC: EFFECT_SUPER,
		Type.GHOST: EFFECT_SUPER,
		Type.NORMAL: EFFECT_IMMUNE,
		Type.DARK: EFFECT_NOT_VERY
	},
	Type.DRAGON: {
		Type.DRAGON: EFFECT_SUPER,
		Type.STEEL: EFFECT_NOT_VERY,
		Type.FAIRY: EFFECT_IMMUNE
	},
	Type.DARK: {
		Type.PSYCHIC: EFFECT_SUPER,
		Type.GHOST: EFFECT_SUPER,
		Type.FIGHTING: EFFECT_NOT_VERY,
		Type.DARK: EFFECT_NOT_VERY,
		Type.FAIRY: EFFECT_NOT_VERY
	},
	Type.STEEL: {
		Type.ICE: EFFECT_SUPER,
		Type.ROCK: EFFECT_SUPER,
		Type.FAIRY: EFFECT_SUPER,
		Type.FIRE: EFFECT_NOT_VERY,
		Type.WATER: EFFECT_NOT_VERY,
		Type.ELECTRIC: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_NOT_VERY
	},
	Type.FAIRY: {
		Type.FIGHTING: EFFECT_SUPER,
		Type.DRAGON: EFFECT_SUPER,
		Type.DARK: EFFECT_SUPER,
		Type.FIRE: EFFECT_NOT_VERY,
		Type.POISON: EFFECT_NOT_VERY,
		Type.STEEL: EFFECT_NOT_VERY
	}
}

## Returns the effectiveness multiplier for an attack of type `attacker_type`
## against a defender of type `defender_type`. Always returns a valid float.
static func get_effectiveness(attacker_type: int, defender_type: int) -> float:
	if not _TYPE_CHART.has(attacker_type):
		push_warning("CreatureTypeChart: Unknown attacker type %d, returning neutral." % attacker_type)
		return EFFECT_NEUTRAL
	var defender_map: Dictionary = _TYPE_CHART[attacker_type]
	if defender_map.has(defender_type):
		return defender_map[defender_type]
	return EFFECT_NEUTRAL

## Returns the display name for a type.
static func get_type_name(type_id: int) -> String:
	return TYPE_NAMES.get(type_id, "Unknown")