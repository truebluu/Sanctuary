class_name SanctuaryHabitatZone
extends Area2D

enum ZoneType {
    FOREST,
    WATERSIDE,
    MEADOW,
    CAVE,
    GARDEN,
    PLAYGROUND,
    RESTING,
}

# Growth rate multiplier while a creature stays in this zone.
@export var growth_multiplier: float = 1.0
# Behavior influence: which personality traits this zone encourages.
@export var behavior_influence: StringName = &""
# Interaction bonus: extra bond points per minute of socializing here.
@export var interaction_bonus: float = 1.0
# Whether creatures naturally gravitate toward this zone.
@export var is_attractive: bool = true

var zone_type: ZoneType = ZoneType.MEADOW
var zone_id: StringName = &""

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("enter_habitat_zone"):
        body.enter_habitat_zone(self)

func _on_body_exited(body: Node2D) -> void:
    if body.has_method("exit_habitat_zone"):
        body.exit_habitat_zone(self)