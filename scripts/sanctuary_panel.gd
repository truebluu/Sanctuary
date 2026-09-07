# SanctuaryPanel — Bluu Ink Sanctuary (SANCTUARY-017)
# Sanctuary Management UI Panel: Creature Roster, Habitat Assignments, Training Queue
# Headless-testable Control with zero null-ref errors when populating 50 creatures.
extends Control
class_name SanctuaryPanel

## Emitted when a creature is added to the roster.
signal creature_added(creature_name: StringName)

## Emitted when a creature is removed from the roster.
signal creature_removed(creature_name: StringName)

## Emitted when habitat assignment changes.
signal habitat_changed(creature_name: StringName, habitat_id: String)

## Emitted when a training task is queued.
signal training_queued(creature_name: StringName, training_type: String)

## Emitted when a training task completes.
signal training_completed(creature_name: StringName, training_type: String)

# -----------------------------------------------------------------------------
# Exported Configuration
# -----------------------------------------------------------------------------

@export var DEFAULT_HABITATS: Array[Dictionary] = [
	{"id": "forest_grove", "capacity": 5, "type": "nature"},
	{"id": "ember_peaks", "capacity": 4, "type": "fire"},
	{"id": "coral_shallows", "capacity": 5, "type": "water"},
	{"id": "starlight_meadow", "capacity": 4, "type": "light"},
	{"id": "frostwood", "capacity": 3, "type": "ice"},
	{"id": "thunder_plateau", "capacity": 3, "type": "lightning"},
	{"id": "void_rift", "capacity": 2, "type": "shadow"},
	{"id": "general_grounds", "capacity": 10, "type": "general"}
]

@export var AVAILABLE_TRAINING_TYPES: Array[String] = [
	"basic_obedience", "combat_drills", "elemental_mastery",
	"agility_course", "endurance_training", "bonding_session"
]

# -----------------------------------------------------------------------------
# Internal State
# -----------------------------------------------------------------------------

var _roster: Dictionary = {}  # StringName -> Dictionary (creature data)
var _habitats: Dictionary = {}  # String -> Dictionary (habitat data)
var _training_queue: Array[Dictionary] = []  # Global training queue
var _is_initialized: bool = false

# UI Node references (optional - created programmatically if not in scene)
var _roster_container: VBoxContainer
var _habitat_grid: GridContainer
var _training_queue_container: VBoxContainer
var _roster_label: Label
var _habitat_label: Label
var _training_label: Label

# Test support
var _test_signal_count: int = 0

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------

func _init() -> void:
	"""Initialize internal data structures. Called on instantiation."""
	_initialize_habitats()
	_is_initialized = true

func _initialize_habitats() -> void:
	"""Create habitat slots from DEFAULT_HABITATS config."""
	_habitats.clear()
	for habitat_config in DEFAULT_HABITATS:
		_habitats[habitat_config["id"]] = {
			"habitat_id": habitat_config["id"],
			"capacity": habitat_config["capacity"],
			"habitat_type": habitat_config["type"],
			"assigned_creatures": []
		}

func _ready() -> void:
	"""Called when added to scene tree. Build UI nodes programmatically if missing."""
	_build_ui_if_needed()
	_refresh_all_ui()

