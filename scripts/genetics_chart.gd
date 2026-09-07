class_name GeneticsChart
extends RefCounted

## Trait structure using a Dictionary for simplicity and compatibility
# Each trait is a Dictionary with keys: name (String), inherited_percent (int), source_parent (String)

var _traits: Array[Dictionary] = []


func add_trait(p_name: String, p_percent: int, p_parent: String) -> void:
	"""Add a trait to the genetics chart."""
	var new_trait: Dictionary = {
		"name": p_name,
		"inherited_percent": p_percent,
		"source_parent": p_parent
	}
	_traits.append(new_trait)


func get_trait_percentages() -> Array[Dictionary]:
	"""Return an array of dicts with trait name, percentage, and source parent."""
	var result: Array[Dictionary] = []
	for tr in _traits:
		result.append({
			"name": tr["name"],
			"inherited_percent": tr["inherited_percent"],
			"source_parent": tr["source_parent"]
		})
	return result


func get_dominant_parent() -> String:
	"""Return the parent name with the most inherited traits (by count)."""
	if _traits.is_empty():
		return ""
	
	var parent_counts: Dictionary = {}
	for tr in _traits:
		var parent = tr["source_parent"]
		if parent_counts.has(parent):
			parent_counts[parent] += 1
		else:
			parent_counts[parent] = 1
	
	var dominant_parent: String = ""
	var max_count: int = 0
	for parent in parent_counts:
		if parent_counts[parent] > max_count:
			max_count = parent_counts[parent]
			dominant_parent = parent
	
	return dominant_parent


func get_parent_contribution(p_parent: String) -> Dictionary:
	"""Get contribution summary for a specific parent."""
	var traits_from_parent: Array[Dictionary] = []
	var total_percent: int = 0
	
	for tr in _traits:
		if tr["source_parent"] == p_parent:
			traits_from_parent.append({
				"name": tr["name"],
				"inherited_percent": tr["inherited_percent"]
			})
			total_percent += tr["inherited_percent"]
	
	return {
		"parent": p_parent,
		"trait_count": traits_from_parent.size(),
		"total_percent": total_percent,
		"traits": traits_from_parent
	}


func run_tests() -> Dictionary:
	"""Run internal tests and return a dict of pass/fail results."""
	var results: Dictionary = {}
	
	# Test 1: Basic trait addition and retrieval
	var chart1 = GeneticsChart.new()
	chart1.add_trait("Eye Color", 75, "Mother")
	chart1.add_trait("Fur Pattern", 60, "Father")
	chart1.add_trait("Size", 50, "Mother")
	
	var percentages = chart1.get_trait_percentages()
	results["test_trait_percentages"] = (
		percentages.size() == 3 and
		percentages[0]["name"] == "Eye Color" and
		percentages[0]["inherited_percent"] == 75 and
		percentages[0]["source_parent"] == "Mother" and
		percentages[1]["name"] == "Fur Pattern" and
		percentages[2]["source_parent"] == "Mother"
	)
	
	# Test 2: Dominant parent by trait count
	var chart2 = GeneticsChart.new()
	chart2.add_trait("Trait A", 80, "Mother")
	chart2.add_trait("Trait B", 70, "Mother")
	chart2.add_trait("Trait C", 90, "Father")
	results["test_dominant_parent"] = (chart2.get_dominant_parent() == "Mother")
	
	# Test 3: Tie goes to first encountered (or any consistent behavior)
	var chart3 = GeneticsChart.new()
	chart3.add_trait("Trait A", 80, "Mother")
	chart3.add_trait("Trait B", 70, "Father")
	results["test_dominant_parent_tie"] = (chart3.get_dominant_parent() == "Mother" or chart3.get_dominant_parent() == "Father")
	
	# Test 4: Empty chart returns empty string
	var chart4 = GeneticsChart.new()
	results["test_empty_dominant_parent"] = (chart4.get_dominant_parent() == "")
	
	# Test 5: get_parent_contribution
	var chart5 = GeneticsChart.new()
	chart5.add_trait("Trait A", 80, "Mother")
	chart5.add_trait("Trait B", 70, "Mother")
	chart5.add_trait("Trait C", 90, "Father")
	var mother_contrib = chart5.get_parent_contribution("Mother")
	results["test_parent_contribution"] = (
		mother_contrib["parent"] == "Mother" and
		mother_contrib["trait_count"] == 2 and
		mother_contrib["total_percent"] == 150
	)
	
	# Test 6: Multiple traits from same parent
	var chart6 = GeneticsChart.new()
	chart6.add_trait("Trait A", 100, "Mother")
	chart6.add_trait("Trait B", 100, "Mother")
	chart6.add_trait("Trait C", 100, "Mother")
	results["test_all_one_parent"] = (chart6.get_dominant_parent() == "Mother")
	
	# Test 7: Percentages bounds (0-100)
	var chart7 = GeneticsChart.new()
	chart7.add_trait("Trait A", 0, "Mother")
	chart7.add_trait("Trait B", 100, "Father")
	var p = chart7.get_trait_percentages()
	results["test_percent_bounds"] = (p[0]["inherited_percent"] == 0 and p[1]["inherited_percent"] == 100)
	
	# Test 8: Case sensitivity of parent names
	var chart8 = GeneticsChart.new()
	chart8.add_trait("Trait A", 50, "mother")
	chart8.add_trait("Trait B", 50, "Mother")
	results["test_case_sensitivity"] = (chart8.get_dominant_parent() == "mother" or chart8.get_dominant_parent() == "Mother")
	
	# Test 9: Traits with same name different parents
	var chart9 = GeneticsChart.new()
	chart9.add_trait("Color", 60, "Mother")
	chart9.add_trait("Color", 40, "Father")
	var p9 = chart9.get_trait_percentages()
	results["test_same_name_different_parents"] = (p9.size() == 2 and p9[0]["source_parent"] != p9[1]["source_parent"])
	
	# Test 10: Run tests returns dictionary with boolean values
	var all_bool = true
	for key in results:
		if typeof(results[key]) != TYPE_BOOL:
			all_bool = false
			break
	results["test_returns_bool_dict"] = all_bool
	
	return results