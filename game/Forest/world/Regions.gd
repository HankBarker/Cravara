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
}


static func title(region: String) -> String:
	return str(INFO.get(region, {}).get("name", "The Skyfang Wilds"))


static func blurb(region: String) -> String:
	return str(INFO.get(region, {}).get("blurb", ""))
