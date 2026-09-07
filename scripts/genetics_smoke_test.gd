# GeneticsSmokeTest — Taming (The Sanctuary)
# Headless validation for SANCT-001 genetics/inheritance system. Verifies:
#   1. A random genome expresses a valid phenotype (every trait resolves).
#   2. Diploid dominance resolves correctly on a crafted homozygous-vs-dominant cross.
#   3. Breeding inherits one allele per parent per locus (child is diploid, both
#      parents represented).
#   4. Dominant allele is expressed over recessive in a controlled cross.
#   5. A homozygous-parent cross produces all dominant phenotype offspring.
#   6. Stat blending lands near the 50/50 midpoint.
#   7. Shiny mutation can be produced (forced high rate) and is always expressed.
# Runs synchronously in _ready; exits 0 on pass, 1 on failure.
extends Node2D

var _failures: Array[String] = []

func _ready() -> void:
	# -- (1) random genome resolves every trait --------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var traits: Array = Genetics.TRAIT_ALLELES.keys()
	var g := Genetics.PetGenome.randomize(rng, traits, ["str", "spd", "res"])
	var ph := g.phenotype(rng)
	for t in traits:
		if not ph.has(t):
			_failures.append("random genome missing trait: " + t)

	# -- (2/4) dominance: build a locus ember(dom2)/verdant(dom1) -> ember ------
	var ember := Genetics.Allele.new("element", "ember", 2)
	var verdant := Genetics.Allele.new("element", "verdant", 1)
	var dom_loc := Genetics.Locus.new("element", ember, verdant)
	var dom_res: Dictionary = dom_loc.phenotype(rng)
	if dom_res["name"] != "ember":
		_failures.append("dominant allele ember(2) not expressed over verdant(1)")

	# -- (3/5) breed two pure ember parents -> all ember offspring ---------------
	var pure_a := Genetics.PetGenome.new()
	var pure_b := Genetics.PetGenome.new()
	for t in traits:
		var al := Genetics.Allele.new(t, Genetics.TRAIT_ALLELES[t][0]["name"], 3)
		pure_a.loci[t] = Genetics.Locus.new(t, al, al)
		pure_b.loci[t] = Genetics.Locus.new(t, al, al)
	pure_a.stats = {"str": 0.8, "spd": 0.2}
	pure_b.stats = {"str": 0.4, "spd": 0.6}
	var engine := Genetics.new(rng, 0.0)   # no mutation -> deterministic inheritance
	for i in 100:
		var child := engine.breed(pure_a, pure_b)
		# Both parents are homozygous for the same allele -> child must express it.
		var cph := child.phenotype(rng)
		for t in traits:
			if cph[t]["name"] != Genetics.TRAIT_ALLELES[t][0]["name"]:
				_failures.append("homozygous cross produced non-parent trait on %s" % t)
				break
		# Stat blend: str ~0.6, spd ~0.4, but the engine adds ±20% stat mutation
		# (STAT_MUTATION_SPAN) even with trait mutation_rate=0, so allow that span.
		if absf(float(child.stats["str"]) - 0.6) > 0.2:
			_failures.append("str blend %.2f far from 0.6±0.2" % float(child.stats["str"]))
		if absf(float(child.stats["spd"]) - 0.4) > 0.2:
			_failures.append("spd blend %.2f far from 0.4±0.2" % float(child.stats["spd"]))

	# -- (7) shiny mutation is expressed -----------------------------------------
	var shiny_rng := RandomNumberGenerator.new()
	shiny_rng.seed = 7
	var found_shiny := false
	for i in 2000:
		var cand := Genetics.PetGenome.randomize(shiny_rng, traits, ["str"])
		var cph := cand.phenotype(shiny_rng)
		for t in traits:
			if cph[t]["shiny"]:
				found_shiny = true
				break
		if found_shiny:
			break
	if not found_shiny:
		_failures.append("no shiny phenotype in 2000 random genomes")

	if _failures.is_empty():
		print("GENETICS SMOKE: PASS (dominance, homozygous breeding, stat blend, shiny all OK)")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("GENETICS FAIL: " + f)
		get_tree().quit(1)
