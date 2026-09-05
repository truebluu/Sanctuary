extends Node
class_name FormatValidator

# Feel: structural guard — ensures forge output lines follow the canonical
# "TITLE | one-line description" pipe format before they reach the build gate.
# Builds on EventBus for validation events and GameState for wave context.

const VALID_TITLE_PATTERN: String = "^[A-Z][A-Z0-9_]+$"
const MAX_TITLE_LENGTH: int = 64
const MAX_DESC_LENGTH: int = 128

signal line_validated(line_index: int, title: String, description: String, ok: bool)
signal validation_failed(line_index: int, reason: String)

func _ready() -> void:
    add_to_group("format_validators")

func validate_line(line: String, line_index: int) -> bool:
    if line.strip_edges().is_empty():
        validation_failed.emit(line_index, "empty line")
        return false
    var parts: PackedStringArray = line.split("|", false)
    if parts.size() < 2:
        validation_failed.emit(line_index, "missing pipe separator")
        return false
    var title: String = parts[0].strip_edges()
    var description: String = parts[1].strip_edges()
    if not _is_valid_title(title):
        validation_failed.emit(line_index, "title fails format: %s" % title)
        return false
    if description.length() > MAX_DESC_LENGTH:
        validation_failed.emit(line_index, "description exceeds %d chars" % MAX_DESC_LENGTH)
        return false
    line_validated.emit(line_index, title, description, true)
    return true

func _is_valid_title(title: String) -> bool:
    if title.length() > MAX_TITLE_LENGTH:
        return false
    var regex: RegEx = RegEx.new()
    regex.compile(VALID_TITLE_PATTERN)
    return regex.search(title) != null

func validate_batch(lines: PackedStringArray) -> int:
    var passed: int = 0
    for i in lines.size():
        if validate_line(lines[i], i):
            passed += 1
    return passed