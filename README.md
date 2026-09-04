# Sanctuary — Bluu Ink Studios (The Sanctuary)

Creature breeding & genetic inheritance demo. Pixel-perfect Godot 4.7 project.

## Architecture (clean, modular)

- **`scripts/CreatureGenome.gd`** — the core genetics engine (RefCounted, no scene
  dependency). Mendelian inheritance, mutation, phenotype computation, stat power.
  This is the REAL production GDScript from the Sanctuary bot, copied verbatim.
- **`autoload/game_state.gd`** — session state (parents, offspring, seeded RNG).
- **`autoload/event_bus.gd`** — central signal hub (Harmony backbone pattern).
- **`scenes/main.tscn`** + **`scripts/main.gd`** — the Breeding Lab UI: two parent
  creatures, a BREED button, and the offspring with phenotype + computed stats.

## Frankenstein cleanup

The Sanctuary bot's `work/` dir previously mixed **legacy Python prototypes**
(`breeding_simulation.py`, `pet_genetics.py`, `pet_personality.py`,
`evolution_triggers.py`, `water_hybrid_evolution.py`, `asset_loading_fix.py`)
with the real GDScript. Those Python files were **archived** (not deleted) to
`bots/sanctuary/work/_legacy_python/`. The Godot project uses ONLY the real
GDScript — no Python, no duplicated logic.

## Verification

- `Godot --headless --path . --import` → exit 0, no errors
- `Godot --headless --path . --script res://scripts/test_genome.gd` → **10/10 PASS**
  (genetics engine smoke test)
- `Godot --headless --path . --script res://scripts/sanctuary_demo_test.gd` → **9/9 PASS**
  (demo flow integration test)
- `Godot --headless --path . --quit-after 5` → boots clean, no script errors

## Next steps (future Sanctuary work)

- Creature visual rendering (procedural sprites from phenotype traits)
- Breeding UI polish (click-to-select parents, lineage tree)
- Evolution triggers (radiation, environment events)
- Save/load creature collection
