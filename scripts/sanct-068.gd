extends Node2D
class_name CreatureBondingMinigame

## Bonding minigame that raises a bond meter unlocking evolution branches and stat bonuses.
## Builds on Creature, CreatureNeeds, and the EventBus/GameState autoloads.
## Feel: a timed interaction where the player matches prompts; success raises bond,
## which gates evolution branches and grants passive stat bonuses.

signal bond_changed(new_value: int, max_value: int)
signal bond_milestone_reached(level: int, reward: String)
signal minigame_started
signal minigame_finished(success: bool, bond_gained: int)

# --- Tunables (one-setting changes) ---
const BOND_MAX: int = 100
const BOND_PER_HIT: int = 5
const BOND_MILESTONE_STEP: int = 25
const PROMPT_DURATION: float = 2.5
const PROMPT_GAP: float = 0.6
const MAX_PROMPTS_PER_RUN: int = 8
const BOND_BONUS_PER_LEVEL: int = 2  # stat bonus per bond milestone

@export var creature: Creature
@export var prompt_label: Label
@export var success_fx: Node2D
@export var fail_fx: Node2D

var _bond: int = 0
var _active: bool = false
var _prompt_timer: SceneTreeTimer
var _prompt_index: int = 0
var _prompts: Array[String] = []
var _current_prompt: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

const PROMPTS: PackedStringArray = [
    "Tap the creature!",
    "Hold to pet!",
    "Quick tap x3!",
    "Follow the glow!",
    "Match the color!",
    "Shield the creature!",
    "Feed the treat!",
    "Dance along!"
]

func _ready() -> void:
    _rng.randomize()
    add_to_group("bonding_minigames")
    if creature == null:
        push_warning("CreatureBondingMinigame: no creature assigned; bond will not persist to a creature.")

func start() -> void:
    if _active:
        return
    _active = true
    _prompt_index = 0
    _prompts = _build_prompt_pool()
    minigame_started.emit()
    EventBus.emit("bonding_minigame_started", self)
    _run_next_prompt()

func _build_prompt_pool() -> Array[String]:
    var pool: Array[String] = PROMPTS.duplicate()
    var result: Array[String] = []
    var count: int = mini(MAX_PROMPTS_PER_RUN, pool.size())
    for i in range(count):
        var idx: int = _rng.randi_range(0, pool.size() - 1)
        result.append(pool[idx])
        pool.remove_at(idx)
    return result

func _run_next_prompt() -> void:
    if _prompt_index >= _prompts.size():
        _finish(true)
        return
    _current_prompt = _prompts[_prompt_index]
    prompt_label.text = _current_prompt
    _prompt_timer = get_tree().create_timer(PROMPT_DURATION)
    _prompt_timer.timeout.connect(_on_prompt_timeout)
    # Player input is handled by the player/controller; we listen for a bond action.
    Input.action_press("bond_prompt")  # placeholder; real input wired to player.gd

func _on_prompt_timeout() -> void:
    _prompt_index += 1
    _advance()

func _advance() -> void:
    await get_tree().create_timer(PROMPT_GAP).timeout
    _run_next_prompt()

func register_hit() -> void:
    if not _active:
        return
    _bond = mini(_bond + BOND_PER_HIT, BOND_MAX)
    _emit_bond_changed()
    _check_milestone()
    if success_fx != null:
        success_fx.visible = true
        success_fx.visible = false

func _emit_bond_changed() -> void:
    bond_changed.emit(_bond, BOND_MAX)
    if creature != null and creature.has_method("set_bond"):
        creature.set_bond(_bond)

func _check_milestone() -> void:
    var level: int = _bond / BOND_MILESTONE_STEP
    var prev_level: int = (_bond - BOND_PER_HIT) / BOND_MILESTONE_STEP
    if level > prev_level:
        var reward: String = "Bond bonus +%d stat" % (BOND_BONUS_PER_LEVEL * level)
        bond_milestone_reached.emit(level, reward)
        GameState.record_event("bond_milestone", {"level": level, "reward": reward})

func _finish(success: bool) -> void:
    _active = false
    var gained: int = _bond
    minigame_finished.emit(success, gained)
    EventBus.emit("bonding_minigame_finished", {"success": success, "bond_gained": gained})

func get_bond() -> int:
    return _bond

func get_bond_level() -> int:
    return _bond / BOND_MILESTONE_STEP

func get_stat_bonus() -> int:
    return BOND_BONUS_PER_LEVEL * get_bond_level()

func reset() -> void:
    _bond = 0
    _active = false
    _emit_bond_changed()
    if creature != null and creature.has_method("set_bond"):
        creature.set_bond(0)
    GameState.record_event("bond_reset", {})

func _unhandled_input(event: InputEvent) -> void:
    if not _active:
        return
    if event.is_action_pressed("bond_prompt"):
        register_hit()
        _prompt_timer.stop()
        _prompt_index += 1
        _advance()
# Feel added: a timed prompt-matching minigame that raises a bond meter gating evolution branches.
# Builds on: Creature (bond persistence), CreatureNeeds (synergy with care), EventBus (events),
# GameState (milestone recording). Bond milestones grant passive stat bonuses via get_stat_bonus().