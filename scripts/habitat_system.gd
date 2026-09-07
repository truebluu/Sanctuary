# HabitatSystem — Sanctuary (Bluu Ink Studios)
# SANCT-742 Creature habitat/environment system.
# Pure simulation logic (headless-testable): each creature has a preferred
# biome and the current biome it is housed in. Habitat-environment fit modifies
# the creature's mood and need-decay so that matching biomes feel comfortable
# and mismatched ones stress the creature. Hooks into CreatureNeeds so the
# effect propagates to hunger/energy/social/trust.
#
# Biome fit rules:
#   - MATCH (preferred == current)     -> small mood boost, decays needs slower.
#   - NEUTRAL (compatible biome)       -> no penalty, no boost.
#   - MISMATCH (incompatible biome)    -> mood penalty + faster need decay.
#
# The system is node-agnostic (RefCounted) and emits signals so a Habitat2D /
# HUD can observe changes; it looks up the creature's CreatureNeeds via the
# "sanctuary_creature" group when one is supplied so real gameplay reads through.
class_name HabitatSystem
extends RefCounted

signal environment_changed(biome: StringName)
signal fit_changed(fit: StringName, score: float)
signal mood_changed(mood: float)
signal abandoned_environment

## Named biomes and which other biomes each is compatible with (NEUTRAL fit).
const COMPAT: Dictionary = {
	&"forest": [&"meadow", &"river"],
	&"meadow": [&"forest", &"river"],
	&"river":  [&"forest", &"meadow", &"coast"],
	&"coast":  [&"river", &"desert"],
	&"desert": [&"coast", &"cave"],
	&"cave":   [&"desert", &"forest"],
	&"tundra": [&"cave", &"mountain"],
	&"mountain": [&"tundra", &"forest"],
}

## How strongly environment fit nudges each need each tick (0..1 delta).
@export var fit_decay_multiplier: float = 0.6
@export var mismatch_decay_multiplier: float = 1.7
@export var match_mood_bonus: float = 0.02
@export var mismatch_mood_penalty: float = 0.05

var current_biome: String = &"meadow"
var preferred_biome: String = &"forest"
var mood: float = 0.5
var _creature: Node = null
var _needs: RefCounted = null

## Bind to a creature node. It must be in the "creatures" group (or the
## "sanctuary_creatures" group) and expose a CreatureNeeds as child "Needs".
func setup_with_creature(creature: Node) -> void:
	if creature == null:
		return
	_creature = creature
	var needs: Node = creature.get_node_or_null("Needs") if creature.has_node("Needs") else null
	if needs != null and needs is CreatureNeeds:
		_needs = needs
		# Feed our mood into the needs system via the trust channel so bonding
		# and habitat are linked in gameplay.
		needs.gain_trust(mood * 0.02)
	# Keep a reference to the group so the game can route environment events.
	if creature.is_in_group("sanctuary_creatures"):
		mood_changed.emit(mood)

## Advance the habitat simulation by `delta` seconds.
func tick(delta: float) -> void:
	var fit: StringName = evaluate_fit()
	# Mood drifts toward 0.5 at rest, pushed by fit each tick.
	mood = clampf(mood + (0.5 - mood) * 0.02 * delta, 0.0, 1.0)
	match fit:
		&"match":
			mood = clampf(mood + match_mood_bonus * delta, 0.0, 1.0)
			if _needs != null:
				_needs.set_social(clampf(_needs.get_social() + 0.004 * delta, 0.0, 1.0))
		&"mismatch":
			mood = clampf(mood - mismatch_mood_penalty * delta, 0.0, 1.0)
			if _needs != null:
				_needs.set_energy(clampf(_needs.get_energy() - 0.006 * delta, 0.0, 1.0))
				_needs.set_social(clampf(_needs.get_social() - 0.004 * delta, 0.0, 1.0))
			if mood <= 0.02:
				abandoned_environment.emit()
	mood_changed.emit(mood)

## Change the biome the creature currently occupies.
func set_environment(biome: String) -> void:
	if biome == current_biome:
		return
	current_biome = biome
	environment_changed.emit(biome)
	fit_changed.emit(evaluate_fit(), mood)

## Set the creature's preferred biome (from its genetics/backstory).
func set_preferred(biome: String) -> void:
	preferred_biome = biome

## Returns &"match" / &"neutral" / &"mismatch" for current vs preferred.
func evaluate_fit(biome: String = current_biome) -> String:
	if biome == preferred_biome:
		return &"match"
	if biome in (COMPAT.get(preferred_biome, []) as Array):
		return &"neutral"
	return &"mismatch"

## Decay multiplier a CreatureNeeds should apply when advancing needs.
func decay_multiplier_for(biome: String = current_biome) -> float:
	match evaluate_fit(biome):
		&"match":
			return fit_decay_multiplier
		&"neutral":
			return 1.0
		_:
			return mismatch_decay_multiplier

func get_mood() -> float: return mood
func get_current_biome() -> String: return current_biome
func get_preferred_biome() -> String: return preferred_biome

func to_dict() -> Dictionary:
	return {
		"biome": current_biome,
		"preferred": preferred_biome,
		"mood": mood,
	}
