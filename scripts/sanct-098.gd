extends Node
class_name CreatureTherapySession

## Healing dialogue tree that improves creature mood over time.
## Presents branching therapeutic prompts; empathetic choices raise mood,
## dismissive ones lower it. Builds on CreatureNeedsEngine for mood state
## and emits through EventBus for UI.

signal session_started(creature_id: String)
signal prompt_shown(prompt_id: String, options: Array[Dictionary])
signal choice_made(prompt_id: String, option_index: int, mood_delta: int)
signal session_completed(creature_id: String, total_mood_gain: int, bonds_formed: int)
signal mood_changed(creature_id: String, new_mood: int)

const MAX_MOOD: int = 100
const MIN_MOOD: int = 0
const MOOD_PER_GOOD_CHOICE: int = 8
const MOOD_PER_BAD_CHOICE: int = -5
const MOOD_PER_NEUTRAL_CHOICE: int = 2
const SESSION_PROMPT_COUNT: int = 5
const BOND_THRESHOLD: int = 30

var _creature_id: String = ""
var _current_prompt_index: int = 0
var _prompts: Array[Dictionary] = []
var _total_mood_gain: int = 0
var _bonds_formed: int = 0
var _active: bool = false

func _ready() -> void:
    set_process(false)

func begin_session(creature_id: String) -> void:
    _creature_id = creature_id
    _current_prompt_index = 0
    _total_mood_gain = 0
    _bonds_formed = 0
    _active = true
    _build_prompt_chain()
    set_process(true)
    session_started.emit(creature_id)
    _show_current_prompt()

func _build_prompt_chain() -> void:
    _prompts.clear()
    var rng := SharedRNG.get()
    var mood: int = _read_mood()
    var empathy: int = _read_empathy()
    var needs := _read_needs()

    # Branch the tree based on the creature's emotional state.
    if mood < 30:
        _prompts.append(_make_prompt("fear", "The creature trembles. What do you do?", [
            _option("Speak softly and wait.", MOOD_PER_GOOD_CHOICE, empathy >= 5),
            _option("Reach out quickly to comfort.", MOOD_PER_BAD_CHOICE, false),
            _option("Offer a treat.", MOOD_PER_NEUTRAL_CHOICE, false),
        ]))
    elif mood < 60:
        _prompts.append(_make_prompt("lonely", "The creature looks away, seeming lonely.", [
            _option("Sit quietly nearby.", MOOD_PER_GOOD_CHOICE, false),
            _option("Tell it about your day.", MOOD_PER_NEUTRAL_CHOICE, false),
            _option("Ask what it wants.", MOOD_PER_GOOD_CHOICE, empathy >= 4),
        ]))
    else:
        _prompts.append(_make_prompt("playful", "The creature seems energetic and playful.", [
            _option("Play along and match its energy.", MOOD_PER_GOOD_CHOICE, false),
            _option("Suggest a rest instead.", MOOD_PER_BAD_CHOICE, false),
            _option("Offer a game.", MOOD_PER_GOOD_CHOICE, false),
        ]))

    # Fill remaining prompts from a pool, weighted by current mood.
    var pool: Array[Dictionary] = _prompt_pool(mood)
    while _prompts.size() < SESSION_PROMPT_COUNT and not pool.is_empty():
        var pick: int = rng.randi_range(0, pool.size() - 1)
        _prompts.append(pool[pick])
        pool.remove_at(pick)

