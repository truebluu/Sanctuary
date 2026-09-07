class_name CreatureArtGallery
extends Node2D

# Tunables — one-setting changes
const _BUFF_DURATION: float = 12.0
const _BUFF_STRENGTH: float = 1.5
const _COOLDOWN: float = 8.0

@export var sprite_path: String = "res://art/player_ship_px.png"
@export var display_duration: float = _BUFF_DURATION
@export var buff_strength: float = _BUFF_STRENGTH
@export var cooldown: float = _COOLDOWN

var _active: bool = false
var _timer: float = 0.0
var _cooldown_timer: float = 0.0

func _ready() -> void:
    var sprite: Sprite2D = Sprite2D.new()
    # Defensive: the sprite may not exist (this was a Galage ship asset). If
    # missing, fall back to a colored placeholder so the gallery still works.
    if ResourceLoader.exists(sprite_path):
        sprite.texture = load(sprite_path)
    else:
        var rect := ColorRect.new()
        rect.size = Vector2(48, 48)
        rect.color = Color(0.3, 0.6, 1.0)
        rect.position = Vector2(216, 156)
        add_child(rect)
    sprite.position = Vector2(240, 180)
    add_child(sprite)

func can_display() -> bool:
    return _cooldown_timer <= 0.0

func display_creature() -> void:
    if _active or not can_display():
        return
    _active = true
    _timer = display_duration
    _cooldown_timer = cooldown
    # Emit a buff event; other systems (player, GameState) listen for it
    EventBus.creature_selected.emit(GameState.parent_a)

func _process(delta: float) -> void:
    if _active:
        _timer -= delta
        if _timer <= 0.0:
            _active = false
            EventBus.creature_selected.emit(GameState.parent_a)
    if _cooldown_timer > 0.0:
        _cooldown_timer -= delta