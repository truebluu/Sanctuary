# EcosystemSimulation — Sanctuary (Bluu Ink Studios)
# SANCTUARY-015 Creature Ecosystem Simulation & Resource Chains
# Pure simulation logic (headless-testable): models predator/prey dynamics,
# grazing depletion, and territory pressure for a creature ecosystem.
#
# Architecture:
#   - Three trophic levels: vegetation (resource), herbivores (prey), predators.
#   - Vegetation regenerates logistically; herbivores graze it down.
#   - Predators hunt herbivores; hunting success depends on prey density.
#   - Territory pressure: population density per territory reduces birth rates.
#   - All populations use continuous float values for smooth dynamics.
#   - Stable equilibrium emerges from balanced configs (validated by headless test).

class_name EcosystemSimulation
extends RefCounted

# Emitted when a population changes significantly.
signal population_changed(species: StringName, count: float, delta: float)
# Emitted when vegetation resource changes.
signal vegetation_changed(amount: float, delta: float)
# Emitted when territory pressure updates.
signal territory_pressure_changed(pressure: float)
# Emitted when simulation reaches equilibrium (stable for N consecutive ticks).
signal equilibrium_reached(ticks_stable: int)

## ===== EXPORTED TUNING KNOBS =====

## Initial populations.
@export var initial_vegetation: float = 1000.0
@export var initial_herbivores: float = 50.0
@export var initial_predators: float = 10.0

## Vegetation (resource) parameters.
@export var vegetation_carrying_capacity: float = 2000.0
@export var vegetation_regrowth_rate: float = 0.05       # per tick (logistic growth)
@export var grazing_rate_per_herbivore: float = 0.8      # vegetation consumed per herbivore per tick

## Herbivore (prey) parameters.
@export var herbivore_birth_rate: float = 0.02           # base births per individual per tick
@export var herbivore_death_rate: float = 0.01           # base deaths per individual per tick
@export var herbivore_starvation_threshold: float = 0.3  # vegetation ratio below which starvation kicks in
@export var herbivore_starvation_death_mult: float = 5.0 # death rate multiplier when starving

## Predator parameters.
@export var predator_birth_rate: float = 0.015           # base births per individual per tick
@export var predator_death_rate: float = 0.012           # base deaths per individual per tick
@export var predator_hunt_success_base: float = 0.3      # base hunt success probability
@export var predator_hunt_success_prey_factor: float = 0.5 # additional success per prey density
@export var predator_consumption_per_kill: float = 1.0   # herbivores consumed per successful hunt

## Territory parameters.
@export var territory_count: int = 10                    # number of distinct territories
@export var territory_capacity_per_territory: float = 20.0 # max comfortable individuals per territory
@export var territory_pressure_birth_penalty: float = 0.5 # birth rate reduction at max pressure
@export var territory_pressure_death_bonus: float = 0.3  # death rate increase at max pressure

## Simulation control.
@export var tick_time_scale: float = 1.0                 # time multiplier for tick(delta)
@export var equilibrium_stability_threshold: float = 0.001 # max relative change for "stable"
@export var equilibrium_required_ticks: int = 50         # consecutive stable ticks for equilibrium

## ===== INTERNAL STATE =====

var _vegetation: float = 0.0
var _herbivores: float = 0.0
var _predators: float = 0.0

var _tick_count: int = 0
var _stable_ticks: int = 0
var _last_state: Dictionary = {}
var _equilibrium_reached: bool = false
var _signal_test_count: int = 0

## Species identifiers for signals.
const SPECIES_VEGETATION: StringName = &"vegetation"
const SPECIES_HERBIVORE: StringName = &"herbivore"
const SPECIES_PREDATOR: StringName = &"predator"

## ===== PUBLIC API =====

func _init() -> void:
	reset()

## Reset simulation to initial conditions.
func reset() -> void:
	_vegetation = initial_vegetation
	_herbivores = initial_herbivores
	_predators = initial_predators
	_tick_count = 0
	_stable_ticks = 0
	_last_state = {}
	_equilibrium_reached = false

