# Smoke test runner for CreatureMigration (RefCounted, SANCT-927).
# Must extend SceneTree to instantiate + exercise the pure-logic class headless.
extends SceneTree

func _initialize() -> void:
	var mig = load("res://scripts/creature_migration.gd").new()
	var failures: Array[String] = []

	# Register creatures
	mig.register_creature("c1", "Glimmerwing", 1.0, 0.0, 2, 4)
	mig.register_creature("c2", "Mossback", 1.0, 0.0, 1, 3)

	# Season set/get
	mig.set_season("Summer")
	if mig.get_current_season() != "Summer":
		failures.append("set_season/get_current_season roundtrip failed")

	# Deterministic RNG seed so the trigger is reproducible
	mig.set_rng_seed(1234)

	# Trigger migration (arrival_chance 1.0 => guaranteed arrivals)
	var events: Array = mig.trigger_migration()
	if events.is_empty():
		failures.append("trigger_migration returned no events despite 1.0 arrival chance")
	var arrived: int = 0
	for e in events:
		if e["direction"] == "arriving":
			arrived += 1
	if arrived != 2:
		failures.append("expected 2 arriving events, got %d" % arrived)

	# Active migration tracking
	if mig.get_active_migration_count() != events.size():
		failures.append("active migration count mismatch")

	# Schedule query
	var summer_schedule: Array = mig.get_migration_schedule("Summer")
	if summer_schedule.size() != 2:
		failures.append("expected 2 scheduled entries for Summer, got %d" % summer_schedule.size())

	# Registered creatures
	if mig.get_registered_creatures().size() != 2:
		failures.append("registered creatures size mismatch")

	# Clear + recount
	mig.clear_active_migrations()
	if mig.get_active_migration_count() != 0:
		failures.append("clear_active_migrations failed")

	if failures.is_empty():
		print("CREATURE_MIGRATION_SMOKE_OK: all assertions passed")
		quit(0)
	else:
		for f in failures:
			print("FAIL: " + f)
		quit(1)
