# DynamicMusic — The Sanctuary (Creature-Taming Game)
# Mood-reactive audio system that crossfades between music tracks based on game state.
# Reacts to: creature needs (calm/danger), battle events (battle/victory), game state changes.
# Uses Tweens for smooth volume crossfades between AudioStreamPlayer tracks.
# Integrates with existing systems: CreatureNeeds (group 'creature'), WaveDirector (battle), GameState (victory).
extends Node
class_name DynamicMusic

## Mood enum representing the current musical atmosphere.
enum Mood { CALM, BATTLE, DANGER, VICTORY }

## Human-readable mood names for debugging and UI.
const MOOD_NAMES := {
	Mood.CALM: "Calm",
	Mood.BATTLE: "Battle",
	Mood.DANGER: "Danger",
	Mood.VICTORY: "Victory",
}

## Crossfade duration in seconds when transitioning between moods.
@export var crossfade_duration: float = 2.0
## Master volume multiplier applied to all music tracks (0.0 to 1.0).
@export var master_volume: float = 0.8
## Threshold (0.0 to 1.0) below which creature needs trigger DANGER mood.
@export var danger_needs_threshold: float = 0.3

## Emitted when the music mood changes (old_mood, new_mood).
signal mood_changed(old_mood: int, new_mood: int)
## Emitted when a crossfade transition completes (target_mood).
signal crossfade_completed(target_mood: int)

## Internal track storage: mood -> AudioStreamPlayer reference.
var _tracks: Dictionary = {}
## Current active mood.
var _current_mood: int = Mood.CALM
## Target mood during crossfade.
var _target_mood: int = Mood.CALM
## Currently playing track (fading out).
var _active_player: AudioStreamPlayer = null
## Next track fading in.
var _next_player: AudioStreamPlayer = null
## Active tween for crossfade.
var _crossfade_tween: Tween = null
## Flag to prevent re-entrant crossfade calls.
var _is_crossfading: bool = false
## Reference to CreatureNeeds for auto-detection.
var _creature_needs: CreatureNeeds = null
## Reference to WaveDirector for battle detection.
var _wave_director: WaveDirector = null
## Reference to GameState for victory detection.
var _game_state: GameState = null

func _ready() -> void:
	"""Initialize the music system: discover tracks, connect signals, set initial mood."""
	# Discover AudioStreamPlayer children named after moods (e.g., "CalmTrack", "BattleTrack").
	# This allows designers to add tracks in the editor without code changes.
	for child in get_children():
		if child is AudioStreamPlayer:
			var mood_key := _mood_from_track_name(child.name)
			if mood_key != -1:
				_tracks[mood_key] = child
				child.volume_db = -80.0  # Start silent
				child.play()             # Start playing (looped streams will loop)
	
	# Fallback: if no tracks found, create placeholder silent players to avoid null errors.
	# In production, designer should assign proper audio streams in the editor.
	if _tracks.is_empty():
		push_warning("DynamicMusic: No AudioStreamPlayer tracks found as children. Creating silent fallbacks.")
		for mood in [Mood.CALM, Mood.BATTLE, Mood.DANGER, Mood.VICTORY]:
			var player := AudioStreamPlayer.new()
			player.name = "%sTrack" % MOOD_NAMES[mood]
			player.volume_db = -80.0
			player.play()
			add_child(player)
			_tracks[mood] = player
	
	# Auto-detect and connect to game systems via groups and autoloads.
	_connect_game_signals()
	
	# Set initial mood to CALM and start its track at master volume.
	_set_track_volume(Mood.CALM, master_volume)
	_current_mood = Mood.CALM
	_target_mood = Mood.CALM

func _connect_game_signals() -> void:
	"""Connect to creature needs, battle waves, and game state for automatic mood detection."""
	# 1. Creature needs (group 'creature') — low needs trigger DANGER mood.
	var creature: Node = get_first_node_in_group("creature")
	if creature and creature.has_method("get_needs"):
		_creature_needs = creature.get_needs()
		if _creature_needs:
			# Connect to needs_changed signal from CreatureNeeds (emits when any need changes)
			_creature_needs.connect("needs_changed", _on_creature_needs_changed.bind())
	else:
		push_warning("DynamicMusic: No node in group 'creature' with get_needs() found.")
	
	# 2. WaveDirector (battle system) — wave_started triggers BATTLE mood.
	_wave_director = get_first_node_in_group("wave_director") as WaveDirector
	if not _wave_director:
		# Try autoload singleton name
		_wave_director = get_node_or_null("/root/WaveDirector") as WaveDirector
	if _wave_director:
		_wave_director.connect("wave_started", _on_battle_started.bind())
		_wave_director.connect("wave_completed", _on_battle_ended.bind())
	else:
		push_warning("DynamicMusic: WaveDirector not found (group 'wave_director' or autoload).")
	
	# 3. GameState autoload — VICTORY state triggers VICTORY mood.
	_game_state = get_node_or_null("/root/GameState") as GameState
	if _game_state:
		_game_state.connect("state_changed", _on_game_state_changed.bind())
	else:
		push_warning("DynamicMusic: GameState autoload not found at /root/GameState.")