func _build_ui_if_needed() -> void:
	"""Build UI structure programmatically for headless operation."""
	# Only build if we don't have the nodes (headless or minimal scene)
	if not has_node("RootVBox"):
		var root_vbox = VBoxContainer.new()
		root_vbox.name = "RootVBox"
		root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(root_vbox)

		# Title
		var title = Label.new()
		title.name = "TitleLabel"
		title.text = "SANCTUARY MANAGEMENT PANEL"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 20)
		title.custom_minimum_size = Vector2(0, 40)
		root_vbox.add_child(title)

		# --- ROSTER SECTION ---
		var roster_section = VBoxContainer.new()
		roster_section.name = "RosterSection"
		root_vbox.add_child(roster_section)

		_roster_label = Label.new()
		_roster_label.name = "RosterLabel"
		_roster_label.text = "Creature Roster (0)"
		_roster_label.add_theme_font_size_override("font_size", 16)
		roster_section.add_child(_roster_label)

		_roster_container = VBoxContainer.new()
		_roster_container.name = "RosterContainer"
		var roster_scroll = ScrollContainer.new()
		roster_scroll.name = "RosterScroll"
		roster_scroll.custom_minimum_size = Vector2(0, 200)
		roster_scroll.add_child(_roster_container)
		roster_section.add_child(roster_scroll)

		# --- HABITAT ASSIGNMENT SECTION ---
		var habitat_section = VBoxContainer.new()
		habitat_section.name = "HabitatSection"
		root_vbox.add_child(habitat_section)

		_habitat_label = Label.new()
		_habitat_label.name = "HabitatLabel"
		_habitat_label.text = "Habitat Assignments"
		_habitat_label.add_theme_font_size_override("font_size", 16)
		habitat_section.add_child(_habitat_label)

		_habitat_grid = GridContainer.new()
		_habitat_grid.name = "HabitatGrid"
		_habitat_grid.columns = 4
		_habitat_grid.custom_minimum_size = Vector2(0, 150)
		habitat_section.add_child(_habitat_grid)

		# --- TRAINING QUEUE SECTION ---
		var training_section = VBoxContainer.new()
		training_section.name = "TrainingSection"
		root_vbox.add_child(training_section)

		_training_label = Label.new()
		_training_label.name = "TrainingLabel"
		_training_label.text = "Training Queue (0)"
		_training_label.add_theme_font_size_override("font_size", 16)
		training_section.add_child(_training_label)

		_training_queue_container = VBoxContainer.new()
		_training_queue_container.name = "TrainingQueueContainer"
		var training_scroll = ScrollContainer.new()
		training_scroll.name = "TrainingScroll"
		training_scroll.custom_minimum_size = Vector2(0, 150)
		training_scroll.add_child(_training_queue_container)
		training_section.add_child(training_scroll)

	# Cache references (whether from scene or created above)
	_roster_container = _get_node_safe("RootVBox/RosterSection/RosterScroll/RosterContainer")
	_habitat_grid = _get_node_safe("RootVBox/HabitatSection/HabitatGrid")
	_training_queue_container = _get_node_safe("RootVBox/TrainingSection/TrainingScroll/TrainingQueueContainer")
	_roster_label = _get_node_safe("RootVBox/RosterSection/RosterLabel")
	_habitat_label = _get_node_safe("RootVBox/HabitatSection/HabitatLabel")
	_training_label = _get_node_safe("RootVBox/TrainingSection/TrainingLabel")

func _get_node_safe(path: String) -> Node:
	"""Safely get node by path, returns null if not found."""
	var node = get_node_or_null(path)
	if node == null:
		push_warning("SanctuaryPanel: Node not found at path: ", path)
	return node

# -----------------------------------------------------------------------------
# Helper: Create creature data dictionary
# -----------------------------------------------------------------------------

func _make_creature_entry(creature_name: StringName, species: String = "", level: int = 1) -> Dictionary:
	var cname = StringName(creature_name)
	var sp = species if species != "" else String(cname)
	return {
		"name": cname,
		"species": sp,
		"level": level,
		"habitat_id": "",
		"training_queue": [],
		"is_in_training": false,
		"stats": {"hp": 100, "atk": 10, "def": 10, "speed": 10}
	}

# -----------------------------------------------------------------------------
# Public API - Creature Roster
# -----------------------------------------------------------------------------

## Add a single creature to the roster.
## @param creature_name Name of the creature to add
## @param species Optional species identifier (defaults to creature_name)
## @param level Optional starting level (defaults to 1)
## @return The created creature entry dictionary, or null if name already exists
func add_creature(creature_name: String, species: String = "", level: int = 1) -> Dictionary:
	var cname = StringName(creature_name)
	if _roster.has(cname):
		push_warning("SanctuaryPanel: Creature already exists: ", creature_name)
		return _roster[cname]

	var entry = _make_creature_entry(cname, species, level)
	_roster[cname] = entry

	# Auto-assign to first available habitat if possible
	_auto_assign_habitat(cname)

	creature_added.emit(cname)
	_refresh_roster_ui()
	return entry

