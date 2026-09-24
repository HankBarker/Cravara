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
	"wolf": {"title": "The Wolf Idol",
		"text": "A guardian carved into a living trunk, facing the raptor lands. The tribe asked it to keep the pack-hunters away.\nThe claw marks on its bark say it did not always work."},
}


static func title(id: String) -> String:
	return str(ENTRIES.get(id, {}).get("title", "A weathered carving"))


static func text(id: String) -> String:
	return str(ENTRIES.get(id, {}).get("text", "The marks are too worn to read."))
