extends RefCounted
## The regions of the Skyfang Wilds (pass 10-11): what each is called on the
## HUD and the map, and the words that greet a keeper there the first time.
## ForestWorld.region_of(cell) says which one a cell is in.

const INFO := {
	"forest": {"name": "The Skyfang Wilds", "blurb": "", "map": Color("386153")},
	"bonelands": {"name": "The Bonelands", "blurb": "Where the crystal took the bones of the old world.", "map": Color("9a8458")},
	# Pass 12: Glassmere became the Mirefen Bog (Hank's direction).
	"glassmere": {"name": "The Mirefen Bog", "blurb": "Black water, reeds and mud. Something moves under the surface.", "map": Color("4a6448")},
	"dunes": {"name": "The Sunscar Dunes", "blurb": "Sand, sun and the old king's grave.", "map": Color("b89a5e")},
	# Pass 12: pale with the ash that falls from the mountain beyond.
	"pale_hills": {"name": "The Pale Lands", "blurb": "Ash falls here like snow, from the mountain beyond. Nothing sings.", "map": Color("a8a39a")},
	# Pass 15: underground (each cave names itself as the keeper goes in).
	"caves": {"name": "Underground", "blurb": "", "map": Color("2a2830")},
}


static func title(region: String) -> String:
	return str(INFO.get(region, {}).get("name", "The Skyfang Wilds"))


## Which way a land lies from camp ("north-east"): a ring world turns its
## lands the way its seed says (pass 15), the old world had them fixed.
const OLD_WAYS := {"glassmere": "west", "dunes": "south", "pale_hills": "north", "bonelands": "east", "forest": "here"}
const COMPASS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
static func way_to(region: String, world) -> String:
	var layout = world.get("layout") if world else null
	if layout == null or not layout.is_rings(): return str(OLD_WAYS.get(region, "out"))
	if region == "forest": return "here"
	var a := wrapf(float(layout.angles.get(region, 0.0)), 0.0, TAU)
	return COMPASS[int(round(a / (TAU / 8.0))) % 8]

## Words with the lands' ways in them: "{dir:glassmere}" -> "west", "{Dir:dunes}" -> "South".
static func say(text: String, world) -> String:
	if not "{" in text: return text
	for region in INFO:
		var way := way_to(region, world)
		text = text.replace("{dir:%s}" % region, way).replace("{Dir:%s}" % region, way.capitalize())
	return text


static func blurb(region: String) -> String:
	return str(INFO.get(region, {}).get("blurb", ""))
