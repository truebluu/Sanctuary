class_name CreatureStatDisplay
extends PanelContainer
## Displays a creature's hunger, happiness, and level in a UI panel.
## Attach to a Control node (e.g., PanelContainer) with child Labels named
## "HungerValue", "HappinessValue", "LevelValue" (or override via exports).
## Use set_creature() to bind a creature; the panel updates automatically
## when the creature's stats change via signals.

signal creature_changed(creature: Creature)

@export var hunger_label_path: NodePath = ^"HungerValue"
@export var happiness_label_path: NodePath = ^"HappinessValue"
@export var level_label_path: NodePath = ^"LevelValue"
@export var creature_name_label_path: NodePath = ^"CreatureName"

var _creature: Creature
var _hunger_label: Label
var _happiness_label: Label
var _level_label: Label
var _name_label: Label

func _ready() -> void:
	_hunger_label = get_node_or_null(hunger_label_path) as Label
	_happiness_label = get_node_or_null(happiness_label_path) as Label
	_level_label = get_node_or_null(level_label_path) as Label
	_name_label = get_node_or_null(creature_name_label_path) as Label
	if not _hunger_label or not _happiness_label or not _level_label:
		push_error("CreatureStatDisplay: Missing required Label nodes. Check export paths.")
		set_process(false)
		return
	# If a creature is already set (e.g., from scene), refresh.
	if _creature:
		_refresh_all()

## Binds a creature to this panel. Disconnects from previous creature.
func set_creature(creature: Creature) -> void:
	if _creature == creature:
		return
	if _creature:
		_disconnect_creature(_creature)
	_creature = creature
	if _creature:
		_connect_creature(_creature)
	_refresh_all()
	creature_changed.emit(_creature)

func get_creature() -> Creature:
	return _creature

func _connect_creature(creature: Creature) -> void:
	# Assuming Creature emits these signals; if not, adjust to actual API.
	if creature.has_signal("hunger_changed"):
		creature.hunger_changed.connect(_on_hunger_changed)
	if creature.has_signal("happiness_changed"):
		creature.happiness_changed.connect(_on_happiness_changed)
	if creature.has_signal("level_changed"):
		creature.level_changed.connect(_on_level_changed)
	# Also connect to a general "stats_changed" if available.
	if creature.has_signal("stats_changed"):
		creature.stats_changed.connect(_on_stats_changed)

func _disconnect_creature(creature: Creature) -> void:
	if creature.has_signal("hunger_changed") and creature.hunger_changed.is_connected(_on_hunger_changed):
		creature.hunger_changed.disconnect(_on_hunger_changed)
	if creature.has_signal("happiness_changed") and creature.happiness_changed.is_connected(_on_happiness_changed):
		creature.happiness_changed.disconnect(_on_happiness_changed)
	if creature.has_signal("level_changed") and creature.level_changed.is_connected(_on_level_changed):
		creature.level_changed.disconnect(_on_level_changed)
	if creature.has_signal("stats_changed") and creature.stats_changed.is_connected(_on_stats_changed):
		creature.stats_changed.disconnect(_on_stats_changed)

func _refresh_all() -> void:
	if not _creature:
		_hunger_label.text = "--"
		_happiness_label.text = "--"
		_level_label.text = "--"
		if _name_label:
			_name_label.text = "No Creature"
		return
	_hunger_label.text = str(_creature.get_hunger())
	_happiness_label.text = str(_creature.get_happiness())
	_level_label.text = str(_creature.get_level())
	if _name_label:
		_name_label.text = _creature.get_creature_name() if _creature.has_method("get_creature_name") else "Creature"

func _on_hunger_changed(value: float) -> void:
	if _hunger_label:
		_hunger_label.text = str(value)

func _on_happiness_changed(value: float) -> void:
	if _happiness_label:
		_happiness_label.text = str(value)

func _on_level_changed(value: int) -> void:
	if _level_label:
		_level_label.text = str(value)

func _on_stats_changed() -> void:
	_refresh_all()

func _exit_tree() -> void:
	if _creature:
		_disconnect_creature(_creature)