## Creature Personality Traits UI
## Displays personality trait badges and behavior hints for creatures in the pet menu.
## @tool

class_name CreaturePersonalityUI
extends Control

## The container that holds trait badges (set in editor)
@export var trait_badge_container: HBoxContainer

## The label that displays behavior hints (set in editor)
@export var behavior_hint_label: RichTextLabel

## Optional texture for trait badge backgrounds
@export var badge_background_texture: Texture2D

## Color for positive/beneficial traits
@export var positive_trait_color: Color = Color(0.2, 0.7, 0.3, 1.0)

## Color for negative/challenging traits
@export var negative_trait_color: Color = Color(0.8, 0.3, 0.2, 1.0)

## Color for neutral traits
@export var neutral_trait_color: Color = Color(0.5, 0.5, 0.6, 1.0)

## Maximum number of trait badges to display
@export var max_displayed_traits: int = 6

## Whether to show trait descriptions as tooltips
@export var show_trait_tooltips: bool = true

## Internal storage for the current creature data
var _current_creature: Dictionary = {}

## Internal storage for trait badge nodes
var _trait_badges: Array[Label] = []

## Signal emitted when a trait badge is hovered (for detailed tooltips)
signal trait_hovered(trait_name: String, trait_data: Dictionary)

## Signal emitted when behavior hint is updated
signal behavior_hint_updated(hint_text: String)

func _ready() -> void:
	"""Initialize the UI components and prepare for creature data."""
	# Ensure container exists
	if trait_badge_container == null:
		trait_badge_container = HBoxContainer.new()
		add_child(trait_badge_container)
		trait_badge_container.name = "TraitBadgeContainer"
	
	# Ensure behavior hint label exists
	if behavior_hint_label == null:
		behavior_hint_label = RichTextLabel.new()
		add_child(behavior_hint_label)
		behavior_hint_label.name = "BehaviorHintLabel"
		behavior_hint_label.bbcode_enabled = true
		behavior_hint_label.fit_content = true
	
	# Initialize empty state
	_clear_trait_badges()
	behavior_hint_label.text = "[i]Select a creature to view personality traits[/i]"

## Sets the creature data and refreshes the displayed traits.
## @param creature_data Dictionary containing 'personality_traits' (Array[Dictionary] or Dictionary)
##                      and optionally 'behavior_hints' (Array[String] or String)
func set_creature(creature_data: Dictionary) -> void:
	"""Set the creature data and refresh the UI display."""
	if creature_data == null or creature_data.is_empty():
		_clear_display()
		return
	
	_current_creature = creature_data
	refresh_display()

## Refreshes the displayed traits and behavior hints from current creature data.
func refresh_display() -> void:
	"""Rebuild the UI based on current creature data."""
	_clear_trait_badges()
	
	var traits = _get_personality_traits()
	if traits.is_empty():
		behavior_hint_label.text = "[i]This creature has no defined personality traits[/i]"
		return
	
	# Display trait badges (limited by max_displayed_traits)
	var displayed_count = 0
	for trait in traits:
		if displayed_count >= max_displayed_traits:
			break
		_add_trait_badge(trait)
		displayed_count += 1
	
	# Build and display behavior hint
	var hint_text = get_behavior_hint()
	behavior_hint_label.text = hint_text
	behavior_hint_updated.emit(hint_text)

## Builds a formatted hint string from behavior data.
## @return Formatted BBCode string for the behavior hint label
func get_behavior_hint() -> String:
	"""Generate a formatted behavior hint string from creature behavior data."""
	var hints = _get_behavior_hints()
	if hints.is_empty():
		return "[i]No behavior hints available for this creature[/i]"
	
	var hint_parts: Array[String] = []
	
	for hint in hints:
		var formatted_hint = _format_hint(hint)
		if formatted_hint != "":
			hint_parts.append(formatted_hint)
	
	if hint_parts.is_empty():
		return "[i]No behavior hints available for this creature[/i]"
	
	# Join with bullet points and format with BBCode
	var result = "[b]Behavior Hints:[/b]\n"
	for i, part in hint_parts:
		result += "  \u2022 [color=#cccccc]%s[/color]\n" % part
	
	return result

