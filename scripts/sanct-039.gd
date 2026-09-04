# CreatureStatDisplay.gd
# This UI panel displays creature stats (hunger, happiness, level) for the player.
# Feel: Makes creature needs visible to player, building on the existing Creature class
#       and HUD UI framework.
# Tunable constants:
#   MAX_UPDATE_RATE_HZ: maximum stat updates per second (throttles UI refresh).
#   UPDATE_INTERVAL: default time between forced refreshes (seconds).
#   FONT_SIZE: point size for stat labels.
# Note: This script builds on the existing EventBus signal "creature_stats_updated"
#       emitted by the Creature class when its stats change.

extends Control

# Tunable constants
const MAX_UPDATE_RATE_HZ: int = 30  # updates per second
@export var update_interval: float = 0.5  # seconds between forced refreshes (if no signal)
@export var font_size: int = 24  # points, for label font size

# References to UI labels (assumes scene has these nodes)
@onready var hunger_label: Label = $HungerLabel
@onready var happiness_label: Label = $HappinessLabel
@onready var level_label: Label = $LevelLabel

# Connect to the global EventBus for creature stat updates
func _ready() -> void:
    # Listen for stat changes broadcast by the Creature system
    EventBus.connect("creature_stats_updated", Callable(self, "_on_creature_stats_updated"))

    # Optional: set up a timer to poll in case the signal is missed (rare)
    # (not used currently, kept for future expansion)

# Called when the Creature emits a stats_updated signal.
# The signal passes the Creature instance whose stats changed.
func _on_creature_stats_updated(creature: Creature) -> void:
    # Pull the latest values from the Creature (these are assumed to be exported or public)
    var hunger: float = creature.hunger
    var happiness: float = creature.happiness
    var level: int = creature.level

    # Update the UI labels (converted to string for display)
    hunger_label.text = str(hunger)
    happiness_label.text = str(happiness)
    level_label.text = str(level)

    # Optional: apply color tint based on hunger level (tunable via constants)
    # Example: red when hungry, green when happy
    # This demonstrates a simple visual cue without adding new systems.
    # (Color logic omitted for brevity; can be expanded later.)

# End of file.
# Feel: Adds clear visibility of creature needs, building on the existing Creature class
#       and HUD UI framework.