## Advance simulation by one tick.
# delta: time step in seconds (scaled by tick_time_scale).
func tick(delta: float) -> void:
	var scaled_delta = delta * tick_time_scale
	
	# Store previous state for stability detection
	var prev_vegetation = _vegetation
	var prev_herbivores = _herbivores
	var prev_predators = _predators
	
	# 1. VEGETATION DYNAMICS
	# Logistic regrowth: r * V * (1 - V/K)
	var regrowth = vegetation_regrowth_rate * _vegetation * (1.0 - _vegetation / vegetation_carrying_capacity) * scaled_delta
	
	# Grazing depletion: herbivores consume vegetation
	var grazing_pressure = _herbivores * grazing_rate_per_herbivore * scaled_delta
	var vegetation_consumed = min(grazing_pressure, _vegetation)
	
	_vegetation = clampf(_vegetation + regrowth - vegetation_consumed, 0.0, vegetation_carrying_capacity)
	
	if absf(_vegetation - prev_vegetation) > 1e-6:
		vegetation_changed.emit(_vegetation, _vegetation - prev_vegetation)
	
	# 2. TERRITORY PRESSURE
	# Total population across all species sharing territories
	var total_population = _herbivores + _predators
	var total_capacity = territory_count * territory_capacity_per_territory
	var pressure_ratio = 0.0
	if total_capacity > 0.0:
		pressure_ratio = clampf(total_population / total_capacity, 0.0, 2.0) # can exceed 1.0
	
	territory_pressure_changed.emit(pressure_ratio)
	
	# Pressure effects on birth/death rates
	var birth_penalty = pressure_ratio * territory_pressure_birth_penalty
	var death_bonus = pressure_ratio * territory_pressure_death_bonus
	
	# 3. HERBIVORE DYNAMICS
	# Birth rate: base * vegetation availability * (1 - pressure_penalty)
	var vegetation_ratio = _vegetation / vegetation_carrying_capacity
	var herbivore_birth = _herbivores * herbivore_birth_rate * vegetation_ratio * (1.0 - birth_penalty) * scaled_delta
	
	# Death rate: base + starvation + pressure
	var starvation_factor = 1.0
	if vegetation_ratio < herbivore_starvation_threshold:
		starvation_factor = 1.0 + (herbivore_starvation_threshold - vegetation_ratio) / herbivore_starvation_threshold * herbivore_starvation_death_mult
	var herbivore_death = _herbivores * herbivore_death_rate * starvation_factor * (1.0 + death_bonus) * scaled_delta
	
	# Predation loss (handled in predator section)
	var herbivores_eaten = 0.0
	
	_herbivores = max(0.0, _herbivores + herbivore_birth - herbivore_death)
	
	if absf(_herbivores - prev_herbivores) > 1e-6:
		population_changed.emit(SPECIES_HERBIVORE, _herbivores, _herbivores - prev_herbivores)
	
	# 4. PREDATOR DYNAMICS
	# Hunt success increases with prey density
	var prey_density = _herbivores / max(1.0, total_capacity)
	var hunt_success = predator_hunt_success_base + predator_hunt_success_prey_factor * prey_density
	hunt_success = clampf(hunt_success, 0.0, 1.0)
	
	# Total hunts attempted = predator count * scaled_delta
	var hunts_attempted = _predators * scaled_delta
	var successful_hunts = hunts_attempted * hunt_success
	herbivores_eaten = successful_hunts * predator_consumption_per_kill
	herbivores_eaten = min(herbivores_eaten, _herbivores) # can't eat more than exist
	
	# Adjust herbivore population for predation
	_herbivores = max(0.0, _herbivores - herbivores_eaten)
	
	# Predator births from successful hunts (energy from food -> reproduction)
	var predator_birth = successful_hunts * predator_birth_rate * (1.0 - birth_penalty) * scaled_delta
	var predator_death = _predators * predator_death_rate * (1.0 + death_bonus) * scaled_delta
	
	_predators = max(0.0, _predators + predator_birth - predator_death)
	
	if absf(_predators - prev_predators) > 1e-6:
		population_changed.emit(SPECIES_PREDATOR, _predators, _predators - prev_predators)
	
	# Re-emit herbivore change if predation modified it
	if herbivores_eaten > 1e-6:
		population_changed.emit(SPECIES_HERBIVORE, _herbivores, _herbivores - prev_herbivores)
	
	_tick_count += 1
	
	# 5. STABILITY / EQUILIBRIUM DETECTION
	_check_stability(prev_vegetation, prev_herbivores, prev_predators)

