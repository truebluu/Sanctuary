extends Node
class_name CreatureGroomingRitual

## Interactive grooming minigame that restores creature trust.
## Presents timed grooming prompts; timely responses build trust,
## missed prompts waste the ritual. Builds on CreatureBonding for
## trust tracking, EnergySystem for cost, EventBus for events.

signal ritual_started(creature: CreatureGenome)
signal prompt_presented(prompt: GroomPrompt, index: int)
signal prompt_resolved(prompt: GroomPrompt, success: bool)
signal ritual_completed(trust_gained: int, energy_spent: int)
signal ritual_failed(reason: String)

## A single grooming action the player must perform in time.
class GroomPrompt:
    var kind: StringName = &""
    var window: float = 0.0
    var deadline: float = 0.0
    var resolved: bool = false
    var success: bool = false

    func _init(p_kind: StringName, p_window: float, p_deadline: float) -> void:
        kind = p_kind
        window = p_window
        deadline = p_deadline

## Tunables — one place to retune the minigame feel.
const _ENERGY_COST: int = 5            # energy spent per ritual
const _BASE_WINDOW: float = 1.8        # seconds to respond per prompt
const _TRUST_PER_HIT: int = 3          # trust gained per successful groom
const _TRUST_PER_MISS: int = -1        # trust lost per missed prompt
const _MAX_PROMPTS: int = 8            # prompts per ritual
const _MIN_PROMPTS: int = 4
const _FAIL_MISS_THRESHOLD: float = 0.5  # miss more than half -> ritual fails

var _creature: CreatureGenome = null
var _prompts: Array[GroomPrompt] = []
var _active_index: int = -1
var _hits: int = 0
var _misses: int = 0
var _running: bool = false
var _process_timer: float = 0.0

func start(creature: CreatureGenome) -> bool:
    if creature == null:
        ritual_failed.emit("no creature")
        return false
    _creature = creature
    _prompts.clear()
    _active_index = -1
    _hits = 0
    _misses = 0
    _process_timer = 0.0
    _build_prompts()
    _running = true
    ritual_started.emit(_creature)
    _advance_prompt()
    return true

func _build_prompts() -> void:
    var count: int = randi_range(_MIN_PROMPTS, _MAX_PROMPTS)
    var kinds: Array[StringName] = [&"brush", &"comb", &"massage", &"pluck"]
    for i in count:
        var kind: StringName = kinds[randi() % kinds.size()]
        var window: float = _BASE_WINDOW + randf_range(-0.4, 0.4)
        var deadline: float = window
        _prompts.append(GroomPrompt.new(kind, window, deadline))

func _advance_prompt() -> void:
    _active_index += 1
    if _active_index >= _prompts.size():
        _finish_ritual()
        return
    var prompt: GroomPrompt = _prompts[_active_index]
    prompt.deadline = prompt.window
    prompt.resolved = false
    prompt.success = false
    prompt_presented.emit(prompt, _active_index)

func respond() -> void:
    if not _running:
        return
    var prompt: GroomPrompt = _prompts[_active_index]
    if prompt.resolved:
        return
    prompt.resolved = true
    prompt.success = true
    _hits += 1
    prompt_resolved.emit(prompt, true)
    _advance_prompt()

func _process(delta: float) -> void:
    if not _running:
        return
    var prompt: GroomPrompt = _prompts[_active_index]
    prompt.deadline -= delta
    if prompt.deadline <= 0.0 and not prompt.resolved:
        prompt.resolved = true
        prompt.success = false
        _misses += 1
        prompt_resolved.emit(prompt, false)
        _advance_prompt()

func _finish_ritual() -> void:
    _running = false
    var total: int = _prompts.size()
    if total > 0 and float(_misses) / float(total) >= _FAIL_MISS_THRESHOLD:
        ritual_failed.emit("too many missed prompts")
        return
    var trust: int = _hits * _TRUST_PER_HIT + _misses * _TRUST_PER_MISS
    trust = max(0, trust)
    ritual_completed.emit(trust, _ENERGY_COST)

func is_running() -> bool:
    return _running

func get_progress() -> float:
    if _prompts.is_empty():
        return 0.0
    return float(_active_index) / float(_prompts.size())

func cancel() -> void:
    _running = false
    ritual_failed.emit("cancelled")