## Clears all displayed traits and resets to empty state.
func _clear_display() -> void:
	"""Clear all UI elements to empty state."""
	_current_creature = {}
	_clear_trait_badges()
	behavior_hint_label.text = "[i]Select a creature to view personality traits[/i]"

## Clears existing trait badge nodes.
func _clear_trait_badges() -> void:
	"""Remove all existing trait badge nodes from container."""
	for badge in _trait_badges:
		if is_instance_valid(badge):
			badge.queue_free()
	_trait_badges.clear()

## Extracts personality traits from creature data (handles multiple formats).
func _get_personality_traits() -> Array:
	"""Extract personality traits array from creature data, handling various formats."""
	if not _current_creature.has("personality_traits"):
		return []
	
	var traits_data = _current_creature["personality_traits"]
	
	# Handle Dictionary format: {"trait_name": value, ...}
	if traits_data is Dictionary:
		var traits_array: Array = []
		for key in traits_data:
			var trait_dict = {
				"name": key,
				"value": traits_data[key],
				"type": _infer_trait_type(key, traits_data[key])
			}
			traits_array.append(trait_dict)
		return traits_array
	
	# Handle Array format: [{"name": "...", "value": ...}, ...] or ["trait1", "trait2"]
	if traits_data is Array:
		var result: Array = []
		for item in traits_data:
			if item is Dictionary:
				result.append(item)
			elif item is String:
				result.append({"name": item, "value": 1.0, "type": "neutral"})
			else:
				result.append({"name": str(item), "value": 1.0, "type": "neutral"})
		return result
	
	# Single string trait
	if traits_data is String:
		return [{"name": traits_data, "value": 1.0, "type": "neutral"}]
	
	return []

## Extracts behavior hints from creature data (handles multiple formats).
func _get_behavior_hints() -> Array:
	"""Extract behavior hints array from creature data, handling various formats."""
	if not _current_creature.has("behavior_hints"):
		return []
	
	var hints_data = _current_creature["behavior_hints"]
	
	if hints_data is Array:
		var result: Array = []
		for item in hints_data:
			if item is String:
				result.append(item)
			elif item is Dictionary and item.has("hint"):
				result.append(item["hint"])
			else:
				result.append(str(item))
		return result
	
	if hints_data is String:
		return [hints_data]
	
	if hints_data is Dictionary and hints_data.has("hint"):
		return [hints_data["hint"]]
	
	return []

## Infers trait type from name and value for color coding.
func _infer_trait_type(name: String, value: Variant) -> String:
	"""Determine trait type (positive/negative/neutral) for color coding."""
	var positive_keywords = ["friendly", "brave", "curious", "playful", "loyal", "gentle", "smart", "calm"]
	var negative_keywords = ["aggressive", "fearful", "lazy", "stubborn", "moody", "wild", "skittish", "destructive"]
	
	var lower_name = name.to_lower()
	
	for keyword in positive_keywords:
		if lower_name.contains(keyword):
			return "positive"
	
	for keyword in negative_keywords:
		if lower_name.contains(keyword):
			return "negative"
	
	# Check numeric value if available
	if value is int or value is float:
		var num_val = float(value)
		if num_val > 0.5:
			return "positive"
		elif num_val < -0.5:
			return "negative"
	
	return "neutral"

