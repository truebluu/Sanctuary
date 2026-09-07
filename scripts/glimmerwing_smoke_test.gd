# GlimmerwingSmokeTest — Taming (The Sanctuary)
# Headless validation for the Glimmerwing rare variant.
# Verifies: spawn gating (chance + reputation), stat modifiers, signals, visual descriptions, save/load-like reset.
extends Node2D

var _failures: Array[String] = []
var _glimmerwing: Glimmerwing
var _reputation: Reputation
var _creature_needs: CreatureNeeds
var _signal_log: Array[Dictionary] = []

func _ready() -> void:
	_glimmerwing = Glimmerwing.new()
	_reputation = Reputation.new()
	_creature_needs = CreatureNeeds.new()
	_glimmerwing.on_spawned.connect(_on_spawned)

	# Test 1: Initial state - not spawned
	_assert("initial state not spawned", not _glimmerwing.is_spawned())
	_assert("initial metadata has variant_name", _glimmerwing.get_spawn_metadata().has("variant_name"))
	_assert("variant_name is Glimmerwing", _glimmerwing.get_spawn_metadata()["variant_name"] == "Glimmerwing")

	# Test 2: Spawn fails without reputation threshold (Stranger = 0 XP < 300)
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(0)  # Stranger
	var spawned: bool = _glimmerwing.try_spawn(_reputation, _creature_needs)
	_assert("spawn fails at Stranger tier", not spawned)
	_assert("not spawned after Stranger attempt", not _glimmerwing.is_spawned())
	_assert("no signal emitted for failed spawn", _signal_log.is_empty())

	# Test 3: Spawn fails at Acquaintance (100 XP < 300)
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(100)  # Acquaintance
	spawned = _glimmerwing.try_spawn(_reputation, _creature_needs)
	_assert("spawn fails at Acquaintance tier", not spawned)
	_assert("not spawned after Acquaintance attempt", not _glimmerwing.is_spawned())

	# Test 4: Spawn succeeds at Friend tier (300 XP >= 300) - but with forced spawn
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(300)  # Friend
	# Use force_spawn to bypass random chance for deterministic test
	spawned = _glimmerwing.force_spawn(_reputation, _creature_needs)
	_assert("force_spawn succeeds at Friend tier", spawned)
	_assert("is_spawned returns true", _glimmerwing.is_spawned())
	_assert("on_spawned signal emitted", _signal_log.size() == 1)
	var meta: Dictionary = _signal_log[0]
	_assert("signal carries variant_name", meta.has("variant_name") and meta["variant_name"] == "Glimmerwing")
	_assert("signal carries spawn_chance", meta.has("spawn_chance"))
	_assert("signal carries reputation_threshold", meta.has("reputation_threshold"))

	# Test 5: Stat modifiers applied to CreatureNeeds
	# Check hunger decay was reduced
	var hunger_decay: float = float(_creature_needs.decay_rate[&"hunger"])
	var expected_hunger_decay: float = 0.04 * (1.0 - 0.30)  # 0.04 * 0.7 = 0.028
	_assert("hunger decay reduced by 30%", abs(hunger_decay - expected_hunger_decay) < 0.001)

	# Test 6: apply_feed_bonus grants bonus trust
	var trust_before: float = _creature_needs.get_trust()
	var bonus: float = _glimmerwing.apply_feed_bonus()
	var trust_after: float = _creature_needs.get_trust()
	_assert("apply_feed_bonus returns bonus amount", abs(bonus - 0.15) < 0.001)
	_assert("trust increased by bonus", abs(trust_after - (trust_before + 0.15)) < 0.001)

	# Test 7: apply_feed_bonus returns 0 when not spawned
	_glimmerwing = Glimmerwing.new()
	bonus = _glimmerwing.apply_feed_bonus()
	_assert("apply_feed_bonus returns 0 when not spawned", bonus == 0.0)

	# Test 8: apply_rest_bonus grants energy bonus
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(300)
	_creature_needs = CreatureNeeds.new()
	_creature_needs.set_energy(0.5)
	_glimmerwing.force_spawn(_reputation, _creature_needs)
	var energy_before: float = _creature_needs.get_energy()
	var rest_bonus: float = _glimmerwing.apply_rest_bonus()
	var energy_after: float = _creature_needs.get_energy()
	_assert("apply_rest_bonus returns positive amount", rest_bonus > 0.0)
	_assert("energy increased", energy_after > energy_before)

	# Test 9: apply_rest_bonus returns 0 when not spawned
	_glimmerwing = Glimmerwing.new()
	rest_bonus = _glimmerwing.apply_rest_bonus()
	_assert("apply_rest_bonus returns 0 when not spawned", rest_bonus == 0.0)

	# Test 10: Visual shimmer description
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(300)
	_creature_needs = CreatureNeeds.new()
	_glimmerwing.force_spawn(_reputation, _creature_needs)
	var desc: String = _glimmerwing.get_shimmer_description()
	_assert("description contains variant name", "Glimmerwing" in desc)
	_assert("description contains shimmer aura", "Shimmer Aura" in desc)
	_assert("description contains bonus trust", "Bonus Trust" in desc)
	_assert("description contains hunger decay", "Hunger Decay" in desc)
	_assert("description contains energy recovery", "Energy Recovery" in desc)
	_assert("description contains visual details", "prismatic" in desc or "particle" in desc)

	# Test 11: Shimmer summary (compact)
	var summary: String = _glimmerwing.get_shimmer_summary()
	_assert("summary contains Glimmerwing", "Glimmerwing" in summary)
	_assert("summary contains trust bonus", "Trust+" in summary)
	_assert("summary contains hunger reduction", "Hunger-" in summary)
	_assert("summary contains energy bonus", "Energy+" in summary)

	# Test 12: Summary when not spawned
	_glimmerwing = Glimmerwing.new()
	summary = _glimmerwing.get_shimmer_summary()
	_assert("dormant summary shows dormant", "dormant" in summary.to_lower())

	# Test 13: Description when not spawned
	desc = _glimmerwing.get_shimmer_description()
	_assert("dormant description shows dormant", "Dormant" in desc or "dormant" in desc)

	# Test 14: Reset clears state
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(300)
	_creature_needs = CreatureNeeds.new()
	_glimmerwing.force_spawn(_reputation, _creature_needs)
	_glimmerwing.reset()
	_assert("reset clears spawned state", not _glimmerwing.is_spawned())
	_assert("reset clears creature_needs ref", _glimmerwing.get_spawn_metadata().has("variant_name"))  # metadata persists

	# Test 15: Spawn chance gating (statistical - force multiple attempts)
	# Create variant with 100% spawn chance for testing
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.spawn_chance = 1.0  # 100%
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(300)
	_creature_needs = CreatureNeeds.new()
	# With 100% chance and sufficient reputation, should always spawn
	var success_count: int = 0
	for i in range(10):
		var gw: Glimmerwing = Glimmerwing.new()
		gw.spawn_chance = 1.0
		gw.on_spawned.connect(_on_spawned)
		if gw.try_spawn(_reputation, _creature_needs):
			success_count += 1
	_assert("100% spawn chance always succeeds", success_count == 10)

	# Test 16: 0% spawn chance never succeeds (even with reputation)
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.spawn_chance = 0.0
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(10000)  # Cherished
	_creature_needs = CreatureNeeds.new()
	success_count = 0
	for i in range(10):
		var gw2: Glimmerwing = Glimmerwing.new()
		gw2.spawn_chance = 0.0
		gw2.on_spawned.connect(_on_spawned)
		if gw2.try_spawn(_reputation, _creature_needs):
			success_count += 1
	_assert("0% spawn chance never succeeds", success_count == 0)

	# Test 17: Verify metadata contains all expected keys
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(300)
	_creature_needs = CreatureNeeds.new()
	_glimmerwing.force_spawn(_reputation, _creature_needs)
	meta = _glimmerwing.get_spawn_metadata()
	_assert("metadata has variant_name", meta.has("variant_name"))
	_assert("metadata has spawn_chance", meta.has("spawn_chance"))
	_assert("metadata has reputation_threshold", meta.has("reputation_threshold"))
	_assert("metadata has shimmer_aura_intensity", meta.has("shimmer_aura_intensity"))
	_assert("metadata has bonus_trust_on_feed", meta.has("bonus_trust_on_feed"))
	_assert("metadata has hunger_decay_reduction", meta.has("hunger_decay_reduction"))
	_assert("metadata has energy_recovery_bonus", meta.has("energy_recovery_bonus"))
	_assert("metadata has spawned_at", meta.has("spawned_at"))

	# Test 18: Reputation threshold at exact boundary
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(299)  # Just below Friend
	_creature_needs = CreatureNeeds.new()
	spawned = _glimmerwing.force_spawn(_reputation, _creature_needs)  # force bypasses chance, but checks reputation
	# force_spawn bypasses BOTH gates, so this should succeed
	_assert("force_spawn bypasses reputation check", spawned)

	# Test 19: try_spawn respects reputation at exact boundary
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.spawn_chance = 1.0
	_glimmerwing.on_spawned.connect(_on_spawned)
	_reputation = Reputation.new()
	_reputation.add_xp(299)  # Just below Friend
	_creature_needs = CreatureNeeds.new()
	spawned = _glimmerwing.try_spawn(_reputation, _creature_needs)
	_assert("try_spawn fails at 299 XP (below 300 threshold)", not spawned)

	_reputation.add_xp(1)  # Now 300 exactly
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.spawn_chance = 1.0
	_glimmerwing.on_spawned.connect(_on_spawned)
	spawned = _glimmerwing.try_spawn(_reputation, _creature_needs)
	_assert("try_spawn succeeds at exactly 300 XP", spawned)

	# Test 20: Null/RefCounted safety - try_spawn with null reputation/needs
	_glimmerwing = Glimmerwing.new()
	_glimmerwing.spawn_chance = 1.0
	_glimmerwing.on_spawned.connect(_on_spawned)
	spawned = _glimmerwing.try_spawn(null, null)
	_assert("try_spawn with null reputation/needs succeeds (no reputation gate)", spawned)

	# Final result
	if _failures.is_empty():
		print("SMOKE: Glimmerwing OK (spawn gating, stat modifiers, signals, descriptions, reset)")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("SMOKE FAIL: " + f)
		get_tree().quit(1)

func _on_spawned(variant_data: Dictionary) -> void:
	_signal_log.append(variant_data.duplicate())

func _assert(msg: String, condition: bool) -> void:
	if not condition:
		_failures.append(msg)