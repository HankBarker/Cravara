extends Node

signal stations_changed
const _Foods = preload("res://Forest/life/Foods.gd")
var nearby_stations: Array[String] = []
var last_failure := ""
var categories: Array[String] = ["All", "Tools", "Building", "Materials", "Food", "Armor", "Trinkets", "Relics"]
var personal_recipes: Array = [
	# Armour, tier 1-6 (docs/ARMOR_PROGRESSION.md). Bulk materials are renewable or
	# plentiful; each scarce drop appears once per piece and only from tier 3 up:
	# raptor_fang (bone), prism_crystal (crystal, tide, rex), trex_scale (rex).
	{"name":"Mossweave Hood","item_id":"moss_helmet","ingredients":{"plant_fiber":6,"berry":2},"station":"workbench","category":"Armor","description":"Tier 1 head armor. Woven entirely from forage."},
	{"name":"Mossweave Chestpiece","item_id":"moss_chestplate","ingredients":{"log":3,"plant_fiber":8},"station":"workbench","category":"Armor","description":"Tier 1 body armor. Mossy skywood bark over a fiber weave."},
	{"name":"Mossweave Leggings","item_id":"moss_leggings","ingredients":{"plant_fiber":7,"log":2},"station":"workbench","category":"Armor","description":"Tier 1 leg armor. Vine-wrapped reeds and bark boots."},
	{"name":"Trail Leather Cap","item_id":"leather_helmet","ingredients":{"reed_perch":2,"plant_fiber":3,"log":1},"station":"workbench","category":"Armor","description":"Tier 2 head armor. Reed perch skins cured into river leather."},
	{"name":"Trail Leather Tunic","item_id":"leather_chestplate","ingredients":{"reed_perch":4,"plant_fiber":4,"log":2},"station":"workbench","category":"Armor","description":"Tier 2 body armor. Reed perch skins cured into river leather."},
	{"name":"Trail Leather Leggings","item_id":"leather_leggings","ingredients":{"reed_perch":3,"plant_fiber":3,"log":1},"station":"workbench","category":"Armor","description":"Tier 2 leg armor. Reed perch skins cured into river leather."},
	{"name":"Fangbound Helmet","item_id":"bone_helmet","ingredients":{"raptor_fang":3,"raptor_hide":2,"plant_fiber":4},"station":"workbench","category":"Armor","description":"Tier 3 head armor. One raptor fang, carved and lashed over woven hide."},
	{"name":"Fangbound Chestplate","item_id":"bone_chestplate","ingredients":{"raptor_fang":4,"raptor_hide":4,"plant_fiber":6},"station":"workbench","category":"Armor","description":"Tier 3 body armor. One raptor fang, carved into plates over woven hide."},
	{"name":"Fangbound Leggings","item_id":"bone_leggings","ingredients":{"raptor_fang":3,"raptor_hide":3,"plant_fiber":5},"station":"workbench","category":"Armor","description":"Tier 3 leg armor. One raptor fang, carved into knee guards over woven hide."},
	{"name":"Skyshard Helmet","item_id":"crystal_helmet","ingredients":{"prism_crystal":2,"crystal_shard":4,"reed_perch":1},"station":"workbench","category":"Armor","description":"Tier 4 head armor. Prism crystal needs a power 2 pickaxe."},
	{"name":"Skyshard Chestplate","item_id":"crystal_chestplate","ingredients":{"prism_crystal":4,"crystal_shard":6,"reed_perch":2},"station":"workbench","category":"Armor","description":"Tier 4 body armor. Prism crystal needs a power 2 pickaxe."},
	{"name":"Skyshard Leggings","item_id":"crystal_leggings","ingredients":{"prism_crystal":3,"crystal_shard":4,"reed_perch":1},"station":"workbench","category":"Armor","description":"Tier 4 leg armor. Prism crystal needs a power 2 pickaxe."},
	{"name":"Tidecaller Helm","item_id":"tide_helmet","ingredients":{"moonscale":2,"shardfin":2,"prism_crystal":1},"station":"workbench","category":"Armor","description":"Tier 5 head armor. Moonscale and shardfin from silver ripple holes."},
	{"name":"Tidecaller Cuirass","item_id":"tide_chestplate","ingredients":{"moonscale":5,"shardfin":2,"prism_crystal":2},"station":"workbench","category":"Armor","description":"Tier 5 body armor. Moonscale and shardfin from silver ripple holes."},
	{"name":"Tidecaller Leggings","item_id":"tide_leggings","ingredients":{"moonscale":3,"shardfin":2,"prism_crystal":1},"station":"workbench","category":"Armor","description":"Tier 5 leg armor. Moonscale and shardfin from silver ripple holes."},
	{"name":"Tyrant Skull Helm","item_id":"rex_helmet","ingredients":{"trex_scale":1,"prism_crystal":2,"shardfin":2},"station":"workbench","category":"Armor","description":"Tier 6 head armor. Bound with a scale of the Emerald Tyrant."},
	{"name":"Tyrant Chestplate","item_id":"rex_chestplate","ingredients":{"trex_scale":1,"prism_crystal":4,"shardfin":3},"station":"workbench","category":"Armor","description":"Tier 6 body armor. Bound with a scale of the Emerald Tyrant."},
	{"name":"Tyrant Greaves","item_id":"rex_leggings","ingredients":{"trex_scale":1,"prism_crystal":3,"shardfin":2},"station":"workbench","category":"Armor","description":"Tier 6 leg armor. Bound with a scale of the Emerald Tyrant."},
	{"name":"Reedwood Bow","item_id":"reed_bow","ingredients":{"log":5,"plant_fiber":8},"category":"Tools","quantity":1,"description":"Hold left-click to draw; release to fire a bone arrow. Usable from a stego or trike saddle.","station":"workbench"},
	{"name":"Bone Arrows","item_id":"bone_arrow","ingredients":{"log":1,"raptor_fang":1},"category":"Tools","quantity":8,"description":"A straight reed shaft, bone point and feather fletching. Ammunition for a reedwood bow."},
	{"name":"Stone Hoe","item_id":"garden_hoe","ingredients":{"log":3,"stone":2},"category":"Tools","quantity":1,"description":"Right-click clear earth to prepare a garden plot. Sow berries or mushroom spores on tilled earth."},
	{"name":"Berry Seeds","item_id":"berry_seed","ingredients":{"berry":1},"category":"Materials","quantity":2,"description":"Sow on tilled soil. Water once with a water bucket; harvest ripe berries and a replacement seed."},
	{"name":"Mushroom Spores","item_id":"mushroom_spore","ingredients":{"mushroom":1},"category":"Materials","quantity":2,"description":"Sow on tilled soil. Water once to grow a patch of edible mushrooms."},
	{"name":"Forest Omelet","item_id":"forest_omelet","ingredients":{"dodo_egg":1,"mushroom":2},"category":"Food","quantity":1,"description":"Dodo eggs folded around woodland mushrooms. 75 hunger, 150 seconds of fullness and 24 vitality over 24 seconds.","station":"campfire"},
	{"name":"Warm Berry Compote","item_id":"berry_compote","ingredients":{"berry":3},"category":"Food","quantity":1,"description":"Slow-cooked berries. 40 hunger, 90 seconds of fullness and 10 vitality over 20 seconds.","station":"campfire"},
	{"name":"Shardbound Pickaxe","item_id":"crystal_pickaxe","ingredients":{"basic_pickaxe":1,"crystal_shard":6,"plant_fiber":3},"category":"Tools","quantity":1,"description":"Pickaxe power 2. Breaks dense violet crystal seams and mines ordinary stone faster.","station":"workbench"},
	{"name":"Shardbound Axe","item_id":"crystal_axe","ingredients":{"basic_axe":1,"crystal_shard":6,"plant_fiber":3},"category":"Tools","quantity":1,"description":"Axe power 2. Fells trees in two swings.","station":"workbench"},
	{"name":"Fang Sabre","item_id":"fang_sabre","ingredients":{"raptor_fang":6,"raptor_hide":2,"crystal_shard":3},"category":"Tools","quantity":1,"description":"12 damage. A raptor's longest fang in a teal guard.","station":"workbench"},
	{"name":"Horn Spear","item_id":"horn_spear","ingredients":{"trike_horn":3,"trike_hide":2,"log":2},"category":"Tools","quantity":1,"description":"16 damage. Tipped with a triceratops horn.","station":"workbench"},
	{"name":"Plate Maul","item_id":"plate_maul","ingredients":{"stego_plate":5,"trike_hide":1,"log":2},"category":"Tools","quantity":1,"description":"21 damage, and its blows bleed. Stego plates on a heavy haft.","station":"workbench"},
	{"name":"Allosaur Cleaver","item_id":"allo_cleaver","ingredients":{"allo_tooth":4,"trex_scale":3,"prism_crystal":2},"category":"Tools","quantity":1,"description":"27 damage. Edged with allosaurus teeth.","station":"workbench"},
	{"name":"Tyrant Fang","item_id":"tyrant_fang","ingredients":{"trex_scale":6,"allo_tooth":3,"prism_crystal":3},"category":"Tools","quantity":1,"description":"36 damage. The Emerald Tyrant's fang.","station":"workbench"},
	# Pass 14: trinkets from a beast's parts (the same parts make its weapons), and
	# two trinkets tinkered into one (tools/items/trinkets.py).
	{"name":"Fang Necklace","item_id":"fang_necklace","ingredients":{"raptor_fang":3,"plant_fiber":2},"station":"workbench","category":"Trinkets","description":"Raptor fangs strung on fibre."},
	{"name":"Plate Pendant","item_id":"plate_pendant","ingredients":{"stego_plate":2,"plant_fiber":2},"station":"workbench","category":"Trinkets","description":"A stego plate, filed to an edge."},
	{"name":"Horn Guard","item_id":"horn_guard","ingredients":{"trike_horn":2,"trike_hide":1},"station":"workbench","category":"Trinkets","description":"Trike horn and hide, a bracer that turns blows."},
	{"name":"Scale Bracer","item_id":"scale_bracer","ingredients":{"trex_scale":3,"raptor_hide":1},"station":"workbench","category":"Trinkets","description":"Crystal scale laced over raptor hide."},
	{"name":"Allo Tooth Ring","item_id":"tooth_ring","ingredients":{"allo_tooth":2,"rustiron":1},"station":"workbench","category":"Trinkets","description":"An allosaur tooth set in rustiron."},
	{"name":"Sunstone Amulet","item_id":"sunstone_amulet","ingredients":{"sunstone":2,"sail_scale":1},"station":"workbench","category":"Trinkets","description":"Warm to the touch, even at night."},
	{"name":"Bog-iron Band","item_id":"bogiron_band","ingredients":{"bog_iron":2,"sucho_claw":1},"station":"workbench","category":"Trinkets","description":"Black bog iron and a Suchomimus claw."},
	{"name":"Ashglass Eye","item_id":"ashglass_eye","ingredients":{"ashglass":2,"ashmane_fur":1},"station":"workbench","category":"Trinkets","description":"A lens of ashglass. Through it, foes show their weak spots."},
	{"name":"Fur-lined Wrap","item_id":"fur_wrap","ingredients":{"ashmane_fur":2,"raptor_hide":1},"station":"workbench","category":"Trinkets","description":"Ashmane fur against the snow."},
	{"name":"Claw Bracelet","item_id":"claw_bracelet","ingredients":{"deino_claw":2,"sickle_claw":1},"station":"workbench","category":"Trinkets","description":"Deinonychus and Utahraptor claws in a ring."},
	{"name":"Spine Torc","item_id":"spine_torc","ingredients":{"spino_spine":2,"bog_iron":1},"station":"workbench","category":"Trinkets","description":"Spinosaur spines bent into a neck ring."},
	{"name":"Bloodfang Necklace","item_id":"bloodfang","ingredients":{"fang_necklace":1,"plate_pendant":1,"crystal_shard":2},"station":"workbench","category":"Trinkets","description":"Fangs and a filed plate: every cut counts."},
	{"name":"Bulwark Charm","item_id":"bulwark_charm","ingredients":{"horn_guard":1,"frill_guard":1,"crystal_shard":2},"station":"workbench","category":"Trinkets","description":"Horn and frill: nothing moves you."},
	{"name":"Wanderer's Step","item_id":"wanderers_step","ingredients":{"wayfarer_anklet":1,"sandblade_plume":1,"prism_crystal":1},"station":"workbench","category":"Trinkets","description":"Anklet and plume: light as the Sandblades."},
	{"name":"Apex Signet","item_id":"apex_signet","ingredients":{"tyrant_eye":1,"rust_signet":1,"prism_crystal":2},"station":"workbench","category":"Trinkets","description":"The rex's eye set in the allosaur's ring."},
	# Pass 18: the jungle's, the Reaper's, Stormcrest's and the Cinderhulk's.
	{"name":"Climber's Claws","item_id":"claw_wraps","ingredients":{"thyla_claw":2,"vine":3},"station":"workbench","category":"Trinkets","description":"Thylacoleo claws strapped to the palms, as the jungle folk climb."},
	{"name":"Emberward Charm","item_id":"emberward_charm","ingredients":{"reaper_claw":1,"pale_crystal":3,"ashmane_fur":2},"station":"workbench","category":"Trinkets","description":"A Reaper's claw bound with pale crystal and Ashmane fur. The Pale Lands' cold is in it.","hidden_until":"reaper"},
	{"name":"Stormcrest Plume","item_id":"stormcrest_plume","ingredients":{"storm_feather":2,"glimmer_shard":3},"station":"workbench","category":"Trinkets","description":"Stormcrest's feathers, bound with glimmer. You move like the wind before a storm.","hidden_until":"stormcrest"},
	{"name":"Molten Heart","item_id":"molten_heart","ingredients":{"molten_core":1,"obsidian":4,"emberstone":4},"station":"ember_forge","category":"Trinkets","description":"The Cinderhulk's core in an obsidian cage. The volcano knows you now.","hidden_until":"cinderhulk"},
	{"name":"Skyshard Sword","item_id":"shard_sword","ingredients":{"prism_crystal":3,"plank":2,"plant_fiber":2},"category":"Tools","quantity":1,"description":"A broad crystal-edged blade. A sweeping slash with greater reach than a dagger.","station":"workbench"},
	{"name":"Reed Fishing Rod", "item_id":"fishing_rod", "ingredients":{"log":6,"plant_fiber":8,"crystal_shard":2}, "station":"workbench", "category":"Tools", "description":"Cast into rippling fishing holes. Hold and release Space to reel in a catch."},
	{"name":"Crystal Flask", "item_id":"crystal_flask", "ingredients":{"crystal_shard":2,"stone":1}, "station":"workbench", "category":"Materials", "description":"Polish a reusable vessel. Fill it at the water's edge."},
	{"name":"Mushroom Tonic", "item_id":"mushroom_potion", "ingredients":{"mushroom":2,"berry":1,"water_flask":1}, "station":"campfire", "category":"Food", "description":"Brew 40 vitality over 8 seconds. Drinking returns the empty flask."},
	{"name":"Grilled Fish", "item_id":"cooked_fish", "ingredients":{"any:fish":1}, "station":"campfire", "category":"Food", "description":"Any fish, grilled whole (the commonest first). 55 hunger and 2 minutes of fullness. Restores 18 vitality over time."},
	{"name":"Hide Tent", "item_id":"tent", "ingredients":{"plank":6,"plant_fiber":12,"trex_scale":3}, "station":"workbench", "category":"Building", "description":"Place a tribal shelter. Reclaim it with any tool or your hands."},
	{"name":"Hide Bed", "item_id":"hide_bed", "ingredients":{"plank":4,"plant_fiber":8,"trex_scale":2}, "station":"workbench", "category":"Building", "description":"A woven hide bed. Place it and press E to set your respawn point."},
	{"name":"Dugout Boat", "item_id":"boat", "ingredients":{"plank":10,"plant_fiber":8,"log":2}, "station":"workbench", "category":"Building", "description":"A hollowed canoe for Glassmere. Set it on the water and press E to climb in; E again steps ashore."},
	{"name":"Grave Horn", "item_id":"grave_horn", "ingredients":{"old_bone":12,"crystal_shard":6,"prism_crystal":1}, "station":"workbench", "category":"Relics", "hidden_until":"lore_buried_king", "description":"Old bone bound with Sky-Fang crystal, as the Kingstone says. Blow it at the Ossuary in the Sunscar Dunes to wake the Buried King."},
	{"name":"Incubator", "item_id":"incubator", "ingredients":{"plank":12,"stone":16,"crystal_shard":8,"fossil_bone":3,"raptor_fang":4}, "station":"workbench", "category":"Building", "hidden_until":"alpha", "description":"Learned in Skarn's den, once the alpha has fallen. Straw in a clay bowl on warm stones. Hold an egg and click it in; keep a fire or torch within three tiles and it hatches a baby that knows you."},
	{"name":"Hornguard Helm","item_id":"horn_helmet","ingredients":{"trike_horn":2,"trike_hide":4,"plant_fiber":4},"category":"Armor","description":"Defence 9. Hornguard set: blows barely move you; 10% less harm.","station":"workbench"},
	{"name":"Hornguard Plate","item_id":"horn_chestplate","ingredients":{"trike_hide":8,"trike_horn":1,"longneck_hide":2,"crystal_shard":3},"category":"Armor","description":"Defence 15. Hornguard set: blows barely move you; 10% less harm.","station":"workbench"},
	{"name":"Hornguard Greaves","item_id":"horn_leggings","ingredients":{"trike_hide":6,"trike_horn":1,"plant_fiber":4},"category":"Armor","description":"Defence 11. Hornguard set: blows barely move you; 10% less harm.","station":"workbench"},
	{"name":"Plateback Helm","item_id":"plate_helmet","ingredients":{"stego_plate":4,"raptor_hide":2},"category":"Armor","description":"Defence 8. Plateback set: your blows and spikes draw blood.","station":"workbench"},
	{"name":"Plateback Cuirass","item_id":"plate_chestplate","ingredients":{"stego_plate":8,"raptor_hide":3,"longneck_hide":2},"category":"Armor","description":"Defence 14. Plateback set: your blows and spikes draw blood.","station":"workbench"},
	{"name":"Plateback Greaves","item_id":"plate_leggings","ingredients":{"stego_plate":6,"raptor_hide":2},"category":"Armor","description":"Defence 10. Plateback set: your blows and spikes draw blood.","station":"workbench"},
	{"name":"Rustback Hood","item_id":"rust_helmet","ingredients":{"allo_tooth":2,"trex_scale":2,"raptor_hide":3},"category":"Armor","description":"Defence 10. Rustback set: blows 20% harder.","station":"workbench"},
	{"name":"Rustback Hauberk","item_id":"rust_chestplate","ingredients":{"allo_tooth":3,"trex_scale":4,"raptor_hide":4},"category":"Armor","description":"Defence 17. Rustback set: blows 20% harder.","station":"workbench"},
	{"name":"Rustback Leggings","item_id":"rust_leggings","ingredients":{"allo_tooth":2,"trex_scale":3,"raptor_hide":3},"category":"Armor","description":"Defence 12. Rustback set: blows 20% harder.","station":"workbench"},
	{"name":"Stego Saddle", "item_id":"stego_saddle", "ingredients":{"plank":8,"plant_fiber":12,"crystal_shard":3}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded stego through its companion menu, then ride."},
	{"name":"Trike Saddle", "item_id":"trike_saddle", "ingredients":{"plank":8,"plant_fiber":12,"crystal_shard":3}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded trike through its companion menu, then ride."},
	# Pass 18: a saddle for every beast a keeper can ride (creatures/Rides.gd):
	# the plant-eaters' at once, the hunters' once Grimjaw's hide is had.
	{"name":"Longneck Saddle", "item_id":"longneck_saddle", "ingredients":{"plank":8, "plant_fiber":12, "crystal_shard":3, "longneck_hide":1}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded longneck through its companion menu, then ride."},
	{"name":"Parasaur Saddle", "item_id":"parasaur_saddle", "ingredients":{"plank":8, "plant_fiber":12, "crystal_shard":3, "longneck_hide":1}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded parasaur through its companion menu, then ride."},
	{"name":"Ankylosaur Saddle", "item_id":"anky_saddle", "ingredients":{"plank":8, "plant_fiber":12, "crystal_shard":3, "longneck_hide":1}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded ankylosaur through its companion menu, then ride."},
	{"name":"Dimetrodon Saddle", "item_id":"dimetrodon_saddle", "ingredients":{"grimjaw_hide":1, "raptor_hide":3, "plank":6, "plant_fiber":10}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded dimetrodon through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Raptor Saddle", "item_id":"raptor_saddle", "ingredients":{"grimjaw_hide":1, "raptor_hide":3, "plank":6, "plant_fiber":10}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded raptor through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Deinonychus Saddle", "item_id":"deino_saddle", "ingredients":{"grimjaw_hide":1, "raptor_hide":3, "plank":6, "plant_fiber":10}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded deinonychus through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Utahraptor Saddle", "item_id":"utah_saddle", "ingredients":{"grimjaw_hide":1, "raptor_hide":3, "plank":6, "plant_fiber":10}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded utahraptor through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Thylacoleo Saddle", "item_id":"thyla_saddle", "ingredients":{"grimjaw_hide":1, "raptor_hide":3, "plank":6, "plant_fiber":10}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded thylacoleo through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Allosaurus Saddle", "item_id":"allo_saddle", "ingredients":{"grimjaw_hide":2, "trex_scale":2, "plank":8, "plant_fiber":12}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded allosaurus through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Carnotaurus Saddle", "item_id":"carno_saddle", "ingredients":{"grimjaw_hide":2, "trex_scale":2, "plank":8, "plant_fiber":12}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded carnotaurus through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Yutyrannus Saddle", "item_id":"yuty_saddle", "ingredients":{"grimjaw_hide":2, "trex_scale":2, "plank":8, "plant_fiber":12}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded yutyrannus through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Tyrant Saddle", "item_id":"rex_saddle", "ingredients":{"grimjaw_hide":2, "trex_scale":2, "plank":8, "plant_fiber":12}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded tyrant through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Suchomimus Saddle", "item_id":"sucho_saddle", "ingredients":{"grimjaw_hide":2, "trex_scale":2, "plank":8, "plant_fiber":12}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded suchomimus through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Spinosaur Saddle", "item_id":"spino_saddle", "ingredients":{"grimjaw_hide":2, "trex_scale":2, "plank":8, "plant_fiber":12}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded spinosaur through its companion menu, then ride.", "hidden_until":"grimjaw"},
	{"name":"Skyfisher Saddle", "item_id":"ptera_saddle", "ingredients":{"vine":8, "plank":4, "glimmer_shard":2, "plant_fiber":6}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded skyfisher through its companion menu, then ride."},
	{"name":"Timber Door", "item_id":"wood_door", "ingredients":{"plank":3,"plant_fiber":2}, "station":"workbench", "category":"Building", "description":"A door for your base. Aim and press E to open or close."},
	{"name":"Thatch Roof", "item_id":"thatch_roof", "quantity":4,"ingredients":{"plant_fiber":4,"plank":1}, "category":"Building", "description":"Build roofing above your floor. It fades while you are beneath it."},
	{"name":"Skyfang Pendant", "item_id":"crystal_pendant", "ingredients":{"crystal_shard":4,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"Recover an extra 0.2 vitality per second while fed."},
	{"name":"Maw Charm", "item_id":"maw_charm", "ingredients":{"maw_tooth":2,"glass_pearl":1,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"Old Maw's teeth on a cord: +3 weapon damage and quicker wading."},
	{"name":"Crestcaller Horn", "item_id":"crest_horn", "ingredients":{"parasaur_crest":2,"longneck_hide":1,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"A parasaur's crest on a cord: wounds mend faster (+0.3 vitality a second)."},
	# Pass 12: the dunes' and the Pale Lands' beasts. Breath for the Pale
	# Lands' ash comes from the south: a dimetrodon's sail-skin, then an
	# Ashmane's coat.
	{"name":"Sail-skin Veil", "item_id":"sail_veil", "ingredients":{"sail_scale":3,"proto_frill":2,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"Keeps out much of the Pale Lands' ash; +2 defence. Thin dimetrodon sail-skin over the mouth and nose."},
	{"name":"Ashmane Mantle", "item_id":"ashmane_mantle", "ingredients":{"ashmane_fur":6,"sail_scale":2,"raptor_hide":2}, "station":"workbench", "category":"Relics", "description":"The ash can't reach you in it; +5 defence. An Ashmane's coat from the Pale Lands."},
	{"name":"Sun Sail", "item_id":"sun_sail", "ingredients":{"sail_scale":4,"plank":6,"plant_fiber":4}, "station":"workbench", "category":"Building", "description":"Crops within three tiles grow half again as fast by day, and on through the night by its glow. It warms whoever stands by it."},
	{"name":"Sandclub Maul", "item_id":"club_maul", "ingredients":{"anky_plate":5,"log":2,"trike_hide":1}, "station":"workbench", "category":"Tools", "description":"30 damage: heavy enough to break through an ankylosaur's plates."},
	{"name":"Scarhorn Lance", "item_id":"scarhorn_lance", "ingredients":{"carno_horn":2,"trex_scale":3,"plank":2}, "station":"workbench", "category":"Tools", "description":"40 damage. The Scarhorn's horn on an ash shaft."},
	# Pass 13: a far land's ore and its beast's parts make each new weapon; the
	# stockman's gear waits on the Taming tree (hidden_until "perk:...").
	{"name":"Rustjaw Sabre", "item_id":"rustjaw_sabre", "ingredients":{"rustiron":5,"allo_tooth":3,"raptor_hide":2}, "station":"workbench", "category":"Tools", "description":"32 damage, sweeping. Rustiron from the allosaurs' ground, edged with their teeth."},
	{"name":"Sunstone Maul", "item_id":"sunstone_maul", "ingredients":{"sunstone":5,"anky_plate":3,"carno_horn":1}, "station":"workbench", "category":"Tools", "description":"42 damage, smashing. Sunstone from the Scarhorn's dunes on an ankylosaur plate."},
	{"name":"Ashglass Knife", "item_id":"ashglass_knife", "ingredients":{"ashglass":4,"ashmane_fur":2,"sickle_claw":1}, "station":"workbench", "category":"Tools", "description":"28 damage, a quick stab. Ashglass from the Ashmane's fields, a Sandblade claw for a guard."},
	# Pass 18: the far ring's weapons and armour (tools/items/gear18.py), and the forge for the volcano's.
	{"name":"Ember Forge", "item_id":"ember_forge", "ingredients":{"stone":24, "emberstone":4, "obsidian":6, "plank":4}, "station":"workbench", "category":"Building", "description":"A forge of black stone that burns emberstone. Obsidian gear and the fire's own are made at it."},
{"name":"Glimmer Spear", "item_id":"glimmer_spear", "ingredients":{"glimmer_shard":5, "vine":4, "thyla_claw":1, "plank":2}, "station":"workbench", "category":"Tools", "description":"44 damage. A glimmer shard lashed to a vine-bound shaft. It glows in the jungle's dark."},
	{"name":"Obsidian Blade", "item_id":"obsidian_blade", "ingredients":{"obsidian":6, "emberstone":3, "plank":2}, "station":"ember_forge", "category":"Tools", "description":"48 damage. Black volcanic glass, keener than any steel, on an emberstone grip."},
	{"name":"Reaper's Scythe", "item_id":"reaper_scythe", "ingredients":{"reaper_claw":1, "palewood":4, "pale_crystal":4}, "station":"workbench", "category":"Tools", "description":"52 damage. The Pale Reaper's claw on a palewood haft. It sweeps wide and cold.", "hidden_until":"reaper"},
	{"name":"Stormwing Glaive", "item_id":"storm_glaive", "ingredients":{"storm_feather":2, "wing_leather":2, "glimmer_shard":4, "plank":2}, "station":"workbench", "category":"Tools", "description":"58 damage. Storm feathers bound down a glimmer blade. It hums before a blow.", "hidden_until":"stormcrest"},
	{"name":"Cinderbrand", "item_id":"cinderbrand", "ingredients":{"molten_core":1, "obsidian":6, "emberstone":6}, "station":"ember_forge", "category":"Tools", "description":"64 damage, smashing. The Cinderhulk's molten core set in an obsidian head. It never cools.", "hidden_until":"cinderhulk"},
	{"name":"Treeshadow Hood", "item_id":"thyla_helmet", "ingredients":{"thyla_pelt":2, "vine":2, "plant_fiber":3}, "station":"workbench", "category":"Armor", "description":"Defence 10. Treeshadow set: beasts notice you from half as far, and you move 6% faster."},
	{"name":"Treeshadow Jerkin", "item_id":"thyla_chestplate", "ingredients":{"thyla_pelt":4, "thyla_claw":1, "vine":3}, "station":"workbench", "category":"Armor", "description":"Defence 16. Treeshadow set: beasts notice you from half as far, and you move 6% faster."},
	{"name":"Treeshadow Leggings", "item_id":"thyla_leggings", "ingredients":{"thyla_pelt":3, "vine":2, "plant_fiber":3}, "station":"workbench", "category":"Armor", "description":"Defence 12. Treeshadow set: beasts notice you from half as far, and you move 6% faster."},
	{"name":"Skywing Crest", "item_id":"sky_helmet", "ingredients":{"wing_leather":2, "ptera_crest":1, "plant_fiber":2}, "station":"workbench", "category":"Armor", "description":"Defence 11. Skywing set: you move 10% faster and roll further."},
	{"name":"Skywing Mantle", "item_id":"sky_chestplate", "ingredients":{"wing_leather":4, "dimorph_tooth":3, "vine":2}, "station":"workbench", "category":"Armor", "description":"Defence 18. Skywing set: you move 10% faster and roll further."},
	{"name":"Skywing Leggings", "item_id":"sky_leggings", "ingredients":{"wing_leather":3, "vine":2, "plant_fiber":2}, "station":"workbench", "category":"Armor", "description":"Defence 13. Skywing set: you move 10% faster and roll further."},
	{"name":"Obsidian Helm", "item_id":"obsidian_helmet", "ingredients":{"obsidian":4, "emberstone":2, "ashmane_fur":1}, "station":"ember_forge", "category":"Armor", "description":"Defence 13. Obsidian set: keeps off 60% of the volcano's heat; fire and lava harm you less."},
	{"name":"Obsidian Cuirass", "item_id":"obsidian_chestplate", "ingredients":{"obsidian":7, "emberstone":3, "ashmane_fur":2}, "station":"ember_forge", "category":"Armor", "description":"Defence 21. Obsidian set: keeps off 60% of the volcano's heat; fire and lava harm you less."},
	{"name":"Obsidian Greaves", "item_id":"obsidian_leggings", "ingredients":{"obsidian":5, "emberstone":2, "ashmane_fur":1}, "station":"ember_forge", "category":"Armor", "description":"Defence 15. Obsidian set: keeps off 60% of the volcano's heat; fire and lava harm you less."},
	{"name":"Bog-iron Harpoon", "item_id":"bogiron_harpoon", "ingredients":{"bog_iron":5,"sucho_claw":2,"plank":2}, "station":"workbench", "category":"Tools", "description":"38 damage, a thrust through three. Bog iron and a Suchomimus claw."},
	{"name":"Spinesail Glaive", "item_id":"spinesail_glaive", "ingredients":{"bog_iron":4,"spino_spine":3,"prism_crystal":2}, "station":"workbench", "category":"Tools", "description":"50 damage, a wide sweep. The Sailking's own spine."},
	{"name":"Lead Rope", "item_id":"lead_rope", "ingredients":{"plant_fiber":6,"raptor_hide":1}, "category":"Tools", "hidden_until":"perk:hand_rope", "description":"Lead a companion close on the rope, or tie it to a hitching post. (Taming: Rope-craft.)"},
	{"name":"Hitching Post", "item_id":"hitching_post", "ingredients":{"log":3,"plant_fiber":4}, "category":"Building", "hidden_until":"perk:hand_rope", "description":"Tie a companion to it and it stays put. (Taming: Rope-craft.)"},
	{"name":"Pen Gate", "item_id":"big_gate", "ingredients":{"plank":10,"log":4,"plant_fiber":6}, "station":"workbench", "category":"Building", "description":"A gate three tiles wide for a pen of big beasts. E opens and shuts it."},
	{"name":"Saddlebags", "item_id":"saddlebag", "ingredients":{"raptor_hide":3,"trike_hide":2,"plant_fiber":4}, "station":"workbench", "category":"Tools", "hidden_until":"perk:hand_bags", "description":"A companion carries a bag for you. (Taming: Saddlebags.)"},
	{"name":"Hunter's Fang", "item_id":"hunter_charm", "ingredients":{"raptor_fang":3,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"Wear this hunting charm for +2 weapon damage."},
	{"name":"River Totem", "item_id":"river_totem", "ingredients":{"crystal_shard":3,"log":2,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"A carved river charm improves shallow-water movement."},
	{"name":"Shard Lantern", "item_id":"lantern", "ingredients":{"crystal_shard":5,"plank":2,"plant_fiber":2}, "station":"workbench", "category":"Relics", "description":"Equip a cool crystal light in your light slot."},
	{"name":"Wooden Plank", "item_id":"plank", "quantity":2, "ingredients":{"log":1}, "category":"Materials", "description":"Split a log into two sturdy boards."},
	# Pass 17: furniture like the fallen houses' (Hank: "we don't have chairs, but we could add in chairs").
	{"name":"Wooden Chair", "item_id":"chair", "ingredients":{"plank":3}, "station":"workbench", "category":"Building", "description":"A plain chair for your house."},
	{"name":"Wooden Table", "item_id":"table", "ingredients":{"plank":5}, "station":"workbench", "category":"Building", "description":"A sturdy table for your house."},
	{"name":"Barrel", "item_id":"barrel", "ingredients":{"plank":4,"plant_fiber":2}, "station":"workbench", "category":"Building", "description":"A barrel, bound in fibre."},
	# Pass 17: Harrow the Delver's bombs (his task "Powder and crystal" teaches them).
	{"name":"Blasting Bomb", "item_id":"bomb", "quantity":2, "ingredients":{"crystal_shard":3,"plant_fiber":2,"stone":2}, "station":"workbench", "category":"Tools", "hidden_until":"learned_bombs", "description":"Crushed Sky-Fang crystal packed in stone and fibre. Click to throw: it blasts rock, ore and trees apart. Keep clear!"},
	{"name":"Torch", "item_id":"torch", "quantity":2, "ingredients":{"log":1,"plant_fiber":1}, "category":"Building", "description":"Light the edge of the wild."},
	{"name":"Workbench", "item_id":"workbench", "ingredients":{"log":5,"stone":3}, "category":"Building", "description":"Place a tribal crafting station."},
	{"name":"Campfire", "item_id":"campfire", "ingredients":{"log":3,"stone":4}, "category":"Building", "description":"Place a fire; stand nearby to roast meat."},
	{"name":"Timber Wall", "item_id":"wood_wall", "quantity":4, "ingredients":{"plank":2}, "category":"Building", "description":"Build a protective palisade on the tile grid."},
	{"name":"Timber Floor", "item_id":"wood_floor", "quantity":4, "ingredients":{"plank":2}, "category":"Building", "description":"Lay a warm timber foundation."},
	{"name":"Stone Wall", "item_id":"stone_wall", "quantity":4, "ingredients":{"stone":6}, "station":"workbench", "category":"Building", "description":"Cut stone in the first builders' way: far sturdier than timber."},
	{"name":"Stone Floor", "item_id":"stone_floor", "quantity":4, "ingredients":{"stone":4}, "station":"workbench", "category":"Building", "description":"Flagstones like the old ruins' paving."},
	{"name":"Stone Door", "item_id":"stone_door", "ingredients":{"stone":4,"plank":2}, "station":"workbench", "category":"Building", "description":"An iron-banded door in a stone frame. Aim and press E to open or close."},
	{"name":"Slate Roof", "item_id":"slate_roof", "quantity":4, "ingredients":{"stone":3,"plank":1}, "station":"workbench", "category":"Building", "description":"Overlapping slates: a roof that keeps the weather out. Fades while you are beneath it."},
	{"name":"Chest", "item_id":"chest", "ingredients":{"plank":4}, "station":"workbench", "category":"Building", "description":"Store supplies at your camp."},
	{"name":"Basic Axe", "item_id":"basic_axe", "ingredients":{"plank":3,"stone":2}, "category":"Tools", "description":"Fell trees and clear your camp."},
	{"name":"Basic Pickaxe", "item_id":"basic_pickaxe", "ingredients":{"plank":3,"stone":2}, "category":"Tools", "description":"Mine stone and crystal walls."},
	{"name":"Wooden Bucket", "item_id":"bucket", "ingredients":{"plank":3,"plant_fiber":2}, "station":"workbench", "category":"Tools", "description":"Scoop and place shallow water."},
	{"name":"Woven Net", "item_id":"net", "ingredients":{"plant_fiber":5,"plank":1}, "category":"Tools", "description":"Restrain a predator, then offer meat."},
	{"name":"Bone Dagger", "item_id":"bone_dagger", "ingredients":{"raptor_fang":2,"plank":1,"crystal_shard":2}, "station":"workbench", "category":"Tools", "description":"A shard-edged fang blade."},
	{"name":"Roasted Meat", "item_id":"cooked_meat", "ingredients":{"trex_meat":1}, "station":"campfire", "category":"Food", "description":"Fill hunger completely; stay full for 3 minutes of walking."},
	{"name":"Baked Tuber", "item_id":"baked_tuber", "ingredients":{"wild_tuber":2}, "station":"campfire", "category":"Food", "description":"Two wild tubers baked soft: 45 hunger, full for a minute."}
]

## Pass 15: the larder's recipes (tools/items/foods.py: the cooking pot's
## dishes, a campfire's roasts, the pot itself).
func _ready() -> void:
	for recipe in preload("res://Forest/life/FoodData.gd").RECIPES + preload("res://Forest/world/Materials.gd").RECIPES:
		if get_recipe(str(recipe.item_id)).is_empty(): personal_recipes.append(recipe.duplicate(true))

func set_nearby_stations(stations: Array[String]) -> void:
	if nearby_stations == stations: return
	nearby_stations = stations.duplicate()
	stations_changed.emit()

func get_recipes_by_category(category: String) -> Array:
	return personal_recipes.filter(func(recipe): return (category == "All" or recipe.category == category) and is_known(recipe))


## A recipe hidden until the keeper has learned of it (a carving read: the
## session's milestones), e.g. the Grave Horn from the Kingstone.
func is_known(recipe: Dictionary) -> bool:
	var needs := str(recipe.get("hidden_until", ""))
	if needs == "": return true
	# Pass 13: a perk of the keeper's skills ("perk:hand_rope").
	if needs.begins_with("perk:"):
		var skills = get_tree().get_first_node_in_group("skills") if is_inside_tree() else null
		return skills != null and skills.has(needs.substr(5))
	var session := get_tree().get_first_node_in_group("forest_session") if is_inside_tree() else null
	return session != null and bool(session.get("_milestones").get(needs, false))

func get_recipe(item_id: String) -> Dictionary:
	for recipe in personal_recipes:
		if recipe.item_id == item_id: return recipe
	return {}

func can_craft(ingredients: Dictionary) -> bool:
	for id in ingredients:
		if int(ingredients[id]) <= 0 or InventoryManager.get_item_count(id) < int(ingredients[id]): return false
	return true

func can_craft_recipe(recipe: Dictionary) -> bool:
	return not _simulate(recipe).is_empty()

# Build the entire transaction on a copy, including space freed by consumed materials.
# A failed craft cannot lose ingredients, insert partial output, or bypass station rules.
func _simulate(recipe: Dictionary) -> Array[Dictionary]:
	last_failure = ""
	var empty: Array[Dictionary] = []
	if recipe.is_empty():
		last_failure = "Unknown recipe"
		return empty
	var station: String = recipe.get("station", "")
	if station != "" and station not in nearby_stations:
		last_failure = "Stand near a " + station
		return empty
	if not can_craft(recipe.ingredients):
		last_failure = "Gather the missing ingredients"
		return empty
	var item := create_item_by_id(recipe.item_id)
	if item == null: return empty
	var result: Array[Dictionary] = []
	for slot in InventoryManager.inventory: result.append(slot.duplicate())
	for id in recipe.ingredients:
		var needed := int(recipe.ingredients[id])
		# "any:fish" (pass 15): the commonest of the group goes first.
		var takes: Array = _Foods.group(str(id))
		if takes.is_empty(): takes = [id]
		for take in takes:
			for slot in result:
				if needed <= 0: break
				if slot.item and slot.item.id == take:
					var used := mini(needed, int(slot.quantity))
					slot.quantity -= used
					needed -= used
					if slot.quantity == 0: slot.item = null
	var remaining := int(recipe.get("quantity",1))
	if recipe.item_id == "bone_arrow" and is_inside_tree():
		var sk = get_tree().get_first_node_in_group("skills")
		if sk and sk.value("arrow_craft") > 0.0: remaining *= 2
	for slot in result:
		if slot.item and slot.item.id == item.id:
			var amount := mini(remaining, maxi(0,item.max_stack-int(slot.quantity)))
			slot.quantity += amount
			remaining -= amount
	for slot in result:
		if remaining == 0: break
		if slot.item == null:
			var amount := mini(remaining,item.max_stack)
			slot.item = item
			slot.quantity = amount
			remaining -= amount
	if remaining > 0:
		last_failure = "Your satchel is full"
		return empty
	return result

# Legacy ingredients argument retained for existing UI; authoritative recipe costs always win.
func try_craft(item_id: String, _ingredients: Dictionary = {}) -> bool:
	var recipe := get_recipe(item_id)
	var result := _simulate(recipe)
	if result.is_empty(): return false
	InventoryManager.inventory = result
	InventoryManager.inventory_changed.emit()
	SignalBus.item_crafted.emit(item_id)
	AudioManager.play_sfx("craft_success")
	return true

func create_item_by_id(id: String) -> Item:
	return ItemDB.make(id)

func get_item_icon(item_id: String) -> Texture2D:
	if item_id.begins_with("any:"): item_id = str(_Foods.group(item_id)[0])
	var item := create_item_by_id(item_id)
	return item.icon if item else null

func get_ingredient_name(item_id: String) -> String:
	if item_id.begins_with("any:"): return _Foods.group_name(item_id)
	var item := create_item_by_id(item_id)
	return item.name if item else item_id.capitalize()
