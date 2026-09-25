extends RefCounted
## The folk of the Skyfang Wilds: who they are, when they come, where they are
## found and what they say. Data only (FolkManager runs it, FolkActor walks it,
## FolkDialogue speaks it).
##
## arrives   "start": beside the keeper on a new journey (never found).
##           "cache": after the first ancient cache is opened.
##           "tames:N": after N dinosaurs trust you.
## found     where they may turn up once they arrive, one picked per world:
##           "hut" their own little house, "stranded" a cold camp beside
##           whatever they lost, "caged" an old tribe's beast-trap (free them).
## services  the dialogue's extra pages: "recipes" (what can I make with...),
##           "trade" (buy and sell for ancient coins), "advice", "tend".

const CAST := {
	"guide": {
		"name": "Orrin", "title": "The Wayfinder", "arrives": "start", "found": [],
		"services": ["help", "recipes", "lore"],
		# The first meeting, when the keeper walks out of the tent on a new
		# journey (after the opening): he saw them fall.
		"intro": [
			"Easy, easy. You're awake. You slept the whole day through.",
			"I saw you come down last night. A light fell past the ridge, bright as a Sky-Fang, and when I got there you were lying by the old shrine north of camp. The crystal was humming like a struck bell.",
			"The old carvings say what falls from the sky must be kept. Maybe that means you. Or maybe you're the one meant to do the keeping. A Keeper.",
			"There's not been a Keeper since the last one went north, past the Pale Hills. The wilds have waited a long while.",
			"I'm Orrin. I find the way; it's all I've ever been good for. This was the old tribe's first camp. It's yours now, if you want it.",
			"Timber first: take your axe to a tree, then build yourself a workbench. And come and find me whenever you're lost.",
		],
		"greet": [
			"Ah, you're awake. The wilds have waited a long while for a new Keeper.",
			"Mind the long grass after dusk. Raptors hunt by the rustle.",
			"Every ruin out there bears a carving. Read them, and the forest starts to make sense.",
			"Back again? Good. A Keeper who listens lives longer.",
		],
		"chat": [
			"I walked these paths before the crystals grew so thick. The beasts were smaller then. Gentler.",
			"The first builders cut stone like cheese. Their walls still stand; ours rot in ten winters.",
			"Stone keeps the damp out and the raptors off. Timber's fine for a start.",
			"When the Sky-Fangs fell, the old tribe didn't flee. They listened. You'd do well to do the same.",
			"A trader always turns up where there's coin to be had. Open one of those old caches and see.",
			"Tame a few beasts and the warden will hear of it. She can't resist a good dinosaur.",
		],
		"lore": [
			"The Sky-Fangs fell in one night, like hail made of stars. Where they struck, crystal grew.",
			"The first builders raised temples to watch the sky. They wanted to know if more would fall.",
			"The old tribe chose a Keeper to speak for the beasts. The last one vanished north, past the Pale Hills.",
			"The crystal grows in the beasts' bones now. That's why the rex glows blue in the dark.",
		],
	},
	"merchant": {
		"name": "Tamsin", "title": "The Trader", "arrives": "cache", "found": ["stranded", "hut"],
		"services": ["trade"],
		"lost": "cart",
		"greet": [
			"A customer! Coin in hand, I hope. Ancient coin, mind. That's the only money that doesn't rot out here.",
			"Tamsin's goods: fair prices, fairer than the rex offers.",
			"Browse all you like. Touch the lantern and you've bought it.",
		],
		"found_line": {
			"stranded": "Oh, thank the stars! A rex roared, my pack-stego bolted, and my cart went with it. If you've a roof to spare, I've goods to trade.",
			"hut": "A visitor, way out here? I built this hut to wait out the rains, but I'd much rather trade by a proper camp.",
		},
		"ready_line": "Build me a proper house by your camp: walls, a door, a roof, a torch and a bed. I'll bring the goods.",
		"chat": [
			"I once swapped a lantern for a raptor egg. Never again. It hatched in my pack.",
			"Stone houses keep the damp out of my silk. Just saying.",
			"Fossil bones, sky idols, crystal: bring me the old things and I'll make you rich in coin.",
			"The first builders stamped a falling star on every coin. Superstitious lot. Good for business.",
		],
	},
	"warden": {
		"name": "Kaya", "title": "The Beast-Warden", "arrives": "tames:2", "found": ["caged", "hut", "stranded"],
		"services": ["advice", "tend", "trade"],
		"lost": "trap",
		"greet": [
			"You're the one the beasts trust? Show me your companions. I want to see everything.",
			"Good timing. I was just about to go and sit on a trike.",
			"Ask me anything about dinosaurs. Anything. I mean it.",
		],
		"found_line": {
			"caged": "Don't laugh. I followed a raptor pack straight into an old tribal trap. Get me out and I'll teach you everything I know about beasts.",
			"hut": "Shh! There's a stego grazing just past the ferns. Oh, you're the Keeper. I've heard about your companions.",
			"stranded": "My tamed trike wandered off in the night and took my supplies with her. Some warden I am.",
		},
		"ready_line": "I'd like to live near your beasts. A house with walls, a door, a roof, a torch and a bed, and I'm yours.",
		"chat": [
			"A trike charges when it's scared. Stand beside it, never in front.",
			"Longnecks hum at dusk. I think they're counting each other.",
			"Raptors test you. Hold your ground, net the leader, and the pack thinks twice.",
			"A stego's tail cuts deep. Bandage fast, or you'll bleed out on the trail.",
		],
	},
}

