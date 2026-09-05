extends Node
# FORGE-1733: Four Title Lines as Named Constants
const TITLE_ONE: String = "ENEMY_FORMATION_PATROL"
const TITLE_TWO: String = "BOSS_PHASE_TRANSITION"
const TITLE_THREE: String = "POWERUP_RARITY_WEIGHTING"
const TITLE_FOUR: String = "ENEMY_WEAK_SPOT"
func get_titles() -> PackedStringArray:
	return PackedStringArray([TITLE_ONE, TITLE_TWO, TITLE_THREE, TITLE_FOUR])