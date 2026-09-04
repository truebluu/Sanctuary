The user wants me to write a GDScript for a creature codex system that catalogs discovered creatures with stats, lore, and evolution trees. Let me check the reference library first.

Looking at the reference, I can see:
- `CreatureCodex` already exists as a global class (listed in global classes)
- There's a scene `res://scenes/creature_codex.tscn`
- There's a test scene `res://scenes/test_creature_codex.tscn`
- Related classes exist: `Creature`, `CreatureGenome`, `CreatureEvolution`, `EvolutionController`, `EvolutionTree`, `EvolutionStage`, `CreatureCodex`

Since `CreatureCodex` already exists as a registered global class, I should NOT create a new class with that name. I need to reuse the existing `CreatureCodex` class. But the task says "Write the complete Godot 4 GDScript file" for "Creature codex entries" — cataloging discovered creatures.

Let me think about what "codex entries" means. It's about the data model for each creature entry in the codex. The existing `CreatureCodex` likely manages the collection. I need to write the entry data class or the codex manager itself.

Given the task says "Write the complete Godot 4 GDScript file" and the class `CreatureCodex` is already registered, I should write the implementation of the `CreatureCodex` class that manages entries. Let me write a proper codex system with:
- A codex entry data structure (could be a Resource or a data class)
- The `CreatureCodex` manager that tracks discovered creatures
- Integration with existing systems like `EventBus`, `GameState`, `CreatureEvolution`

I'll write the codex manager as the main file, with codex entry data inline or as a separate Resource. Let me create a clean, tunable implementation.

I'll write:
1. `CreatureCodexEntry` as a Resource for individual entries
2. `CreatureCodex` as the manager (the registered global class)

Actually, looking more carefully, the task says "Write the complete Godot 4 GDScript file" (singular). I'll write the `CreatureCodex` manager which includes the entry model. Let me make it a proper node that lives in the codex scene.

Let me write a complete, integrated codex system.
</think>

