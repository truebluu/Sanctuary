class_name CreatureBattleSystem
extends Node
## Turn-based battle system for creatures.
## Builds on the existing creature stats, type chart, and sanctuary systems.
## Feel: strategic type advantages, turn order by speed, and a simple AI that
## exploits weaknesses. Tunables are grouped at the top for one-setting changes.

# --- Tunables (designer-friendly) ---
const BASE_DAMAGE := 10.0          # Base damage before stat scaling
const CRITICAL_CHANCE := 0.1       # Chance for a critical hit (1.5x damage)
const CRITICAL_MULTIPLIER := 1.5   # Damage multiplier on critical
const STAB_MULTIPLIER := 1.2       # Same-type attack bonus (STAB)
const TYPE_EFFECTIVENESS := {
    "fire": {"water": 0.5, "grass": 2.0, "ice": 2.0, "bug": 2.0},
    "water": {"fire": 2.0, "grass": 0.5, "ground": 2.0, "rock": 2.0},
    "grass": {"fire": 0.5, "water": 2.0, "ground": 2.0, "rock": 2.0},
    "electric": {"water": 2.0, "grass": 0.5, "ground": 0.0, "flying": 2.0},
    "ice": {"fire": 0.5, "water": 0.5, "grass": 2.0, "ground": 2.0},
    "ground": {"fire": 2.0, "electric": 2.0, "grass": 0.5, "ice": 2.0},
    "rock": {"fire": 2.0, "ice": 2.0, "bug": 2.0, "flying": 2.0},
    "bug": {"grass": 2.0, "psychic": 2.0, "fire": 0.5, "flying": 0.5},
    "psychic": {"fighting": 2.0, "poison": 2.0, "bug": 0.5, "ghost": 0.0},
    "ghost": {"psychic": 2.0, "ghost": 2.0, "normal": 0.0},
    "normal": {"rock": 0.5, "ghost": 0.0},
    "fighting": {"normal": 2.0, "ice": 2.0, "rock": 2.0, "psychic": 0.5},
    "poison": {"grass": 2.0, "bug": 2.0, "poison": 0.5, "ground": 0.5},
    "flying": {"grass": 2.0, "fighting": 2.0, "electric": 0.5, "rock": 0.5},
    "dragon": {"dragon": 2.0, "steel": 0.5},
    "steel": {"ice": 2.0, "rock": 2.0, "fire": 0.5, "water": 0.5},
    "dark": {"psychic": 2.0, "ghost": 2.0, "fighting": 0.5, "dark": 0.5},
    "fairy": {"fighting": 2.0, "dragon": 2.0, "fire": 0.5, "poison": 0.5},
}
# --- End Tunables ---

# Signals for UI and game flow
signal battle_started(creature_a, creature_b)
signal battle_ended(winner, loser)
signal turn_started(attacker, defender)
signal turn_ended(attacker, defender, move, damage, effectiveness)
signal move_selected(creature, move)
signal creature_fainted(creature)
signal battle_log(message)

# Battle state
var _creature_a: Creature
var _creature_b: Creature
var _is_active := false
var _turn_count := 0

# Move definitions (simple: name, type, power, accuracy)
const MOVE_POOL := {
    "tackle": {"type": "normal", "power": 40, "accuracy": 1.0},
    "scratch": {"type": "normal", "power": 40, "accuracy": 1.0},
    "ember": {"type": "fire", "power": 50, "accuracy": 1.0},
    "water_gun": {"type": "water", "power": 50, "accuracy": 1.0},
    "vine_whip": {"type": "grass", "power": 50, "accuracy": 1.0},
    "thunder_shock": {"type": "electric", "power": 50, "accuracy": 0.9},
    "ice_beam": {"type": "ice", "power": 60, "accuracy": 0.8},
    "earthquake": {"type": "ground", "power": 80, "accuracy": 0.9},
    "rock_throw": {"type": "rock", "power": 50, "accuracy": 0.9},
    "bug_bite": {"type": "bug", "power": 50, "accuracy": 1.0},
    "psybeam": {"type": "psychic", "power": 60, "accuracy": 0.9},
    "shadow_ball": {"type": "ghost", "power": 70, "accuracy": 0.8},
    "body_slam": {"type": "normal", "power": 60, "accuracy": 0.9},
    "brick_break": {"type": "fighting", "power": 70, "accuracy": 0.9},
    "poison_sting": {"type": "poison", "power": 40, "accuracy": 1.0},
    "wing_attack": {"type": "flying", "power": 60, "accuracy": 0.9},
    "dragon_breath": {"type": "dragon", "power": 70, "accuracy": 0.9},
    "metal_claw": {"type": "steel", "power": 60, "accuracy": 0.9},
    "bite": {"type": "dark", "power": 60, "accuracy": 0.9},
    "dazzling_gleam": {"type": "fairy", "power": 70, "accuracy": 0.9},
}

func _ready() -> void:
    # Ensure we don't process until battle starts
    set_process(false)

## Start a battle between two creatures.
## Returns true if battle started successfully.
func start_battle(creature_a: Creature, creature_b: Creature) -> bool:
    if _is_active:
        push_warning("Battle already in progress")
        return false
    if not creature_a or not creature_b:
        push_error("Both creatures must be valid")
        return false
    _creature_a = creature_a
    _creature_b = creature_b
    _is_active = true
    _turn_count = 0
    battle_started.emit(_creature_a, _creature_b)
    battle_log.emit("Battle started: %s vs %s" % [_creature_a.creature_name, _creature_b.creature_name])
    set_process(true)
    return true

