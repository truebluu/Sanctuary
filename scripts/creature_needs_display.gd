# CreatureNeedsDisplay — Sanctuary (Bluu Ink Studios)
# SANCT-141 Creature needs system — visual indicator.
# A simple HUD panel that renders one colored bar per need (hunger/trust/energy/
# social). Each bar is a ColorRect whose width scales with the need value.
# Attach to the same tree as the CreatureNeeds node (or call refresh()).
extends Node2D

@export var bar_width: float = 120.0
@export var bar_height: float = 12.0
@export var bar_gap: float = 4.0
@export var row_gap: float = 6.0

var _bars: Dictionary = {}
var _need: CreatureNeeds

const NEED_ORDER: Array[StringName] = [&"hunger", &"trust", &"energy", &"social"]
const NEED_COLORS: Dictionary = {
	&"hunger": Color("ef4444"),   # red
	&"trust": Color("8b5cf6"),    # violet
	&"energy": Color("eab308"),   # yellow
	&"social": Color("22c55e"),   # green
}

func setup(need: CreatureNeeds) -> void:
	_need = need
	if _need:
		_need.need_changed.connect(_on_need_changed)
	_build()

func _build() -> void:
	for i in range(NEED_ORDER.size()):
		var which: StringName = NEED_ORDER[i]
		var row := ColorRect.new()
		row.color = Color(0, 0, 0, 0.4)
		row.position = Vector2(0, i * (bar_height + row_gap))
		row.size = Vector2(bar_width, bar_height)
		add_child(row)
		var fill := ColorRect.new()
		fill.name = String(which)
		fill.position = Vector2(0, 0)
		fill.size = Vector2(bar_width, bar_height)
		fill.color = Color(NEED_COLORS[which])
		row.add_child(fill)
		_bars[which] = fill

func _on_need_changed(which: StringName, value: float) -> void:
	var fill: ColorRect = _bars.get(which)
	if fill:
		fill.size.x = bar_width * value

## Draw current values once (in case _need was set before build).
func refresh() -> void:
	if _need:
		for which in NEED_ORDER:
			_on_need_changed(which, float(_need.need_values[which]))
