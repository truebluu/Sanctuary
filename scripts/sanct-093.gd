extends Node2D
class_name DamageNumberPopup

# Floating damage/heal numbers that pop up at a world position and fade out.
# Builds on the game-feel pillar: every hit must FEEL impactful.
# Hooks into EventBus for spawn requests and GameState for scaling.
# NOTE: built entirely in code — no scene file, so there is no missing-resource risk.

# === TUNABLES ===
const POPUP_LIFETIME: float = 1.2          # how long a number lingers before fading
const RISE_SPEED: float = 120.0            # pixels/sec the number floats upward
const FADE_START: float = 0.8              # seconds into lifetime when fade begins
const CRITICAL_SCALE: float = 1.5          # size multiplier for crit numbers
const CRITICAL_COLOR: Color = Color(1.0, 0.9, 0.2)
const NORMAL_COLOR: Color = Color.WHITE
const HEAL_COLOR: Color = Color(0.3, 1.0, 0.5)
const FONT_SIZE: int = 22

@onready var _label: Label = $Label

func _ready() -> void:
    _label.add_theme_font_size_override("font_size", FONT_SIZE)
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    # Listen for popup requests from anywhere in the game.
    if EventBus.has_signal("damage_number_requested"):
        EventBus.damage_number_requested.connect(_on_damage_number_requested)

func _on_damage_number_requested(position: Vector2, amount: int, is_crit: bool, is_heal: bool) -> void:
    _spawn(position, amount, is_crit, is_heal)

func _spawn(position: Vector2, amount: int, is_crit: bool, is_heal: bool) -> void:
    global_position = position
    var display: int = abs(amount)
    _label.text = str(display)
    _apply_style(is_crit, is_heal)
    _animate()

func _apply_style(is_crit: bool, is_heal: bool) -> void:
    if is_heal:
        _label.add_theme_color_override("font_color", HEAL_COLOR)
    elif is_crit:
        _label.add_theme_color_override("font_color", CRITICAL_COLOR)
        _label.scale = Vector2.ONE * CRITICAL_SCALE
    else:
        _label.add_theme_color_override("font_color", NORMAL_COLOR)

func _animate() -> void:
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    # Float upward while fading out toward the end.
    tween.tween_property(self, "position", position + Vector2(0.0, -RISE_SPEED * POPUP_LIFETIME), POPUP_LIFETIME)
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 0.0, POPUP_LIFETIME)
        .set_delay(POPUP_LIFETIME - FADE_START)
    tween.set_finished(self.queue_free)

# Public entry point for one-shot spawns without going through the bus.
# Builds the node tree in code instead of loading a missing scene file.
static func spawn_at(parent: Node2D, position: Vector2, amount: int, is_crit: bool = false, is_heal: bool = false) -> DamageNumberPopup:
    var popup: DamageNumberPopup = DamageNumberPopup.new()
    var label: Label = Label.new()
    label.name = "Label"
    popup.add_child(label)
    parent.add_child(popup)
    popup._spawn(position, amount, is_crit, is_heal)
    return popup