## End the battle (e.g., when one faints or player flees).
func end_battle(winner: Creature, loser: Creature) -> void:
    if not _is_active:
        return
    _is_active = false
    set_process(false)
    battle_ended.emit(winner, loser)
    battle_log.emit("Battle ended. Winner: %s" % winner.creature_name)

## Process a turn with the player's chosen move and the enemy's AI move.
## Returns true if the turn was processed.
func process_turn(player_move: String, enemy_move: String) -> bool:
    if not _is_active:
        return false
    # Determine turn order by speed (higher goes first)
    var first_attacker: Creature
    var first_move: String
    var second_attacker: Creature
    var second_move: String
    if _creature_a.speed >= _creature_b.speed:
        first_attacker = _creature_a
        first_move = player_move
        second_attacker = _creature_b
        second_move = enemy_move
    else:
        first_attacker = _creature_b
        first_move = enemy_move
        second_attacker = _creature_a
        second_move = player_move

    _turn_count += 1
    turn_started.emit(first_attacker, second_attacker)

    # First attack
    if not _execute_move(first_attacker, second_attacker, first_move):
        return false
    # Check if second fainted
    if second_attacker.current_hp <= 0:
        _handle_faint(second_attacker)
        return true

    # Second attack (if still alive)
    if _execute_move(second_attacker, first_attacker, second_move):
        if first_attacker.current_hp <= 0:
            _handle_faint(first_attacker)
            return true

    turn_ended.emit(first_attacker, second_attacker, first_move, 0, 1.0)  # Placeholder, actual damage emitted in _execute_move
    return true

## AI chooses a move for the given creature.
## Simple heuristic: pick a move that is super effective against the opponent, else highest power.
func choose_enemy_move(attacker: Creature, defender: Creature) -> String:
    var best_move: String = ""
    var best_score := -INF
    for move_name in attacker.moves:
        if not MOVE_POOL.has(move_name):
            continue
        var move = MOVE_POOL[move_name]
        var effectiveness = _get_effectiveness(move["type"], defender.type)
        var score = move["power"] * effectiveness
        # Prefer moves with higher accuracy
        score *= move["accuracy"]
        if score > best_score:
            best_score = score
            best_move = move_name
    if best_move == "":
        # Fallback to first move
        best_move = attacker.moves[0] if attacker.moves.size() > 0 else "tackle"
    return best_move

## Calculate damage for a move.
func calculate_damage(attacker: Creature, defender: Creature, move_name: String) -> Dictionary:
    if not MOVE_POOL.has(move_name):
        push_error("Unknown move: %s" % move_name)
        return {"damage": 0, "effectiveness": 1.0, "critical": false}
    var move = MOVE_POOL[move_name]
    var attack_stat = attacker.attack
    var defense_stat = defender.defense
    var power = move["power"]
    var effectiveness = _get_effectiveness(move["type"], defender.type)
    var stab = 1.0
    if move["type"] == attacker.type:
        stab = STAB_MULTIPLIER
    var critical = randf() < CRITICAL_CHANCE
    var crit_mult = CRITICAL_MULTIPLIER if critical else 1.0
    # Damage formula: (base + attack * power / defense) * effectiveness * stab * crit
    var damage = (BASE_DAMAGE + (attack_stat * power) / max(defense_stat, 1.0)) * effectiveness * stab * crit_mult
    damage = max(1.0, round(damage))  # Minimum 1 damage
    return {"damage": damage, "effectiveness": effectiveness, "critical": critical}

## Execute a move and apply damage.
func _execute_move(attacker: Creature, defender: Creature, move_name: String) -> bool:
    if not MOVE_POOL.has(move_name):
        push_error("Unknown move: %s" % move_name)
        return false
    var move = MOVE_POOL[move_name]
    # Accuracy check
    if randf() > move["accuracy"]:
        battle_log.emit("%s's %s missed!" % [attacker.creature_name, move_name])
        return true
    var result = calculate_damage(attacker, defender, move_name)
    var damage = result["damage"]
    defender.current_hp = max(0, defender.current_hp - damage)
    move_selected.emit(attacker, move_name)
    battle_log.emit("%s used %s! Damage: %d (eff: %.2f, crit: %s)" % [attacker.creature_name, move_name, damage, result["effectiveness"], result["critical"]])
    damage_dealt.emit(attacker, defender, damage, move_name, result["effectiveness"], result["critical"])
    return true

## Handle a creature fainting.
func _handle_faint(creature: Creature) -> void:
    creature_fainted.emit(creature)
    battle_log.emit("%s fainted!" % creature.creature_name)
    var winner = _creature_a if creature == _creature_b else _creature_b
    end_battle(winner, creature)

## Get type effectiveness multiplier (0.0, 0.5, 1.0, 2.0).
func _get_effectiveness(attack_type: String, defense_type: String) -> float:
    if TYPE_EFFECTIVENESS.has(attack_type):
        var type_map = TYPE_EFFECTIVENESS[attack_type]
        if type_map.has(defense_type):
            return type_map[defense_type]
    return 1.0

## Check if battle is active.
func is_active() -> bool:
    return _is_active

## Get current turn count.
func get_turn_count() -> int:
    return _turn_count

## Reset battle state (for reuse).
func reset() -> void:
    _is_active = false
    _creature_a = null
    _creature_b = null
    _turn_count = 0
    set_process(false)