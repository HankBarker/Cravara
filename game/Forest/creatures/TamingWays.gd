extends RefCounted
## Pass 13: every beast is won its own way, and Kaya teaches each ("rather
## than just stuffing berries up everybody's butts"). The ways:
##  - hand: food from the hand (dodo, lystro, compy).
##  - calm: come at it at a walk. A keeper who runs up startles it and loses
##    ground (parasaur, protoceratops).
##  - offering: set its food down, back away, let it come to eat (longneck).
##  - sleeping: it only takes food while it sleeps, at night (stego).
##  - stand: stand your ground through its warning once, then feed (trike).
##  - clearing: break the rocks around it while it watches, then feed (anky:
##    it roots for what's under them).
##  - basking: it only eats while it basks in the sun (dimetrodon).
##  - net: net it, then meat before it tears free (raptors, deinonychus).
##  - kin: wear its kin's smell (an armour set), set meat down and back away:
##    it takes you for one of its own (allosaur: the Rustback; Ashmane: the
##    Ashen gear).
##  - respect: strike it and get away unhurt, three times, then feed (rex,
##    Sandblade).
##  - dodge: meet its charge and roll clear, three times, then feed (Scarhorn).
##  - fish: set fish down at the water's edge (Suchomimus, spinosaur).
## The taming tree's lore (Skills.LORE) decides which will take the keeper at all.

const WAYS := {
	"dodo": "hand", "lystro": "hand", "compy": "hand",
	"parasaur": "calm", "proto": "calm",
	"longneck": "offering",
	"stego": "sleeping",
	"trike": "stand",
	"anky": "clearing",
	"dimetrodon": "basking",
	"raptor": "net", "deino": "net",
	"allo": "kin", "yuty": "kin",
	"rex": "respect", "utah": "respect",
	"carno": "dodge",
	"sucho": "fish", "spino": "fish",
}
## The armour set (SetBonus) that carries a beast's kin-smell.
const KIN_SET := {"allo": "rust", "yuty": "ashen"}
const KIN_NAME := {"rust": "the Rustback set", "ashen": "the Ashen gear"}
## Marks (stands, cleared rocks, respect, dodged charges) before it eats from you.
const MARKS := {"trike": 1, "anky": 3, "rex": 3, "utah": 3, "carno": 3}
## Trust one eaten offering is worth.
const OFFER_TRUST := {"longneck": 2, "allo": 3, "yuty": 3, "sucho": 3, "spino": 4}
## Ways where the food is set down, not handed over.
const SET_DOWN := ["offering", "kin", "fish"]
## A keeper this near an offering keeps the beast from coming to it.
const OFFER_SHY := 56.0
## How far a beast sees an offering.
const OFFER_SIGHT := 120.0
## Respect: get this far away within RESPECT_TIME of the blow, unhurt.
const RESPECT_GAP := 170.0
const RESPECT_TIME := 12.0


static func way(species: String) -> String:
	return str(WAYS.get(species, "hand"))


static func marks_needed(species: String) -> int:
	return int(MARKS.get(species, 0))


static func sets_down(species: String) -> bool:
	return way(species) in SET_DOWN


static func food_name(food: String) -> String:
	return {"berry": "berries", "trex_meat": "raw meat", "reed_perch": "fish"}.get(food, food.replace("_", " "))