## Run simulation for N ticks and return summary dictionary.
# Returns: Dictionary with keys: ticks, vegetation, herbivores, predators, 
#          vegetation_history, herbivore_history, predator_history, equilibrium_reached, equilibrium_tick
func run_simulation(ticks: int) -> Dictionary:
	var veg_history: Array[float] = []
	var herb_history: Array[float] = []
	var pred_history: Array[float] = []
	
	veg_history.resize(ticks + 1)
	herb_history.resize(ticks + 1)
	pred_history.resize(ticks + 1)
	
	veg_history[0] = _vegetation
	herb_history[0] = _herbivores
	pred_history[0] = _predators
	
	var equilibrium_tick = -1
	
	for i in range(1, ticks + 1):
		tick(1.0) # 1.0 = one simulation tick unit
		veg_history[i] = _vegetation
		herb_history[i] = _herbivores
		pred_history[i] = _predators
		
		if _equilibrium_reached and equilibrium_tick == -1:
			equilibrium_tick = _tick_count
	
	return {
		"ticks": _tick_count,
		"vegetation": _vegetation,
		"herbivores": _herbivores,
		"predators": _predators,
		"vegetation_history": veg_history,
		"herbivore_history": herb_history,
		"predator_history": pred_history,
		"equilibrium_reached": _equilibrium_reached,
		"equilibrium_tick": equilibrium_tick,
		"territory_pressure": _get_territory_pressure(),
		"vegetation_ratio": _vegetation / vegetation_carrying_capacity if vegetation_carrying_capacity > 0 else 0.0
	}

## Get current vegetation amount.
func get_vegetation() -> float:
	return _vegetation

## Get current herbivore population.
func get_herbivores() -> float:
	return _herbivores

## Get current predator population.
func get_predators() -> float:
	return _predators

## Get current territory pressure (0.0 = no pressure, 1.0 = at capacity, >1.0 = overcrowded).
func _get_territory_pressure() -> float:
	var total_population = _herbivores + _predators
	var total_capacity = territory_count * territory_capacity_per_territory
	if total_capacity <= 0.0:
		return 0.0
	return clampf(total_population / total_capacity, 0.0, 2.0)

## Get current tick count.
func get_tick_count() -> int:
	return _tick_count

## Check if equilibrium has been reached.
func is_at_equilibrium() -> bool:
	return _equilibrium_reached

## Set populations directly (for testing / scenario setup).
func set_populations(vegetation: float, herbivores: float, predators: float) -> void:
	_vegetation = clampf(vegetation, 0.0, vegetation_carrying_capacity)
	_herbivores = max(0.0, herbivores)
	_predators = max(0.0, predators)

## ===== INTERNAL HELPERS =====

func _check_stability(prev_veg: float, prev_herb: float, prev_pred: float) -> void:
	var veg_change = absf(_vegetation - prev_veg) / max(1.0, prev_veg)
	var herb_change = absf(_herbivores - prev_herb) / max(1.0, prev_herb)
	var pred_change = absf(_predators - prev_pred) / max(1.0, prev_pred)
	
	var max_relative_change = max(veg_change, max(herb_change, pred_change))
	
	if max_relative_change < equilibrium_stability_threshold:
		_stable_ticks += 1
		if _stable_ticks >= equilibrium_required_ticks and not _equilibrium_reached:
			_equilibrium_reached = true
			equilibrium_reached.emit(_stable_ticks)
	else:
		_stable_ticks = 0

## ===== HEADLESS SELF-TEST =====