## Creates and adds a trait badge to the container.
func _add_trait_badge(trait_data: Dictionary) -> void:
	"""Create a badge label for a personality trait and add to container."""
	var name = trait_data.get("name", "Unknown Trait")
	var value = trait_data.get("value", 1.0)
	var trait_type = trait_data.get("type", _infer_trait_type(name, value))
	
	var badge = Label.new()
	badge.name = "TraitBadge_%s" % name
	badge.text = _format_trait_name(name, value)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge.custom_minimum_size = Vector2(100, 36)
	
	# Apply color based on trait type
	var badge_color = _get_trait_color(trait_type)
	badge.add_theme_color_override("font_color", badge_color)
	
	# Add background style if texture provided
	if badge_background_texture != null:
		var stylebox = StyleBoxTexture.new()
		stylebox.texture = badge_background_texture
		badge.add_theme_stylebox_override("normal", stylebox)
	
	# Add tooltip if enabled
	if show_trait_tooltips:
		var tooltip_text = _build_trait_tooltip(trait_data)
		badge.tooltip_text = tooltip_text
	
	# Connect mouse entered signal for detailed hover
	badge.mouse_entered.connect(_on_trait_badge_hovered.bind(trait_data))
	
	trait_badge_container.add_child(badge)
	_trait_badges.append(badge)

## Formats trait name with value indicator.
func _format_trait_name(name: String, value: Variant) -> String:
	"""Format trait name for display, optionally including value."""
	var formatted = name.capitalize()
	
	if value is int or value is float:
		var val = float(value)
		if val != 1.0:  # Don't show default value
			var percentage = (val * 100).round()
			formatted += " (%d%%)" % percentage
	
	return formatted

## Gets color for trait type.
func _get_trait_color(trait_type: String) -> Color:
	"""Return appropriate color for trait type."""
	match trait_type:
		"positive":
			return positive_trait_color
		"negative":
			return negative_trait_color
		_:
			return neutral_trait_color

## Builds tooltip text for a trait.
func _build_trait_tooltip(trait_data: Dictionary) -> String:
	"""Build detailed tooltip text for a trait badge."""
	var name = trait_data.get("name", "Unknown")
	var value = trait_data.get("value", 1.0)
	var trait_type = trait_data.get("type", "neutral")
	var description = trait_data.get("description", "")
	
	var tooltip = "[b]%s[/b]\n" % name.capitalize()
	tooltip += "Type: [color=#ffffff]%s[/color]\n" % trait_type.capitalize()
	
	if value is int or value is float:
		tooltip += "Intensity: [color=#ffffff]%.0f%%[/color]\n" % (float(value) * 100)
	
	if description != "":
		tooltip += "\n[i]%s[/i]" % description
	
	return tooltip

## Formats a single hint string with BBCode.
func _format_hint(hint: String) -> String:
	"""Format a single behavior hint with appropriate BBCode styling."""
	var trimmed = hint.strip_edges()
	if trimmed == "":
		return ""
	
	# Capitalize first letter
	if trimmed.length() > 0:
		trimmed = trimmed[0].to_upper() + trimmed.substr(1)
	
	# Ensure ends with period
	if not trimmed.ends_with(".") and not trimmed.ends_with("!") and not trimmed.ends_with("?"):
		trimmed += "."
	
	return trimmed

## Callback when a trait badge is hovered.
func _on_trait_badge_hovered(trait_data: Dictionary) -> void:
	"""Emit signal with trait data for detailed tooltip display."""
	var name = trait_data.get("name", "Unknown")
	trait_hovered.emit(name, trait_data)

## Gets the currently displayed creature data.
func get_current_creature() -> Dictionary:
	"""Return the currently set creature data."""
	return _current_creature

## Checks if a creature is currently displayed.
func has_creature() -> bool:
	"""Return true if creature data is set and not empty."""
	return not _current_creature.is_empty()

## Sets the maximum number of traits to display.
func set_max_displayed_traits(count: int) -> void:
	"""Update max displayed traits and refresh if creature is set."""
	max_displayed_traits = max(1, count)
	if has_creature():
		refresh_display()

## Updates trait badge container reference (for runtime setup).
func set_trait_badge_container(container: HBoxContainer) -> void:
	"""Set the trait badge container at runtime."""
	trait_badge_container = container

## Updates behavior hint label reference (for runtime setup).
func set_behavior_hint_label(label: RichTextLabel) -> void:
	"""Set the behavior hint label at runtime."""
	behavior_hint_label = label
	if behavior_hint_label != null:
		behavior_hint_label.bbcode_enabled = true
		behavior_hint_label.fit_content = true