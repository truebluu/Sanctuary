# sanctuary_feature_driver.gd — headless feature/integration driver for the Sanctuary demo.
# Extends Node2D and runs as a SCENE (sanctuary_feature_driver.tscn) — the proven Godot 4
# pattern that registers autoloads (GameState/EventBus) at compile time.
# Loads the REAL main.tscn, finds EVERY Button node (scene Tree + the ~24 code-built
# buttons that main.gd adds at _ready), presses each through its real .pressed signal,
# and verifies the game's signal/state contract reacts.
# Purpose: catches feature bugs the unit-style demo misses — the demo never loads the
# scene, never presses a button, and never exercises the UI. (sanct-016's broken
# "Inherit Traits" button passed "ALL PASSED" because the demo never pressed it.)
# Bounded wall-clock. Exits 0 on ALL OK, 1 on failures, 2 on timeout.
extends Node2D

const TIMEOUT_MS := 30000
const RESULT_ABS := "C:/Users/bluue/Documents/Sanctuary/sanctuary_feature_driver_result.txt"

var _gs: Node = null
var _main: Node = null
var _failures: Array[String] = []
var _log_lines: Array[String] = []
var _pressed_ok: Array[String] = []
var _t0: int = 0
var _finished := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_log("SANCTUARY FEATURE DRIVER: loading real main.tscn")
	_gs = get_node("/root/GameState")
	_check(_gs != null, "GameState autoload exists")
	var main_scene := load("res://scenes/main.tscn")
	_check(main_scene != null, "main.tscn loads")
	if main_scene == null:
		_quit(1)
		return
	_main = main_scene.instantiate()
	add_child(_main)
	_drive()

func _process(_delta: float) -> void:
	if _finished or _gs == null:
		return
	if Time.get_ticks_msec() - _t0 > TIMEOUT_MS:
		_log("TIMEOUT after %dms — not finished cleanly" % TIMEOUT_MS)
		_finished = true
		_quit(2)

