extends Node2D
class_name DamageNumberPopup

# FORGE-1688 — Damage Number Popups
# Floating numbers on enemy hits, building on the existing EventBus/GameState
# backbone. Each popup is a short-lived Node2D that fades and floats upward.

# === TUNABLES ===
const POPUP_LIFETIME: float = 1.2          # seconds a number stays on screen
const POPUP_RISE: float = 60.0             # pixels/sec upward drift
const POPUP_FADE_SPEED: float = 3.0        # alpha decay per second
const POPUP_FONT_SIZE: int = 22            # base font size for the number
const CRIT_FONT_SIZE: int = 30             # font size for critical hits
const CRIT_COLOR: Color = Color(1.0, 0.85, 0.0)
const NORMAL_COLOR: Color = Color.WHITE
const HEAL_COLOR: Color = Color(0.3, 1.0, 0.4)

@onready var _label: Label = $Label

# Spawn a popup at world position. `amount` > 0 = damage, < 0 = heal.
static func spawn(parent: Node2D, world_pos: Vector2, amount: int, is_crit: bool = false) -> DamageNumberPopup:
    var popup: DamageNumberPopup = DamageNumberPopup.new()
    popup._amount = abs(amount)
    popup._is_heal = amount < 0
    popup._is_crit = is_crit
    parent.add_child(popup)
    popup.position = world_pos
    popup._setup()
    return popup

var _amount: int = 0
var _is_heal: bool = false
var _is_crit: bool = false
var _elapsed: float = 0.0

func _setup() -> void:
    _label.text = str(_amount)
    _label.add_theme_font_size_override("font_size", CRIT_FONT_SIZE if _is_crit else POPUP_FONT_SIZE)
    _label.add_theme_color_override("font_color", _color_for())
    _label.global_position = global_position
    # Slight random horizontal jitter so stacked hits don't overlap perfectly.
    var jitter: float = SharedRNG.randf_range(-12.0, 12.0)
    position.x += jitter

func _color_for() -> Color:
    if _is_crit:
        return CRIT_COLOR
    if _is_heal:
        return HEAL_COLOR
    return NORMAL_COLOR

func _process(delta: float) -> void:
    _elapsed += delta
    position.y -= POPUP_RISE * delta
    var life_ratio: float = 1.0 - (_elapsed / POPUP_LIFETIME)
    _label.modulate.a = clampf(life_ratio, 0.0, 1.0)
    if _elapsed >= POPUP_LIFETIME:
        queue_free()