func _mood_from_track_name(name: String) -> int:
	"""Map track node name to Mood enum. Returns -1 if unrecognized."""
	match name.to_lower():
		"calmtrack", "calm_track", "calm": return Mood.CALM
		"battletrack", "battle_track", "battle": return Mood.BATTLE
		"dangertrack", "danger_track", "danger": return Mood.DANGER
		"victorytrack", "victory_track", "victory": return Mood.VICTORY
		_: return -1

func set_mood(mood: int) -> void:
	"""Public API: request a mood change. Triggers crossfade if mood differs from current."""
	if mood not in Mood:
		push_error("DynamicMusic.set_mood: Invalid mood value %d" % mood)
		return
	if mood == _current_mood and not _is_crossfading:
		return  # Already in this mood, no action needed
	if _is_crossfading:
		# Queue the new target; current crossfade will complete then transition to this.
		_target_mood = mood
		return
	
	_target_mood = mood
	_start_crossfade()

func _start_crossfade() -> void:
	"""Begin a volume crossfade from current mood track to target mood track using Tween."""
	if _target_mood == _current_mood:
		return
	
	var current_player: AudioStreamPlayer = _tracks.get(_current_mood)
	var target_player: AudioStreamPlayer = _tracks.get(_target_mood)
	
	if not current_player or not target_player:
		push_error("DynamicMusic: Missing AudioStreamPlayer for mood %s or %s" % [MOOD_NAMES[_current_mood], MOOD_NAMES[_target_mood]])
		# Fallback: instant switch
		_complete_crossfade_immediate()
		return
	
	_is_crossfading = true
	_active_player = current_player
	_next_player = target_player
	
	# Create tween for smooth crossfade
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(false)  # Sequential: fade out then fade in (or parallel for X-fade)
	
	# Fade OUT current track: volume_db from master_volume -> -80 (silent)
	var current_start_db := linear_to_db(master_volume)
	var silent_db: float = -80.0
	_crossfade_tween.tween_property(_active_player, "volume_db", silent_db, crossfade_duration)
	
	# Fade IN target track: volume_db from -80 -> master_volume (parallel for true crossfade)
	_crossfade_tween.parallel().tween_property(_next_player, "volume_db", current_start_db, crossfade_duration)
	
	# On completion, finalize the mood switch
	_crossfade_tween.finished.connect(_on_crossfade_finished.bind(_target_mood))
	
	# Ensure target track is playing (looped streams)
	if not _next_player.playing:
		_next_player.play()

func _on_crossfade_finished(target_mood: int) -> void:
	"""Called when crossfade tween completes. Finalize mood state."""
	_is_crossfading = false
	
	# Ensure old track is fully silent and stopped
	if _active_player and _active_player != _next_player:
		_active_player.volume_db = -80.0
		_active_player.stop()
	
	# Lock in new track at master volume
	_next_player.volume_db = linear_to_db(master_volume)
	
	var old_mood: int = _current_mood
	_current_mood = target_mood
	_target_mood = target_mood
	
	_active_player = null
	_next_player = null
	_crossfade_tween = null
	
	# Emit signals for external listeners
	mood_changed.emit(old_mood, _current_mood)
	crossfade_completed.emit(_current_mood)

func _complete_crossfade_immediate() -> void:
	"""Fallback: instant mood switch without crossfade (used on errors)."""
	for mood in _tracks.keys():
		var player: AudioStreamPlayer = _tracks[mood]
		if mood == _target_mood:
			player.volume_db = linear_to_db(master_volume)
			if not player.playing:
				player.play()
		else:
			player.volume_db = -80.0
			player.stop()
	
	var old_mood: int = _current_mood
	_current_mood = _target_mood
	_is_crossfading = false
	mood_changed.emit(old_mood, _current_mood)
	crossfade_completed.emit(_current_mood)

func _set_track_volume(mood: int, volume: float) -> void:
	"""Helper: set a specific track's volume (linear 0-1 converted to dB)."""
	var player: AudioStreamPlayer = _tracks.get(mood)
	if player:
		player.volume_db = linear_to_db(volume)

## --- Automatic Mood Detection Callbacks ------------------------------------

