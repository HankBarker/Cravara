extends RefCounted
## The Sky-Fang Wilds' story, told by what the old peoples left behind. Each
## entry belongs to one point of interest (ForestWorld.lore_at) and is read
## with E; the field journal keeps the ones found (milestones "lore_<id>").

const ENTRIES := {
	"temple": {"title": "The Star Temple",
		"text": "The first builders raised this round temple to watch the sky. When the Sky-Fangs fell, one struck here and split the dome in two. The stair inside still climbs toward it.\nThey called it a blessing. Then the beasts began to change."},
	"statue": {"title": "The Star-God",
		"text": "A figure with its arms raised to the sky. Its eyes are two chips of Sky-Fang crystal.\nThe base is carved: WHAT FALLS FROM THE SKY MUST BE KEPT."},
	"tower": {"title": "The Old Watchtower",
		"text": "Tally marks cover the inner wall: seasons, then herds, then fewer herds.\nThe last lines are cut deep: 'The crystal-backed ones no longer sleep. We go north, past the Pale Hills.'"},
	"hall": {"title": "The Hall of the First Builders",
		"text": "Words run round the arch: a people who built in stone, counted their years by the stars and traded in gold.\nTheir coins still turn up in the soil. A trader who knew their worth would pay for them."},
	"moot": {"title": "The Moot Circle",
		"text": "The old tribe met in this ring to settle quarrels and to choose a Keeper, one who spoke for the beasts.\nThe carved face in the middle wears a crown of the same blue crystal that grows on the rex."},
	"grove": {"title": "The Grove Shrine",
		"text": "Living trees bent into an arch around a single shard. The tribe believed the forest was healing the sky's wound.\nBerries lie at its feet, still fresh. Someone has been here recently."},
	"deer": {"title": "The Deer Idol",
		"text": "It watches over the grazing herds. The tribe tamed the gentle beasts first: feed them from your hand, earn their trust, and they will carry you."},
	"glass_isle": {"title": "The Fishers' Shrine",
		"text": "The fishers of the Mirefen left their catch here for the mere. A carved fin runs round the base, longer than a longneck.\nBelow it: 'The Maw rises for the boats that stay out after dark.'"},
	"buried_king": {"title": "The Kingstone",
		"text": "Here they buried the old king, a beast so great his ribs still stand. The crystal went into his bones, and he does not rest.\n'Wake him only with his own: twelve of his bones, bound with the sky's crystal into a horn. Blow it at his ring, and end him.'"},
	"keeper_journal": {"title": "The Last Keeper's Journal",
		"text": "The pages are water-stained. 'The crystal grows thicker north of the hills, white instead of blue. The beasts there don't sleep at all. I've found the pass, but it's choked with crystal.'\nThe last entry: 'Something falls from the sky every hundred years. It must be kept. I'm going on.'"},
	"pale_road": {"title": "The Pale Waystone",
		"text": "A worn stone at the start of the old road north. The tribe marked the hills with a Keeper's sign: an eye over a falling star.\n'North of here, the Keepers walked alone.'"},
	# Pass 15: the far lands' ruins (a new journey's world).
	"drowned_hall": {"title": "The Drowned Hall",
		"text": "The builders' hall stood on dry ground once. The bog rose around it, a finger's width a year, and they carved each year's water line into the arch.\nThe last line is at a child's height: 'We leave the hall to the mere.'"},
	"sunken_watch": {"title": "The Sunken Watch",
		"text": "A watchtower leaning into the black water. Scratched on its stair: a great fin, drawn again and again, each one bigger than the last."},
	"sand_temple": {"title": "The Sand Temple",
		"text": "The dunes have buried it to the shoulders. Inside, the builders painted the sky as they saw it the night the Sky-Fangs fell: every star a falling one.\n'The old king heard them fall, and woke.'"},
	"buried_arches": {"title": "The Buried Arches",
		"text": "Arches of a market street, sand to their tops. Coins of the first builders turn up in the sand round them, and the Sunward come here to dig."},
	"ash_moot": {"title": "The Ash Moot",
		"text": "A meeting ring grey with ash. The carved face wears no crown here, only a cloth over its mouth.\n'We met to choose who would go north. None came back to say what they found.'"},
	"bone_shrine": {"title": "The Bone Shrine",
		"text": "A shrine of great ribs lashed into an arch, the wolf's face carved on the keystone. The tribe brought the bones of their fiercest hunts here.\nThe newest bones are an allosaur's, and the marks on them are not from any blade."},
	"wolf": {"title": "The Wolf Idol",
		"text": "A guardian carved into a living trunk, facing the raptor lands. The tribe asked it to keep the pack-hunters away.\nThe claw marks on its bark say it did not always work."},
}


## Pages read from something other than a carving (the Last Keeper's journal,
## found at their camp in the Pale Hills): never placed in `lore_at`.
const NOT_CARVED := ["keeper_journal"]
## Carvings only a new journey's world has (pass 15: the far lands' ruins,
## world/RingsGen.gd): an old journey's world never shows them.
const RINGS_ONLY := ["drowned_hall", "sunken_watch", "sand_temple", "buried_arches", "ash_moot", "bone_shrine"]


static func title(id: String) -> String:
	return str(ENTRIES.get(id, {}).get("title", "A weathered carving"))


static func text(id: String) -> String:
	return str(ENTRIES.get(id, {}).get("text", "The marks are too worn to read."))
