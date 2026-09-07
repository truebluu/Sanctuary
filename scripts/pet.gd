# Pet — Taming (The Sanctuary)
# Visualizes a single pet from a genetics genome. SANCT-001 + SANCT-186.
# Generates a random genome on spawn, expresses its phenotype, and draws a
# simple creature + a Label listing the expressed traits. The trait values
# drive the sprite tint (element) and a couple of visual flags, proving the
# genome actually controls the creature.
#
# This is a self-contained Area2D (no dependency on the Galage combat scene);
# it is what a "Sanctuary" vertical-slice scene would instance per creature.
extends Node2D

## Element palette map (Harmony-style named colors per element trait).
const ELEMENT_COLORS := {
	"ember":   Color("#FF6B35"),
	"splash":  Color("#38BDF8"),
	"verdant": Color("#4ADE80"),
	"gale":    Color("#C4B5FD"),
	"shiny":   Color("#FFE066"),
}

var genome: Genetics.PetGenome
var _rng := RandomNumberGenerator.new()
var _body: Polygon2D
var _label: Label

func _ready() -> void:
	_rng.randomize()
	genome = Genetics.PetGenome.randomize(_rng,
		Genetics.TRAIT_ALLELES.keys(), ["str", "spd", "res"])
	_build_visual()

func _build_visual() -> void:
	var ph := genome.phenotype(_rng)
	# Tint the body by element (color never carries meaning alone: the label
	# always lists the trait name text too).
	var element: String = str(ph["element"]["name"])
	var is_shiny: bool = ph["element"]["shiny"]
	var color: Color = ELEMENT_COLORS.get(element, Color("#94A3B8"))
	if is_shiny:
		color = ELEMENT_COLORS["shiny"]
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(20, -10), Vector2(26, 12), Vector2(14, 30),
		Vector2(-14, 30), Vector2(-26, 12), Vector2(-20, -10),
	])
	_body.color = color
	add_child(_body)

	# Text summary of every expressed trait.
	_label = Label.new()
	var lines: Array[String] = []
	for t in genome.loci.keys():
		var p: Dictionary = ph[t]
		var line: String = "%s: %s" % [t, p["name"]]
		if p["shiny"]:
			line += " ✨"
		lines.append(line)
	lines.append("str %.2f" % float(genome.stats["str"]))
	_label.text = "\n".join(lines)
	_label.position = Vector2(-120, 40)
	_label.add_theme_font_size_override("font_size", 12)
	add_child(_label)
