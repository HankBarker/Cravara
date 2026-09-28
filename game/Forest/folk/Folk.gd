extends RefCounted
## The folk of the Skyfang Wilds: who they are, when they come, where they are
## found and what they say. Data only (FolkManager runs it, FolkActor walks it,
## FolkDialogue speaks it).
##
## arrives   "start": beside the keeper on a new journey (never found).
##           "cache": after the first ancient cache is opened.
##           "tames:N": after N dinosaurs trust you.
##           "cave": underground, the first time the keeper goes down (pass 17).
##           "eggs:N": after N eggs taken from nests; "kills:N": after N beasts
##           brought down (pass 17).
## found     where they may turn up once they arrive, one picked per world:
##           "hut" their own little house, "stranded" a cold camp beside
##           whatever they lost, "caged" an old tribe's beast-trap (free them).
## services  the dialogue's extra pages: "recipes" (what can I make with...),
##           "trade" (buy and sell for ancient coins), "advice", "tend";
##           pass 17: "next" (What next?: quests/Advice.gd), "lore_tips" (their
##           own know-how, `tips`).
## pronoun   "him" or "her" (their banners).

const CAST := {
	"guide": {
		"name": "Orrin", "title": "The Wayfinder", "pronoun": "him", "arrives": "start", "found": [],
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
		"name": "Tamsin", "title": "The Trader", "pronoun": "her", "arrives": "cache", "found": ["stranded", "hut"],
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
		"name": "Kaya", "title": "The Beast-Warden", "pronoun": "her", "arrives": "tames:2", "found": ["caged", "hut", "stranded"],
		"services": ["next", "advice", "tend", "trade"],
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
	# Pass 17 (Hank: "in the caves you could find a guy that's really good
	# for... he's a miner, so he can help with mining and learning new skills.
	# Maybe you can learn how to create bombs... one that's more of, like, a
	# breeding expert... a combat expert as well").
	"miner": {
		"name": "Harrow", "title": "The Delver", "pronoun": "him", "arrives": "cave", "found": ["stranded"],
		"services": ["next", "lore_tips", "trade"],
		"lost": "lamp",
		"greet": [
			"Mind your head. Rock doesn't care who you are.",
			"Harrow's the name, rock's the game. Got anything that needs breaking?",
			"Back again? Good. A miner's no use without someone to show off to.",
		],
		"found_line": {
			"stranded": "Light! Ha, I thought I'd seen the last of it. My lamp's out and my rope's cut. Name's Harrow. Get me somewhere with a roof and I'll teach you a thing or two about rock.",
		},
		"ready_line": "I've had enough of the dark for a while. A house by your camp, walls and a roof and a light and a bed, and I'm yours. I'll bring my picks.",
		"chat": [
			"Crystal hums before a quake. Hear it and get into the open.",
			"The deeper you go, the thicker the crystal grows. And the bigger the things that eat it.",
			"Never throw a bomb uphill. Trust me.",
			"I once dug for a week straight and came up in a rex's nest. Never again.",
		],
		"tips": [
			"Violet seams are prism crystal. A power-two pick breaks them; a stone one just bounces.",
			"Every far land has its own ore: rustiron in the Bonelands, sunstone in the dunes, bog iron by the meres, ashglass in the ash.",
			"A bomb breaks rock, ore, trees and boulders, drops and all. It breaks you too, if you're standing next to it.",
			"The quakes drop boulders. Good stone in every one of them, if you've a pick or a bomb.",
			"An ankylosaur at your side cracks stone with its club: more from every rock you mine.",
		],
	},
	"breeder": {
		"name": "Nell", "title": "The Brood-Keeper", "pronoun": "her", "arrives": "eggs:1", "found": ["hut", "stranded", "caged"],
		"services": ["next", "lore_tips", "trade"],
		"lost": "basket",
		"greet": [
			"Eggs, eggs, eggs! Have you brought me any?",
			"Shh, they're sleeping. Oh, not the beasts. The eggs.",
			"You've the smell of a nest about you. Good.",
		],
		"found_line": {
			"hut": "Careful where you step! There's a clutch under that fern. Oh, you're the Keeper who steals eggs. We should talk.",
			"stranded": "A raptor pack took my basket and every egg in it. I'm Nell. I raise beasts from the egg. Help me start again?",
			"caged": "I climbed in after an egg and the trap shut behind me. Don't laugh. Get me out and I'll show you how to raise the little ones.",
		},
		"ready_line": "Find me a house near your beasts: walls, a door, a roof, a light and a bed. Hatchlings need company.",
		"chat": [
			"A hatchling that sees you first thinks you're its mother. Don't let it down.",
			"Babies grow faster well fed and close to you.",
			"Two of a kind, kept at home together a while, will lay. Pick your pairs: the young take after both.",
			"I've a soft spot for dodos. Don't tell the others.",
		],
		"tips": [
			"An incubator wants warmth: a fire or a torch within three tiles. Out in the cold, an egg barely grows.",
			"A nest lays again in time. Leave one egg and come back later.",
			"Every beast of your own has its own nature: bold, calm, fierce. The young take after their parents.",
			"Now and then a clutch comes out special: bigger, stronger, a different coat. That's the blood talking.",
			"Your Breeding stars (L) make incubation faster and twins likelier.",
		],
	},
	"fighter": {
		"name": "Rusk", "title": "The Old Blade", "pronoun": "him", "arrives": "kills:8", "found": ["stranded", "hut"],
		"services": ["next", "lore_tips", "trade"],
		"lost": "spear",
		"greet": [
			"Still alive? Good. Keep it that way.",
			"Stand up straight. Shield side forward. You haven't got a shield? Then roll.",
			"Every scar's a lesson. I'm a library.",
		],
		"found_line": {
			"stranded": "Heard you fighting from a mile off. You've spirit and no sense. I'm Rusk. I've been hunting these beasts since before you were born. Want to learn how to stay alive?",
			"hut": "Don't creep up on an old soldier. I'm Rusk. I watched you take down that last one. Sloppy. I can fix that.",
		},
		"ready_line": "A roof, a bed, four walls and a light, somewhere near your camp. Build it and I'll train you proper.",
		"chat": [
			"The raptor that leaps is the one you're watching. It's the one you're not that kills you.",
			"A bow starts the fight where it can't bite you. That's the whole trick.",
			"Rest when you're hurt. Eat when you're hungry. Heroes die of stupidity.",
			"I lost this eye to a Scarhorn. Kept the horn, though.",
		],
		"tips": [
			"Roll (Space) through a lunge, not away from it. You're safe while you roll.",
			"Each weapon strikes its own way: a sweep cuts every foe in its arc, a spear runs through, a club knocks them back.",
			"A full set of armour gives more than its pieces: Rustback hits harder, Plateback makes them bleed, Hornguard won't be moved.",
			"Hunters come in from the side and from cover. Keep your back to a wall and your beasts close.",
			"Big hunters tire. Keep your distance, let it run itself out, then strike.",
		],
	},
}

const Ways = preload("res://Forest/creatures/TamingWays.gd")
## Kaya's beasts (pass 13): species -> [her name for it, what it eats, how it's
## won (TamingWays.LESSONS: each beast its own way), riding].
const BEASTS := {
	"dodo": ["Dodo", "Greens, fruit, roots and grain", Ways.LESSONS.dodo, "Too small to ride. Set them to work and they'll gather for you."],
	"lystro": ["Lystro", "Greens, fruit, roots and grain", Ways.LESSONS.lystro, "Too small to ride, but it'll follow you anywhere."],
	"compy": ["Compy", "Any raw meat", Ways.LESSONS.compy, "Too small to ride. A swarm of your own guards your back."],
	"parasaur": ["Parasaur", "Greens, fruit, roots and grain", Ways.LESSONS.parasaur, "Too skittish to ride, but one at your side hears everything: it finds ore, caches and nests for you."],
	"proto": ["Proto", "Greens, fruit, roots and grain", Ways.LESSONS.proto, "Too small to ride. On sand it noses up old bones, fossils and coins."],
	"longneck": ["Longneck", "Greens, fruit, roots and grain", Ways.LESSONS.longneck, "Too tall for any saddle yet made."],
	"stego": ["Stego", "Greens, fruit, roots and grain", Ways.LESSONS.stego, "Fit a stego saddle (workbench). Steady, strong, and its tail swing bleeds foes."],
	"trike": ["Trike", "Greens, fruit, roots and grain", Ways.LESSONS.trike, "Fit a trike saddle. Click to gore; hold to charge a ram that bowls foes over."],
	"anky": ["Anky", "Greens, fruit, roots and grain", Ways.LESSONS.anky, "Not for riding, but beside you its club cracks stone: more from every rock and vein you mine."],
	"dimetrodon": ["Dimetrodon", "Any raw meat", Ways.LESSONS.dimetrodon, "Too low to ride, but its sail gathers the sun: your crops grow faster by day."],
	"raptor": ["Raptor", "Any raw meat", Ways.LESSONS.raptor, "No saddle fits a raptor. It fights beside you instead."],
	"deino": ["Deino", "Any raw meat", Ways.LESSONS.deino, "No saddle fits it. A pack of your own in the reeds."],
	"utah": ["Sandblade", "Any raw meat", Ways.LESSONS.utah, "Not yet ridden. Its sickle claws open anything."],
	"allo": ["Allosaur", "Any raw meat", Ways.LESSONS.allo, "No saddle for an allosaurus. Yet."],
	"carno": ["Scarhorn", "Any raw meat", Ways.LESSONS.carno, "Not yet ridden. At your side you sprint faster."],
	"yuty": ["Ashmane", "Any raw meat", Ways.LESSONS.yuty, "Not yet ridden. With one at your side the ash can't reach you."],
	"sucho": ["Suchomimus", "Any fish", Ways.LESSONS.sucho, "Not ridden. It fishes the mere for you."],
	"rex": ["Rex", "Any raw meat", Ways.LESSONS.rex, "Rex saddles are the stuff of legend."],
	"spino": ["Spinosaur", "Any fish", Ways.LESSONS.spino, "The bog's king carries no one. Yet."],
	"ptera": ["Pteranodon", "Any fish", Ways.LESSONS.ptera, "Saddle one and it will carry you into the sky, and up into the treetops."],
	"thyla": ["Thylacoleo", "Any raw meat", Ways.LESSONS.thyla, "A killer at your side, and it climbs."],
	"dimorph": ["Dimorphodon", "Any fish", Ways.LESSONS.dimorph, "Too small to ride. It'll shriek at anything that comes near you."],
	"alpha": ["Skarn", "Nothing", "Skarn leads the Shardback pack from its den in the north-east. It won't take food. It takes keepers.", "Beat it and the pack loses its nerve."],
}

## The trader's goods: id -> [price in ancient coins, how many per purchase].
const STOCK := {
	"merchant": {"berry_seed": [2, 3], "mushroom_spore": [2, 2], "redgrain": [2, 3], "net": [3, 1], "bone_arrow": [4, 10], "torch": [2, 3], "lantern": [12, 1], "crystal_flask": [6, 1], "garden_hoe": [5, 1], "fishing_rod": [6, 1], "cooked_meat": [3, 2]},
	# Pass 15: the warden keeps what beasts love (a favourite wins twice the trust).
	"warden": {"net": [3, 2], "stego_saddle": [18, 1], "trike_saddle": [22, 1], "berry": [1, 4], "trex_meat": [2, 1], "beast_treat": [5, 1], "bloody_bait": [6, 1]},
	# Pass 17: the new folk's wares.
	"miner": {"torch": [2, 3], "lantern": [12, 1], "basic_pickaxe": [4, 1], "bomb": [7, 2], "crystal_flask": [6, 1], "stone": [1, 6]},
	"breeder": {"incubator": [20, 1], "beast_treat": [5, 1], "berry": [1, 4], "dodo_egg": [4, 1], "lystro_egg": [5, 1], "trex_meat": [2, 1]},
	"fighter": {"bone_arrow": [4, 12], "net": [3, 1], "reed_bow": [10, 1], "hunter_charm": [20, 1], "cooked_meat": [3, 2], "mushroom_potion": [8, 1]},
}
## Rarer wares that turn up one or two at a time, a new pick each day.
const RARE := {"merchant": {"hunter_charm": 20, "crystal_pendant": 25, "river_totem": 25, "mushroom_potion": 8, "prism_crystal": 6}}
## What the trader pays (ancient coins each).
const BUYS := {"fossil_bone": 4, "sky_idol": 15, "crystal_shard": 1, "prism_crystal": 4, "trex_scale": 6, "raptor_fang": 2, "moonscale": 5, "shardfin": 3, "dodo_egg": 1, "old_bone": 1, "glass_pearl": 6, "pale_crystal": 8, "maw_tooth": 20, "cactus_fruit": 1, "raptor_hide": 1, "trike_horn": 3, "trike_hide": 1, "stego_plate": 3, "longneck_hide": 1, "allo_tooth": 5, "parasaur_crest": 3,
	# Pass 15: the far waters' fish and the far lands' crops.
	"mire_eel": 2, "fen_pike": 3, "oasis_carp": 2, "sunfin": 3, "ash_char": 3, "frostjaw": 6, "rust_catfish": 2, "bonegill": 6,
	"sun_melon": 2, "ember_pepper": 1, "marrow_gourd": 2, "mirelotus": 1}
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
