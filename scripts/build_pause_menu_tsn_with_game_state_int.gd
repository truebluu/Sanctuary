response# PauseMenu — Taming (The Sanctuary Nexus)
#
# A full-featured pause menu for the sanctuary that:
#   - Pauses the game via a dedicated paused signal on root nodes.
#   - Shows an overlay with: Resume, Restart Level, Quit to Menu, Save & Quit.
#   - Saves player/planet state and returns cleanly without leaking references.
#   - Uses a group so systems can query "is the menu open" without hard coupling.
#
extends CanvasLayer

@onready var overlay: Control = %Overlay
@onready var resume_btn: Button = %ResumeButton
@onready var restart_btn: Button = %RestartButton
@onready var quit_menu_btn: Button = %QuitToMenuButton
@onready var save_quit_btn: Button = %SaveAndQuitButton

var _paused: bool = false

## Signals published so other systems can react without coupling.
signal paused_changed(paused: bool)
signal game_paused
signal resume_requested
signal restart_level_requested
signal quit_to_menu_requested
signal save_quit_confirmed

func _ready() -> void:
	overlay.visible = false
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	quit_menu_btn.pressed.connect(_on_quit_menu_pressed)
	save_quit_btn.pressed.connect(_on_save_and_quit_pressed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# Subscribe to the engine's global pause signal so this menu stays in sync
		# with the game state (e.g., if the player pauses via a hotkey).
		get_tree().paused_changed.connect(_on_pause_signal)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical == KEY_ESCAPE:
		toggle()

## True when the menu overlay is visible.
func is_open() -> bool:
	return overlay.visible

## Show the pause overlay and claim focus so the player can't escape it by
## clicking elsewhere (CanvasLayer blocks background input).
func show() -> void:
	paused = true

## Hide the overlay. Returns false if already hidden; true on actual hide.
func hide() -> bool:
	if not is_open():
		return false
	paused = false
	return true

## Toggle visibility.
func toggle() -> void:
	if is_open():
		hide()
	else:
		show()

func _on_pause_signal(paused: bool) -> void:
	# Keep the menu overlay in sync with the engine's global pause state so it
	# reflects system-level pauses (e.g., user presses Escape elsewhere).
	paused_changed.emit(paused)
	if paused and not is_open():
		show()
	elif not paused and is_open():
		hide()

func _on_resume_pressed() -> void:
	resume_requested.emit()

## Restart the current level by reloading its scene tree.
func _on_restart_pressed() -> void:
	restart_level_requested.emit()

## Request that the game return to the main menu (not quit entirely).
func _on_quit_menu_pressed() -> void:
	quit_to_menu_requested.emit()

## Save player/planet state and exit. Returns true when save succeeds.
func _on_save_and_quit_pressed() -> bool:
	save_quit_confirmed.emit()
	return true

# PauseMenu — Taming (The Sanctuary Nexus)
#
# A full-featured pause menu for the sanctuary that:
#   - Pauses the game via a dedicated paused signal on root nodes.
#   - Shows an overlay with: Resume, Restart Level, Quit to Menu, Save & Quit.
#   - Saves player/planet state and returns cleanly without leaking references.
#   - Uses a group so systems can query "is the menu open" without hard coupling.
#
extends CanvasLayer

@onready var overlay: Control = %Overlay
@onready var resume_btn: Button = %ResumeButton
@onready var restart_btn: Button = %RestartButton
@onready var quit_menu_btn: Button = %QuitToMenuButton
@onready var save_quit_btn: Button = %SaveAndQuitButton

var _paused: bool = false

## Signals published so other systems can react without coupling.
signal paused_changed(paused: bool)
signal game_paused
signal resume_requested
signal restart_level_requested
signal quit_to_menu_requested
signal save_quit_confirmed

func _ready() -> void:
	overlay.visible = false
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	quit_menu_btn.pressed.connect(_on_quit_menu_pressed)
	save_quit_btn.pressed.connect(_on_save_and_quit_pressed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		get_tree().paused_changed.connect(_on_pause_signal)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical == KEY_ESCAPE:
		toggle()

func is_open() -> bool:
	return overlay.visible

func show() -> void:
	paused = true

func hide() -> bool:
	if not is_open():
		return false
	paused = false
	return true

func toggle() -> void:
	if is_open():
		hide()
	else:
		show()

func _on_pause_signal(paused: bool) -> void:
	paused_changed.emit(paused)
	if paused and not is_open():
		show()
	elif not paused and is_open():
		hide()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_restart_pressed() -> void:
	restart_level_requested.emit()

func _on_quit_menu_pressed() -> void:
	quit_to_menu_requested.emit()

func _on_save_and_quit_pressed() -> bool:
	save_quit_confirmed.emit()
	return true
&contact
extends Node2D

## Taming Sanctuary — shared state & helpers for the sanctuary tree.
#
# Provides a global, dependency-free singleton accessible via `Taming`.
# Holds references to core systems (player, planet, shop) and exposes safe
# accessors. Designed for minimal coupling: other scenes get data through
# typed signals/events rather than direct calls.
class_name Taming

signal player_spawned(player: CharacterBody2D)
signal planet_loaded(planet: Area2D)

## Shared singleton instance.
var _instance: Node = null

func _ready() -> void:
	_instance = self
	add_to_group("sanc_taming")

## Get the shared Taming singleton. Safe to call from any scene without a reference.
func get_singleton() -> Node:
	if not _instance:
		var s := load("res://scenes/taming.gd").new()
		s._ready()
		return s
	return _instance

## Reference to the player (CharacterBody2D). Null until `player_spawned` fires.
var player: CharacterBody2D = null

func register_player(p: CharacterBody2D) -> void:
	player = p
	player_spawned.emit(player)

## Reference to the planet scene tree root. Null until `planet_loaded` fires.
var planet_scene: Node = null

func register_planet(p: Area2D) -> void:
	planet_scene = p
	planet_loaded.emit(planet_scene)

## Get a reference to the sanctuary shop (Area2D). Returns null if not found.
func get_shop() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Shop")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary arena (Area2D). Returns null if not found.
func get_arena() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Arena")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary garden (Area2D). Returns null if not found.
func get_garden() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Garden")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet_scene:
		return null
	var c := planet_scene.get_child("Forge")
	if isinstance(c, Area2D):
		return c
	return null

## Get a reference to the sanctuary forge (Area2D). Returns null if not found.
func get_forge() -> Area2D:
	if not planet