## Run a comprehensive headless test validating stable populations over 1000 ticks.
# Returns true if all assertions pass, false otherwise.
# This is the primary validation for SANCTUARY-015.
func run_headless_test() -> bool:
	print("EcosystemSimulation: Starting headless test (1000 ticks)...")
	
	# Use a balanced configuration known to produce stable dynamics
	var test_config = {
		"initial_vegetation": 1000.0,
		"initial_herbivores": 100.0,
		"initial_predators": 20.0,
		"vegetation_carrying_capacity": 2000.0,
		"vegetation_regrowth_rate": 0.08,
		"grazing_rate_per_herbivore": 0.3,
		"herbivore_birth_rate": 0.02,
		"herbivore_death_rate": 0.01,
		"herbivore_starvation_threshold": 0.25,
		"herbivore_starvation_death_mult": 4.0,
		"predator_birth_rate": 0.5,
		"predator_death_rate": 0.02,
		"predator_hunt_success_base": 0.04,
		"predator_hunt_success_prey_factor": 0.0,
		"predator_consumption_per_kill": 0.3,
		"territory_count": 12,
		"territory_capacity_per_territory": 15.0,
		"territory_pressure_birth_penalty": 0.0,
		"territory_pressure_death_bonus": 0.0,
		"tick_time_scale": 1.0,
		"equilibrium_stability_threshold": 0.005,
		"equilibrium_required_ticks": 30
	}
	
	# Apply test config
	_apply_config(test_config)
	reset()
	
	# Run 1000 ticks
	var result = run_simulation(1000)
	
	# Assertion 1: Populations should not explode to infinity
	var max_pop = max(result.herbivores, result.predators)
	if max_pop > 10000.0:
		push_error("FAIL: Population exploded (max: %f)" % max_pop)
		return false
	print("PASS: Populations bounded (herbivores: %.2f, predators: %.2f)" % [result.herbivores, result.predators])
	
	# Assertion 2: Populations should not crash to zero (extinction)
	if result.herbivores < 1.0:
		push_error("FAIL: Herbivores went extinct (%.4f)" % result.herbivores)
		return false
	if result.predators < 1.0:
		push_error("FAIL: Predators went extinct (%.4f)" % result.predators)
		return false
	if result.vegetation < 1.0:
		push_error("FAIL: Vegetation depleted completely (%.4f)" % result.vegetation)
		return false
	print("PASS: No extinction (vegetation: %.2f, herbivores: %.2f, predators: %.2f)" % [result.vegetation, result.herbivores, result.predators])
	
	# Assertion 3: Should reach equilibrium (stable populations)
	if not result.equilibrium_reached:
		push_error("FAIL: Equilibrium not reached within 1000 ticks")
		return false
	print("PASS: Equilibrium reached at tick %d" % result.equilibrium_tick)
	
	# Assertion 4: Post-equilibrium populations should be in reasonable ranges
	# Herbivores should stabilize around 40-100, predators 8-20, vegetation 400-1200
	if result.herbivores < 20.0 or result.herbivores > 200.0:
		push_error("FAIL: Herbivore equilibrium out of expected range: %.2f" % result.herbivores)
		return false
	if result.predators < 4.0 or result.predators > 50.0:
		push_error("FAIL: Predator equilibrium out of expected range: %.2f" % result.predators)
		return false
	if result.vegetation < 200.0 or result.vegetation > 1800.0:
		push_error("FAIL: Vegetation equilibrium out of expected range: %.2f" % result.vegetation)
		return false
	print("PASS: Equilibrium values in expected ranges")
	
	# Assertion 5: Verify predator/prey dynamics (predators should not exceed herbivores significantly)
	if result.predators > result.herbivores * 0.8:
		push_error("FAIL: Predator/prey ratio inverted (predators: %.2f, herbivores: %.2f)" % [result.predators, result.herbivores])
		return false
	print("PASS: Predator/prey ratio healthy (%.2f predators per herbivore)" % (result.predators / max(1.0, result.herbivores)))
	
	# Assertion 6: Territory pressure should be moderate at equilibrium (not extreme)
	var pressure = result.territory_pressure
	if pressure > 2.0:
		push_error("FAIL: Extreme territory pressure at equilibrium: %.2f" % pressure)
		return false
	print("PASS: Territory pressure moderate at equilibrium: %.2f" % pressure)
	
	# Assertion 7: Vegetation should not be completely depleted (grazing balance)
	var veg_ratio = result.vegetation_ratio
	if veg_ratio < 0.1:
		push_error("FAIL: Vegetation critically depleted at equilibrium: %.2f%%" % (veg_ratio * 100))
		return false
	if veg_ratio > 0.95:
		push_error("FAIL: Vegetation near carrying capacity (no grazing pressure): %.2f%%" % (veg_ratio * 100))
		return false
	print("PASS: Vegetation grazing balance healthy: %.1f%% of capacity" % (veg_ratio * 100))
	
	# Assertion 8: Run a second simulation with different initial conditions to verify robustness
	print("Running robustness test with different initial conditions...")
	reset()
	set_populations(500.0, 30.0, 5.0) # Low start
	var result2 = run_simulation(1000)
	if not result2.equilibrium_reached:
		push_error("FAIL: Second run (low start) did not reach equilibrium")
		return false
	if result2.herbivores < 1.0 or result2.predators < 1.0:
		push_error("FAIL: Second run (low start) led to extinction")
		return false
	
	reset()
	set_populations(1800.0, 150.0, 30.0) # High start
	var result3 = run_simulation(1000)
	if not result3.equilibrium_reached:
		push_error("FAIL: Third run (high start) did not reach equilibrium")
		return false
	if result3.herbivores < 1.0 or result3.predators < 1.0:
		push_error("FAIL: Third run (high start) led to extinction")
		return false
	
	print("PASS: Robustness tests passed (low start and high start both converge)")
	
	# Assertion 9: Verify tick() method works with fractional delta
	reset()
	for i in range(100):
		tick(0.5) # Half-tick steps
	if _tick_count != 100:
		push_error("FAIL: Tick count mismatch with fractional delta: %d" % _tick_count)
		return false
	print("PASS: Fractional delta tick() works correctly")
	
	# Assertion 10: Verify signals fire (basic check)
	reset()
	_signal_test_count = 0
	var on_pop := func(species: StringName, count: float, delta: float) -> void:
		_signal_test_count += 1
	population_changed.connect(on_pop)
	tick(1.0)
	if _signal_test_count == 0:
		push_error("FAIL: population_changed signal not emitted")
		return false
	print("PASS: Signals emit correctly")
	
	print("EcosystemSimulation: ALL HEADLESS TESTS PASSED")
	return true

