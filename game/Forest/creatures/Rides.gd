extends RefCounted
## Pass 18: every beast a keeper can ride, and how (Hank: "with the dinosaurs
## that we have, I want to make sure that we have the capability to tame and
## then ride them. Allosaurus, T-Rex, Bronto... you should be able to ride
## basically every major dino that we've added").
##
## A ridden beast wears its saddled clips: the stego's and the trike's drawn by
## PixelLab, the rest a saddle painted onto their own clips
## (tools/dino/saddle_paint.py), the rider following its seat frame by frame
## (MountedAppearance). Each has its pace under a rider, and the strike its
## rider can make (one of its own moves, DinoMoves). The hunters' saddles need
## the hide of Grimjaw, the bog's old croc (CraftingManager: hidden until
## "grimjaw"). A pteranodon flies (MountController: Space up and down, E over
## the jungle to rise into the treetops or dive back down).

const RIDES := {
	# speed: walking pace under a rider (px/s; the sprint is SPRINT times it);
	# move: the rider's strike (a DinoMoves id); cooldown (s); damage: the
	# strike's (the beast's own damage times DAMAGE if not set);
	# hunter: its saddle needs Grimjaw's hide; fly_speed: on the wing.
	"stego": {"speed": 50.0, "move": "tail", "cooldown": 1.15, "damage": 18},
	"trike": {"speed": 62.0, "move": "gore", "cooldown": 0.95, "damage": 22},
	"longneck": {"speed": 46.0, "move": "stomp", "cooldown": 1.6},
	"parasaur": {"speed": 72.0, "move": "stomp", "cooldown": 1.2},
	"anky": {"speed": 44.0, "move": "tail", "cooldown": 1.3},
	"dimetrodon": {"speed": 54.0, "move": "bite", "cooldown": 1.1, "hunter": true},
	"raptor": {"speed": 80.0, "move": "slash", "cooldown": 0.8, "hunter": true},
	"deino": {"speed": 78.0, "move": "slash", "cooldown": 0.8, "hunter": true},
	"utah": {"speed": 82.0, "move": "slash", "cooldown": 0.85, "hunter": true},
	"thyla": {"speed": 76.0, "move": "maul", "cooldown": 0.9, "hunter": true},
	"allo": {"speed": 70.0, "move": "bite", "cooldown": 1.0, "hunter": true},
	"carno": {"speed": 78.0, "move": "bite", "cooldown": 1.0, "hunter": true},
	"yuty": {"speed": 70.0, "move": "bite", "cooldown": 1.05, "hunter": true},
	"rex": {"speed": 66.0, "move": "bite", "cooldown": 1.1, "hunter": true},
	"sucho": {"speed": 60.0, "move": "bite", "cooldown": 1.05, "hunter": true},
	"spino": {"speed": 62.0, "move": "bite", "cooldown": 1.1, "hunter": true},
	"ptera": {"speed": 56.0, "move": "bite", "cooldown": 1.0, "fly_speed": 132.0},
}
const SPRINT := 1.55
## A ridden strike's damage: the beast's own, a little less (a rider aims it).
const DAMAGE := 0.85
## A flyer's height with a rider on it (px).
const RIDE_ALT := 40.0


static func can_ride(species: String) -> bool:
	return RIDES.has(species)


static func of(species: String) -> Dictionary:
	return RIDES.get(species, {})


static func flies(species: String) -> bool:
	return RIDES.get(species, {}).has("fly_speed")


## The saddle a species wears (its item id).
static func saddle_id(species: String) -> String:
	return species + "_saddle"