func _on_creature_needs_changed() -> void:
	"""Called when creature needs change. If any critical need is low, enter DANGER mood."""
	if not _creature_needs:
		return
	
	# Check all needs; if any drops below danger threshold and we're not in combat, go to DANGER
	var needs_dict: Dictionary = _creature_needs.get_all_needs()
	var any_critical: bool = false
	for need_name in needs_dict.keys():
		var need_data: Dictionary = needs_dict[need_name]
		var current: float = need_data.get("current", 1.0)
		var max_val: float = need_data.get("max", 1.0)
		if max_val > 0 and (current / max_val) < danger_needs_threshold:
			any_critical = true
			break
	
	# Only auto-switch to DANGER if currently CALM (don't interrupt BATTLE/VICTORY)
	if any_critical and _current_mood == Mood.CALM and not _is_crossfading:
		set_mood(Mood.DANGER)
	elif not any_critical and _current_mood == Mood.DANGER and not _is_crossfading:
		# Needs recovered while in DANGER -> return to CALM
		set_mood(Mood.CALM)

func _on_battle_started(wave: int) -> void:
	"""WaveDirector wave_started signal: enter BATTLE mood immediately."""
	if _current_mood != Mood.BATTLE and not _is_crossfading:
		set_mood(Mood.BATTLE)

func _on_battle_ended(wave: int) -> void:
	"""WaveDirector wave_completed signal: return to CALM or DANGER based on creature needs."""
	# Don't auto-transition if we're in VICTORY (handled by GameState)
	if _current_mood == Mood.VICTORY:
		return
	
	# Check creature needs to decide between CALM or DANGER
	if _creature_needs:
		var needs_dict: Dictionary = _creature_needs.get_all_needs()
		var any_critical: bool = false
		for need_name in needs_dict.keys():
			var need_data: Dictionary = needs_dict[need_name]
			var current: float = need_data.get("current", 1.0)
			var max_val: float = need_data.get("max", 1.0)
			if max_val > 0 and (current / max_val) < danger_needs_threshold:
				any_critical = true
				break
		set_mood(Mood.DANGER if any_critical else Mood.CALM)
	else:
		set_mood(Mood.CALM)

func _on_game_state_changed(prev_state: StringName, cur_state: StringName) -> void:
	"""GameState state_changed signal: VICTORY state triggers VICTORY mood."""
	if cur_state == GameState.S.VICTORY and _current_mood != Mood.VICTORY:
		set_mood(Mood.VICTORY)
	elif prev_state == GameState.S.VICTORY and _current_mood == Mood.VICTORY:
		# Left victory state; return to appropriate mood based on battle/needs
		if _wave_director and _wave_director.current_wave > 0:
			set_mood(Mood.BATTLE)
		elif _creature_needs:
			var needs_dict: Dictionary = _creature_needs.get_all_needs()
			var any_critical: bool = false
			for need_name in needs_dict.keys():
				var need_data: Dictionary = needs_dict[need_name]
				var current: float = need_data.get("current", 1.0)
				var max_val: float = need_data.get("max", 1.0)
				if max_val > 0 and (current / max_val) < danger_needs_threshold:
					any_critical = true
					break
			set_mood(Mood.DANGER if any_critical else Mood.CALM)
		else:
			set_mood(Mood.CALM)

## --- Utility Methods --------------------------------------------------------

func linear_to_db(linear: float) -> float:
	"""Convert linear volume (0.0-1.0) to decibels. -80 dB = silent."""
	if linear <= 0.0:
		return -80.0
	return 20.0 * log10(linear)

func get_current_mood() -> int:
	"""Return the current mood enum value."""
	return _current_mood

func get_mood_name(mood: int) -> String:
	"""Return human-readable name for a mood enum."""
	return MOOD_NAMES.get(mood, "Unknown")

func set_master_volume(volume: float) -> void:
	"""Update master volume and apply to currently playing track."""
	master_volume = clamp(volume, 0.0, 1.0)
	if _current_mood in _tracks and not _is_crossfading:
		_tracks[_current_mood].volume_db = linear_to_db(master_volume)

func is_crossfading() -> bool:
	"""Return true if a crossfade is currently in progress."""
	return _is_crossfading

## --- Cleanup ----------------------------------------------------------------

func _exit_tree() -> void:
	"""Disconnect signals on node removal to prevent memory leaks."""
	if _creature_needs and _creature_needs.is_connected("needs_changed", Callable(self, "_on_creature_needs_changed")):
		_creature_needs.disconnect("needs_changed", Callable(self, "_on_creature_needs_changed"))
	if _wave_director:
		if _wave_director.is_connected("wave_started", Callable(self, "_on_battle_started")):
			_wave_director.disconnect("wave_started", Callable(self, "_on_battle_started"))
		if _wave_director.is_connected("wave_completed", Callable(self, "_on_battle_ended")):
			_wave_director.disconnect("wave_completed", Callable(self, "_on_battle_ended"))
	if _game_state and _game_state.is_connected("state_changed", Callable(self, "_on_game_state_changed")):
		_game_state.disconnect("state_changed", Callable(self, "_on_game_state_changed"))