## The line under a wild beast in the interaction prompt.
static func hint(c) -> String:
	var name := str(c.stats.name)
	var looks: String = preload("res://Forest/creatures/Genes.gd").looks(c.genes)
	if looks != "": name += " (" + looks + ")"
	var reading: String = c.stat_reading()
	if reading != "": name += " · " + reading
	var food := food_name(str(c.stats.food))
	var tally := "Trust %d/%d" % [c.trust, c.feeds_needed()]
	var skills = c.skills()
	if skills and not skills.knows(c.species):
		return "%s · Beyond you: needs %s (Taming)" % [name, skills.lore_needed(c.species)]
	var need := marks_needed(c.species)
	match way(c.species):
		"calm": return "%s · Walk up slowly (no running), then %s · %s" % [name, food, tally]
		"offering": return "%s · E: set %s down, then back away · %s" % [name, food, tally]
		"fish": return "%s · E: set fish down near the water, back away · %s" % [name, tally]
		"kin":
			var worn: bool = c.wearing_kin()
			return "%s · %s · %s" % [name, ("E: set raw meat down, back away" if worn else "Wear %s first" % KIN_NAME.get(KIN_SET.get(c.species, ""), "its kin's smell")), tally]
		"sleeping": return "%s · Feed %s while it sleeps (night) · %s" % [name, food, tally]
		"basking": return "%s · Feed %s while it basks · %s" % [name, food, tally]
		"stand":
			if c.tame_marks < need: return "%s · Let it warn you and stand your ground" % name
		"clearing":
			if c.tame_marks < need: return "%s · Break rocks near it while it watches (%d/%d)" % [name, c.tame_marks, need]
		"respect":
			if c.tame_marks < need: return "%s · Strike it and get away unhurt (%d/%d)" % [name, c.tame_marks, need]
		"dodge":
			if c.tame_marks < need: return "%s · Roll clear of its charge (%d/%d)" % [name, c.tame_marks, need]
		"net":
			return "%s · Net, then %s · %s" % [name, food, tally]
	return "%s · Hand-feed %s · %s" % [name, food, tally]


## Why the beast won't take food from the hand right now ("" when it will).
static func refusal(c) -> String:
	var need := marks_needed(c.species)
	match way(c.species):
		"sleeping":
			if not c.asleep(): return "The stego won't eat while it's watchful. Come back at night, while it sleeps."
		"basking":
			if c.state != "bask": return "It's too cold and sluggish to eat. Try while it basks in the sun."
		"stand":
			if c.tame_marks < need: return "It won't let you near. Let it warn you off, and stand your ground."
		"clearing":
			if c.tame_marks < need: return "It's rooting for grubs. Break the rocks around it while it watches (%d/%d)." % [c.tame_marks, need]
		"respect":
			if c.tame_marks < need: return "It won't eat from a keeper it doesn't respect. Strike it and get away unhurt (%d/%d)." % [c.tame_marks, need]
		"dodge":
			if c.tame_marks < need: return "It yields only to one who meets its charge. Roll clear of it (%d/%d)." % [c.tame_marks, need]
		"kin":
			if not c.wearing_kin(): return "It won't come near a stranger's meat. It trusts the smell of its own kind: wear %s." % KIN_NAME.get(KIN_SET.get(c.species, ""), "its kin's gear")
	return ""


## Kaya's teaching, one line per beast (the journal's "The beasts" page and her advice).
const LESSONS := {
	"dodo": "Berries from your hand. Dodos trust anyone.",
	"lystro": "A berry or two from your hand and it's yours.",
	"compy": "Scraps of raw meat from your hand, but mind the rest of the swarm.",
	"parasaur": "Walk up to a parasaur, never run: a running keeper is a hunter to them. Then berries.",
	"proto": "Same as the parasaur, and slower still: they bolt at a run.",
	"longneck": "A longneck won't eat from a hand. Set berries down, walk away, and let it come to them.",
	"stego": "A stego only lets its guard down asleep. Feed it at night, while it rests.",
	"trike": "Let a trike warn you off and don't give ground. Once you've stood up to it, it takes berries.",
	"anky": "The club-tail roots for grubs under stones. Break the rocks around it while it watches, then berries.",
	"dimetrodon": "Only while it basks. Cold, it bites; warm, it eats.",
	"raptor": "Net it, then raw meat before it tears free. You'll need Pack-lore first.",
	"deino": "The bog's raptors: nets and raw meat, like their cousins. Pack-lore.",
	"allo": "An allosaur trusts its own kind's smell. Wear the Rustback, set meat down and back away. Hunter-lore.",
	"yuty": "The Ashmane hunts beside the Ashen. Wear their gear and set meat down for it. Hunter-lore.",
	"carno": "The Scarhorn yields to one who meets its charge: roll clear of it three times, then meat. Hunter-lore.",
	"utah": "The Sandblade respects nerve. Strike it and get away unhurt, three times, then meat. Hunter-lore.",
	"sucho": "Fish, set down at the water's edge, and back away. Hunter-lore.",
	"rex": "A rex respects nothing but nerve: strike it and get clear unhurt, three times. Then meat, a lot of it. Apex-lore.",
	"spino": "The bog's king eats fish. Set them down by the mere and keep your distance. Apex-lore.",
}
