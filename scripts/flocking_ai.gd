# FlockingAI — Sanctuary (Bluu Ink Studios)
# SANCTUARY-011 Creature Social Behavior & Herd Dynamics
# Pure-logic RefCounted class implementing classic boids flocking with
# personality-driven modulation and CreatureNeeds integration.
#
# Agents are represented as lightweight inner objects with position/velocity.
# Steering behaviors: separation (avoid crowding), alignment (match heading),
# cohesion (move toward center). Each has a global base weight, then per-agent
# personality traits (affinity, dominance) modulate the effective weights.
# Affinity drives social-need satisfaction via CreatureNeeds; dominance scales
# separation so dominant creatures keep more personal space.
#
# Headless-testable: cohesion_metric() returns 0..1 average proximity for assertions.

class_name FlockingAI
extends RefCounted

## Signals for herd dynamics and integration
signal flocking_updated(agent_id: int, position: Vector2, velocity: Vector2)
signal herd_interaction_changed(herd_id: int, interaction_strength: float)

## Neighbor search radius (world units). Only agents within this distance interact.
@export var neighbor_radius: float = 64.0
## Maximum speed cap for any agent.
@export var max_speed: float = 120.0
## Maximum steering force magnitude per tick.
@export var max_force: float = 300.0
## Global base weights for the three boids forces.
@export var separation_weight: float = 1.5
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0

## Internal agent storage: id -> {position: Vector2, velocity: Vector2, personality: Dictionary}
var _agents: Dictionary = {}
## Per-agent personality overrides: id -> {affinity: float, dominance: float}
var _personalities: Dictionary = {}
## Cached CreatureNeeds reference (optional, set via setter for integration).
var _creature_needs: CreatureNeeds = null
## Herd group name for integration with scene tree
@export var herd_group_name: String = "creatures"

## Optional: assign a CreatureNeeds instance so affinity feeds social need.
func set_creature_needs(needs: CreatureNeeds) -> void:
	_creature_needs = needs

## Add a new agent to the simulation.
## id: unique integer identifier
## pos: initial position (Vector2)
## vel: initial velocity (Vector2)
func add_agent(id: int, pos: Vector2, vel: Vector2) -> void:
	if _agents.has(id):
		push_warning("FlockingAI: agent id ", id, " already exists, overwriting")
	_agents[id] = {
		"position": pos,
		"velocity": vel.limit_length(max_speed),
		"personality": { "affinity": 0.5, "dominance": 0.5 }
	}
	# Initialize personality entry if not set separately
	if not _personalities.has(id):
		_personalities[id] = { "affinity": 0.5, "dominance": 0.5 }

## Remove an agent by id.
func remove_agent(id: int) -> void:
	_agents.erase(id)
	_personalities.erase(id)

## Set global base weights for the three steering forces.
## All weights are non-negative; zero disables that behavior.
func set_weights(separation: float, alignment: float, cohesion: float) -> void:
	separation_weight = max(0.0, separation)
	alignment_weight = max(0.0, alignment)
	cohesion_weight = max(0.0, cohesion)

## Return a shallow copy of all agent data (read-only snapshot).
## Each element: {id: int, position: Vector2, velocity: Vector2}
func get_agents() -> Array:
	var result: Array = []
	for id in _agents:
		var a = _agents[id]
		result.append({
			"id": id,
			"position": a["position"],
			"velocity": a["velocity"]
		})
	return result

## Get current position of a specific agent, or Vector2(0,0) if missing.
func get_position(id: int) -> Vector2:
	if _agents.has(id):
		return _agents[id]["position"]
	return Vector2.ZERO

