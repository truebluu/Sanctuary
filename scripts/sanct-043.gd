class FeedingUI extends Control:
    # --------------------------------------------------------------
    # Feeding UI constants and tunables
    # --------------------------------------------------------------
    const MAX_FOOD_ITEMS: int = 6                     # max icons displayed
    const DEFAULT_COOLDOWN: float = 1.0               # seconds between feeds
    const BASE_FEED_AMOUNT: int = 1                   # base hunger increment

    # Exported for easy designer tweaking
    @export var cooldown: float = DEFAULT_COOLDOWN    # feed cooldown in seconds
    @export var feed_amount: int = BASE_FEED_AMOUNT   # base amount to increase hunger
    @export var food_profiles: Dictionary = {}       # populated from wave profile

    # Node references (onready)
    @onready var food_grid: GridContainer = $FoodGrid
    @onready var cooldown_timer: Timer = $CooldownTimer

    # Runtime state
    var target_creature: Creature = null
    var _last_feed_time: float = 0.0

    # --------------------------------------------------------------
    # Public API
    # --------------------------------------------------------------
    # Sets the creature that this UI should feed.
    func set_target(creature: Creature) -> void:
        target_creature = creature
        _populate_food_grid()

    # --------------------------------------------------------------
    # Internal logic
    # --------------------------------------------------------------
    func _ready() -> void:
        # Ensure timer is configured
        cooldown_timer.wait_time = cooldown
        cooldown_timer.one_shot = true
        cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timeout"))
        _populate_food_grid()

    func _populate_food_grid() -> void:
        food_grid.clear()
        var profile = GameState.profile
        # Build list of food definitions from the profile dictionary
        for i in range(MAX_FOOD_ITEMS):
            var key = "food_%d" % i
            var food_def = profile.get(key, {})
            if not food_def:
                break
            var btn = Button.new()
            btn.name = "FoodButton_%d" % i
            btn.texture = load("res://art/%s" % food_def.get("icon"))
            btn.tooltip_text = food_def.get("name", "Food %d" % i)
            btn.connect("pressed", Callable(self, "_on_food_pressed").bind(i))
            food_grid.add_child(btn)

    func _on_food_pressed(food_index: int) -> void:
        if target_creature == null:
            return
        if not cooldown_timer.is_stopped():
            return
        var now = OS.get_ticks_msec() / 1000.0
        if now - _last_feed_time < cooldown:
            return
        _last_feed_time = now

        # Determine how much hunger to give based on difficulty profile
        var difficulty_factor: float = profile.get("feeding_amount_multiplier", 1.0)
        var amount_to_add: int = int(feed_amount * difficulty_factor)

        # Perform the feed on the creature
        target_creature.feed(food_index, amount_to_add)

        # Start cooldown
        cooldown_timer.start()

        # Broadcast feed event for other systems (e.g., analytics, UI feedback)
        EventBus.emit("creature_fed", target_creature, food_index, amount_to_add)

    func _on_cooldown_timeout() -> void:
        # Timer elapsed – UI is ready for next feed
        pass

# Feel: Adds interactive feeding that ties into powerup impact and creature growth,
# building on the Creature class and Inventory autoload for item handling.