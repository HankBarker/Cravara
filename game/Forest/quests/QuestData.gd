extends RefCounted
## The folk's tasks (pass 11), in the order each gives them. Each giver offers
## one at a time; the next opens when the last is handed in.
##
## goals: {"type", ...}
##   have (id, count, take): items in the satchel (taken on hand-in if take)
##   craft (id, count) · lore (count: carvings read) · house (a home stands)
##   defeat (id: species) · region (id) · bones (count: bone heaps searched)
##   egg (count: taken from nests) · hatch · grow (babies raised) · dig · fish
##   tame (ids: species, count)
## Everything done before a task is taken counts too (the keeper's tallies).
## needs: "region:ID" / "species:ID" / "item:ID" the world must have first
## (tasks for places not yet in the wilds stay hidden).
## reward: {item id: count} ("ancient_coin" is money).

const QUESTS := [
	# Orrin, the Wayfinder: the land, its story, and the way on.
	{"id": "guide_tools", "giver": "guide", "title": "Better tools",
		"ask": "Those stone tools won't last. Sky-Fang crystal grows in the rock hereabouts: mine a few shards and make yourself a crystal pickaxe at the workbench.",
		"done": "Now that's a Keeper's pickaxe. Here, torches: the nights are long out here.",
		"goals": [{"type": "craft", "id": "crystal_pickaxe", "count": 1}], "reward": {"torch": 4, "ancient_coin": 3}},
	{"id": "guide_carvings", "giver": "guide", "title": "What the old ones left",
		"ask": "The first builders carved their story into the ruins. Read three of their carvings (E on the stones) and you'll know this land better than I do.",
		"done": "You see it now. The Sky-Fangs, the tribe, the Keepers. You're part of that story whether you like it or not.",
		"goals": [{"type": "lore", "count": 3}], "reward": {"ancient_coin": 6}},
	{"id": "guide_home", "giver": "guide", "title": "Four walls and a roof",
		"ask": "Folk won't settle where there's no shelter. Build a proper house: walls all round, a door, a roof over every tile, a torch and a bed.",
		"done": "A real home! Word travels in the wilds. You'll have neighbours before long.",
		"goals": [{"type": "house", "count": 1}], "reward": {"torch": 6, "ancient_coin": 5}},
	{"id": "guide_alpha", "giver": "guide", "title": "The Shardback's den",
		"ask": "The raptors answer to something big in the north-east. Skarn, the old tribe called it. Until it falls, nowhere's safe. It's marked red on your map.",
		"done": "Skarn, down! The packs will scatter now. The tribe would have sung about this for a month.",
		"goals": [{"type": "defeat", "id": "alpha", "count": 1}], "reward": {"ancient_coin": 15, "prism_crystal": 2}},
	{"id": "guide_bonelands", "giver": "guide", "title": "Where the bones lie",
		"ask": "East, past the forest's edge, the crystal took the bones of the old world. Walk the Bonelands and search three bone heaps. See what the sky left behind.",
		"done": "Crystal in the marrow of bones older than the tribe. Something out there was buried, not just dead. Keep your eyes open.",
		"goals": [{"type": "region", "id": "bonelands", "count": 1}, {"type": "bones", "count": 3}], "reward": {"ancient_coin": 10}},
	{"id": "guide_glassmere", "giver": "guide", "title": "The water to the west", "needs": "region:glassmere",
		"ask": "West of here the land sinks into the Mirefen: bog and black water, and at its heart a mere as deep as a well. Go and see it, and mind what swims there.",
		"done": "You saw the islands? The tribe fished from boats out there, once. Maybe you can too.",
		"goals": [{"type": "region", "id": "glassmere", "count": 1}], "reward": {"ancient_coin": 8}},
	{"id": "guide_sunward", "giver": "guide", "title": "The Sunward", "needs": "region:dunes",
		"ask": "There are people in the dunes: nomads, the old tribe's cousins. They call themselves the Sunward. Find their oasis and talk to their trader. Don't draw a blade on them.",
		"done": "Traders! Then we're not alone out here. Keep on their good side.",
		"goals": [{"type": "visit", "id": "sunward_oasis", "count": 1}], "reward": {"ancient_coin": 10}},
	{"id": "guide_ashen", "giver": "guide", "title": "The Ashen", "needs": "milestone:alpha",
		"ask": "Raiders came down out of the ash and burned a fisher's camp. The Ashen, they call themselves: skull masks, tamed raptors. Their war camp is in the Pale Lands' east. Bring down their chief.",
		"done": "Their chief, fallen. They'll think twice before they come south again. For a while.",
		"goals": [{"type": "visit", "id": "ashen_chief", "count": 1}], "reward": {"ancient_coin": 25, "trex_scale": 2}},
	{"id": "guide_king", "giver": "guide", "title": "The Buried King", "needs": "species:ossuar",
		"ask": "The desert carvings speak of a king of bones, bound with crystal and buried under the sand. The tribe called him Ossuar. They say he wakes if you call him with his own bones. I'd rather he didn't.",
		"done": "Ossuar, laid to rest for good. The bones will sleep easier now. So will I.",
		"goals": [{"type": "defeat", "id": "ossuar", "count": 1}], "reward": {"ancient_coin": 25, "prism_crystal": 4}},
	{"id": "guide_north", "giver": "guide", "title": "Into the ash", "needs": "region:pale_hills",
		"ask": "The last Keeper went north, into the Pale Lands, where the ash falls from the burning mountain. No one's seen them since. Cover your face out there. If anyone can find where they went, it's you.",
		"done": "Their camp, still standing... and their journal. Whatever they found up there, it's waiting for you now.",
		"goals": [{"type": "region", "id": "pale_hills", "count": 1}, {"type": "visit", "id": "keeper_camp", "count": 1}], "reward": {"ancient_coin": 20}},

	# Tamsin, the Trader: go out, bring things back.
	{"id": "trader_fossils", "giver": "trader", "title": "Bones of the old world",
		"ask": "Collectors pay a fortune for fossil bones. Dig up relic mounds with a hoe, or pick through bone heaps, and bring me three.",
		"done": "Beautiful. Well, beautifully old. Here's your cut.",
		"goals": [{"type": "have", "id": "fossil_bone", "count": 3, "take": true}], "reward": {"ancient_coin": 12}},
	{"id": "trader_shards", "giver": "trader", "title": "Shards for the market",
		"ask": "Sky-Fang crystal sells in every market from here to the coast. Ten shards, and I'll pay you better than I pay anyone. Don't tell anyone.",
		"done": "Ten shards, ten little stars. Pleasure doing business.",
		"goals": [{"type": "have", "id": "crystal_shard", "count": 10, "take": true}], "reward": {"ancient_coin": 10}},
	{"id": "trader_bones", "giver": "trader", "title": "A cartload of bones",
		"ask": "There's a bone-carver who'll buy anything from the Bonelands. Twelve old bones from the heaps out east. Big ones.",
		"done": "My poor pack-stego would have loved to carry these. Your coin.",
		"goals": [{"type": "have", "id": "old_bone", "count": 12, "take": true}], "reward": {"ancient_coin": 12}},
	{"id": "trader_fangs", "giver": "trader", "title": "Fangs on a string",
		"ask": "Raptor fangs make lovely necklaces. Lovely, expensive necklaces. Four of them, please.",
		"done": "Fresh! Well, fresh-ish. Here, and keep your fingers.",
		"goals": [{"type": "have", "id": "raptor_fang", "count": 4, "take": true}], "reward": {"ancient_coin": 14}},
	# Pass 12: the Sunward, the Ashen, the dunes' beasts.
	{"id": "trader_scales", "giver": "trader", "title": "Sail-scale", "needs": "item:sail_scale",
		"ask": "The sail-backs in the dunes lie on the warm stones all morning. Their sail-scales hold the sun, they say. Bring me three and I'll show you what a gardener does with them.",
		"done": "Still warm! Here: the pattern for a Sun Sail, and a little something for the walk.",
		"goals": [{"type": "have", "id": "sail_scale", "count": 3, "take": true}], "reward": {"ancient_coin": 12, "sun_sail": 1}},
	{"id": "trader_pearls", "giver": "trader", "title": "Mirefen pearls", "needs": "item:glass_pearl",
		"ask": "The clams on the Mirefen's islands grow pearls, clear as glass for all the black water. You'll need a boat to reach them. Three pearls and I'll make it worth the trip.",
		"done": "Clear as glass! These will fetch a small fortune. Well, a medium fortune. For you: coin.",
		"goals": [{"type": "have", "id": "glass_pearl", "count": 3, "take": true}], "reward": {"ancient_coin": 20}},
	{"id": "trader_cactus", "giver": "trader", "title": "Fruit of the dunes", "needs": "item:cactus_fruit",
		"ask": "Down in the southern dunes the cacti fruit red as embers. Sweet as honey, and nobody sells them. Five, please.",
		"done": "Mm! Sticky. Worth every coin. Here.",
		"goals": [{"type": "have", "id": "cactus_fruit", "count": 5, "take": true}], "reward": {"ancient_coin": 12}},
	{"id": "trader_tooth", "giver": "trader", "title": "A tooth from the deep", "needs": "item:maw_tooth",
		"ask": "Fishermen swear there's a monster in the Mirefen's deep mere. Big as a longneck, all teeth. Bring me one of those teeth and I'll believe it.",
		"done": "It's... real. And it's the size of my hand. Here, take all of this before I faint.",
		"goals": [{"type": "have", "id": "maw_tooth", "count": 1, "take": true}], "reward": {"ancient_coin": 30}},
	{"id": "trader_chalk", "giver": "trader", "title": "Pale crystal", "needs": "item:pale_crystal",
		"ask": "Up in the Pale Hills the crystal grows white, not blue. Nobody's ever brought any down. Three pieces and you'll be the first.",
		"done": "White Sky-Fang. I've never seen it. Nobody has. Name your price. No, wait, I'll name it.",
		"goals": [{"type": "have", "id": "pale_crystal", "count": 3, "take": true}], "reward": {"ancient_coin": 25}},

	# Kaya, the Beast-Warden: taming, eggs and young.
	{"id": "warden_lystro", "giver": "warden", "title": "A gentle start",
		"ask": "Let's see your hands with a beast. Lystrosaurs are the gentlest things out there: a berry or two and they're yours. Tame one.",
		"done": "Look at it, following you about! That's the start of everything.",
		"goals": [{"type": "tame", "ids": ["lystro"], "count": 1}], "reward": {"berry": 10, "ancient_coin": 3}},
	{"id": "warden_egg", "giver": "warden", "title": "Egg thief",
		"ask": "Every beast nests somewhere. Find a nest, take one egg, and don't stop running till its parents give up. Then bring me the tale.",
		"done": "You're still in one piece! Here: an incubator. Set the egg in it and keep it warm.",
		"goals": [{"type": "egg", "count": 1}], "reward": {"incubator": 1}},
	{"id": "warden_hatch", "giver": "warden", "title": "New life", "needs": "milestone:alpha",
		"ask": "Put an egg in a warm incubator, a fire or torch close by, and wait. A baby that hatches in your care thinks you're its mother.",
		"done": "A hatchling! Keep it fed and close. They grow up faster than you'd think.",
		"goals": [{"type": "hatch", "count": 1}], "reward": {"ancient_coin": 8, "berry": 10}},
	{"id": "warden_patient", "giver": "warden", "title": "Patient hands",
		"ask": "The big grazers take patience. Twenty berries, one at a time, stepping back between. Tame a stego, a trike or a longneck.",
		"done": "That's real patience. Most folk get a tail to the face.",
		"goals": [{"type": "tame", "ids": ["stego", "trike", "longneck"], "count": 1}], "reward": {"ancient_coin": 10}},
	{"id": "warden_raptor", "giver": "warden", "title": "The netted hunter",
		"ask": "Now the hard one. Net a raptor, and feed it meat while it's down. Mind its packmates.",
		"done": "A Shardback that trusts you. The old Keepers rode out with packs of them.",
		"goals": [{"type": "tame", "ids": ["raptor"], "count": 1}], "reward": {"net": 4, "ancient_coin": 8}},
	{"id": "warden_grow", "giver": "warden", "title": "Raised by hand", "needs": "milestone:alpha",
		"ask": "Raise a baby to full size. Hatch one, or win over a wild one, if you dare get past its mother.",
		"done": "All grown up. You'll never have a more loyal beast than one you raised.",
		"goals": [{"type": "grow", "count": 1}], "reward": {"ancient_coin": 15}},
	{"id": "warden_parasaur", "giver": "warden", "title": "Down by the water", "needs": "species:parasaur",
		"ask": "Parasaurs graze the edges of the Mirefen. Listen for them: they trumpet through those crests. Tame one and it'll warn you when a hunter's near.",
		"done": "Hear that call? That's the best alarm in the wilds.",
		"goals": [{"type": "tame", "ids": ["parasaur"], "count": 1}], "reward": {"ancient_coin": 12}},
	{"id": "warden_sand", "giver": "warden", "title": "Sand and sun", "needs": "region:dunes",
		"ask": "The dunes have beasts of their own. A frill-headed protoceratops, or a sail-backed dimetrodon if you've the nerve. Tame one and bring it home.",
		"done": "A beast of the sand. Watch it: it knows things about that desert we don't.",
		"goals": [{"type": "tame", "ids": ["proto", "dimetrodon"], "count": 1}], "reward": {"ancient_coin": 12}},
	{"id": "warden_allo", "giver": "warden", "title": "Rust and patience",
		"ask": "An allosaur. Net it, feed it, don't die. If you can tame one of those, you can tame anything out there.",
		"done": "A Rustback at your side. I'd say I'm not jealous, but I'd be lying.",
		"goals": [{"type": "tame", "ids": ["allo"], "count": 1}], "reward": {"ancient_coin": 20}},
]


static func by_id(id: String) -> Dictionary:
	for q in QUESTS:
		if q.id == id: return q
	return {}


static func for_giver(giver: String) -> Array:
	return QUESTS.filter(func(q): return q.giver == giver)