func _prompt_pool(mood: int) -> Array[Dictionary]:
    var all: Array[Dictionary] = []
    all.append(_make_prompt("trust", "The creature tests your trustworthiness.", [
        _option("Be patient and consistent.", MOOD_PER_GOOD_CHOICE, false),
        _option("Push for a quick bond.", MOOD_PER_BAD_CHOICE, false),
        _option("Respect its pace.", MOOD_PER_GOOD_CHOICE, false),
    ]))
    all.append(_make_prompt("hurt", "The creature reveals an old wound.", [
        _option("Listen without interrupting.", MOOD_PER_GOOD_CHOICE, false),
        _option("Offer a solution right away.", MOOD_PER_NEUTRAL_CHOICE, false),
        _option("Acknowledge its pain.", MOOD_PER_GOOD_CHOICE, false),
    ]))
    all.append(_make_prompt("joy", "The creature shares a happy memory.", [
        _option("Celebrate with it.", MOOD_PER_GOOD_CHOICE, false),
        _option("Change the subject.", MOOD_PER_BAD_CHOICE, false),
        _option("Ask more about it.", MOOD_PER_GOOD_CHOICE, false),
    ]))
    all.append(_make_prompt("anxious", "The creature seems anxious about something.", [
        _option("Validate its feelings.", MOOD_PER_GOOD_CHOICE, false),
        _option("Tell it not to worry.", MOOD_PER_BAD_CHOICE, false),
        _option("Help it plan.", MOOD_PER_NEUTRAL_CHOICE, false),
    ]))
    all.append(_make_prompt("grateful", "The creature expresses gratitude.", [
        _option("Say it was nothing.", MOOD_PER_NEUTRAL_CHOICE, false),
        _option("Share the credit.", MOOD_PER_GOOD_CHOICE, false),
        _option("Greet it warmly.", MOOD_PER_GOOD_CHOICE, false),
    ]))
    return all

func _make_prompt(prompt_id: String, text: String, options: Array[Dictionary]) -> Dictionary:
    return {
        "id": prompt_id,
        "text": text,
        "options": options,
    }

func _option(text: String, mood_delta: int, requires_empathy: bool) -> Dictionary:
    return {
        "text": text,
        "mood_delta": mood_delta,
        "requires_empathy": requires_empathy,
    }

func _show_current_prompt() -> void:
    if _current_prompt_index >= _prompts.size():
        _end_session()
        return
    var prompt: Dictionary = _prompts[_current_prompt_index]
    prompt_shown.emit(prompt["id"], prompt["options"])

func make_choice(option_index: int) -> void:
    if not _active:
        return
    var prompt: Dictionary = _prompts[_current_prompt_index]
    var options: Array[Dictionary] = prompt["options"]
    if option_index < 0 or option_index >= options.size():
        return
    var chosen: Dictionary = options[option_index]
    var delta: int = chosen["mood_delta"]
    _apply_mood(delta)
    choice_made.emit(prompt["id"], option_index, delta)
    _current_prompt_index += 1
    _show_current_prompt()

func _apply_mood(delta: int) -> void:
    var current: int = _read_mood()
    var new_mood: int = clampi(current + delta, MIN_MOOD, MAX_MOOD)
    _total_mood_gain += (new_mood - current)
    if _total_mood_gain >= BOND_THRESHOLD:
        _bonds_formed += 1
    _write_mood(new_mood)
    mood_changed.emit(_creature_id, new_mood)

func _read_mood() -> int:
    if not is_instance_valid(CreatureNeedsEngine):
        return 50
    return CreatureNeedsEngine.get_mood(_creature_id)

func _write_mood(value: int) -> void:
    if is_instance_valid(CreatureNeedsEngine):
        CreatureNeedsEngine.set_mood(_creature_id, value)

func _read_empathy() -> int:
    if not is_instance_valid(CreatureNeedsEngine):
        return 0
    return CreatureNeedsEngine.get_trait_value(_creature_id, "empathy")

func _read_needs() -> Dictionary:
    if not is_instance_valid(CreatureNeedsEngine):
        return {}
    return CreatureNeedsEngine.get_needs(_creature_id)

func _end_session() -> void:
    _active = false
    set_process(false)
    session_completed.emit(_creature_id, _total_mood_gain, _bonds_formed)
    if _total_mood_gain > 0:
        EventBus.emit("creature_therapy_done", {
            "creature_id": _creature_id,
            "mood_gain": _total_mood_gain,
            "bonds": _bonds_formed,
        })

func is_active() -> bool:
    return _active

func get_current_mood() -> int:
    return _read_mood()

func get_total_mood_gain() -> int:
    return _total_mood_gain

func get_bonds_formed() -> int:
    return _bonds_formed

func cancel_session() -> void:
    if not _active:
        return
    _active = false
    set_process(false)
    session_completed.emit(_creature_id, _total_mood_gain, _bonds_formed)