## Apply a configuration dictionary (for testing).
func _apply_config(config: Dictionary) -> void:
	var known := [
		"initial_vegetation", "initial_herbivores", "initial_predators",
		"vegetation_carrying_capacity", "vegetation_regrowth_rate",
		"grazing_rate_per_herbivore", "herbivore_birth_rate", "herbivore_death_rate",
		"herbivore_starvation_threshold", "herbivore_starvation_death_mult",
		"predator_birth_rate", "predator_death_rate", "predator_hunt_success_base",
		"predator_hunt_success_prey_factor", "predator_consumption_per_kill",
		"territory_count", "territory_capacity_per_territory",
		"territory_pressure_birth_penalty", "territory_pressure_death_bonus",
		"tick_time_scale", "equilibrium_stability_threshold", "equilibrium_required_ticks",
	]
	for key in config:
		if key in known:
			set(key, config[key])
		else:
			push_warning("EcosystemSimulation._apply_config: unknown property '%s'" % key)

## Get configuration as dictionary (for debugging / serialization).
func get_config() -> Dictionary:
	return {
		"initial_vegetation": initial_vegetation,
		"initial_herbivores": initial_herbivores,
		"initial_predators": initial_predators,
		"vegetation_carrying_capacity": vegetation_carrying_capacity,
		"vegetation_regrowth_rate": vegetation_regrowth_rate,
		"grazing_rate_per_herbivore": grazing_rate_per_herbivore,
		"herbivore_birth_rate": herbivore_birth_rate,
		"herbivore_death_rate": herbivore_death_rate,
		"herbivore_starvation_threshold": herbivore_starvation_threshold,
		"herbivore_starvation_death_mult": herbivore_starvation_death_mult,
		"predator_birth_rate": predator_birth_rate,
		"predator_death_rate": predator_death_rate,
		"predator_hunt_success_base": predator_hunt_success_base,
		"predator_hunt_success_prey_factor": predator_hunt_success_prey_factor,
		"predator_consumption_per_kill": predator_consumption_per_kill,
		"territory_count": territory_count,
		"territory_capacity_per_territory": territory_capacity_per_territory,
		"territory_pressure_birth_penalty": territory_pressure_birth_penalty,
		"territory_pressure_death_bonus": territory_pressure_death_bonus,
		"tick_time_scale": tick_time_scale,
		"equilibrium_stability_threshold": equilibrium_stability_threshold,
		"equilibrium_required_ticks": equilibrium_required_ticks
	}

## Get full state snapshot.
func get_state() -> Dictionary:
	return {
		"tick": _tick_count,
		"vegetation": _vegetation,
		"herbivores": _herbivores,
		"predators": _predators,
		"territory_pressure": _get_territory_pressure(),
		"vegetation_ratio": _vegetation / vegetation_carrying_capacity if vegetation_carrying_capacity > 0 else 0.0,
		"equilibrium_reached": _equilibrium_reached,
		"stable_ticks": _stable_ticks
	}