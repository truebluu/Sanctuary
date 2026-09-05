class_name SanctuaryWeatherEffects
extends Node
## Sanctuary weather effects: rain/sun modify creature behavior.
## Builds on WeatherSystem, DayNightCycle, and CreatureNeeds.
## Adds feel: weather makes sanctuary alive, creatures react to environment.

# --- Tunables (one place to adjust) ---
@export var rain_hunger_decay_multiplier: float = 1.5      # Rain increases hunger decay (creatures get hungrier)
@export var rain_happiness_decay_multiplier: float = 1.2    # Rain slightly increases happiness decay
@export var sun_happiness_gain: float = 5.0                 # Sun gives a flat happiness bonus per minute
@export var sun_energy_gain: float = 2.0                    # Sun gives a flat energy bonus per minute (if creature has energy)
@export var rain_energy_decay_multiplier: float = 1.1       # Rain slightly increases energy decay
@export var weather_check_interval: float = 1.0             # How often to apply continuous effects (seconds)

# --- Internal state ---
var _current_weather: String = "clear"  # "clear", "rain", "sun", etc.
var _timer: Timer

func _ready() -> void:
	# Connect to weather system if available
	var weather_system = get_node_or_null("/root/WeatherSystem")
	if weather_system:
		if weather_system.has_signal("weather_changed"):
			weather_system.weather_changed.connect(_on_weather_changed)
		# Initialize with current weather
		if weather_system.has_method("get_current_weather"):
			_current_weather = weather_system.get_current_weather()
	else:
		push_warning("SanctuaryWeatherEffects: WeatherSystem not found, weather effects disabled")

	# Set up timer for continuous effects
	_timer = Timer.new()
	_timer.wait_time = weather_check_interval
	_timer.timeout.connect(_apply_continuous_effects)
	add_child(_timer)
	_timer.start()

	# Connect to creature group changes
	# We'll use the group "creatures" (existing sanctuary group)
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

func _on_weather_changed(new_weather: String) -> void:
	_current_weather = new_weather
	# Apply immediate effects on weather change
	_apply_weather_change_effects()

func _apply_weather_change_effects() -> void:
	# For each creature, apply immediate effects (e.g., happiness boost on sun)
	for creature in get_tree().get_nodes_in_group("creatures"):
		if not creature.has_method("modify_happiness"):
			continue
		match _current_weather:
			"sun":
				creature.modify_happiness(sun_happiness_gain)
			"rain":
				# Rain might cause a small happiness drop
				creature.modify_happiness(-2.0)
			_:
				pass

func _apply_continuous_effects() -> void:
	# Apply per-tick effects based on weather
	for creature in get_tree().get_nodes_in_group("creatures"):
		if not creature.has_method("modify_hunger") or not creature.has_method("modify_happiness"):
			continue
		match _current_weather:
			"rain":
				# Increase hunger decay
				creature.modify_hunger(-rain_hunger_decay_multiplier * weather_check_interval)
				# Increase happiness decay
				creature.modify_happiness(-rain_happiness_decay_multiplier * weather_check_interval)
				# Increase energy decay if creature has energy
				if creature.has_method("modify_energy"):
					creature.modify_energy(-rain_energy_decay_multiplier * weather_check_interval)
			"sun":
				# Happiness gain over time
				creature.modify_happiness(sun_happiness_gain * weather_check_interval)
				# Energy gain if creature has energy
				if creature.has_method("modify_energy"):
					creature.modify_energy(sun_energy_gain * weather_check_interval)
			_:
				# Clear weather: no special effects
				pass

func _on_node_added(node: Node) -> void:
	if node.is_in_group("creatures"):
		# Apply current weather effects immediately to new creature
		_apply_weather_to_creature(node)

func _on_node_removed(node: Node) -> void:
	# Nothing to clean up, but we could disconnect if needed
	pass

func _apply_weather_to_creature(creature: Node) -> void:
	# Apply immediate effects when a creature enters the scene
	if not creature.has_method("modify_happiness"):
		return
	match _current_weather:
		"sun":
			creature.modify_happiness(sun_happiness_gain)
		"rain":
			creature.modify_happiness(-2.0)
		_:
			pass

# --- Cleanup ---
func _exit_tree() -> void:
	if _timer:
		_timer.stop()
		_timer.queue_free()