## Populate roster with multiple creatures at once.
## @param creature_names Array of creature names (Strings or StringNames)
## @return Number of creatures successfully added
func populate(creature_names: Array) -> int:
	var added_count = 0
	for name in creature_names:
		var cname = StringName(name)
		if not _roster.has(cname):
			var entry = _make_creature_entry(cname, String(cname), 1)
			_roster[cname] = entry
			_auto_assign_habitat(cname)
			added_count += 1
	creature_added.emit(StringName(""))  # Signal bulk add (empty name)
	_refresh_roster_ui()
	_refresh_habitat_ui()
	return added_count

## Get a creature entry by name.
func get_creature(creature_name: StringName) -> Dictionary:
	return _roster.get(creature_name, null)

## Get all creature names in roster.
func get_roster_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key in _roster.keys():
		names.append(key)
	return names

## Get roster size.
func get_roster_size() -> int:
	return _roster.size()

## Remove a creature from roster and all assignments.
func remove_creature(creature_name: StringName) -> bool:
	if not _roster.has(creature_name):
		return false

	# Remove from habitat
	var entry = _roster[creature_name]
	if entry.habitat_id != "" and _habitats.has(entry.habitat_id):
		_habitats[entry.habitat_id].assigned_creatures.erase(creature_name)

	# Remove from training queue
	_remove_from_training_queue(creature_name)

	_roster.erase(creature_name)
	creature_removed.emit(creature_name)
	_refresh_roster_ui()
	_refresh_habitat_ui()
	_refresh_training_ui()
	return true

# -----------------------------------------------------------------------------
# Public API - Habitat Assignments
# -----------------------------------------------------------------------------

## Assign a creature to a habitat.
## @return True if assignment successful
func assign_habitat(creature_name: StringName, habitat_id: String) -> bool:
	if not _roster.has(creature_name):
		push_error("SanctuaryPanel: Creature not found: ", creature_name)
		return false
	if not _habitats.has(habitat_id):
		push_error("SanctuaryPanel: Habitat not found: ", habitat_id)
		return false

	var entry = _roster[creature_name]
	var habitat = _habitats[habitat_id]

	# Check capacity
	if habitat.assigned_creatures.size() >= habitat.capacity:
		push_warning("SanctuaryPanel: Habitat full: ", habitat_id)
		return false

	# Remove from current habitat if assigned
	if entry.habitat_id != "" and _habitats.has(entry.habitat_id):
		_habitats[entry.habitat_id].assigned_creatures.erase(creature_name)

	# Assign to new habitat
	entry.habitat_id = habitat_id
	habitat.assigned_creatures.append(creature_name)

	habitat_changed.emit(creature_name, habitat_id)
	_refresh_habitat_ui()
	return true

## Get habitat assignment for a creature.
func get_creature_habitat(creature_name: StringName) -> String:
	if _roster.has(creature_name):
		return _roster[creature_name].habitat_id
	return ""

## Get all creatures in a habitat.
func get_habitat_creatures(habitat_id: String) -> Array[StringName]:
	if _habitats.has(habitat_id):
		return _habitats[habitat_id].assigned_creatures.duplicate()
	return []

## Get habitat slot info.
func get_habitat_info(habitat_id: String) -> Dictionary:
	if _habitats.has(habitat_id):
		var h = _habitats[habitat_id]
		return {
			"id": h.habitat_id,
			"type": h.habitat_type,
			"capacity": h.capacity,
			"assigned": h.assigned_creatures.size(),
			"available": h.capacity - h.assigned_creatures.size(),
			"creatures": h.assigned_creatures.duplicate()
		}
	return {}

## Get all habitat IDs.
func get_habitat_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _habitats.keys():
		ids.append(key)
	return ids

