# CreatureNamePersistence.gd
# Persists player‑assigned creature names across sessions.
# Builds on the existing GameState singleton for cross‑session storage.

extends Node

# Reference to the global GameState autoload.
var gs : GameState

func _ready() -> void:
    # Ensure the storage dictionary exists.
    if not has_meta("creature_names"):
        gs.creature_names = {}

# Assign a name to a creature identified by its unique ID.
# Updates GameState and emits a signal for UI updates.
func assign_name(id: String, name: String) -> void:
    gs.creature_names[id] = name
    emit_signal("name_changed", id, name)

# Retrieve the saved name for a creature ID, returning an empty string if none.
func get_name(id: String) -> String:
    return gs.creature_names.get(id, "")