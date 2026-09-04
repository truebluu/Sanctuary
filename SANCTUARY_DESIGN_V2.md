# SANCTUARY_DESIGN_V2.md

**Bluu Ink Studios — The Sanctuary: Floating-Island Pet/Tamer Game Design**
**Status:** v2 — 2026-08-30 (turns the user's floating-island / portal / element vision into an implementation-ready Godot 4 spec)
**Engine:** Godot 4.7 / GDScript 4
**Project root:** `C:/Users/bluue/Documents/Sanctuary`

---

## 1. VISION & CORE LOOP

**The Sanctuary is a Sims-like pet/tamer game.** The player owns a **floating island** that they build and grow into the ideal environment for their pets. They nurture creatures, shape the land toward different elements, open **portals to other worlds** to explore/battle/capture/kill, and bring new creatures back to evolve and mutate in their island ecosystem. Future multiplayer lets players visit each other's islands — the contrast between **customization** (your island) and **exploration** (others' islands) is the core social hook.

### Core gameplay loop
```
BUILD the island (grow land, plant resources, shape elements)
   → NURTURE pets (feed, bond, meet needs)
   → EXPLORE portals (enter other worlds/biomes)
   → BATTLE / CAPTURE / KILL creatures
   → RETURN with new creatures + materials
   → BREED / EVOLVE / MUTATE them in your environment
   → repeat (island grows richer, pets stronger, more portals open)
```

### Design pillars (each maps to a technical system in §6)
1. **Floating Island** — the base; build/grow, not just place.
2. **Resources & Economy** — renewable food/materials, pet economy.
3. **Environment & Elements** — shape the land toward elements; drives which creatures thrive.
4. **Creatures** — capture, tame, breed, evolve, mutate, bond, needs, sickness.
5. **Portals & Exploration** — other worlds, battle/capture/kill, biomes, risk/reward.
6. **Multiplayer** — visit islands, trade, breed together, sell.

---

## 2. FLOATING ISLAND SYSTEMS