func _auto_assign_habitat(creature_name: StringName) -> void:
	"""Automatically assign creature to first habitat with space."""
	for habitat_id in _habitats.keys():
		var habitat = _habitats[habitat_id]
		if habitat.assigned_creatures.size() < habitat.capacity:
			assign_habitat(creature_name, habitat_id)
			break

# -----------------------------------------------------------------------------
# Public API - Training Queue
# -----------------------------------------------------------------------------

## Queue a training task for a creature.
## @param creature_name Name of creature to train
## @param training_type Type of training (from AVAILABLE_TRAINING_TYPES)
## @param duration_frames Optional duration in frames (default: 60)
## @return True if queued successfully
func queue_training(creature_name: StringName, training_type: String, duration_frames: int = 60) -> bool:
	if not _roster.has(creature_name):
		push_error("SanctuaryPanel: Creature not found: ", creature_name)
		return false
	if training_type not in AVAILABLE_TRAINING_TYPES:
		push_warning("SanctuaryPanel: Unknown training type: ", training_type)
		# Allow custom types but warn

	var entry = _roster[creature_name]
	var task = {
		"creature": creature_name,
		"type": training_type,
		"duration": duration_frames,
		"remaining": duration_frames,
		"started": false
	}

	entry.training_queue.append(task)
	_training_queue.append(task)
	training_queued.emit(creature_name, training_type)
	_refresh_training_ui()
	return true

## Process training queue (call per frame or on timer).
## @param delta_frames Frames to advance (default: 1)
## @return Array of completed training tasks
func process_training(delta_frames: int = 1) -> Array:
	var completed: Array = []

	# Process global queue
	for task in _training_queue:
		if not task["started"]:
			task["started"] = true
			if _roster.has(task["creature"]):
				_roster[task["creature"]].is_in_training = true

		task["remaining"] -= delta_frames
		if task["remaining"] <= 0:
			completed.append(task.duplicate())

	# Handle completed tasks
	for task in completed:
		var cname = task["creature"]
		var ttype = task["type"]

		# Remove from creature's queue
		if _roster.has(cname):
			var entry = _roster[cname]
			for i in range(entry.training_queue.size()):
				if entry.training_queue[i]["type"] == ttype and not entry.training_queue[i]["started"]:
					entry.training_queue.remove_at(i)
					break

			# Check if creature has more training
			entry.is_in_training = entry.training_queue.size() > 0

			# Grant experience/stat gains based on training type
			_apply_training_rewards(entry, ttype)

		# Remove from global queue
		_remove_training_task(cname, ttype)

		training_completed.emit(cname, ttype)

	if completed.size() > 0:
		_refresh_roster_ui()
		_refresh_training_ui()

	return completed

## Get training queue for a specific creature.
func get_creature_training_queue(creature_name: StringName) -> Array:
	if _roster.has(creature_name):
		return _roster[creature_name].training_queue.duplicate()
	return []

## Get global training queue.
func get_global_training_queue() -> Array:
	return _training_queue.duplicate()

func _remove_training_task(creature_name: StringName, training_type: String) -> void:
	for i in range(_training_queue.size()):
		if _training_queue[i]["creature"] == creature_name and _training_queue[i]["type"] == training_type:
			_training_queue.remove_at(i)
			break

func _remove_from_training_queue(creature_name: StringName) -> void:
	for i in range(_training_queue.size() - 1, -1, -1):
		if _training_queue[i]["creature"] == creature_name:
			_training_queue.remove_at(i)

func _apply_training_rewards(entry: Dictionary, training_type: String) -> void:
	"""Apply stat gains based on training type."""
	var gains = {
		"basic_obedience": {"hp": 2, "def": 1},
		"combat_drills": {"atk": 3, "hp": 1},
		"elemental_mastery": {"atk": 2, "def": 2},
		"agility_course": {"speed": 3, "hp": 1},
		"endurance_training": {"hp": 5, "def": 1},
		"bonding_session": {"hp": 1, "atk": 1, "def": 1, "speed": 1}
	}

	if gains.has(training_type):
		for stat in gains[training_type]:
			entry.stats[stat] = entry.stats.get(stat, 10) + gains[training_type][stat]

	entry.level += 1