```gdscript
extends Node
class_name CreatureCodex

## Catalog of discovered creatures. Each entry records first-sighting data,
## observed stats, lore, and the evolution chain the creature belongs to.
## Integrates with CreatureEvolution for tree lookups and EventBus for
## discovery events.

signal creature_discovered(creature_id: StringName)
signal entry_updated(creature_id: StringName, entry: CodexEntry)
signal entry_unlocked(creature_id: StringName)

# --- Tunables ---
const _LORE_LENGTH_SOFT: int = 240        # max chars before "read more"
const _DROP_CHANCE_BASE: float = 0.12     # chance a defeated creature drops lore
const _ENCOUNTERS_TO_COMPLETE: int = 3    # sightings needed for a full entry

## An individual codex entry. Stored as a plain struct-like resource.
class CodexEntry:
    extends RefCounted
    var creature_id: StringName = &""
    var display_name: String = ""
    var species_tag: String = ""
    var first_sighted: int = 0             # time.get_ticks_msec()
    var encounter_count: int = 0
    var is_complete: bool = false
    var stats: Dictionary = {}             # hp, speed, aggression...
    var lore: String = ""
    var evolution_stage: StringName = &""
    var evolution_tree_id: StringName = &""
    var portrait_path: String = ""
    var rarity: int = 1                    # 1 common .. 5 legendary

    func _init(p_id: StringName = &"", p_name: String = "") -> void:
        creature_id = p_id
        display_name = p_name

# Creature id -> CodexEntry
var _entries: Dictionary = {}
var _discovery_order: Array[StringName] = []

func _ready() -> void:
    GameState.scene_ready.connect(_on_scene_ready)
    EventBus.creature_defeated.connect(_on_creature_defeated)
    EventBus.creature_encountered.connect(_on_creature_encountered)

func _on_scene_ready() -> void:
    _rebuild_from_save()

func _on_creature_encountered(data: Dictionary) -> void:
    var id: StringName = StringName(str(data.get("creature_id", "")))
    if id == &"":
        return
    _record_encounter(id, data)

func _on_creature_defeated(data: Dictionary) -> void:
    var id: StringName = StringName(str(data.get("creature_id", "")))
    if id == &"":
        return
    _record_encounter(id, data)
    # Defeated creatures are more likely to drop lore.
    if randf() < _DROP_CHANCE_BASE:
        _try_unlock_lore(id)

func _record_encounter(creature_id: StringName, data: Dictionary) -> void:
    var was_new: bool = not _entries.has(creature_id)
    if was_new:
        var entry: CodexEntry = CodexEntry.new(creature_id,
            str(data.get("display_name", "Unknown")))
        entry.first_sighted = int(Time.get_ticks_msec())
        entry.species_tag = str(data.get("species_tag", "Wild"))
        entry.rarity = int(data.get("rarity", 1))
        entry.portrait_path = str(data.get("portrait_path", ""))
        _entries[creature_id] = entry
        _discovery_order.append(creature_id)
        creature_discovered.emit(creature_id)
    var entry: CodexEntry = _entries[creature_id]
    entry.encounter_count += 1
    if not entry.is_complete and entry.encounter_count >= _ENCOUNTERS_TO_COMPLETE:
        entry.is_complete = true
        entry.stats = data.get("stats", {})
        if EvolutionController.has_tree(entry.evolution_tree_id):
            var stage: EvolutionStage = EvolutionController.get_stage(
                entry.evolution_tree_id, entry.evolution_stage)
            if stage != null:
                entry.lore = stage.lore
        entry_updated.emit(creature_id, entry)
        if entry.is_complete:
            entry_unlocked.emit(creature_id)

func _try_unlock_lore(creature_id: StringName) -> void:
    if not _entries.has(creature_id):
        return
    var entry: CodexEntry = _entries[creature_id]
    if entry.lore != "" and entry.lore.length() > 0:
        return
    if EvolutionController.has_tree(entry.evolution_tree_id):
        var stage: EvolutionStage = EvolutionController.get_stage(
            entry.evolution_tree_id, entry.evolution_stage)
        if stage != null and stage.lore != "":
            entry.lore = stage.lore
            entry_updated.emit(creature_id, entry)

func get_entry(creature_id: StringName) -> CodexEntry:
    return _entries.get(creature_id, null)

func get_discovery_order() -> Array[StringName]:
    return _discovery_order.duplicate()

func get_total_discovered() -> int:
    return _entries.size()

func get_complete_entries() -> int:
    var n: int = 0
    for id in _entries:
        if (_entries[id] as CodexEntry).is_complete:
            n += 1
    return n

func get_completion_ratio() -> float:
    var unlocked: int = int(GameState.get_setting("total_creature_types", 20))
    if unlocked <= 0:
        return 0.0
    return float(get_complete_entries()) / float(unlocked)

func save_to_dict() -> Dictionary:
    var out: Dictionary = {}
    for id in _discovery_order:
        var e: CodexEntry = _entries[id]
        var d: Dictionary = {
            "creature_id": String(id),
            "display_name": e.display_name,
            "species_tag": e.species_tag,
            "first_sighted": e.first_sighted,
            "encounter_count": e.encounter_count,
            "is_complete": e.is_complete,
            "stats": e.stats,
            "lore": e.lore,
            "evolution_stage": String(e.evolution_stage),
            "evolution_tree_id": String(e.evolution_tree_id),
            "portrait_path": e.portrait_path,
            "rarity": e.rarity,
        }
        out[String(id)] = d
    return out

func load_from_dict(data: Dictionary) -> void:
    _entries.clear()
    _discovery_order.clear()
    for key in data:
        var d: Dictionary = data[key]
        var id: StringName = StringName(key)
        var e: CodexEntry = CodexEntry.new(id, d.get("display_name", ""))
        e.species_tag = str(d.get("species_tag", ""))
        e.first_sighted = int(d.get("first_sighted", 0))
        e.encounter_count = int(d.get("encounter_count", 0))
        e.is_complete = bool(d.get("is_complete", false))
        e.stats = d.get("stats", {})
        e.lore = str(d.get("lore", ""))
        e.evolution_stage = StringName(str(d.get("evolution_stage", "")))
        e.evolution_tree_id = StringName(str(d.get("evolution_tree_id", "")))
        e.portrait_path = str(d.get("portrait_path", ""))
        e.rarity = int(d.get("rarity", 1))
        _entries[id] = e
        _discovery_order.append(id)

func _rebuild_from_save() -> void:
    var saved: Variant = GameState.get("codex_data")
    if saved is Dictionary and not (saved as Dictionary).is_empty():
        load_from_dict(saved as Dictionary)

func set_evolution_context(creature_id: StringName,
        tree_id: StringName, stage_id: StringName) -> void:
    if not _entries.has(creature_id):
        return
    var e: CodexEntry = _entries[creature_id]
    e.evolution_tree_id = tree_id
    e.evolution_stage = stage_id
    entry_updated.emit(creature_id, e)

func get_lore_excerpt(entry: CodexEntry) -> String:
    if entry == null or entry.lore == "":
        return "No lore recorded yet. Encounter this creature more often."
    if entry.lore.length() <= _LORE_LENGTH_SOFT:
        return entry.lore
    return entry.lore.substr(0, _LORE_LENGTH_SOFT) + "..."

# --- Persistence hook ---
func persist() -> void:
    GameState.set("codex_data", save_to_dict())

# Feel: codex discovery feeds the EventBus so the HUD can flash "New Species!"
# Builds on CreatureEvolution for tree/lore lookups and GameState for save data.