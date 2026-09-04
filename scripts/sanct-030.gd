class_name CreatureCodexEntries
extends RefCounted
## Populates the CreatureCodex with discovered creature data.
## Builds on the existing CreatureCodex class (see _reference/API_INDEX.md).
## This is a data layer: all tunable stats, lore, and evolution trees live here
## so a designer can edit one dictionary without touching logic.

const ENTRIES := {
	"glimmerwing": {
		"name": "Glimmerwing",
		"description": "A shy, bioluminescent moth-like creature. Its wings pulse with soft light when it feels safe.",
		"lore": "First discovered in the Whispering Glades, Glimmerwings are known to guide lost travelers. Their light is said to repel shadow creatures.",
		"stats": {
			"health": 20.0,
			"speed": 1.2,
			"happiness": 0.8,
			"hunger_decay": 0.1,
			"friendship_gain": 0.05,
		},
		"evolution_tree": [
			{"stage": 1, "name": "Glimmerwing", "unlock_at": 0},
			{"stage": 2, "name": "Radiant Glimmerwing", "unlock_at": 50},
			{"stage": 3, "name": "Luminous Glimmerwing", "unlock_at": 100},
		],
		"diet": ["nectar", "fruit"],
		"habitat": "glades",
		"capture_rate": 0.7,
	},
	"emberpaw": {
		"name": "Emberpaw",
		"description": "A small fox-like creature with smoldering paws. It leaves faint ember trails when excited.",
		"lore": "Emberpaws are native to the volcanic highlands. Their paws never burn the ground they walk on, a mystery researchers are still unraveling.",
		"stats": {
			"health": 30.0,
			"speed": 1.5,
			"happiness": 0.6,
			"hunger_decay": 0.15,
			"friendship_gain": 0.04,
		},
		"evolution_tree": [
			{"stage": 1, "name": "Emberpaw", "unlock_at": 0},
			{"stage": 2, "name": "Blazeclaw", "unlock_at": 60},
			{"stage": 3, "name": "Inferno Stalker", "unlock_at": 120},
		],
		"diet": ["meat", "berries"],
		"habitat": "volcanic",
		"capture_rate": 0.5,
	},
	"tidewhisker": {
		"name": "Tidewhisker",
		"description": "An aquatic creature with long, sensitive whiskers that detect water currents. It can change color to match its surroundings.",
		"lore": "Tidewhiskers are found along the coral reefs. Their whiskers are prized by alchemists for potions that grant water-breathing.",
		"stats": {
			"health": 25.0,
			"speed": 1.0,
			"happiness": 0.7,
			"hunger_decay": 0.12,
			"friendship_gain": 0.06,
		},
		"evolution_tree": [
			{"stage": 1, "name": "Tidewhisker", "unlock_at": 0},
			{"stage": 2, "name": "Deep Tidewhisker", "unlock_at": 70},
			{"stage": 3, "name": "Abyssal Tidewhisker", "unlock_at": 140},
		],
		"diet": ["fish", "algae"],
		"habitat": "reef",
		"capture_rate": 0.6,
	},
	"mossling": {
		"name": "Mossling",
		"description": "A tiny plant-like creature that grows moss on its back. It photosynthesizes and rarely moves unless disturbed.",
		"lore": "Mosslings are considered good luck in the old forest. They are said to absorb negative energy and release calm.",
		"stats": {
			"health": 15.0,
			"speed": 0.5,
			"happiness": 0.9,
			"hunger_decay": 0.05,
			"friendship_gain": 0.08,
		},
		"evolution_tree": [
			{"stage": 1, "name": "Mossling", "unlock_at": 0},
			{"stage": 2, "name": "Fernling", "unlock_at": 40},
			{"stage": 3, "name": "Elder Mossling", "unlock_at": 90},
		],
		"diet": ["sunlight", "water"],
		"habitat": "forest",
		"capture_rate": 0.8,
	},
	"cinderwing": {
		"name": "Cinderwing",
		"description": "A moth-like creature with wings that smolder and glow. It is attracted to heat sources and can withstand extreme temperatures.",
		"lore": "Cinderwings are often seen near lava flows. Their cocoons are fireproof and are used in high-grade insulation.",
		"stats": {
			"health": 22.0,
			"speed": 1.3,
			"happiness": 0.65,
			"hunger_decay": 0.13,
			"friendship_gain": 0.05,
		},
		"evolution_tree": [
			{"stage": 1, "name": "Cinderwing", "unlock_at": 0},
			{"stage": 2, "name": "Ashwing", "unlock_at": 55},
			{"stage": 3, "name": "Pyrewing", "unlock_at": 110},
		],
		"diet": ["ash", "ember"],
		"habitat": "volcanic",
		"capture_rate": 0.55,
	},
	"frostbloom": {
		"name": "Frostbloom",
		"description": "A delicate flower-like creature that thrives in cold climates. Its petals are made of ice and never melt.",
		"lore": "Frostblooms are said to bloom only during the first snowfall. They are a symbol of resilience in the northern tribes.",
		"stats": {
			"health": 18.0,
			"speed": 0.8,
			"happiness": 0.75,
			"hunger_decay": 0.08,
			"friendship_gain": 0.07,
		},
		"evolution_tree": [
			{"stage": 1, "name": "Frostbloom", "unlock_at": 0},
			{"stage": 2, "name": "Glacierbloom", "unlock_at": 45},
			{"stage": 3, "name": "Permafrostbloom", "unlock_at": 95},
		],
		"diet": ["snow", "ice crystals"],
		"habitat": "tundra",
		"capture_rate": 0.65,
	},
	"thunderquill": {
		"name": "Thunderquill",
		"description": "A bird-like creature with feathers that crackle with static electricity. It can release small lightning bolts when threatened.",
		"lore": "Thunderquills are often seen during storms. Their feathers are used to craft conductive threads for advanced technology.",
		"stats": {
			"health": 28.0,
			"speed": 1.8,
			"happiness": 0.5,
			"hunger_decay": 0.18,
			"friendship_gain": 0.03,
		},
		"evolution_tree": [
			{"stage": 1, "name": "Thunderquill", "unlock_at": 0},
			{"stage": 2, "name": "Stormquill", "unlock_at": 65},
			{"stage": 3, "name": "Tempestquill", "unlock_at": 130},
		],
		"diet": ["insects", "berries"],
		"habitat": "highlands",
		"capture_rate": 0.45,
	},
	"shadowpup": {
		"name": "Shadowpup",
		"description": "A mysterious canine-like creature that can phase through solid matter. It is playful but elusive.",
		"lore": "Shadowpups are believed to be guardians of the void. They appear only to those with pure intentions.",
		"stats": {
			"health": 24.0,
			"speed": 1.6,
			"happiness": 0.7,
			"hunger_decay": 0.14,
			"friendship_gain": 0.05,
		},
		"evolution_tree": [
			{"stage": 1, "name": "Shadowpup", "unlock_at": 0},
			{"stage": 2, "name": "Shadowhound", "unlock_at": 75},
			{"stage": 3, "name": "Voidstalker", "unlock_at": 150},
		],
		"diet": ["moonlight", "dreams"],
		"habitat": "void",
		"capture_rate": 0.4,
	},
}

## Registers all entries with the global CreatureCodex.
## Call this once at game start (e.g., from an autoload or main scene).
static func register_all() -> void:
	for creature_id in ENTRIES:
		var entry: Dictionary = ENTRIES[creature_id]
		CreatureCodex.add_entry(creature_id, entry)

## Returns a copy of the entry for a given creature id, or an empty Dictionary if not found.
static func get_entry(creature_id: String) -> Dictionary:
	return ENTRIES.get(creature_id, {}).duplicate(true)

## Returns all creature ids currently in the codex.
static func get_all_ids() -> Array[String]:
	return ENTRIES.keys()