## What the warden knows of each beast ([food, how to earn trust, riding]).
const BEASTS := {
	"parasaur": ["Berries", "Eighteen berries, stepping back between. They graze the Mirefen's edges in herds and trumpet when a hunter comes.", "Too skittish to ride, but one at your side warns you of hunters."],
	# Pass 12.
	"dimetrodon": ["Meat", "Net it first; then meat, stepping back between. Go by day, when it's warm and slow to anger.", "Too low to ride, but its sail gathers the sun: your crops grow faster by day."],
	"protoceratops": ["Berries", "A few berries; the herd bolts, so come at them slowly.", "Too small to ride. On sand it noses up old bones, fossils and coins."],
	"ankylosaur": ["Berries", "Two dozen berries, stepping back between. Its plates shrug off light blows; don't make it angry.", "Not for riding, but beside you its club cracks stone: more from every rock and vein you mine, and it stands guard."],
	"scarhorn": ["Meat", "A net, then meat and patience. It's the fastest hunter in the dunes: don't run from it.", "Not yet ridden. At your side you sprint faster."],
	"ashmane": ["Meat", "A net, then meat and patience, in the ash of the Pale Lands.", "Not yet ridden. With one at your side the ash can't reach you."],
	"dodo": ["Berries", "Offer berries from your hand. Dodos trust quickly and lay eggs at home.", "Too small to ride. Set them to work and they'll gather for you."],
	"lystro": ["Berries", "A berry or two and it's yours. Lystrosaurs are the friendliest things in the wilds.", "Too small to ride, but it'll follow you anywhere."],
	"stego": ["Berries", "Twenty berries and a lot of patience. Feed it, then step well back and let it settle before the next. Crowd it and that tail comes round.", "Fit a stego saddle (workbench). Steady, strong, and its tail swing bleeds foes."],
	"trike": ["Berries", "Twenty berries, one at a time, with room between. Hang about and it charges, so feed and step away.", "Fit a trike saddle. Click to gore; hold to charge a ram that bowls foes over."],
	"longneck": ["Berries", "Two dozen berries and the patience of stone. It spooks easily but never forgets a friend.", "Too tall for any saddle yet made."],
	"raptor": ["Raw meat", "Net it and it goes down. Feed it raw meat before it tears free: about fifteen bites, so bring nets. Net the leader and the pack scatters.", "No saddle fits a raptor. It fights beside you instead."],
	"allo": ["Raw meat", "A big hunter, and it tears nets fast. Net it, feed it, net it again. Its crystal scales make the finest armour, if you'd rather fight it.", "No saddle for an allosaurus. Yet."],
	"rex": ["Raw meat", "Nobody tames a rex. It'd take forty bites and every net you own. Don't fight it alone either: bring beasts and arrows.", "Rex saddles are the stuff of legend."],
	"alpha": ["Nothing", "Skarn leads the Shardback pack from its den in the north-east. It won't take food. It takes keepers.", "Beat it and the pack loses its nerve."],
}

## The trader's goods: id -> [price in ancient coins, how many per purchase].
const STOCK := {
	"merchant": {"berry_seed": [2, 3], "mushroom_spore": [2, 2], "net": [3, 1], "bone_arrow": [4, 10], "torch": [2, 3], "lantern": [12, 1], "crystal_flask": [6, 1], "garden_hoe": [5, 1], "fishing_rod": [6, 1], "cooked_meat": [3, 2]},
	"warden": {"net": [3, 2], "stego_saddle": [18, 1], "trike_saddle": [22, 1], "berry": [1, 4], "trex_meat": [2, 1]},
}
## Rarer wares that turn up one or two at a time, a new pick each day.
const RARE := {"merchant": {"hunter_charm": 20, "crystal_pendant": 25, "river_totem": 25, "mushroom_potion": 8, "prism_crystal": 6}}
## What the trader pays (ancient coins each).
const BUYS := {"fossil_bone": 4, "sky_idol": 15, "crystal_shard": 1, "prism_crystal": 4, "trex_scale": 6, "raptor_fang": 2, "moonscale": 5, "shardfin": 3, "dodo_egg": 1, "old_bone": 1, "glass_pearl": 6, "pale_crystal": 8, "maw_tooth": 20, "cactus_fruit": 1, "raptor_hide": 1, "trike_horn": 3, "trike_hide": 1, "stego_plate": 3, "longneck_hide": 1, "allo_tooth": 5, "parasaur_crest": 3}
const COIN := "ancient_coin"
## What tending a companion costs at the warden's (coins each).
const TEND_PRICE := 1


static func info(id: String) -> Dictionary:
	# The tribes' traders (pass 12) talk through the same dialogue.
	if id.begins_with("tribe_"): return preload("res://Forest/tribes/Tribes.gd").CAST.get(id, {})
	return CAST.get(id, {})


static func full_name(id: String) -> String:
	var who := info(id)
	return "%s, %s" % [who.get("name", id), str(who.get("title", "")).to_lower()] if who else id