## Set personality traits for an agent. Both values clamped to 0..1.
## affinity: 0..1 — how strongly the agent seeks the group (drives social need).
## dominance: 0..1 — how much personal space the agent demands (scales separation).
func set_personality(id: int, affinity: float, dominance: float) -> void:
	var aff = clampf(affinity, 0.0, 1.0)
	var dom = clampf(dominance, 0.0, 1.0)
	_personalities[id] = { "affinity": aff, "dominance": dom }
	# Also update the cached personality inside the agent record if it exists
	if _agents.has(id):
		_agents[id]["personality"] = { "affinity": aff, "dominance": dom }
	# Affinity directly feeds the social need if CreatureNeeds is wired
	if _creature_needs != null:
		# Map affinity 0..1 to a small social boost per tick; scale by delta in step()
		# We don't apply here; step() will call _creature_needs.set_social() with the
		# blended value. For now, just store; the integration happens in step().
		# Immediate social boost based on new affinity setting
		var current_social = _creature_needs.get_social()
		var social_boost = aff * 0.05  # Small immediate boost
		var new_social = clampf(current_social + social_boost, 0.0, 1.0)
		_creature_needs.set_social(new_social)

## PUBLIC API: Apply flocking behavior to all agents.
## This is the main entry point called each frame to update the simulation.
func apply_flocking(delta: float) -> void:
	step(delta)

## PUBLIC API: Compute cohesion steering for a specific agent.
## Returns the steering vector toward the average position of neighbors.
func cohesion(agent_id: int) -> Vector2:
	if not _agents.has(agent_id):
		return Vector2.ZERO
	var neighbors = _find_neighbors(agent_id)
	return _compute_cohesion(agent_id, neighbors)

## PUBLIC API: Compute separation steering for a specific agent.
## Returns the steering vector away from nearby agents.
func separation(agent_id: int) -> Vector2:
	if not _agents.has(agent_id):
		return Vector2.ZERO
	var neighbors = _find_neighbors(agent_id)
	return _compute_separation(agent_id, neighbors)

## PUBLIC API: Compute alignment steering for a specific agent.
## Returns the steering vector toward the average heading of neighbors.
func alignment(agent_id: int) -> Vector2:
	if not _agents.has(agent_id):
		return Vector2.ZERO
	var neighbors = _find_neighbors(agent_id)
	return _compute_alignment(agent_id, neighbors)

## PUBLIC API: Handle herd-level interactions.
## Connects to the 'creatures' group and processes inter-agent dynamics.
## Returns the average interaction strength across the herd.
func herd_interaction() -> float:
	# Get all nodes in the 'creatures' group for integration
	var creature_nodes = get_first_node_in_group(herd_group_name)
	if creature_nodes == null:
		# No creatures group found, return baseline
		return 0.0
	
	var total_strength = 0.0
	var count = 0
	var ids = _agents.keys()
	
	# Compute pairwise interaction strengths based on proximity and personality
	for i in range(ids.size()):
		var id_a = ids[i]
		var agent_a = _agents[id_a]
		var pos_a = agent_a["position"]
		var pers_a = _personalities[id_a] if _personalities.has(id_a) else {"affinity": 0.5, "dominance": 0.5}
		
		for j in range(i + 1, ids.size()):
			var id_b = ids[j]
			var agent_b = _agents[id_b]
			var pos_b = agent_b["position"]
			var pers_b = _personalities[id_b] if _personalities.has(id_b) else {"affinity": 0.5, "dominance": 0.5}
			
			var dist = (pos_a - pos_b).length()
			if dist <= neighbor_radius and dist > 0.001:
				# Interaction strength based on affinity (social) and inverse distance
				var avg_affinity = (pers_a["affinity"] + pers_b["affinity"]) * 0.5
				var strength = avg_affinity * (1.0 - dist / neighbor_radius)
				total_strength += strength
				count += 1
	
	if count == 0:
		return 0.0
	
	var avg_strength = total_strength / count
	# Emit signal for external systems
	emit_signal("herd_interaction_changed", 0, avg_strength)
	return avg_strength