func _drive() -> void:
	# --- 1. Structural: the two tree-wired buttons exist ---
	var breed_btn := _find_button("BreedButton")
	var reroll_btn := _find_button("RerollButton")
	_check(breed_btn != null, "BreedButton exists in tree")
	_check(reroll_btn != null, "RerollButton exists in tree")

	# --- 2. Breed must emit an offspring via GameState.offspring_bred (done BEFORE the
	#         mass-press below so the breeding cooldown hasn't started yet) ---
	if breed_btn != null and _gs.has_signal("offspring_bred"):
		var bred: Array = []
		var cb := func(_c): bred.append(true)
		_gs.offspring_bred.connect(cb)
		breed_btn.pressed.emit()
		await _wait_frames(2)
		_check(not bred.is_empty(), "BreedButton emitted offspring_bred")
		if not bred.is_empty():
			_gs.offspring_bred.disconnect(cb)

	# --- 3. Press EVERY button reachable in the tree exactly once, through .pressed ---
	var buttons: Array = []
	_collect_buttons(_main, buttons)
	_log("found %d Button(s) in tree" % buttons.size())
	_check(buttons.size() >= 20, "expected >=20 buttons (scene + code-built), got %d" % buttons.size())
	_pressed_ok.clear()
	for b in buttons:
		var t: String = str(b.get("text"))
		b.pressed.emit()
		_pressed_ok.append(t)
		await _wait_frames(1)
		_log("  pressed %s" % t)
	# C2: exact count — every collected button was pressed (a handler crash during
	# the loop would abort it and _pressed_ok would fall short of buttons.size()).
	_check(_pressed_ok.size() == buttons.size(), "pressed all %d buttons without runtime crash" % buttons.size())

	# --- 3.1 Weather toggle must drive REAL creature effects through the autoload.
	#         deepseek-pro C1: the old assertion only checked the local string
	#         flip (a false-green). Now: mood_creature is in the "creatures"
	#         group and sanct-029 applies hunger/happiness per-tick; toggling
	#         rain vs sun must move happiness observably via the group contract. ---
	var weather_effects := _find_weather_node()
	var mood_creature := _find_node_by_name(_main, "MoodCreature")
	if weather_effects != null and mood_creature != null:
		_check(mood_creature.is_in_group("creatures"), "MoodCreature is in the 'creatures' group")
		var ws := get_node_or_null("/root/WeatherSystem")
		_check(ws != null, "WeatherSystem autoload is registered (/root/WeatherSystem)")
		var wb := _find_button_by_text("Toggle Rain/Sun")
		if wb != null:
			var before: float = float(mood_creature.get_happiness())
			wb.pressed.emit()
			await _wait_frames(2)
			var after: float = float(mood_creature.get_happiness())
			# sun boosts happiness +5/interval; rain drops it. At minimum the
			# toggle must move the value through the autoload -> group path.
			_check(after != before, "Weather toggle changed MoodCreature happiness (%.1f -> %.1f)" % [before, after])
		var cast_btn := _find_button_by_text("Creature casts Storm")
		if cast_btn != null and ws != null:
			var before_w: String = str(ws.get_current_weather())
			cast_btn.pressed.emit()
			await _wait_frames(2)
			var after_w: String = str(ws.get_current_weather())
			_check(after_w == "storm", "Creature cast drives autoload to storm (%s -> %s)" % [before_w, after_w])
	else:
		_log("  WARN: weather/creature node not found — weather assertions skipped")

	# --- 3.2 Reroll must change the parents' CONTENTS (L5: the old assertion
	#         compared instance addresses, which always differ — a tautology).
	#         Compare the described genome (loci + phenotypes), which is real
	#         content and only meaningful if the parents actually rotated. ---
	if reroll_btn != null and _gs.get("parent_a") != null:
		var pa: Variant = _gs.get("parent_a")
		var desc_a: String = str(pa.describe(_gs.get("rng"))) if pa.has_method("describe") else ""
		# set_parents resets offspring to null; capture it to prove rotation ran.
		reroll_btn.pressed.emit()
		await _wait_frames(2)
		var pa2: Variant = _gs.get("parent_a")
		var desc_a2: String = str(pa2.describe(_gs.get("rng"))) if pa2 != null and pa2.has_method("describe") else ""
		var changed: bool = (pa2 != pa) or (desc_a != desc_a2)
		_check(changed, "RerollButton rotated parent A (genome: '%s' -> '%s')" % [desc_a, desc_a2])
		# set_parents clears offspring; a reroll must drop any stale offspring so the
		# labels reset to "Press BREED" (main.gd:302 offline_reset). Assert it is
		# actually nulled, not that null==null (which is what the old tautology did).
		var offspring_after: Variant = _gs.get("offspring")
		_check(offspring_after == null, "reroll clears stale offspring (set_parents sets null)")

	# --- 3.3 L8: breeding on cooldown must early-return (second immediate BREED
	#         press must NOT emit offspring_bred). ---
	if breed_btn != null and _gs.has_signal("offspring_bred"):
		# The first BREED above started the 30s cooldown. A second immediate press
		# must hit the can_breed() guard in _on_breed and produce no offspring.
		var bred2: Array = []
		var cb2 := func(_c): bred2.append(true)
		_gs.offspring_bred.connect(cb2)
		breed_btn.pressed.emit()
		await _wait_frames(2)
		_check(bred2.is_empty(), "second immediate BREED is gated by cooldown (L8)")
		_gs.offspring_bred.disconnect(cb2)

	_finished = true
	_quit(0 if _failures.is_empty() else 1)

func _find_button(node_name: String) -> Button:
	var stack: Array = [_main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and str(n.name) == node_name:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _find_button_by_text(txt: String) -> Button:
	var stack: Array = [_main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and str(n.get("text")) == txt:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _find_node_by_name(root: Node, node_name: String) -> Node:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if str(n.name) == node_name:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _find_weather_node() -> Node:
	# main.gd:153 adds an unnamed SanctuaryWeatherEffects child of main, whose node
	# name is auto-generated (@Node@...), so find it by the class's methods/state.
	var stack: Array = [_main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_method("_on_weather_changed") and n.get("_current_weather") != null:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _collect_buttons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_collect_buttons(c, out)

func _wait_frames(n: int) -> void:
	var waited := 0
	while waited < n:
		if Time.get_ticks_msec() - _t0 > TIMEOUT_MS:
			_log("TIMEOUT during _wait_frames")
			_finished = true
			_quit(2)
			return
		await get_tree().process_frame
		waited += 1

func _check(cond: bool, msg: String) -> void:
	if cond:
		_log("PASS: " + msg)
	else:
		_failures.append(msg)
		_log("FAIL: " + msg)

func _log(msg: String) -> void:
	_log_lines.append(msg)
	print(msg)

func _quit(code: int) -> void:
	_log("SANCTUARY FEATURE DRIVER: %s (%d pressed, %d failures)"
		% ["ALL PASSED" if code == 0 else "%d FAILURES" % _failures.size(), _pressed_ok.size(), _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	var f := FileAccess.open(RESULT_ABS, FileAccess.WRITE)
	if f:
		f.store_line("EXIT=%d" % code)
		for l in _log_lines:
			f.store_line(l)
		f.close()
	get_tree().quit(code)
