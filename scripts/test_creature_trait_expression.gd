# CreatureTraitExpressionSmokeTest — Taming (The Sanctuary)
# Headless validation harness for CreatureTraitExpression.
# Asserts: set/get traits, trait_names, expression_level, describe, reset, clamping.
# Writes results then quits 0/1.
extends Node2D

const RESULT_ABS := "C:/Users/bluue/Documents/Galage/creature_trait_expression_smoke_result.txt"

var _failures: Array[String] = []

func _ready() -> void:
	_run()
	_quit()

func _run() -> void:
	var expression: CreatureTraitExpression = CreatureTraitExpression.new()
	
	## Set test traits
	expression.set_trait("boldness", 0.9)
	expression.set_trait("affection", 0.2)
	
	## Test get_trait
	var boldness_val: float = expression.get_trait("boldness")
	var affection_val: float = expression.get_trait("affection")
	var unknown_val: float = expression.get_trait("unknown_trait")
	
	_check(boldness_val == 0.9, "boldness should be 0.9")
	_check(affection_val == 0.2, "affection should be 0.2")
	_check(unknown_val == 0.0, "unknown trait should return 0.0")
	
	## Test trait_names
	var names: Array[StringName] = expression.trait_names()
	_check(names.has("boldness"), "trait_names should contain boldness")
	_check(names.has("affection"), "trait_names should contain affection")
	_check(names.size() == 2, "trait_names should have 2 entries")
	
	## Test expression_level - weighted average of 0.9 and 0.2 with equal weights = 0.55
	var level: float = expression.expression_level()
	_check(level >= 0.54 and level <= 0.56, "expression_level should be ~0.55, got " + str(level))
	
	## Test describe returns non-empty string
	var desc: String = expression.describe()
	_check(desc.length() > 0, "describe() should return non-empty string")
	_log("describe() returned: " + desc)
	
	## Test reset
	expression.reset()
	_check(expression.trait_names().is_empty(), "reset should clear traits")
	_check(expression.expression_level() == 0.0, "reset should make expression_level 0.0")
	
	## Test clamping in set_trait
	expression.set_trait("test_clamp_high", 1.5)
	expression.set_trait("test_clamp_low", -0.5)
	_check(expression.get_trait("test_clamp_high") == 1.0, "clamp high should be 1.0")
	_check(expression.get_trait("test_clamp_low") == 0.0, "clamp low should be 0.0")

func _check(cond: bool, msg: String) -> void:
	if cond:
		_log("PASS: " + msg)
	else:
		_failures.append(msg)
		_log("FAIL: " + msg)

func _log(msg: String) -> void:
	print(msg)
	var f := FileAccess.open(RESULT_ABS, FileAccess.WRITE_READ)
	if f != null:
		f.seek_end()
		f.store_line(msg)
		f.close()

func _quit() -> void:
	var code := 1
	if _failures.is_empty():
		_log("CREATURE TRAIT EXPRESSION SMOKE: ALL PASS")
		code = 0
	else:
		_log("CREATURE TRAIT EXPRESSION SMOKE: %d FAILURES" % _failures.size())
	var f := FileAccess.open(RESULT_ABS, FileAccess.WRITE_READ)
	if f != null:
		f.seek_end()
		f.store_line("EXIT=%d" % code)
		f.close()
	get_tree().quit(code)