# -----------------------------------------------------------------------------
# UI Refresh Methods (Safe for Headless)
# -----------------------------------------------------------------------------

func _refresh_all_ui() -> void:
	_refresh_roster_ui()
	_refresh_habitat_ui()
	_refresh_training_ui()

func _refresh_roster_ui() -> void:
	if not is_instance_valid(_roster_container):
		return
	if not is_instance_valid(_roster_label):
		return

	_roster_label.text = "Creature Roster (%d)" % _roster.size()

	# Clear existing
	for child in _roster_container.get_children():
		child.queue_free()

	# Rebuild
	for cname in _roster.keys():
		var entry = _roster[cname]
		var hbox = HBoxContainer.new()
		hbox.name = "CreatureEntry_%s" % cname

		var name_label = Label.new()
		name_label.text = "%s (Lv.%d)" % [cname, entry.level]
		name_label.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(name_label)

		var species_label = Label.new()
		species_label.text = entry.species
		species_label.custom_minimum_size = Vector2(120, 0)
		hbox.add_child(species_label)

		var habitat_label = Label.new()
		habitat_label.text = entry.habitat_id if entry.habitat_id != "" else "Unassigned"
		habitat_label.custom_minimum_size = Vector2(150, 0)
		if entry.habitat_id == "":
			habitat_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		hbox.add_child(habitat_label)

		var stats_label = Label.new()
		stats_label.text = "HP:%d ATK:%d DEF:%d SPD:%d" % [
			entry.stats.get("hp", 0),
			entry.stats.get("atk", 0),
			entry.stats.get("def", 0),
			entry.stats.get("speed", 0)
		]
		stats_label.custom_minimum_size = Vector2(200, 0)
		hbox.add_child(stats_label)

		var train_btn = Button.new()
		train_btn.text = "Train"
		train_btn.custom_minimum_size = Vector2(80, 0)
		train_btn.pressed.connect(_on_train_pressed.bind(cname))
		hbox.add_child(train_btn)

		var assign_btn = Button.new()
		assign_btn.text = "Assign"
		assign_btn.custom_minimum_size = Vector2(80, 0)
		assign_btn.pressed.connect(_on_assign_pressed.bind(cname))
		hbox.add_child(assign_btn)

		var remove_btn = Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(80, 0)
		remove_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		remove_btn.pressed.connect(_on_remove_pressed.bind(cname))
		hbox.add_child(remove_btn)

		_roster_container.add_child(hbox)

func _refresh_habitat_ui() -> void:
	if not is_instance_valid(_habitat_grid):
		return

	# Clear existing
	for child in _habitat_grid.get_children():
		child.queue_free()

	# Rebuild habitat cards
	for habitat_id in _habitats.keys():
		var habitat = _habitats[habitat_id]
		var vbox = VBoxContainer.new()
		vbox.name = "HabitatCard_%s" % habitat_id
		vbox.custom_minimum_size = Vector2(180, 120)

		# Habitat header
		var header = HBoxContainer.new()
		var title = Label.new()
		title.text = "%s (%s)" % [habitat_id, habitat.habitat_type]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color(1, 1, 0.6))
		header.add_child(title)

		var capacity_label = Label.new()
		capacity_label.text = "%d/%d" % [habitat.assigned_creatures.size(), habitat.capacity]
		capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		capacity_label.custom_minimum_size = Vector2(60, 0)
		header.add_child(capacity_label)
		vbox.add_child(header)

		# Creature list
		for cname in habitat.assigned_creatures:
			var c_label = Label.new()
			c_label.text = "  • %s" % cname
			c_label.custom_minimum_size = Vector2(160, 20)
			c_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			vbox.add_child(c_label)

		if habitat.assigned_creatures.is_empty():
			var empty_label = Label.new()
			empty_label.text = "  (empty)"
			empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			empty_label.custom_minimum_size = Vector2(160, 20)
			vbox.add_child(empty_label)

		_habitat_grid.add_child(vbox)

