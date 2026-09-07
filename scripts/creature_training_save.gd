extends RefCounted
class_name CreatureTrainingSave

const SAVE_VERSION: int = 1

func create_skill_record(skill_name: String, level: int, xp: int) -> Dictionary:
	var record: Dictionary = {
		"skill_id": skill_name.to_lower().replace(" ", "_"),
		"skill_name": skill_name,
		"level": max(1, level),
		"xp": max(0, xp),
		"total_xp_earned": max(0, xp),
	}
	return record

func add_skill(skills: Dictionary, record: Dictionary) -> void:
	var skill_id: String = record["skill_id"]
	if not skills.has(skill_id):
		skills[skill_id] = record.duplicate(true)
	else:
		var existing: Dictionary = skills[skill_id]
		existing["level"] = max(existing["level"], record["level"])
		existing["xp"] = record["xp"]
		existing["total_xp_earned"] += record["total_xp_earned"]

func serialize_training(skills: Dictionary, owner_id: String) -> Dictionary:
	var normalized_skills: Dictionary = {}
	for skill_id in skills:
		var skill: Dictionary = skills[skill_id]
		normalized_skills[skill_id] = {
			"skill_id": skill["skill_id"],
			"skill_name": skill["skill_name"],
			"level": skill["level"],
			"xp": skill["xp"],
			"total_xp_earned": skill["total_xp_earned"],
		}
	return {
		"version": SAVE_VERSION,
		"owner_id": owner_id,
		"skills": normalized_skills,
		"saved_at": Time.get_datetime_string_from_system(),
	}

func deserialize_training(data: Dictionary) -> Dictionary:
	if not data.has("version") or data["version"] != SAVE_VERSION:
		return {}
	if not data.has("skills") or not typeof(data["skills"]) == TYPE_DICTIONARY:
		return {}
	var skills: Dictionary = data["skills"]
	var result: Dictionary = {}
	for skill_id in skills:
		var skill: Dictionary = skills[skill_id]
		if skill.has("skill_id") and skill.has("skill_name") and skill.has("level") and skill.has("xp") and skill.has("total_xp_earned"):
			result[skill_id] = {
				"skill_id": str(skill["skill_id"]),
				"skill_name": str(skill["skill_name"]),
				"level": int(skill["level"]),
				"xp": int(skill["xp"]),
				"total_xp_earned": int(skill["total_xp_earned"]),
			}
	return result

func skill_total_xp(skills: Dictionary, skill_id: String) -> int:
	if skills.has(skill_id):
		return int(skills[skill_id]["total_xp_earned"])
	return 0

func _test() -> bool:
	var skills: Dictionary = {}
	var record1: Dictionary = create_skill_record("Fire Breath", 3, 1500)
	var record2: Dictionary = create_skill_record("Water Pulse", 2, 800)
	add_skill(skills, record1)
	add_skill(skills, record2)
	
	var duplicate_record: Dictionary = create_skill_record("Fire Breath", 5, 3000)
	add_skill(skills, duplicate_record)
	
	if skills["fire_breath"]["level"] != 5:
		return false
	if skills["fire_breath"]["total_xp_earned"] != 4500:
		return false
	
	var serialized: Dictionary = serialize_training(skills, "player_123")
	if serialized["version"] != SAVE_VERSION:
		return false
	if serialized["owner_id"] != "player_123":
		return false
	if not serialized.has("saved_at"):
		return false
	
	var deserialized: Dictionary = deserialize_training(serialized)
	if deserialized.size() != 2:
		return false
	if deserialized["fire_breath"]["level"] != 5:
		return false
	if deserialized["fire_breath"]["total_xp_earned"] != 4500:
		return false
	if deserialized["water_pulse"]["level"] != 2:
		return false
	if deserialized["water_pulse"]["total_xp_earned"] != 800:
		return false
	
	var empty_test: Dictionary = deserialize_training({})
	if empty_test.size() != 0:
		return false
	
	var wrong_version: Dictionary = deserialize_training({"version": 999, "skills": {}})
	if wrong_version.size() != 0:
		return false
	
	if skill_total_xp(deserialized, "fire_breath") != 4500:
		return false
	if skill_total_xp(deserialized, "nonexistent") != 0:
		return false
	
	return true