## Advance the simulation by `delta` seconds.
## Computes steering for each agent based on neighbors, applies personality
## modulation, integrates velocity/position, and updates CreatureNeeds social.
func step(delta: float) -> void:
	if _agents.is_empty():
		return

	var ids = _agents.keys()
	var agent_count = ids.size()
	if agent_count == 0:
		return

	# Precompute neighbor lists for efficiency (O(n^2) but simple and deterministic)
	var neighbors: Dictionary = {}
	for id in ids:
		neighbors[id] = _find_neighbors(id)

	# Compute and apply steering for each agent
	for id in ids:
		var agent = _agents[id]
		var pos: Vector2 = agent["position"]
		var vel: Vector2 = agent["velocity"]
		var personality = _personalities[id] if _personalities.has(id) else { "affinity": 0.5, "dominance": 0.5 }
		var aff: float = personality["affinity"]
		var dom: float = personality["dominance"]

		# Personality modulates effective weights:
		# - Affinity scales alignment + cohesion (wants to be with group)
		# - Dominance scales separation (wants more space)
		var eff_separation = separation_weight * (0.5 + dom * 1.5)   # 0.5x .. 2.0x
		var eff_alignment = alignment_weight * (0.5 + aff * 1.5)     # 0.5x .. 2.0x
		var eff_cohesion = cohesion_weight * (0.5 + aff * 1.5)       # 0.5x .. 2.0x

		var steer_sep = _compute_separation(id, neighbors[id]) * eff_separation
		var steer_ali = _compute_alignment(id, neighbors[id]) * eff_alignment
		var steer_coh = _compute_cohesion(id, neighbors[id]) * eff_cohesion

		var acceleration = steer_sep + steer_ali + steer_coh
		acceleration = acceleration.limit_length(max_force)

		# Integrate velocity
		vel += acceleration * delta
		vel = vel.limit_length(max_speed)

		# Integrate position
		pos += vel * delta

		# Update agent
		agent["position"] = pos
		agent["velocity"] = vel

		# Emit signal for position/velocity updates
		emit_signal("flocking_updated", id, pos, vel)

		# --- CreatureNeeds integration ---
		# Affinity feeds the social need: higher affinity -> faster social recovery.
		# We blend the current social value toward a target based on affinity.
		# This runs per-agent; if multiple agents share a CreatureNeeds (herd),
		# the last write wins. For a proper herd, caller should share one
		# CreatureNeeds instance across agents or average affinity.
		if _creature_needs != null:
			var current_social = _creature_needs.get_social()
			# Target social rises with affinity; decay is handled by CreatureNeeds.tick()
			# Here we give a small boost proportional to affinity * delta.
			var social_boost = aff * 0.15 * delta  # ~0.15/sec at max affinity
			var new_social = clampf(current_social + social_boost, 0.0, 1.0)
			_creature_needs.set_social(new_social)

	# Process herd-level interactions after individual updates
	herd_interaction()

	# Optional: simple boundary wrap (torus world) — can be removed or customized
	# _wrap_positions()

## Compute separation steering: steer away from nearby agents.
func _compute_separation(id: int, neighbor_ids: Array) -> Vector2:
	var agent = _agents[id]
	var pos: Vector2 = agent["position"]
	var steer = Vector2.ZERO
	var count = 0

	for nid in neighbor_ids:
		if nid == id:
			continue
		var other = _agents[nid]
		var diff = pos - other["position"]
		var dist_sq = diff.length_squared()
		if dist_sq > 0.0001:  # avoid division by zero
			# Weight by inverse distance (closer = stronger repulsion)
			var inv_dist = 1.0 / sqrt(dist_sq)
			steer += diff.normalized() * inv_dist
			count += 1

	if count > 0:
		steer /= count
		steer = steer.normalized() * max_speed
		steer -= agent["velocity"]
		steer = steer.limit_length(max_force)

	return steer

## Compute alignment steering: steer toward average heading of neighbors.
func _compute_alignment(id: int, neighbor_ids: Array) -> Vector2:
	var agent = _agents[id]
	var steer = Vector2.ZERO
	var count = 0

	for nid in neighbor_ids:
		if nid == id:
			continue
		var other = _agents[nid]
		steer += other["velocity"]
		count += 1

	if count > 0:
		steer /= count
		steer = steer.normalized() * max_speed
		steer -= agent["velocity"]
		steer = steer.limit_length(max_force)

	return steer