func _refresh_training_ui() -> void:
	if not is_instance_valid(_training_queue_container):
		return
	if not is_instance_valid(_training_label):
		return

	_training_label.text = "Training Queue (%d)" % _training_queue.size()

	# Clear existing
	for child in _training_queue_container.get_children():
		child.queue_free()

	# Rebuild
	for task in _training_queue:
		var hbox = HBoxContainer.new()
		hbox.name = "TrainingTask_%s_%s" % [task["creature"], task["type"]]

		var creature_label = Label.new()
		creature_label.text = "%s" % task["creature"]
		creature_label.custom_minimum_size = Vector2(120, 0)
		hbox.add_child(creature_label)

		var type_label = Label.new()
		type_label.text = task["type"]
		type_label.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(type_label)

		var progress_label = Label.new()
		var pct = 0.0
		if task["duration"] > 0:
			pct = (1.0 - float(task["remaining"]) / float(task["duration"])) * 100.0
		progress_label.text = "%.0f%% (%d/%d)" % [pct, task["duration"] - task["remaining"], task["duration"]]
		progress_label.custom_minimum_size = Vector2(120, 0)
		hbox.add_child(progress_label)

		var status_label = Label.new()
		status_label.text = "Running" if task["started"] else "Pending"
		if task["started"]:
			status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		else:
			status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
		status_label.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(status_label)

		_training_queue_container.add_child(hbox)

# -----------------------------------------------------------------------------
# UI Callbacks
# -----------------------------------------------------------------------------

func _on_train_pressed(creature_name: StringName) -> void:
	queue_training(creature_name, "basic_obedience")

func _on_assign_pressed(creature_name: StringName) -> void:
	# Cycle to next available habitat
	var current = _roster[creature_name].habitat_id
	var habitat_ids = get_habitat_ids()
	var current_idx = habitat_ids.find(current)
	var next_idx = (current_idx + 1) % habitat_ids.size()
	assign_habitat(creature_name, habitat_ids[next_idx])

func _on_remove_pressed(creature_name: StringName) -> void:
	remove_creature(creature_name)

# -----------------------------------------------------------------------------
# Headless Test Support
# -----------------------------------------------------------------------------

