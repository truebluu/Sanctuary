extends RefCounted
class_name CreatureTraitExpression

## CreatureTraitExpression — Taming (The Sanctuary)
## Creature personality & trait expression system. Stores normalized traits in
## [0.0, 1.0], computes a weighted aggregate expression level, and maps it to a
## human-readable personality label. Pure logic (RefCounted) so it runs headless
## in CI and is unit-testable without a scene. The Sanctuary creature sim reads
## this every session to drive behavior, evolution, and the codex UI.

## Emitted when a trait changes (trait_name, old_value, new_value).
signal trait_changed(trait_name: StringName, old_value: float, new_value: float)

var traits: Dictionary = {}

## Thresholds for personality classification
const THRESHOLD_BOLD: float = 0.7
const THRESHOLD_TIMID: float = 0.3
const THRESHOLD_BALANCED_LOW: float = 0.4
const THRESHOLD_BALANCED_HIGH: float = 0.6

## Trait weight modifiers (default 1.0 each)
var trait_weights: Dictionary = {
	"boldness": 1.0,
	"affection": 1.0,
	"curiosity": 1.0,
	"patience": 1.0,
	"playfulness": 1.0
}

func _init() -> void:
	# Traits and weights are initialized inline; nothing else to set up.
	# The Sanctuary creature sim calls apply_needs_delta() each tick to drive
	# personality drift, and the codex UI reads describe() for the label.
	return

## Set a trait value, clamped to [0.0, 1.0]. Emits trait_changed.
func set_trait(trait_name: StringName, value: float) -> void:
	var old_value: float = traits.get(trait_name, 0.0)
	var clamped: float = clamp(value, 0.0, 1.0)
	traits[trait_name] = clamped
	# Ensure weight exists for this trait (default 1.0)
	if not trait_weights.has(trait_name):
		trait_weights[trait_name] = 1.0
	if not is_equal_approx(old_value, clamped):
		trait_changed.emit(trait_name, old_value, clamped)

## Return trait value or 0.0 if unknown.
func get_trait(trait_name: StringName) -> float:
	return traits.get(trait_name, 0.0)

## Return all known trait names.
func trait_names() -> Array[StringName]:
	return traits.keys()

## Weighted average of all traits; 0.0 if none set.
func expression_level() -> float:
	if traits.is_empty():
		return 0.0
	var total_weight: float = 0.0
	var weighted_sum: float = 0.0
	for trait_name in traits:
		var weight: float = trait_weights.get(trait_name, 1.0)
		weighted_sum += traits[trait_name] * weight
		total_weight += weight
	if total_weight == 0.0:
		return 0.0
	return weighted_sum / total_weight

## Human-readable personality label based on aggregate + dominant trait.
func describe() -> String:
	var level: float = expression_level()
	if traits.is_empty():
		return "Unknown"
	# Find dominant trait (highest value)
	var dominant_trait: StringName = ""
	var dominant_value: float = -1.0
	for trait_name in traits:
		if traits[trait_name] > dominant_value:
			dominant_value = traits[trait_name]
			dominant_trait = trait_name
	# Classify based on aggregate level and dominant trait
	if level >= THRESHOLD_BOLD:
		if dominant_trait == "boldness":
			return "Bold"
		elif dominant_trait == "affection":
			return "Devoted"
		elif dominant_trait == "curiosity":
			return "Inquisitive"
		elif dominant_trait == "playfulness":
			return "Exuberant"
		else:
			return "Confident"
	elif level <= THRESHOLD_TIMID:
		if dominant_trait == "patience":
			return "Steady"
		else:
			return "Timid"
	elif level >= THRESHOLD_BALANCED_LOW and level <= THRESHOLD_BALANCED_HIGH:
		return "Balanced"
	else:
		# Moderate range
		if dominant_trait == "boldness":
			return "Assertive"
		elif dominant_trait == "affection":
			return "Warm"
		elif dominant_trait == "curiosity":
			return "Curious"
		elif dominant_trait == "playfulness":
			return "Playful"
		elif dominant_trait == "patience":
			return "Patient"
		else:
			return "Moderate"

## Clear all traits and reset to defaults.
func reset() -> void:
	traits.clear()
	trait_weights.clear()
	trait_weights["boldness"] = 1.0
	trait_weights["affection"] = 1.0
	trait_weights["curiosity"] = 1.0
	trait_weights["patience"] = 1.0
	trait_weights["playfulness"] = 1.0

## Feed a trait from the creature sim's needs system (e.g. hunger/energy).
## This is how the Sanctuary creature loop drives personality drift each tick.
func apply_needs_delta(trait_name: StringName, delta: float) -> void:
	var current: float = get_trait(trait_name)
	set_trait(trait_name, current + delta)