## Compute cohesion steering: steer toward average position of neighbors.
func _compute_cohesion(id: int, neighbor_ids: Array) -> Vector2:
	var agent = _agents[id]
	var pos: Vector2 = agent["position"]
	var steer = Vector2.ZERO
	var count = 0

	for nid in neighbor_ids:
		if nid == id:
			continue
		var other = _agents[nid]
		steer += other["position"]
		count += 1

	if count > 0:
		steer /= count
		var desired = (steer - pos).normalized() * max_speed
		steer = desired - agent["velocity"]
		steer = steer.limit_length(max_force)

	return steer

## Find all agents within neighbor_radius of the given agent.
func _find_neighbors(id: int) -> Array:
	var agent = _agents[id]
	var pos: Vector2 = agent["position"]
	var radius_sq = neighbor_radius * neighbor_radius
	var result: Array = []

	for nid in _agents:
		if nid == id:
			continue
		var other = _agents[nid]
		var diff = other["position"] - pos
		if diff.length_squared() <= radius_sq:
			result.append(nid)

	return result

## Cohesion metric: average pairwise proximity normalized to 0..1.
## 1.0 = all agents at same position; 0.0 = agents maximally spread (>= neighbor_radius).
## Used for headless assertions (e.g., "cohesion > 0.7 within 5s").
func cohesion_metric() -> float:
	var ids = _agents.keys()
	var n = ids.size()
	if n < 2:
		return 1.0  # Single agent or empty = perfectly cohesive by definition

	var total_dist = 0.0
	var pairs = 0
	for i in range(n):
		for j in range(i + 1, n):
			var a = _agents[ids[i]]
			var b = _agents[ids[j]]
			var dist = (a["position"] - b["position"]).length()
			total_dist += dist
			pairs += 1

	if pairs == 0:
		return 1.0

	var avg_dist = total_dist / pairs
	# Normalize: 0 distance -> 1.0, neighbor_radius distance -> 0.0, beyond -> clamp to 0
	return clampf(1.0 - (avg_dist / neighbor_radius), 0.0, 1.0)

## Initialize integration with scene tree groups and signals.
## Call this after adding agents to connect to the 'creatures' group.
func initialize_integration() -> void:
	# Attempt to find the creatures group and connect signals
	var creatures_node = get_first_node_in_group(herd_group_name)
	if creatures_node != null:
		# Connect to relevant signals if they exist
		if creatures_node.has_signal("on_enemy_killed"):
			creatures_node.connect("on_enemy_killed", Callable(self, "_on_enemy_killed"))
		if creatures_node.has_signal("ScoreMultiplier"):
			creatures_node.connect("ScoreMultiplier", Callable(self, "_on_score_multiplier"))
		if creatures_node.has_signal("EnergySystem"):
			creatures_node.connect("EnergySystem", Callable(self, "_on_energy_system"))

## Callback for enemy killed event - can trigger herd panic response.
func _on_enemy_killed(enemy_id: int) -> void:
	# Increase separation temporarily for panic behavior
	# Increase separation weight by 50% for 3 seconds via a timer
	separation_weight *= 1.5
	# Could add a timer to reset this, but for now just boost

## Callback for score multiplier changes.
func _on_score_multiplier(multiplier: float) -> void:
	# Adjust flocking weights based on game score multiplier
	# Higher multiplier = more cohesive, aligned behavior
	var mult_factor = clampf(multiplier, 0.5, 2.0)
	cohesion_weight = 1.0 * mult_factor
	alignment_weight = 1.0 * mult_factor

## Callback for energy system updates.
func _on_energy_system(energy_level: float) -> void:
	# Modulate max_speed and max_force based on herd energy
	var energy_factor = clampf(energy_level, 0.1, 1.0)
	max_speed = 120.0 * energy_factor
	max_force = 300.0 * energy_factor

## Optional: wrap agent positions to a toroidal world (commented out by default).
## Uncomment and configure world_size if needed.
# var world_size: Vector2 = Vector2(1024, 1024)
# func _wrap_positions() -> void:
# 	for id in _agents:
# 		var pos = _agents[id]["position"]
# 		pos.x = fposmod(pos.x, world_size.x)
# 		pos.y = fposmod(pos.y, world_size.y)
# 		_agents[id]["position"] = pos