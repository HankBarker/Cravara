extends RefCounted
## Young and the wild's needs (pass 11), as data: which species raise young,
## what a baby of each is like, how long an egg takes to hatch and a baby to
## grow, which egg each species lays, and how fast hunger and thirst come on.
## CreatureLife.gd does the living; ForestCreature.gd holds the hooks.

## Species that lay eggs and raise young. The rex and the alpha do not.
const BREEDS := ["dodo", "lystro", "stego", "trike", "longneck", "raptor", "allo", "parasaur"]
## Short names ("Baby Stego", "a stego egg").
const SHORT := {"dodo": "Dodo", "lystro": "Lystro", "stego": "Stego", "trike": "Trike", "longneck": "Longneck", "raptor": "Raptor", "allo": "Allosaur", "parasaur": "Parasaur",
	"dimetrodon": "Dimetrodon", "proto": "Protoceratops", "anky": "Ankylosaur", "carno": "Scarhorn", "yuty": "Ashmane", "compy": "Compy"}
## The egg item each species lays (the dodo's is the one tamed dodos already lay).
const EGG := {"dodo": "dodo_egg", "lystro": "lystro_egg", "stego": "stego_egg", "trike": "trike_egg", "longneck": "longneck_egg", "raptor": "raptor_egg", "allo": "allo_egg", "parasaur": "parasaur_egg"}
## Seconds (real time) an egg takes in a warm incubator.
const HATCH_TIME := {"dodo": 120.0, "lystro": 120.0, "raptor": 240.0, "stego": 300.0, "trike": 300.0, "longneck": 360.0, "allo": 360.0, "parasaur": 300.0}
## Seconds (real time) from hatching to grown.
const GROW_TIME := {"dodo": 360.0, "lystro": 360.0, "raptor": 600.0, "stego": 780.0, "trike": 780.0, "longneck": 900.0, "allo": 840.0, "parasaur": 780.0}
## Seconds for a full belly to go hungry, and for a drink to wear off.
const HUNGER_TIME := {"dodo": 150.0, "lystro": 150.0, "stego": 260.0, "trike": 240.0, "longneck": 300.0, "parasaur": 240.0, "proto": 200.0, "anky": 300.0}
const THIRST_TIME := 320.0
## How close (px) a keeper may come to a wild baby before its kin charge.
const PROTECT := 140.0
## How close (px) a keeper may come to a guarded nest.
const NEST_GUARD := 150.0


static func has_young(species: String) -> bool:
	return species in BREEDS


static func egg_of(species: String) -> String:
	return str(EGG.get(species, ""))


## The species an egg item hatches into ("" if it isn't an egg).
static func species_of_egg(item_id: String) -> String:
	for sp in EGG:
		if EGG[sp] == item_id:
			return sp
	return ""


## A baby's stats from its parent's: a third of the health, no real bite,
## half the size, and a few feeds to tame (the parents are the hard part).
## Babies never hunt, so even a baby raptor takes meat from the hand unnetted.
static func baby_stats(adult: Dictionary, species: String) -> Dictionary:
	var s := adult.duplicate()
	s.name = "Baby " + str(SHORT.get(species, adult.name))
	s.hp = maxi(6, int(round(float(adult.hp) * 0.3)))
	s.damage = maxi(1, int(round(float(adult.damage) * 0.25)))
	s.speed = float(adult.speed) * 0.9
	s.radius = maxf(4.0, float(adult.radius) * 0.55)
	s.feeds = maxi(1, int(ceil(float(adult.feeds) / 4.0)))
	s.predator = false
	s.width = int(round(float(adult.width) * 0.55))
	s.height = int(round(float(adult.height) * 0.55))
	s.boss = false
	return s


## A baby's body: small strides (its clips are drawn half size), light on its
## feet, never armoured, and it nibbles at things.
static func baby_body(adult: Dictionary) -> Dictionary:
	var b := adult.duplicate()
	b.walk = float(adult.walk) * 0.6
	b.run = float(adult.run) * 0.6
	if float(adult.run_at) < 999.0:
		b.run_at = float(adult.run_at) * 0.6
	b.accel = float(adult.accel) * 1.2
	b.armour = false
	b.heavy_steps = false
	b.idle = "eat"
	b.idle_every = 5.0
	return b