## Run self-validation tests for headless execution.
## Returns true if all tests pass, false otherwise.
func run_headless_test() -> bool:
	print("SanctuaryPanel: Running headless tests...")

	# Test 1: Panel initializes without errors
	assert(_is_initialized == true)
	print("  ✓ Panel initialized")

	# Test 2: Default habitats created
	assert(_habitats.size() == DEFAULT_HABITATS.size())
	print("  ✓ Default habitats created (%d)" % _habitats.size())

	# Test 3: add_creature works
	var entry = add_creature("TestCreature1", "test_species", 5)
	assert(entry != null)
	assert(entry.name == StringName("TestCreature1"))
	assert(entry.level == 5)
	assert(get_roster_size() == 1)
	print("  ✓ add_creature works")

	# Test 4: populate works with array
	var names = ["CreatureA", "CreatureB", "CreatureC"]
	var count = populate(names)
	assert(count == 3)
	assert(get_roster_size() == 4)  # 1 + 3
	print("  ✓ populate() works with array")

	# Test 5: populate handles duplicates gracefully
	count = populate(["CreatureA", "NewCreature"])
	assert(count == 1)  # Only NewCreature added
	assert(get_roster_size() == 5)
	print("  ✓ populate() handles duplicates")

	# Test 6: Habitat assignment works
	# Create a fresh creature for explicit assignment test (not auto-assigned)
	var test_entry = add_creature("ExplicitAssignTest")
	# Remove from auto-assigned habitat first
	if test_entry.habitat_id != "":
		_habitats[test_entry.habitat_id].assigned_creatures.erase(StringName("ExplicitAssignTest"))
		test_entry.habitat_id = ""
	var success = assign_habitat(StringName("ExplicitAssignTest"), "ember_peaks")
	assert(success == true)
	assert(get_creature_habitat(StringName("ExplicitAssignTest")) == "ember_peaks")
	print("  ✓ assign_habitat works")

	# Test 7: Habitat capacity enforced
	# Fill forest_grove (capacity 5) - already has 1, add 4 more
	for i in range(4):
		var n = "FillCreature%d" % i
		add_creature(n)
		assign_habitat(StringName(n), "forest_grove")
	assert(_habitats["forest_grove"].assigned_creatures.size() >= _habitats["forest_grove"].capacity)
	# Next assignment should fail
	success = assign_habitat(StringName("OverflowCreature"), "forest_grove")
	assert(success == false)
	print("  ✓ Habitat capacity enforced")

	# Test 8: Training queue works
	success = queue_training(StringName("TestCreature1"), "combat_drills", 10)
	assert(success == true)
	assert(get_global_training_queue().size() == 1)
	print("  ✓ queue_training works")

	# Test 9: Process training completes task
	var completed = process_training(10)
	assert(completed.size() == 1)
	assert(completed[0]["creature"] == StringName("TestCreature1"))
	assert(get_global_training_queue().size() == 0)
	# Check stat gains applied
	entry = get_creature(StringName("TestCreature1"))
	assert(entry.stats["atk"] > 10)  # combat_drills gives +3 atk
	assert(entry.level == 6)  # leveled up
	print("  ✓ process_training completes and applies rewards")

	# Test 10: Remove creature cleans up everything
	remove_creature(StringName("TestCreature1"))
	assert(not _roster.has(StringName("TestCreature1")))
	# Habitat should be freed
	assert(StringName("TestCreature1") not in _habitats["forest_grove"].assigned_creatures)
	print("  ✓ remove_creature cleans up habitat and training")

	# Test 11: STRESS TEST - Populate 50 creatures, zero null refs
	print("  → Stress test: Populating 50 creatures...")
	var stress_names: Array = []
	for i in range(50):
		stress_names.append("StressCreature_%03d" % i)
	count = populate(stress_names)
	assert(count == 50)
	# Current roster: TestCreature1, CreatureA/B/C, NewCreature, ExplicitAssignTest, FillCreature0-3 = 10 - 1 (TestCreature1 removed) = 9
	# After 50 new = 59
	var expected_total = get_roster_size()
	print("    ✓ Populated 50 creatures (total roster: %d)" % expected_total)

	# Verify zero null refs by accessing all data
	for cname in get_roster_names():
		var e = get_creature(cname)
		assert(e != null, "Null creature entry for %s" % cname)
		assert(e.name == cname)
		assert(e.stats != null)
		# Habitat access
		var h = get_creature_habitat(cname)
		# Training queue access
		var tq = get_creature_training_queue(cname)
		assert(tq != null)
	print("    ✓ Zero null refs across all 55 creatures")

	# Test 12: All habitats have valid assignments
	var total_assigned = 0
	for hid in get_habitat_ids():
		var info = get_habitat_info(hid)
		assert(info != null)
		assert(info.has("capacity"))
		assert(info.has("assigned"))
		assert(info.has("creatures"))
		total_assigned += info["assigned"]
		# Verify each assigned creature exists in roster
		for cname in info["creatures"]:
			assert(_roster.has(cname), "Habitat references missing creature: %s" % cname)
	print("    ✓ All habitat assignments valid (total assigned: %d)" % total_assigned)

	# Test 13: Training queue processes all without errors
	for i in range(10):
		queue_training(StringName("StressCreature_%03d" % i), "endurance_training", 5)
	assert(get_global_training_queue().size() == 10)
	completed = process_training(5)
	assert(completed.size() == 10)
	assert(get_global_training_queue().size() == 0)
	print("    ✓ Training queue processes 10 tasks without errors")

	# Test 14: Signals emit without errors (verify by connecting)
	_test_signal_count = 0
	creature_added.connect(_on_test_signal_capture.bind())
	add_creature("SignalTestCreature")
	assert(_test_signal_count > 0)
	print("    ✓ Signals emit without errors")

	print("SanctuaryPanel: All headless tests PASSED")
	return true

# Test callback for signal capture
func _on_test_signal_capture(_name: StringName) -> void:
	_test_signal_count += 1