### 2.1 Procedural island generation & growth
- The island is a **grid of tiles** (e.g. 32×32 tiles, each 16px). Tiles have a **terrain type** (grass, soil, water, rock, sand, crystal) and an **element affinity** (earth/fire/water/air/nature/void).
- **Growth, not placement:** the player doesn't just place objects — they **grow** the island. Land expands by spending resources (e.g. "grow a new soil tile" costs water + earth essence). This is the "builds and grows" feel.
- **Island core:** a central "heart" tile (the island's life). Island health/energy derives from it. If it's neglected, the island stagnates.

### 2.2 Build/grow mechanics
- **Tiles** are the atomic unit. Player selects a tile → chooses a **growth action** (plant crop, place structure, terraform element, expand land).
- **Structures** (buildings) sit on tiles: breeding lab (exists), feeding trough, portal anchor, storage, market stall, evolution shrine.
- **Growth is time-based + resource-based** (like a farm sim): plant a crop → it matures over real/ingame time → harvest. Renewable.

### 2.3 Renewable resource planting
- **Food crops:** berries, grain, meat-plants (for carnivores), nectar (for flying/insect pets).
- **Material plants:** wood-trees, crystal-vines, ore-blooms (grow minerals).
- Each crop has a **grow cycle** (seed → sprout → mature → harvest → replant). Renewable = replantable.

### 2.4 Environment shaping toward ELEMENTS
- The island has an **elemental balance** (a vector: earth/fire/water/air/nature/void, each 0–100).
- Player **terraforms tiles** to shift the balance (e.g. place a lava vent → +fire; a pond → +water; a grove → +nature).
- **Element balance determines which creatures thrive:** a fire-element creature is happy/strong in a fire-heavy island; a water creature wilts there. This is the core "ideal environment for your pets" mechanic.
- **Elemental zones:** contiguous tiles of the same element form a **zone** that boosts matching creatures and enables element-specific evolution.

### 2.5 Land expansion
- Expand the island by growing new tiles at the edge (costs resources + time).
- Larger island = more zones = more diverse creatures can coexist.

---

## 3. PET / CREATURE SYSTEMS

### 3.1 Capture & taming
- **Capture** (exists: `CreatureCaptureMinigame`): weaken a wild creature, then run a capture minigame.
- **Taming:** a captured creature has a **tameness** stat (0–100). Feed it, bond with it, keep it in a matching environment → tameness rises. Untamed creatures may flee or attack.

### 3.2 Breeding (keep & extend `CreatureGenome`)
- **Keep** the existing Mendelian genetics engine (`CreatureGenome.gd`): inheritance, mutation, phenotype, stat power. This is the proven core.
- **Extend** with: **element genes** (creatures carry element alleles), **trait genes** (size, color, ability), and **mutation triggers** (see below).
- **Breeding** (exists: `BreedingCooldown`, `CreatureTrade`): two compatible creatures breed → offspring inherits a mix of genes with mutation chance.

### 3.3 Evolution & environment-driven mutation
- **Evolution** (`EvolutionTrigger` exists): a creature evolves when it meets conditions — level, bond, and **elemental exposure**.
- **Mutation (environment-driven):** this is the key new mechanic. A creature living in a **fire-heavy zone** for long enough has a chance to **mutate toward fire** (gain fire traits, change phenotype). This is how the player "grows them in the type of setting they want."
- **Mutation is directional:** the island's element balance biases which mutations occur. A nature-heavy island grows nature mutations; a void-heavy island grows void mutations.

### 3.4 Friendship / bonding
- **Bonding** (`CreatureBonding` referenced, not built): a bond level (0–100) that rises with feeding, petting, playing, and fighting alongside. High bond → better evolution, loyalty in battle, special abilities.
- **Friendship** (`FriendshipManager` referenced, not built): social relationships between creatures (rivals, friends, mates) that affect breeding compatibility and group behavior.

### 3.5 Needs & sickness
- **Needs** (`CreatureHunger` exists): hunger, thirst, energy, happiness, social. Needs decay over time; unmet needs lower tameness/bond and can cause sickness.
- **Sickness:** a creature in a **mismatched environment** (e.g. water creature in a fire zone) or with unmet needs gets sick → stat penalties, needs medicine (crafted from resources) or a better environment.

### 3.6 How elements drive evolution/mutation (summary)
| Element | Thriving creatures | Mutation bias | Zone bonus |
|---------|-------------------|----------------|------------|
| Earth | burrowers, rock-types | +defense, +size | +stamina |
| Fire | fire-types, lava | +attack, +fire traits | +aggression |
| Water | aquatics, ice | +speed, +water traits | +regen |
| Air | flyers, wind | +evasion, +air traits | +agility |
| Nature | plant, forest | +healing, +nature traits | +growth |
| Void | shadow, cosmic | +special, +void traits | +power |

---

## 4. PORTAL & EXPLORATION

### 4.1 Opening portals
- A **portal anchor** structure is built on the island. It opens a portal to a **biome** (fire world, water world, forest world, void world, etc.).
- **Unlock:** each biome is unlocked by reaching an element threshold + a key item (e.g. "fire world" needs fire balance ≥ 60 + a fire crystal).
- **Cost:** opening/entering a portal costs resources (energy, essence). Deeper biomes cost more.

### 4.2 Explore / battle / capture / kill
- **Explore:** enter the biome as a small expedition (the player + up to N pets). The biome is a procedurally-generated map with wild creatures, resources, and hazards.
- **Battle:** turn-based or real-time battles (pets fight wild creatures). Winning yields XP, materials, and capture chances.
- **Capture:** weaken a wild creature → capture minigame → bring it home.
- **Kill:** defeat a creature permanently → yields rare materials (bones, essence, meat). This is the "kill" option — a moral/strategic choice vs capture.

### 4.3 Biomes & risk/reward
- Each biome has a **danger level** and **reward tier**. Deeper biomes = stronger creatures, rarer materials, but higher risk (pets can be hurt/killed).
- **Risk/reward:** the player chooses how deep to push. Losing a beloved pet to a deep biome is a real cost.

### 4.4 Integration into home island
- **Captured creatures** return to the island and join the ecosystem. They need a **matching environment** to thrive (ties into §2.4).
- **Wild creatures** can be introduced to the island to **grow/evolve/mutate** in the player's chosen setting — the "introduce wild creatures to grow and evolve in their island" vision.

---

## 5. MULTIPLAYER VISION

### 5.1 Visiting other players' islands
- Players can **visit each other's islands** (future). The contrast: **your island = customization** (you built it), **others' islands = exploration** (you explore their choices).
- Visiting shows the other player's environment, creatures, and builds — a showcase of their design.

### 5.2 Pet economy
- **Sell pets:** trade creatures to other players (exists: `CreatureTrade`/`TradeOffer`).
- **Breed together:** two players' creatures can breed (cross-island breeding) → offspring with combined genes.
- **Sell skill books/items:** craft and sell skill books, armor, accessories, weapons, evolution items.
- **Tradeable/collectible:** pets and items are tradeable and collectible — a real economy.

### 5.3 Economy items
| Item type | Examples | Source |
|-----------|----------|--------|
| Armor | elemental armor, stat-boost gear | craft from materials |
| Accessories | collars, charms, element orbs | craft / drop |
| Weapons | pet weapons (claws, staffs) | craft / drop |
| Evolution items | evolution stones, mutation catalysts | craft / rare drop |
| Skill books | teach abilities | craft / drop |

---

## 6. SANCTUARY-SPECIFIC TECHNICAL MAP (Godot 4 / GDScript)

Build on the existing architecture: autoloads `game_state.gd` + `event_bus.gd`, and existing class_names. **Prioritize the SIM part first** (island base + resources + environment) — it's the foundation everything else sits on.

### 6.1 Autoloads (extend existing)
| Autoload | Role | Extend with |
|----------|------|-------------|
| `game_state.gd` | session state, parents/offspring, seeded RNG | island state, element balance, resources, unlocked biomes |
| `event_bus.gd` | central signal hub | new signals (below) |

### 6.2 New signals on `event_bus.gd`
```gdscript
signal island_grown(tile_pos, terrain_type)
signal element_changed(tile_pos, element, new_balance)
signal resource_harvested(resource_id, amount)
signal creature_captured(creature_id)
signal creature_tamed(creature_id, tameness)
signal creature_evolved(creature_id, new_species)
signal creature_mutated(creature_id, element, new_trait)
signal creature_bond_changed(creature_id, bond_level)
signal creature_needs_changed(creature_id, need, value)
signal creature_sick(creature_id, sickness)
signal portal_opened(biome_id)
signal portal_entered(biome_id)
signal battle_started(creature_ids)
signal battle_won(creature_ids, rewards)
signal creature_killed(creature_id, drops)
signal trade_offered(offer_id)
signal trade_completed(offer_id)
```

### 6.3 Core scripts (new class_names, RefCounted/Node, no scene dependency where possible)
| Script | Type | Purpose |
|--------|------|---------|
| `IslandGrid.gd` | RefCounted | tile grid, terrain, element affinity, growth/expansion |
| `IslandGrowth.gd` | RefCounted | grow-tile mechanics, land expansion, island heart/energy |
| `ResourceSystem.gd` | RefCounted | renewable crops, grow cycles, harvest, material plants |
| `ElementBalance.gd` | RefCounted | element vector, terraform, zones, balance→creature fit |
| `CreatureNeeds.gd` | RefCounted | needs decay, sickness, environment fit |
| `CreatureBonding.gd` | RefCounted | bond level, friendship, loyalty |
| `CreatureEvolution.gd` | RefCounted | evolution conditions, environment-driven mutation |
| `PortalSystem.gd` | RefCounted | portal anchors, biome unlock, entry cost |
| `BiomeGenerator.gd` | RefCounted | procedural biome maps, wild creatures, hazards |
| `BattleSystem.gd` | RefCounted | turn-based battle, XP, rewards, capture/kill resolution |
| `PetEconomy.gd` | RefCounted | items, armor/accessories/weapons, skill books, trade |
| `SaveLoad.gd` | RefCounted | full island+creature+economy save/load schema |

### 6.4 Scenes (new)
| Scene | Purpose |
|-------|---------|
| `scenes/island.tscn` | the floating island view (tile grid, structures, creatures) |
| `scenes/portal.tscn` | portal anchor + biome selection |
| `scenes/biome.tscn` | expedition view (explore/battle/capture) |
| `scenes/battle.tscn` | battle UI |
| `scenes/market.tscn` | pet economy / trade UI |

### 6.5 Save/load schema (JSON, via `SaveLoad.gd`)
```json
{
  "island": {
    "grid": [[{"terrain":"grass","element":"nature","structure":null}, ...]],
    "element_balance": {"earth":30,"fire":10,"water":20,"air":10,"nature":25,"void":5},
    "heart_energy": 100,
    "unlocked_biomes": ["fire_world"]
  },
  "resources": {"food":120,"wood":45,"crystal":12,"essence_fire":8},
  "creatures": [
    {"id":"c1","species":"emberling","genome":{...},"tameness":80,"bond":60,
     "needs":{"hunger":70,"thirst":80,"energy":50,"happiness":90},
     "element":"fire","evolved":false,"sick":false}
  ],
  "economy": {"items":[...],"skill_books":[...],"trades":[...]},
  "meta": {"version":2,"playtime_hours":12.5}
}
```

---

## 7. MILESTONE ROADMAP

### Phase 1 — Island Base / Resources / Environment (FOUNDATION — do first)
1. `IslandGrid.gd` — tile grid + terrain + element affinity; render in `island.tscn`.
2. `IslandGrowth.gd` — grow-tile + land expansion + island heart/energy.
3. `ResourceSystem.gd` — renewable crops, grow cycles, harvest.
4. `ElementBalance.gd` — element vector, terraform, zones.
5. `CreatureNeeds.gd` — needs decay, sickness, environment fit.
6. `CreatureBonding.gd` — bond level, friendship.
7. `SaveLoad.gd` — island + resources + creatures schema.
8. **Playtest:** build a small island, grow resources, shape elements, keep a creature happy. Verify the sim loop feels good.

### Phase 2 — Portal Worlds + Battle/Capture
9. `PortalSystem.gd` — portal anchors, biome unlock, entry cost.
10. `BiomeGenerator.gd` — procedural biome maps, wild creatures, hazards.
11. `BattleSystem.gd` — turn-based battle, XP, rewards.
12. Capture minigame integration (extend `CreatureCaptureMinigame`).
13. Kill mechanic → rare drops.
14. `CreatureEvolution.gd` — evolution + environment-driven mutation.
15. **Playtest:** enter a biome, battle/capture/kill, bring creatures home, evolve them in a chosen environment.

### Phase 3 — Multiplayer / Pet Economy
16. `PetEconomy.gd` — items, armor/accessories/weapons, skill books.
17. Trade system (extend `CreatureTrade`/`TradeOffer`).
18. Cross-island breeding.
19. Island visiting (customization vs exploration).
20. **Playtest:** full loop with economy + multiplayer.

---

## 8. OPEN QUESTIONS FOR THE USER
- Lock the **element set** (earth/fire/water/air/nature/void — or fewer/more)?
- **Battle style:** turn-based or real-time?
- **Kill vs capture:** should killing be a meaningful moral/strategic choice (affects bond/other creatures)?
- **Multiplayer scope:** local co-op first, or online from the start?
- **Island size:** how big should the starting island be, and how much expansion is satisfying?
