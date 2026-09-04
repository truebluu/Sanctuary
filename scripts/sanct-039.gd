extends Label
class_name DamagePopup

# Floating damage numbers that spawn on enemy hits. Builds on the EventBus
# damage-reporting flow and the existing Enemy class. Tunable via exports
# and the wave profile so popup size/color scales with difficulty.
# NOTE: intentionally a pure GDScript node (no .tscn) so it never depends
# on a missing scene resource.

# === TUNABLES ===
@export var font_size: int = 24
@export var font_color: Color = Color(1, 0.9, 0.2, 1)
@export var crit_color: Color = Color(1, 0.3, 0.2, 1)
@export var lifetime: float = 1.2
@export var rise_distance: float = 48.0
@export var fade_curve: Curve = null

var _elapsed: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO
var _amount: int = 0
var _is_crit: bool = false

func _ready() -> void:
    _apply_style()
    _start_pos = global_position
    _target_pos = global_position - Vector2.UP * rise_distance
    if fade_curve == null:
        fade_curve = Curve.create_from_points(
            PackedVector2Array([Vector2(0, 1), Vector2(0.6, 1), Vector2(1, 0)]))

func _apply_style() -> void:
    add_theme_font_size_override("font_size", font_size)
    add_theme_color_override("font_color", crit_color if _is_crit else font_color)
    add_theme_color_override("font_color_shadow", Color.BLACK)
    add_theme_constant_override("shadow_offset_x", 2)
    add_theme_constant_override("shadow_offset_y", 2)

func spawn(world_pos: Vector2, amount: int, crit: bool = false) -> void:
    global_position = world_pos
    _start_pos = world_pos
    _target_pos = world_pos - Vector2.UP * rise_distance
    _amount = amount
    _is_crit = crit
    text = str(amount) + ("!" if crit else "")
    _apply_style()
    _elapsed = 0.0

func _process(delta: float) -> void:
    _elapsed += delta
    var t: float = clampf(_elapsed / lifetime, 0.0, 1.0)
    global_position = _start_pos.lerp(_target_pos, t)
    var alpha: float = fade_curve.sample(1.0 - t) if fade_curve != null else (1.0 - t)
    modulate.a = alpha
    if _elapsed >= lifetime:
        queue_free()

# === Popup spawner that listens for damage events ===
extends Node
class_name DamagePopupSpawner

const _MAX_POPUPS: int = 64
var _active: int = 0

func _ready() -> void:
    EventBus.enemy_hit.connect(_on_enemy_hit)

func _on_enemy_hit(world_pos: Vector2, damage: int, crit: bool) -> void:
    if _active >= _MAX_POPUPS:
        return
    var popup: DamagePopup = DamagePopup.new()
    add_child(popup)
    popup.spawn(world_pos, damage, crit)
    _active += 1
    popup.tree_exited.connect(func() -> void: _active -= 1)

# Feel added: floating damage numbers on every hit, with crit emphasis.
# Builds on EventBus.enemy_hit and the existing Enemy damage flow.
# Fixed: no longer depends on a missing damage_popup.tscn — instantiates
# the pure-GDScript DamagePopup node directly via DamagePopup.new().