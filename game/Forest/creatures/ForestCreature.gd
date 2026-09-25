extends CharacterBody2D
## Forest bestiary: crystal growths are the living legacy of the Sky-Fangs.
## Inventory transaction belongs to the caller: consume only when interact().consume.
##
## Dinosaur v2: every clip comes from DinoArt (art/v2, one strip per clip and
## facing) and every attack from DinoMoves (telegraphed wind-ups, contact on
## the clip's hit frame, real hit shapes, knockback). Wild behaviour: herds
## graze and keep together, dodos startle and flee, raptors flank and pounce,
## the rex roars, stalks and charges; heavy bodies accelerate and turn slowly.
signal notice(text: String)

const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const SetBonus = preload("res://Forest/equipment/SetBonus.gd")
const DinoMoves = preload("res://Forest/creatures/DinoMoves.gd")
const Puff = preload("res://Forest/fx/Puff.gd")
const Surface = preload("res://Forest/fx/Surface.gd")
const Bleed = preload("res://Forest/combat/Bleed.gd")
const Life = preload("res://Forest/creatures/Life.gd")
const CreatureLife = preload("res://Forest/creatures/CreatureLife.gd")
## Pass 13: each beast's own way to be won (Kaya teaches them).
const Ways = preload("res://Forest/creatures/TamingWays.gd")
const OFFERING = preload("res://Forest/creatures/Offering.gd")
## Pass 13: each beast its own animal (colours, markings, temperament, traits, stats).
const Genes = preload("res://Forest/creatures/Genes.gd")
## How far out (px from camp) counts as the world's far edge (more mutations there).
const FAR_EDGE := 2800.0

## The rex is the wilds' terror (one in the world, near unkillable on foot:
## bring companions and arrows); the allosaurus is the big hunter a keeper can
## take, and its scales make the finest armour; the alpha is the first boss
## (AlphaBoss.gd), never tamed. feeds: trust a beast needs (see taming below).
const SPECIES := {
	"raptor": {"name":"Shardback Raptor", "hp":75, "speed":53.0, "damage":11, "radius":7.0, "feeds":15, "predator":true, "food":"trex_meat", "width":42, "height":32},
	"rex": {"name":"Emerald Tyrant", "hp":1600, "speed":46.0, "damage":44, "radius":14.0, "feeds":40, "predator":true, "food":"trex_meat", "width":76, "height":56},
	"stego": {"name":"Amberplate Stegosaurus", "hp":380, "speed":23.0, "damage":20, "radius":12.0, "feeds":20, "predator":false, "food":"berry", "width":60, "height":40},
	"trike": {"name":"Jadehorn Triceratops", "hp":360, "speed":29.0, "damage":22, "radius":12.0, "feeds":20, "predator":false, "food":"berry", "width":54, "height":42},
	"longneck": {"name":"Moonstone Longneck", "hp":600, "speed":20.0, "damage":24, "radius":14.0, "feeds":24, "predator":false, "food":"berry", "width":70, "height":60},
	"dodo": {"name":"Sunplume Dodo", "hp":20, "speed":18.0, "damage":2, "radius":5.0, "feeds":2, "predator":false, "food":"berry", "width":20, "height":24},
	"lystro": {"name":"Mossback Lystrosaurus", "hp":24, "speed":20.0, "damage":2, "radius":5.0, "feeds":2, "predator":false, "food":"berry", "width":24, "height":20},
	"allo": {"name":"Rustback Allosaurus", "hp":520, "speed":47.0, "damage":26, "radius":11.0, "feeds":25, "predator":true, "food":"trex_meat", "width":64, "height":46},
	"alpha": {"name":"Skarn, the Shardback Alpha", "hp":1400, "speed":56.0, "damage":26, "radius":13.0, "feeds":0, "predator":true, "food":"trex_meat", "width":84, "height":60, "boss":true},
	# Pass 11: Glassmere's shore-grazers, and the second boss (OssuarBoss.gd).
	"parasaur": {"name":"Crestcaller Parasaur", "hp":240, "speed":30.0, "damage":14, "radius":11.0, "feeds":18, "predator":false, "food":"berry", "width":74, "height":48},
	"ossuar": {"name":"Ossuar, the Buried King", "hp":3200, "speed":40.0, "damage":36, "radius":15.0, "feeds":0, "predator":true, "food":"trex_meat", "width":82, "height":62, "boss":true},
	# Pass 12: the Sunscar Dunes' own beasts (the sail-backed dimetrodon that
	# basks by day, protoceratops herds, the clubbed ankylosaur), two apex
	# hunters for the far wilds (the Scarhorn in the dunes, the Ashmane in
	# the ash of the Pale Lands) and the compy swarms.
	"dimetrodon": {"name":"Sunsail Dimetrodon", "hp":340, "speed":24.0, "damage":20, "radius":10.0, "feeds":16, "predator":true, "food":"trex_meat", "width":60, "height":44},
	"proto": {"name":"Dune Protoceratops", "hp":70, "speed":22.0, "damage":7, "radius":7.0, "feeds":5, "predator":false, "food":"berry", "width":32, "height":24},
	"anky": {"name":"Sandclub Ankylosaur", "hp":900, "speed":16.0, "damage":30, "radius":13.0, "feeds":24, "predator":false, "food":"berry", "width":56, "height":44},
	"carno": {"name":"Scarhorn Carnotaurus", "hp":1150, "speed":50.0, "damage":34, "radius":12.0, "feeds":32, "predator":true, "food":"trex_meat", "width":68, "height":50},
	"yuty": {"name":"Ashmane Yutyrannus", "hp":1900, "speed":44.0, "damage":40, "radius":14.0, "feeds":40, "predator":true, "food":"trex_meat", "width":68, "height":64},
	"compy": {"name":"Compy", "hp":10, "speed":44.0, "damage":3, "radius":4.0, "feeds":3, "predator":true, "food":"trex_meat", "width":20, "height":16},
	# Pass 13: the Mirefen's hunters (reed-running deinonychus packs, the
	# Suchomimus that waits at the water's edge, and its king, the
	# spinosaur, which wades the deep mere itself), and the Bonelands'
	# Sandblade Utahraptors, hunting in pairs.
	"utah": {"name":"Sandblade Utahraptor", "hp":420, "speed":50.0, "damage":24, "radius":9.0, "feeds":26, "predator":true, "food":"trex_meat", "width":52, "height":54},
	"deino": {"name":"Reedstalker Deinonychus", "hp":140, "speed":50.0, "damage":15, "radius":8.0, "feeds":18, "predator":true, "food":"trex_meat", "width":42, "height":44},
	"sucho": {"name":"Mirefang Suchomimus", "hp":880, "speed":38.0, "damage":30, "radius":12.0, "feeds":30, "predator":true, "food":"reed_perch", "width":72, "height":64},
	"spino": {"name":"Sailking Spinosaurus", "hp":2600, "speed":42.0, "damage":48, "radius":16.0, "feeds":44, "predator":true, "food":"reed_perch", "width":108, "height":90},
}
## The great beasts that roam the wilds: a nameplate floats over them when
## the keeper comes near (bosses have the top bar instead).
const MINIBOSS := {"rex": "The Emerald Tyrant", "carno": "Scarhorn", "yuty": "Ashmane", "spino": "The Sailking"}
## Kinds of a species (pass 11): the Pale Hills' crystal-backed hunters, and
## the great roaming beasts of the new regions (mini-bosses, with a nameplate).
##   name: "%s" takes the species' name; title: the mini-boss's own name
##   hp, damage, speed: times the species' · tint: the sprite's colour
##   hostile: comes for the keeper on sight (even a herbivore) · loot: extra
const VARIANTS := {
	"crystal": {"name": "Crystalback %s", "hp": 1.5, "damage": 1.25, "speed": 1.05, "tint": Color(0.84, 0.96, 1.12)},
	"dune": {"title": "Dunestalker", "hp": 3.4, "damage": 1.7, "speed": 1.06, "tint": Color(1.14, 1.02, 0.84), "loot": {"trex_scale": 6, "old_bone": 6}},
	"old": {"title": "Greyhorn, the Old Trike", "hp": 3.6, "damage": 1.5, "speed": 1.1, "tint": Color(0.92, 0.95, 0.92), "hostile": true, "loot": {"trex_scale": 3, "pale_crystal": 2}},
	# The Buried King's thralls (OssuarBoss): drawn in old bone, no meat on them.
	"bone": {"name": "Bone %s", "hp": 0.6, "damage": 0.9, "speed": 1.0, "hostile": true, "bone": true, "loot": {"old_bone": 1}},
	# Pass 12: coats of their own (art: the species' clips recoloured by
	# tools/dino/coats.py into art key <species>_<art>): the dunes' sand-
	# striped raptors, and the Pale Lands' ash-grey ones, shaggy, with the
	# Sky-Fangs' ember glow in their veins.
	"sand": {"name": "Dune %s", "hp": 1.2, "damage": 1.1, "speed": 1.05, "art": "sand"},
	"ash": {"name": "Ashfang %s", "hp": 1.5, "damage": 1.25, "speed": 1.08, "art": "ash", "loot": {"crystal_shard": 1}},
}
const BONE_LOOK := preload("res://Forest/creatures/bone.gdshader")
## Taming. The dodo and the lystrosaurus eat from any hand. Everything else
## needs patience: after each feed (once it has eaten, FEED_WAIT) it must SETTLE
## with the keeper at a distance before it will take another; a keeper who
## hangs about within SPACE px while it isn't eating makes it uneasy, and
## UNEASE seconds of that and it lashes out and forgets two feeds. Predators
## are netted first (NET_TIME), which knocks them down to the ground.
const EASY := ["dodo", "lystro"]
## The small herd beasts that bolt from danger and only peck when cornered.
const SKITTISH := ["dodo", "lystro", "proto"]
const FEED_WAIT := {"dodo": 1.6, "lystro": 1.6, "raptor": 2.2, "allo": 2.4, "rex": 2.6, "carno": 2.6, "yuty": 2.6, "dimetrodon": 2.2, "compy": 1.6,
	"deino": 2.2, "utah": 2.4, "sucho": 2.6, "spino": 2.8}
const SETTLE := 6.0
const SPACE := 46.0
const UNEASE := 3.5
const NET_TIME := {"raptor": 15.0, "allo": 12.0, "rex": 8.0, "carno": 8.0, "yuty": 7.0, "dimetrodon": 12.0, "compy": 20.0,
	"deino": 14.0, "utah": 10.0, "sucho": 8.0, "spino": 6.0}
## What each predator hunts when nothing else calls it (raptors take the big
## herbivores only as a pack of three or more; the rex takes anything).
const PREY := {"raptor": ["dodo", "lystro", "proto", "compy"], "allo": ["dodo", "lystro", "stego", "trike", "raptor", "proto", "dimetrodon"],
	"rex": ["dodo", "lystro", "stego", "trike", "longneck", "raptor", "allo", "proto", "dimetrodon", "parasaur"],
	"dimetrodon": ["dodo", "lystro", "proto", "compy"],
	"carno": ["dodo", "lystro", "proto", "dimetrodon", "raptor", "stego", "trike", "parasaur"],
	"yuty": ["dodo", "lystro", "raptor", "stego", "trike", "longneck", "parasaur", "proto"],
	"compy": ["dodo", "lystro"],
	"utah": ["dodo", "lystro", "proto", "raptor", "parasaur", "stego"],
	"deino": ["dodo", "lystro", "parasaur", "compy"],
	"sucho": ["dodo", "lystro", "parasaur", "deino"],
	"spino": ["dodo", "lystro", "parasaur", "stego", "trike", "longneck", "deino", "sucho", "raptor"]}
## Territory (pass 12): the great hunters won't share ground. Two rivals that
## meet square up and fight; badly hurt, one breaks off (_rival_check) and the
## winner lets it go with a roar. Against the keeper they fight to the end.
const RIVALS := {"rex": ["carno", "yuty", "spino"], "carno": ["rex", "yuty", "allo"], "yuty": ["rex", "carno", "allo"], "allo": ["carno", "yuty", "utah"],
	"spino": ["rex", "sucho"], "sucho": ["spino"], "utah": ["allo"]}
const DISPUTE_RANGE := 170.0
## Bony plates shrug off this much of every blow (heavy weapons get through).
const PLATED := {"anky": 9}
const PACK_PREY := ["stego", "trike"]
## Pass 13: every beast moves at PACE of its species' speed ("everyone's too
## speedy"). BODY.chase is its run-down speed (the big hunters still just beat
## a keeper's sprint of 88, which only lasts a breath). walk/run are stride
## speeds for the clips (not scaled: the clips just play slower).
const PACE := 0.72
## How each body moves and animates. accel: px/s^2 (heavy bodies build up and
## shed speed slowly). walk/run: ground speed at which the clip's feet do not
## slide (speed_scale follows the real speed). run_at: speed that switches to
## the run clip. armour: keeps attacking through hits instead of flinching.
## idle: the clip it plays now and then while resting.
const BODY := {
	"raptor": {"accel": 420.0, "walk": 26.0, "run": 58.0, "run_at": 34.0, "armour": false, "idle": "sniff", "idle_every": 7.0, "chase": 98.0, "tire": 14.0},
	"rex": {"accel": 150.0, "walk": 26.0, "run": 70.0, "run_at": 56.0, "armour": true, "idle": "roar", "idle_every": 26.0, "heavy_steps": true, "chase": 92.0, "tire": 9.0},
	"stego": {"accel": 120.0, "walk": 15.0, "run": 15.0, "run_at": 999.0, "armour": true, "idle": "eat", "idle_every": 6.0, "chase": 40.0, "tire": 5.0},
	"trike": {"accel": 170.0, "walk": 18.0, "run": 60.0, "run_at": 40.0, "armour": true, "idle": "eat", "idle_every": 6.5, "chase": 76.0, "tire": 6.0},
	"longneck": {"accel": 90.0, "walk": 14.0, "run": 14.0, "run_at": 999.0, "armour": true, "idle": "eat", "idle_every": 7.0, "heavy_steps": true, "chase": 30.0, "tire": 5.0},
	"dodo": {"accel": 360.0, "walk": 11.0, "run": 30.0, "run_at": 22.0, "armour": false, "idle": "eat", "idle_every": 4.0, "chase": 38.0, "tire": 4.0},
	"lystro": {"accel": 320.0, "walk": 10.0, "run": 26.0, "run_at": 20.0, "armour": false, "idle": "eat", "idle_every": 4.5, "chase": 34.0, "tire": 4.0},
	"allo": {"accel": 260.0, "walk": 24.0, "run": 62.0, "run_at": 40.0, "armour": true, "idle": "roar", "idle_every": 24.0, "heavy_steps": true, "chase": 94.0, "tire": 11.0},
	"alpha": {"accel": 400.0, "walk": 30.0, "run": 66.0, "run_at": 38.0, "armour": true, "idle": "idle", "idle_every": 9.0, "heavy_steps": true, "chase": 100.0, "tire": 40.0},
	"parasaur": {"accel": 200.0, "walk": 17.0, "run": 52.0, "run_at": 36.0, "armour": false, "idle": "eat", "idle_every": 6.0, "chase": 64.0, "tire": 6.0},
	"ossuar": {"accel": 140.0, "walk": 24.0, "run": 60.0, "run_at": 50.0, "armour": true, "idle": "roar", "idle_every": 20.0, "heavy_steps": true, "chase": 72.0, "tire": 60.0},
	# Pass 12. The dimetrodon sprints in short bursts (a cold-blooded
	# ambusher); the carnotaurus is the fastest big hunter there is.
	"dimetrodon": {"accel": 190.0, "walk": 15.0, "run": 46.0, "run_at": 30.0, "armour": true, "idle": "idle", "idle_every": 9.0, "chase": 68.0, "tire": 4.0},
	"proto": {"accel": 300.0, "walk": 16.0, "run": 32.0, "run_at": 24.0, "armour": false, "idle": "eat", "idle_every": 5.0, "chase": 46.0, "tire": 5.0},
	"anky": {"accel": 90.0, "walk": 30.0, "run": 30.0, "run_at": 999.0, "armour": true, "idle": "eat", "idle_every": 7.0, "heavy_steps": true, "chase": 32.0, "tire": 5.0},
	# (walk/run: stride.py on its PixelLab clips; pass 13 retired the Blender Scarhorn)
	"carno": {"accel": 330.0, "walk": 26.0, "run": 55.0, "run_at": 44.0, "armour": true, "idle": "roar", "idle_every": 22.0, "heavy_steps": true, "chase": 108.0, "tire": 8.0},
	"yuty": {"accel": 170.0, "walk": 30.0, "run": 66.0, "run_at": 52.0, "armour": true, "idle": "roar", "idle_every": 24.0, "heavy_steps": true, "chase": 94.0, "tire": 12.0},
	"compy": {"accel": 640.0, "walk": 10.0, "run": 48.0, "run_at": 26.0, "armour": false, "idle": "idle", "idle_every": 3.0, "chase": 86.0, "tire": 18.0},
	# Pass 13's beasts (walk/run from stride.py once their clips are in).
	"utah": {"accel": 360.0, "walk": 22.0, "run": 64.0, "run_at": 36.0, "armour": false, "idle": "idle", "idle_every": 8.0, "chase": 100.0, "tire": 12.0},
	"deino": {"accel": 420.0, "walk": 16.0, "run": 44.0, "run_at": 34.0, "armour": false, "idle": "idle", "idle_every": 7.0, "chase": 96.0, "tire": 14.0},
	"sucho": {"accel": 200.0, "walk": 28.0, "run": 56.0, "run_at": 40.0, "armour": true, "idle": "roar", "idle_every": 26.0, "heavy_steps": true, "chase": 80.0, "tire": 7.0},
	"spino": {"accel": 150.0, "walk": 31.0, "run": 66.0, "run_at": 50.0, "armour": true, "idle": "roar", "idle_every": 30.0, "heavy_steps": true, "chase": 84.0, "tire": 9.0}
}
@export var species: String = "raptor"
## A baby (pass 11): half size, a third of the health, never fights (it runs
## to its mother, whose kin charge anyone who comes near), tames in a few
## feeds, and grows up over Life.GROW_TIME. Hatched ones are born tamed.
var baby := false
var growth := 0.0
## A kind of the species (VARIANTS), "" for the usual.
var variant := ""
var _tint := Color.WHITE
## Hunger, thirst, goals, nests and mothers (CreatureLife.gd).
var life
var stats: Dictionary
var body: Dictionary
var health: int
var tamed := false
var trust := 0
const ORDERS := ["follow", "stay", "guard", "roam", "work", "return", "lead", "tether"]
## Pass 13: a companion's care. Saddlebags (BeastBag); a lead rope (it heels
## close, LEAD_GAP, and never picks a fight) or a hitching post (it keeps
## within TETHER_REACH of it); a little training now and then (Genes).
const BEAST_BAG = preload("res://Forest/creatures/BeastBag.gd")
const LEAD_GAP := 22.0
const TETHER_REACH := 26.0
const TRAIN_REST := 600.0
const TRAIN_FOOD := 4
const NO_POST := Vector2i(9999, 9999)
var bag: Node = null
var tether_cell := NO_POST
## Pass 13: beasts break things. A hunter (or a provoked beast) blocked on its
## way by the keeper's building bashes through it, slowly: SIEGE_SECONDS over
## a timber wall, door or gate (STONE_SLOW times that over stone). The keeper's
## tools are far quicker. The big beasts shoulder through trees in the way.
const SIEGE_SECONDS := {"rex": 35.0, "spino": 35.0, "anky": 40.0, "carno": 45.0, "yuty": 45.0, "trike": 45.0,
	"longneck": 50.0, "stego": 55.0, "allo": 55.0, "sucho": 60.0, "alpha": 60.0, "ossuar": 45.0, "utah": 90.0,
	"dimetrodon": 90.0, "parasaur": 90.0, "raptor": 150.0, "deino": 140.0}
const TREE_BREAKERS := ["rex", "spino", "anky", "longneck", "stego", "trike", "carno", "yuty", "ossuar"]
const TREES := ["tree", "palm", "pine", "birch", "dead_tree"]
## Pass 13: the Mirefen's water hunters. In water they keep most of their pace
## (AQUATIC: the rest wade at WATER_SPEED_MULTIPLIER); the spinosaur walks
## into the deep mere, and the Suchomimus waits in the shallows at the edge
## (LURK: it keeps to water near home while it has nothing to hunt).
const AQUATIC := {"sucho": 0.9, "spino": 0.85}
const DEEP_WADERS := ["spino"]
const LURK := ["sucho"]
const STONE_BUILT := ["stone_wall", "stone_door", "stone_floor"]
const STONE_SLOW := 2.2
const TREE_SECONDS := 7.0
var _siege_cell := NO_POST
var _siege_swing := 0.0
var _train_rest := 0.0
const STANCES := ["neutral", "passive", "aggressive"]
const WATER_SPEED_MULTIPLIER := 40.0 / 76.0
var order := "follow"
var stance := "neutral"
var in_water := false
var _order_anchor := Vector2.ZERO
var _anchor_restored := false
var _threat: Node2D
var net_time := 0.0
var feed_cooldown := 0.0
var provoked_time := 0.0
## Taming patience: settle counts down only while the keeper keeps away;
## unease builds while they crowd a beast that isn't eating.
var settle := 0.0
var unease := 0.0
## After a kill a predator leaves prey alone for a while.
var sated := 0.0
## A boss resting in its den ignores everything until woken (AlphaBoss), or
## until something strikes it.
var dormant := false
## Enraged (bosses): moves come round faster and the body runs harder.
var haste := 1.0
## Pass 12: running down a target costs wind. Seconds spent chasing hard; once
## past the body's "tire" it is winded (cruising speed) for a while.
var _chase_time := 0.0
var _winded := 0.0
## Beaten by a rival (another wild hunter, never the keeper): it breaks off
## and runs from it for a while.
var _retreat_from: Node2D
var _retreat_time := 0.0
## Stuck against rocks: a sidestep, then paths round (A*) for a while.
var _stuck_clock := 0.0
var _stuck_from := Vector2.INF
var _stuck_side := 1.0
var _unstick_time := 0.0
var _unstick_dir := Vector2.ZERO
var _path_boost := 0.0
## Out of reach for a moment (the Buried King under the sand): no blow lands.
var untouchable := false
## A territorial fight (pass 12): the rival it squared up to, and how long
## before it will pick another.
var _disputing: Node2D
var _dispute_scan := 0.0
var _dispute_rest := 0.0
## A tribe's beast (pass 12, Forest/tribes): it keeps to its tribesman, fights
## what they fight and, a raiding tribe's, comes for the keeper. When its
## master falls it goes wild.
var master: Node2D
var is_dead := false
var state := "wander"
var home := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_time := 0.0
var _attack_time := 0.0
var _attack_target: Node2D
var _attack_hit := false
var _hurt_time := 0.0
var bleed = Bleed.new()
var _bleed_flash := 0.0
var _clock := 0.0
var _facing := "side"
var _face_hold := 0.0
var _player: Node2D
var _world: Node
var _sprite: AnimatedSprite2D
var _rng := RandomNumberGenerator.new()
var saddle: Item
var _mount_controller: Node2D
var worker = preload("res://Forest/creatures/CreatureWorker.gd").new()
var _worker_restore: Dictionary = {}
var voice: Node2D
var _attack_aim := Vector2.RIGHT
var _attack_duration := 0.85
var _path := PackedVector2Array()
var _path_goal := Vector2.INF
var _path_refresh := 0.0
var _work_swing_time := 0.0
var _work_aim := Vector2.UP
var _work_audio: AudioStreamPlayer2D
## v2 animation and behaviour
var moves: DinoMoves
var art_key := ""
var _clip := ""
var _flinch := 0.0
var _knock := Vector2.ZERO
var _action := ""
var _action_time := 0.0
var _idle_timer := 0.0
var _flee_time := 0.0
var _roared := false
## Pass 13: nothing attacks out of nowhere. The first time a beast goes for the
## keeper, a companion or one of the tribes' folk (and again once it has been
## calm a while), it shows it first: it turns to face them, a "!" rises over
## its head, and it makes its display (a threat, a roar, a paw at the ground)
## for ALERT_TIME seconds, holding its ground. Then it comes. Struck first, it
## answers faster. Bosses stage their own entrances.
const ALERT_TIME := {"rex": 1.0, "allo": 0.9, "carno": 0.8, "yuty": 1.0, "dimetrodon": 0.75,
	"utah": 0.7, "deino": 0.55, "sucho": 0.5, "spino": 1.1,
	"raptor": 0.6, "compy": 0.5, "trike": 0.9, "stego": 0.9, "longneck": 1.0, "anky": 0.9,
	"parasaur": 0.8, "proto": 0.6, "dodo": 0.4, "lystro": 0.4}
const ALERT_STRUCK := 0.35
## A herbivore's ground: how far from home it will drive a threat, and how far
## off the threat must keep before it's let go.
const WARD_LEASH := 150.0
const WARD_GAP := 110.0
## A herbivore's space: a keeper this close gets its display (a paw, a bellow),
## a warning only, every WARN_EVERY seconds.
const COMFORT := {"trike": 50.0, "stego": 52.0, "longneck": 58.0, "anky": 48.0, "parasaur": 44.0}
const WARN_EVERY := 9.0
var _ward_out := 0.0
## A grazer's look up at a keeper running by (pass 13).
var _look_time := 0.0
var _look_rest := 0.0
## Taming ways (pass 13, TamingWays): stands, cleared rocks, respect or dodged
## charges earned; a respect run under way; a stand being watched; an
## offering it's going to eat; a calm beast's startle cooldown.
var tame_marks := 0
## This beast's genes (Genes.gd): rolled when it's first made, saved with it.
var genes := {}
var _respect_run := 0.0
var _stand_watch := 0.0
var _offer: Node2D = null
var _offer_scan := 0.0
var _startle_wait := 0.0
## Height of a leap off the ground (DinoMoves' pounce): the drawing rises, the
## shadow stays and shrinks.
var hop := 0.0 : set = _set_hop
var _sprite_base := Vector2.ZERO

func _set_hop(value: float) -> void:
	hop = maxf(0.0, value)
	if _sprite: _sprite.position = _sprite_base - Vector2(0.0, roundf(hop))
	queue_redraw()
## The display, the first of these the beast's art has.
const ALERT_CLIPS := ["threat", "roar", "windup", "stomp", "sniff"]
var _alert_left := 0.0
var _alert_mark := 0.0
var _alerted_for: Node2D = null
var _calm_for := 0.0
var _struck_clock := 0.0
var _warned := 0.0
var _orbit_sign := 1.0
var _step_frame := -1
var _fx_audio: AudioStreamPlayer2D
var _flinch_ready := 0.0
## The body's own steering velocity; knockback (_knock) is layered on top of
## it each frame, never folded into it.
var _move_velocity := Vector2.ZERO
## Looks round a few times a second (staggered across the herd), not every
## tick: the wild target, a hunter bearing down, and the way round rocks.
var _hunt_target: Node2D
var _hunt_none := false
var _hunt_scan := 0.0
var _hunter: Node2D
var _hunter_scan := 0.0
var _avoid_angle := 0.0
var _avoid_for := 0
var _avoid_last := Vector2.ZERO
var body_radius := 8.0
## Every creature, gathered once a physics tick (the group query copies the
## list each time, and each creature looks round several times a tick).
## A creature arriving or leaving starts a fresh list.
static var _roster: Array = []
static var _roster_tick := -1

static func roster(tree: SceneTree) -> Array:
	var tick := Engine.get_physics_frames()
	if tick != _roster_tick:
		_roster_tick = tick
		_roster = tree.get_nodes_in_group("forest_creatures")
	return _roster

## The creatures within `radius` of a point, give or take a bucket: the roster
## sorted into BUCKET-px squares once a physics tick (pass 11: the wilds hold
## ~180 beasts, and every one asks after its neighbours).
const BUCKET := 64.0
static var _buckets := {}
static var _bucket_tick := -1

static func near(tree: SceneTree, at: Vector2, radius: float) -> Array:
	var tick := Engine.get_physics_frames()
	if tick != _bucket_tick or _roster_tick == -1:
		var all := roster(tree)
		_bucket_tick = tick
		_buckets.clear()
		for c in all:
			if not is_instance_valid(c): continue
			var k := Vector2i(floori(c.global_position.x / BUCKET), floori(c.global_position.y / BUCKET))
			if not _buckets.has(k): _buckets[k] = []
			_buckets[k].append(c)
	var out: Array = []
	var r := int(ceil(radius / BUCKET))
	var k0 := Vector2i(floori(at.x / BUCKET), floori(at.y / BUCKET))
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var bucket = _buckets.get(k0 + Vector2i(x, y))
			if bucket: out.append_array(bucket)
	return out

func _enter_tree() -> void:
	_roster_tick = -1
	_bucket_tick = -1

func _exit_tree() -> void:
	_roster_tick = -1
	_bucket_tick = -1

func _ready() -> void:
	if not SPECIES.has(species): species = "raptor"
	if baby and not Life.has_young(species): baby = false
	# Its own animal: genes rolled from where it was born (never a boss's).
	if genes.is_empty() and not bool(SPECIES[species].get("boss", false)):
		var grng := RandomNumberGenerator.new()
		grng.seed = int(position.x * 735 + position.y * 97) + species.hash() + 7919
		genes = Genes.roll(grng, clampf(position.length() / FAR_EDGE, 0.0, 1.0))
	_stage_stats()
	health = int(stats.hp) if health <= 0 else health
	home = position
	if not _anchor_restored: _order_anchor = global_position
	_rng.seed = int(position.x * 735 + position.y * 97) + species.hash()
	_orbit_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	_idle_timer = _rng.randf_range(1.5, float(body.idle_every))
	# A wild hunter starts out fed (a journey's first minutes aren't one
	# bloodbath of every hunter on the nearest prey at once); the keeper
	# coming close is another matter.
	if bool(stats.predator) and not tamed and not bool(stats.get("boss", false)):
		sated = maxf(sated, _rng.randf_range(20.0, 100.0))
	add_to_group("forest_creatures")
	add_to_group("enemies")
	collision_layer = 2
	# Walls (16) and deep water (32): no beast wades into Glassmere's depths.
	collision_mask = 48
	# The spinosaur wades the deep mere itself (pass 13): only walls stop it.
	if species in DEEP_WADERS: collision_mask = 16
	var shape_node := CollisionShape2D.new()
	shape_node.name = "BodyShape"
	var shape := CircleShape2D.new()
	shape.radius = float(stats.radius)
	shape_node.shape = shape
	add_child(shape_node)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 4
	var hurt_shape := CollisionShape2D.new()
	var hit := CircleShape2D.new()
	hit.radius = float(stats.radius) + 5.0
	hurt_shape.shape = hit
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	moves = DinoMoves.new(self)
	_apply_art()
	_player = get_tree().get_first_node_in_group("player")
	if not _player: _player = get_tree().root.find_child("Player", true, false)
	_world = get_tree().get_first_node_in_group("forest_world")
	worker.creature=self
	worker.anchor=global_position
	if not _worker_restore.is_empty(): worker.restore(_worker_restore)
	voice=preload("res://Forest/creatures/CreatureAudio.gd").new()
	add_child(voice)
	_work_audio=AudioStreamPlayer2D.new()
	_work_audio.bus="SFX"
	_work_audio.volume_db=-20
	_work_audio.max_distance=200
	_work_audio.attenuation=1.8
	add_child(_work_audio)
	_fx_audio=AudioStreamPlayer2D.new()
	_fx_audio.bus="SFX"
	_fx_audio.max_distance=320
	_fx_audio.attenuation=1.5
	add_child(_fx_audio)
	_mount_controller = preload("res://Forest/creatures/MountController.gd").new()
	add_child(_mount_controller)
	life = CreatureLife.new(self)
	life.begin()
	if MINIBOSS.has(species):
		var plate = preload("res://Forest/creatures/Nameplate.gd").new()
		add_child(plate)
		plate.setup(self, str(MINIBOSS[species]))
	queue_redraw()


## Stats and body for this stage of life (a baby's are its parent's, scaled).
func _stage_stats() -> void:
	stats = Life.baby_stats(SPECIES[species], species) if baby else SPECIES[species]
	body = Life.baby_body(BODY[species]) if baby else BODY[species]
	_tint = Color.WHITE
	if VARIANTS.has(variant) and not baby:
		var v: Dictionary = VARIANTS[variant]
		stats = stats.duplicate()
		stats.hp = int(round(float(stats.hp) * float(v.get("hp", 1.0))))
		stats.damage = int(round(float(stats.damage) * float(v.get("damage", 1.0))))
		stats.speed = float(stats.speed) * float(v.get("speed", 1.0))
		if v.has("title"): stats.name = str(v.title)
		elif v.has("name"): stats.name = str(v.name) % str(stats.name).split(" ")[-1]
		if bool(v.get("hostile", false)): stats.predator_like = true
		_tint = v.get("tint", Color.WHITE)
	stats = stats.duplicate()
	if not genes.is_empty():
		stats.hp = maxi(1, int(round(float(stats.hp) * Genes.stat_mult(genes, "hp"))))
		stats.damage = maxi(1, int(round(float(stats.damage) * Genes.stat_mult(genes, "damage"))))
		stats.speed = float(stats.speed) * Genes.stat_mult(genes, "speed")
	stats.speed = float(stats.speed) * PACE
	body_radius = float(stats.radius)


## Become a kind of the species after spawning (a Crystalback, a mini-boss).
func set_variant(value: String) -> void:
	if value != "" and not VARIANTS.has(value): value = ""
	var fraction := float(health) / maxf(1.0, float(stats.hp)) if stats else 1.0
	variant = value
	_stage_stats()
	health = maxi(1, int(round(fraction * float(stats.hp))))
	if _sprite:
		_apply_art()
		if bool(VARIANTS.get(value, {}).get("bone", false)):
			var look := ShaderMaterial.new()
			look.shader = BONE_LOOK
			_sprite.material = look
		elif _sprite.material is ShaderMaterial and (_sprite.material as ShaderMaterial).shader == BONE_LOOK:
			_sprite.material = null
	if VARIANTS.get(value, {}).has("title") and get_node_or_null("Nameplate") == null:
		var plate = preload("res://Forest/creatures/Nameplate.gd").new()
		add_child(plate)
		plate.setup(self, str(stats.name))


## Become (or stop being) a baby after spawning: stats, size and clips follow.
func set_baby(value: bool, grown := 0.0) -> void:
	if value and not Life.has_young(species): value = false
	var fraction := float(health) / maxf(1.0, float(stats.hp)) if stats else 1.0
	baby = value
	growth = clampf(grown, 0.0, 1.0) if value else 0.0
	_stage_stats()
	health = maxi(1, int(round(fraction * float(stats.hp))))
	var shape_node := get_node_or_null("BodyShape")
	if shape_node: shape_node.shape.radius = float(stats.radius)
	var hurt := get_node_or_null("Hurtbox")
	if hurt and hurt.get_child_count() > 0: hurt.get_child(0).shape.radius = float(stats.radius) + 5.0
	if _sprite: _apply_art()
	queue_redraw()


## A baby grown: full size, its parent's stats and clips.
func grow_up() -> void:
	if not baby: return
	set_baby(false)
	if tamed:
		notice.emit("Your %s has grown up!" % str(Life.SHORT.get(species, stats.name)).to_lower())
	SignalBus.creature_grew.emit(self)

## Halt the body: steering, velocity and any shove (orders, mounting, strikes).
func stop() -> void:
	velocity = Vector2.ZERO
	_move_velocity = Vector2.ZERO
	_knock = Vector2.ZERO

## The art this body wears: the species, or its saddled variant.
func wanted_art_key() -> String:
	var key := species
	if baby and DinoArt.has_key(species + "_baby"): return species + "_baby"
	var coat := str(VARIANTS.get(variant, {}).get("art", ""))
	if coat != "" and not saddle and DinoArt.has_key(species + "_" + coat): return species + "_" + coat
	if saddle and DinoArt.has_key(species + "_saddle"): key = species + "_saddle"
	return key

## Switch to the bare or saddled clips, keeping the current clip and frame.
func _apply_art() -> void:
	var key := wanted_art_key()
	var frames := DinoArt.frames(key)
	if key == art_key and _sprite.sprite_frames == frames: return
	art_key = key
	var anim: StringName = _sprite.animation
	var frame := _sprite.frame
	_sprite.sprite_frames = frames
	_sprite_base = DinoArt.sprite_offset(key)
	_sprite.position = _sprite_base - Vector2(0.0, roundf(hop))
	if frames.has_animation(anim):
		_sprite.play(anim)
		_sprite.set_frame_and_progress(mini(frame, frames.get_frame_count(anim) - 1), 0.0)
	elif frames.has_animation("idle_" + _facing):
		_sprite.play("idle_" + _facing)
		_clip = "idle"
	_apply_genes_look()

## Its genes' colours on the sprite (genes.gdshader); a bone thrall keeps its bone.
func _apply_genes_look() -> void:
	if not _sprite or not _sprite.sprite_frames: return
	if bool(VARIANTS.get(variant, {}).get("bone", false)): return
	var ours: bool = _sprite.material is ShaderMaterial and (_sprite.material as ShaderMaterial).shader == Genes.SHADER
	if genes.is_empty():
		if ours: _sprite.material = null
		return
	var anim := "idle_side" if _sprite.sprite_frames.has_animation("idle_side") else str(_sprite.animation)
	var tex: Texture2D = _sprite.sprite_frames.get_frame_texture(anim, 0) if _sprite.sprite_frames.has_animation(anim) else null
	var size: Vector2 = tex.get_size() if tex else Vector2(64, 64)
	if ours: Genes.apply(_sprite.material, genes, size)
	else: _sprite.material = Genes.material(genes, size)

## New genes (a hatchling of the keeper's own pair): stats and look follow.
func set_genes(value: Dictionary, keep_health := false) -> void:
	var fraction := float(health) / maxf(1.0, float(stats.hp)) if stats else 1.0
	genes = Genes.clean(value)
	_stage_stats()
	if keep_health and health > 0: health = clampi(health, 1, int(stats.hp))
	else: health = maxi(1, int(round(fraction * float(stats.hp))))
	_apply_genes_look()

## Off screen and not mid-move, a wild beast lives at a slower rate: every
## second tick once it's more than VIEW_MARGIN px outside the view, every
## fourth far away (past LAZY_RANGE), every 16th further (FAR_RANGE) and every
## 32nd out in the far wilds (REMOTE_RANGE), moving as far as those ticks
## would take it. In or near the view, tamed, or striking: every tick. (Pass
## 12: the world holds ~240 beasts, nearly all of them far off on any tick.)
const LAZY_RANGE := 640.0
## Half the view (the game draws 480 x 270 world px round the keeper), and the
## room past its edges that still counts as in view: big bodies reach in, and
## the camera leads the keeper a little.
const HALF_VIEW := Vector2(240.0, 135.0)
const VIEW_MARGIN := 110.0
## Heard this far off (the loudest voice carries 460 px).
const EARSHOT := 520.0
const FAR_RANGE := 1400.0
const REMOTE_RANGE := 2400.0
const HIDE_RANGE := 760.0
const CLOSE_FIGHT := 110.0
var _lazy_delta := 0.0
## Ticks to bank before the next full one. Between full ticks a lazy beast
## does nothing else (the step is judged afresh on each full tick); a blow,
## a tame or a mount ends the wait at once (`wake`).
var _lazy_wait := 0

func _lazy_step() -> int:
	if not is_instance_valid(_player): return 1
	var rel := global_position - _player.global_position
	var d2 := rel.length_squared()
	# Far off screen, not drawn at all (the renderer walks every visible item),
	# and out of earshot its voice rests.
	visible = d2 < HIDE_RANGE * HIDE_RANGE or is_mounted()
	if is_instance_valid(voice): voice.set_process(d2 < EARSHOT * EARSHOT)
	if tamed or moves.busy(): return 1
	# Close combat runs at full rate wherever it is: a lazy stride carries a
	# hunter right into its foe, and jaws that close on a body already inside
	# them miss (a far rex could chew on a stego for seconds without a bite).
	if _close_foe(): return 1
	if d2 > REMOTE_RANGE * REMOTE_RANGE: return 32
	if d2 > FAR_RANGE * FAR_RANGE: return 16
	if d2 > LAZY_RANGE * LAZY_RANGE: return 4
	if absf(rel.x) - HALF_VIEW.x > VIEW_MARGIN or absf(rel.y) - HALF_VIEW.y > VIEW_MARGIN: return 2
	return 1

## Hunting or striking a foe within CLOSE_FIGHT. The foe moves on its own
## ticks, so a lazy hunter asks this every tick, even while it waits.
func _close_foe() -> bool:
	if state != "hunt" and state != "attack" and state != "alert": return false
	var foe: Node2D = _threat if provoked_time > 0.0 and is_instance_valid(_threat) else (_hunt_target if is_instance_valid(_hunt_target) else null)
	return foe != null and global_position.distance_squared_to(foe.global_position) < CLOSE_FIGHT * CLOSE_FIGHT

## Mid-move, hunting, defending or on the run: what it does now decides a
## fight, seen or not.
func _in_fight() -> bool:
	return moves.busy() or state in ["hunt", "attack", "defend", "flee"] or provoked_time > 0.0

## Back to full rate on the next tick (struck, tamed, mounted, or the keeper
## put down nearby).
func wake() -> void:
	_lazy_wait = 0

## Every beast back to full rate: the keeper was moved (a respawn, a test).
static func wake_all(tree: SceneTree) -> void:
	for c in roster(tree):
		if is_instance_valid(c): c._lazy_wait = 0

func _physics_process(delta: float) -> void:
	if is_dead: return
	if _lazy_wait > 0 and not _close_foe():
		_lazy_wait -= 1
		_lazy_delta += delta
		return
	_lazy_wait = 0
	var step := _lazy_step()
	if step > 1:
		_lazy_delta += delta
		# Staggered: each beast's full ticks fall on its own slot of the
		# cycle, so the far ones never all think on the same tick.
		var slot := (Engine.get_physics_frames() + get_instance_id()) % step
		if slot != 0:
			_lazy_wait = step - slot - 1
			return
		_lazy_wait = step - 1
		delta = _lazy_delta
	_lazy_delta = 0.0
	_clock += delta
	if life: life.tick(delta)
	if baby:
		# The keeper's own young grow faster for a breeder's care (pass 13).
		var care := 1.0
		if tamed:
			var sk := skills()
			if sk: care += sk.value("growth_speed")
		growth += delta * care / float(Life.GROW_TIME.get(species, 600.0))
		if growth >= 1.0: grow_up()
	feed_cooldown = maxf(0.0, feed_cooldown - delta)
	provoked_time = maxf(0.0, provoked_time - delta)
	sated = maxf(0.0, sated - delta)
	_winded = maxf(0.0, _winded - delta)
	_retreat_time = maxf(0.0, _retreat_time - delta)
	_path_boost = maxf(0.0, _path_boost - delta)
	_hunt_scan -= delta
	_hunter_scan -= delta
	_dispute_scan -= delta
	_dispute_rest = maxf(0.0, _dispute_rest - delta)
	_tick_patience(delta)
	_tick_taming(delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_alert_left = maxf(0.0, _alert_left - delta)
	_alert_mark = maxf(0.0, _alert_mark - delta)
	_struck_clock = maxf(0.0, _struck_clock - delta)
	_bleed_flash = maxf(0.0, _bleed_flash - delta)
	var bled: int = bleed.tick(delta)
	if bled > 0:
		_bleed_hurt(bled)
		if is_dead: return
	bleed.drip(delta, _world if is_instance_valid(_world) else get_parent(), global_position, float(stats.height) * 0.45)
	_flinch = maxf(0.0, _flinch - delta)
	_warned = maxf(0.0, _warned - delta)
	_flinch_ready = maxf(0.0, _flinch_ready - delta)
	_face_hold = maxf(0.0, _face_hold - delta)
	_work_swing_time=maxf(0,_work_swing_time-delta)
	if _action_time > 0.0:
		_action_time = maxf(0.0, _action_time - delta)
		if _action_time <= 0.0: _action = ""
	_sprite.modulate = Color(1.8, 1.6, 1.3) if _hurt_time > 0 else (Color(1.3, 0.74, 0.74) if _bleed_flash > 0 else _tint)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if is_mounted():
		_mount_controller.update_mounted(delta)
		queue_redraw()
		return
	# Passive companions never keep a blow going, even one already wound up.
	if tamed and stance == "passive" and moves.busy() and not moves.mounted:
		moves.cancel()
	var move_velocity := moves.tick(delta)
	_attack_time = moves.remaining()
	if not moves.busy(): _attack_target = null
	var wanted := Vector2.ZERO
	if net_time > 0.0:
		net_time = maxf(0.0, net_time - delta)
		state = "netted"
		if moves.busy(): moves.cancel()
		_attack_time = 0.0
	elif moves.busy():
		state = "attack"
	elif _flinch > 0.0:
		state = "hurt"
	elif tamed:
		state = order
		var hostile := _companion_target()
		if hostile:
			state = "defend"
			wanted = _approach_or_attack(hostile)
			# Stay means stand your ground, including during combat.
			if order == "stay": wanted = Vector2.ZERO
		elif order in ["work","return"]:
			wanted=worker.update(delta)
		elif order == "follow" and is_instance_valid(_player):
			var goal:=_follow_position()
			var lag:=global_position.distance_to(goal)
			# Close by, a stroll; fallen behind, it hurries: a light beast up to a
			# keeper's sprint, a heavy one to a little over the keeper's walk (at
			# most 2.6 times its own pace), so it keeps up with a walking keeper
			# and lags a sprinting one.
			if lag>12: wanted=_navigate_to(goal,delta)*clampf(lag/40.0,1.3,clampf(96.0/maxf(1.0,float(stats.speed)),1.3,2.6))
		elif order == "lead" and is_instance_valid(_player):
			var gap := global_position.distance_to(_player.global_position)
			if gap > 120.0:
				set_order("follow")
				notice.emit("The lead rope slips: %s follows on its own." % str(stats.name))
			elif gap > LEAD_GAP + 4.0:
				var heel: Vector2 = _player.global_position + _player.global_position.direction_to(global_position) * LEAD_GAP
				wanted = _navigate_to(heel, delta) * clampf(gap / 30.0, 1.0, 2.6)
		elif order == "tether":
			var post := Vector2(tether_cell * 16) + Vector2(8, 8)
			var p = _world.props.get(tether_cell) if is_instance_valid(_world) else null
			if not is_instance_valid(p) or p.kind != "hitching_post":
				# The post is gone: it stays where it stands, the rope on the ground.
				set_order("stay")
			elif global_position.distance_to(post) > TETHER_REACH:
				wanted = global_position.direction_to(post) * float(stats.speed) * 0.7
			else:
				wanted = _wander_velocity(delta, post, TETHER_REACH * 0.6) * 0.5
		elif order == "guard":
			if global_position.distance_to(_order_anchor) > 4.0:
				wanted = global_position.direction_to(_order_anchor) * minf(float(stats.speed), global_position.distance_to(_order_anchor) * 3.0)
		elif order == "roam":
			wanted = _wander_velocity(delta, _order_anchor, 65.0)
		if state in ["follow", "stay", "guard", "roam", "lead", "tether"]: _resting_behaviour(delta, wanted)
	elif is_instance_valid(master) and not master.get("is_dead"):
		wanted = _tribe_behaviour(delta)
	else:
		master = null
		wanted = _wild_behaviour(delta) * haste * _sun_pace()
	if _unstick_time > 0.0 and wanted.length() > 0.0:
		_unstick_time -= delta
		wanted = _unstick_dir * maxf(float(stats.speed), 30.0)
	if moves.busy():
		# The move owns the body: planted strikes, lunges, the charge lane, the leap.
		_move_velocity = Vector2.ZERO
		velocity = move_velocity + _knock
	else:
		# Stationary companions must not drift under herd separation. During a duel,
		# contact distance already accounts for both bodies, so separation cannot
		# bounce the attacker outside its own bite range.
		# Herd spacing only shows (beasts don't collide with each other), but
		# a fight plays out the same seen or unseen.
		if wanted.length() > 0 and net_time <= 0 and (visible or _in_fight()):
			wanted += _separation() * 12.0
		if _world and wanted.length() > 0: wanted = _avoid_obstacles(wanted)
		if _outside_world() and not (tamed and order == "stay"):
			wanted = global_position.direction_to(home) * float(stats.speed)
		in_water = is_instance_valid(_world) and _world.is_water_at(global_position)
		if in_water: wanted *= float(AQUATIC.get(species, WATER_SPEED_MULTIPLIER))
		if _action_time > 0.0 or _flinch > 0.0: wanted = Vector2.ZERO
		# Heavy bodies build up and shed speed slowly; turning sharply costs speed.
		var accel := float(body.accel)
		if wanted.length() > 0 and _move_velocity.length() > 5 and _move_velocity.normalized().dot(wanted.normalized()) < 0.2: accel *= 1.6
		_move_velocity = _move_velocity.move_toward(wanted, accel * delta)
		if net_time > 0 or _work_swing_time>0 or (tamed and order == "stay"): _move_velocity = Vector2.ZERO
		velocity = _move_velocity + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 520.0 * delta)
	# A lazy tick covers several ticks' ground in one step. (Against the
	# engine's own step, which already carries Engine.time_scale: a test run
	# at 4x, or a hitstop, must not stretch every stride again.)
	var stretch := delta / maxf(get_physics_process_delta_time(), 0.0001)
	if stretch > 1.01: velocity *= stretch
	move_and_slide()
	if stretch > 1.01: velocity /= stretch
	_watch_stuck(delta, wanted)
	if is_on_wall(): _wander = _wander.rotated(PI / 2.0)
	# Out of sight, the clip is picked again once it's back in view (unless
	# it's fighting: the strikes are timed by their clips).
	if visible or _in_fight():
		_update_animation()
		_heavy_footsteps()
	if _on_view(): queue_redraw()

## Near enough the keeper to be on screen, or about to be.
func _on_view() -> bool:
	return not is_instance_valid(_player) or global_position.distance_squared_to(_player.global_position) < 176400.0

# ------------------------------------------------------------------ behaviour
## Idle life while not fighting: graze, sniff or roar now and then.
func _resting_behaviour(delta: float, wanted: Vector2) -> void:
	if moves.busy() or _action_time > 0.0 or wanted.length() > 2.0 or velocity.length() > 4.0: return
	_idle_timer -= delta
	if _idle_timer > 0.0: return
	_idle_timer = _rng.randf_range(float(body.idle_every) * 0.6, float(body.idle_every) * 1.4)
	var clip := str(body.idle)
	if species == "rex" and tamed: clip = "idle"
	if clip != "idle": play_action(clip)

## Play a one-shot clip (graze, sniff, roar, warning) while standing still.
func play_action(clip: String, speed := 1.0) -> bool:
	if is_dead or moves.busy() or not DinoArt.has_clip(art_key, clip): return false
	_action = clip
	_action_time = DinoArt.duration(art_key, clip) / speed
	stop()
	_play_clip(clip, true, speed)
	if clip == "roar" and is_instance_valid(voice): voice.play_cue("roar")
	return true

func _wild_behaviour(delta: float) -> Vector2:
	# A wild baby keeps to its mother and runs from danger, never fights.
	if baby:
		var keep: Vector2 = life.baby_move(delta)
		if keep != CreatureLife.NO_GOAL: return keep
		state = "wander"
		var near_home := _wander_velocity(delta, home, 26.0)
		_resting_behaviour(delta, near_home)
		return near_home
	if _retreat_time > 0.0 and is_instance_valid(_retreat_from) and not _retreat_from.is_dead:
		state = "flee"
		return _retreat_from.global_position.direction_to(global_position) * _chase_speed()
	if dormant and provoked_time <= 0.0:
		state = "wander"
		var rest := _wander_velocity(delta, home, 36.0) * 0.6
		_resting_behaviour(delta, rest)
		return rest
	# Dodos, lystrosaurs and protoceratops bolt from a threat: anything that
	# hurt them, a hunter closing in, or a keeper rushing in.
	if species in SKITTISH:
		var hunter := _hunter_nearby()
		if hunter and not (provoked_time > 0 and _valid_target(_threat)):
			_threat = hunter
			provoked_time = 2.5
		if provoked_time > 0 and _valid_target(_threat):
			if global_position.distance_to(_threat.global_position) < float(stats.radius) + 20.0 and _can_attack(_threat):
				# Cornered: peck the attacker, then run.
				state = "hunt"
				return _approach_or_attack(_threat)
			state = "flee"
			return _threat.global_position.direction_to(global_position) * _chase_speed()
		if _flee_time > 0.0:
			_flee_time -= delta
			state = "flee"
			return _player.global_position.direction_to(global_position) * _chase_speed() if is_instance_valid(_player) else Vector2.ZERO
		if is_instance_valid(_player) and global_position.distance_to(_player.global_position) < 38.0 and _player.velocity.length() > 70.0:
			_flee_time = 1.6
			_action_time = 0.0
			_action = ""
			if is_instance_valid(voice): voice.play_cue("hurt")
			# One startled dodo sets the whole flock running.
			for other in roster(get_tree()):
				if other != self and other.species == species and not other.tamed and not other.is_dead and other.global_position.distance_to(global_position) < 90.0:
					other._flee_time = maxf(other._flee_time, 1.4)
	# Pass 13: a calm-way beast (the parasaur) bolts a few strides from a keeper
	# who runs up on it (see _tick_taming).
	if _flee_time > 0.0 and species not in SKITTISH:
		_flee_time -= delta
		state = "flee"
		return _player.global_position.direction_to(global_position) * _chase_speed() if is_instance_valid(_player) else Vector2.ZERO
	# Food set down for it (an offering): it goes to eat once the keeper backs off.
	var offered := _offer_steer(delta)
	if offered != Vector2.INF: return offered
	# A compy alone is a coward: it keeps its distance until the swarm gathers.
	if species == "compy" and not provoked_time > 0 and _pack_size() < 3 and is_instance_valid(_player):
		var d := global_position.distance_to(_player.global_position)
		if d < 70.0:
			state = "flee"
			return _player.global_position.direction_to(global_position) * float(stats.speed)
	# Pass 13: a herbivore wards off, it doesn't hunt. Once the threat has kept
	# away a moment, or the chase has carried it out of its ground, it lets it
	# go and goes back to grazing (a trike used to follow a keeper for minutes).
	if not bool(stats.predator) and not bool(stats.get("predator_like", false)) and provoked_time > 0.0 and is_instance_valid(_threat):
		var out_of_ground := global_position.distance_to(home) > WARD_LEASH
		if out_of_ground or global_position.distance_to(_threat.global_position) > WARD_GAP:
			_ward_out += delta
			if _ward_out > (0.6 if out_of_ground else 1.6):
				_ward_out = 0.0
				_give_up()
		else:
			_ward_out = 0.0
	var target := _current_target()
	if target:
		_calm_for = 0.0
		if _alert_needed(target):
			return _begin_alert(target)
		if _alert_left > 0.0:
			state = "alert"
			_face(global_position.direction_to(target.global_position))
			return Vector2.ZERO
		state = "hunt"
		# A hunt interrupts grazing or sniffing, never a roar it just began.
		if _action in ["eat", "sniff"]:
			_action_time = 0.0
			_action = ""
		if _action_time > 0.0:
			_face(global_position.direction_to(target.global_position))
			return Vector2.ZERO
		return _hunt(target, delta)
	_roared = false
	# Calm a while, the next target gets the warning again.
	_calm_for += delta
	if _calm_for > 8.0: _alerted_for = null
	if species == "dimetrodon" and _basking(delta):
		return Vector2.ZERO
	# Needs and goals: graze, drink, rest at night, keep to the nest, move on.
	var goal_move: Vector2 = life.steer(delta) if life else CreatureLife.NO_GOAL
	if goal_move != CreatureLife.NO_GOAL:
		return goal_move
	state = "wander"
	var wanted := _wander_velocity(delta, home, 36.0 if species in LURK else 85.0)
	if species in LURK and in_water and wanted.length() > 0.0: wanted *= 0.5
	_alert(delta)
	# Heads up (pass 13): a keeper running by stops a grazer for a look.
	if _look_time > 0.0:
		_look_time -= delta
		wanted = Vector2.ZERO
		if is_instance_valid(_player): _face(global_position.direction_to(_player.global_position))
	_resting_behaviour(delta, wanted)
	return wanted

## Herbivores look up at a keeper who comes close; a trike paws the ground
## at one who charges in (a warning: it only attacks when struck).
func _alert(delta: float) -> void:
	_look_rest = maxf(0.0, _look_rest - delta)
	if species in SKITTISH or bool(stats.predator) or not is_instance_valid(_player) or _action_time > 0.0: return
	var d := global_position.distance_to(_player.global_position)
	# A keeper running by (the noise of it): it stops and looks up a moment.
	if d < 130.0 and d > 60.0 and _look_rest <= 0.0 and _player.velocity.length() > 60.0 and trust <= 0:
		_look_rest = _rng.randf_range(6.0, 10.0)
		_look_time = _rng.randf_range(0.8, 1.6)
	if d > 60.0: return
	var comfort: float = float(COMFORT.get(species, 0.0)) * Genes.temper(genes, "comfort")
	if _warned <= 0.0 and d < comfort + float(stats.radius) and trust <= 0:
		var clip := _display_clip()
		if clip != "":
			_warned = WARN_EVERY
			_face(global_position.direction_to(_player.global_position), true)
			play_action(clip)
			# The trike's way: does the keeper stand their ground?
			if Ways.way(species) == "stand" and tame_marks < Ways.marks_needed(species) and not tamed: _stand_watch = maxf(1.6, _action_time + 0.5)
			return
	if velocity.length() < 6.0:
		_face(global_position.direction_to(_player.global_position))

## Whether going for this target wants the warning first (see ALERT_TIME).
func _alert_needed(target: Node2D) -> bool:
	if tamed or baby or bool(stats.get("boss", false)) or target == _alerted_for or moves.busy(): return false
	# Wild prey is simply hunted; the keeper, their beasts and the tribes' folk
	# are warned.
	return target == _player or target.is_in_group("tribesmen") or (target.is_in_group("forest_creatures") and target.tamed)


func _begin_alert(target: Node2D) -> Vector2:
	_alerted_for = target
	var seconds: float = ALERT_STRUCK if _struck_clock > 0.0 else float(ALERT_TIME.get(species, 0.7))
	_alert_left = seconds
	_alert_mark = seconds + 0.45
	state = "alert"
	stop()
	_face(global_position.direction_to(target.global_position), true)
	var clip := _display_clip()
	if clip != "" and seconds > ALERT_STRUCK:
		play_action(clip, clampf(DinoArt.duration(art_key, clip) / seconds, 0.8, 2.6))
	if is_instance_valid(voice):
		voice.play_cue("roar" if clip in ["roar", "threat"] else "attack")
	if species == "yuty" and seconds > ALERT_STRUCK: _ash_roar()
	queue_redraw()
	return Vector2.ZERO


## The display clip this beast has (a threat, a roar, a paw), "" for none.
func _display_clip() -> String:
	for clip in ALERT_CLIPS:
		if DinoArt.has_clip(art_key, clip): return clip
	return ""


## Pursuit tactics per species; attacks start from _approach_or_attack.
func _hunt(target: Node2D, delta: float) -> Vector2:
	# Breaking through what's in the way (pass 13).
	if _siege_cell != NO_POST:
		var bash := _tick_siege(delta, target)
		if bash != Vector2.INF: return bash
	var wanted := _approach_or_attack(target)
	if moves.busy(): return Vector2.ZERO
	var to := target.global_position - global_position
	var g := moves.gap(target)
	# Past its own ground (and then some) it lets the quarry go (pass 13).
	if _out_of_territory(90.0) and g > moves.close_reach() + 24.0:
		_give_up()
		return Vector2.ZERO
	# A long chase winds it; winded and still far off, it gives up.
	if g > moves.close_reach() + 12.0:
		_chase_time += delta
		if _chase_time > float(body.get("tire", 10.0)) * Genes.temper(genes, "tire") and _winded <= 0.0 and not bool(stats.get("boss", false)):
			_chase_time = 0.0
			_winded = 7.0
		if _winded > 0.0 and g > 170.0:
			_give_up()
			return Vector2.ZERO
	else:
		_chase_time = maxf(0.0, _chase_time - delta * 2.0)
	match species:
		"allo":
			# (Its roar is the alert display.) A fast, low stalk.
			return wanted
		"rex":
			# (Its roar is the alert display.) A heavy stalk until a move is ready.
			if not moves.is_ready("charge") and not moves.is_ready("bite") and g < 30.0:
				return Vector2.ZERO
			return wanted * (0.7 if g > 40.0 else 1.0)
		"carno":
			# (Its bellow is the alert display.) It runs its quarry down: the
			# fastest big hunter there is, with a horned charge from mid range.
			return wanted
		"yuty":
			# The Ashmane's alert roar is a blast of ash (_ash_roar, from
			# _begin_alert); a pair hunt from both sides.
			_orbit_sign = _pack_side(target)
			if wanted.length() > 0.0 and g > 60.0:
				return (to.normalized().rotated(_orbit_sign * 0.35) * wanted.length())
			return wanted
		"dimetrodon":
			# A cold-blooded ambusher (its hiss is the alert display), then a
			# burst at close range.
			return wanted
		"raptor", "compy", "deino", "utah":
			# Pack tactics: each raptor on the prey takes a side, closes in on a
			# flanking line, darts back out after a slash, circles while its moves
			# cool down, then comes in again.
			_orbit_sign = _pack_side(target)
			var radial := to.normalized()
			var spread := _pack_spread() * 18.0
			if moves.cooldown_left("slash") > 0.8 and g < 60.0:
				return ((-radial) + radial.orthogonal() * _orbit_sign * 0.6 + spread).normalized() * float(stats.speed)
			if not moves.is_ready("slash") and not moves.is_ready("pounce"):
				var ring := 46.0 + float(get_instance_id() % 3) * 8.0
				var tangent := radial.orthogonal() * _orbit_sign
				var pull := (to.length() - ring - float(stats.radius)) / 20.0
				return (tangent + radial * clampf(pull, -1.0, 1.0) + spread).normalized() * float(stats.speed) * 0.8
			if wanted.length() > 0.0 and g > moves.close_reach():
				# Running in on its flanking line: flat out from afar, easing
				# to its cruising pace for the last few strides.
				var pace := _chase_speed() if g > 70.0 else float(stats.speed) * 1.3
				return (radial.rotated(_orbit_sign * 0.55 * clampf(80.0 / maxf(g, 1.0), 0.2, 1.0)) + spread).normalized() * pace
	return wanted

## Wanting to move but going nowhere (wedged between rocks, pressed into a
## wall): a sidestep one way, next time the other, and for a few seconds it
## paths round (A*) whatever it is after.
func _watch_stuck(delta: float, wanted: Vector2) -> void:
	if moves.busy() or wanted.length() < 20.0 or net_time > 0.0 or (tamed and order == "stay"):
		_stuck_clock = 0.0
		_stuck_from = global_position
		return
	_stuck_clock += delta
	if _stuck_clock < 0.9: return
	# Hunting and blocked by the keeper's building (or a tree, for the big
	# ones): it sets about breaking through.
	if not tamed and _stuck_from != Vector2.INF and global_position.distance_to(_stuck_from) < 5.0 and _siege_cell == NO_POST:
		var quarry: Node2D = _threat if provoked_time > 0.0 and _valid_target(_threat) else (_hunt_target if is_instance_valid(_hunt_target) else null)
		if quarry != null:
			var blocker := _find_blocker(quarry)
			if blocker != NO_POST:
				_siege_cell = blocker
				_siege_swing = 0.0
				_stuck_clock = 0.0
				return
	if _stuck_from != Vector2.INF and global_position.distance_to(_stuck_from) < 5.0:
		_stuck_side = -_stuck_side
		_unstick_dir = wanted.normalized().rotated(_stuck_side * PI * 0.5)
		_unstick_time = 0.8
		_path_boost = 4.0
	_stuck_clock = 0.0
	_stuck_from = global_position


## What stands between it and its quarry that it would break: a keeper's
## building (any beast with a SIEGE_SECONDS) or, for the big ones, a tree.
func _find_blocker(quarry: Node2D) -> Vector2i:
	if not is_instance_valid(_world) or not is_inside_tree(): return NO_POST
	var to := global_position.direction_to(quarry.global_position)
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + to * (float(stats.radius) + 24.0), 16)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return NO_POST
	var body = hit.collider
	var prop = body if body.get("kind") != null else body.get_parent()
	if prop == null or prop.get("kind") == null or prop.get("cell") == null: return NO_POST
	if prop.get("is_placed") == true and SIEGE_SECONDS.has(species): return prop.cell
	if str(prop.kind) in TREES and species in TREE_BREAKERS: return prop.cell
	return NO_POST

## Breaking through: it faces the thing, strikes at it now and then, and wears
## it down. Vector2.INF when it's done (broken, or no longer worth it).
func _tick_siege(delta: float, quarry: Node2D) -> Vector2:
	var p = _world.props.get(_siege_cell) if is_instance_valid(_world) else null
	if not is_instance_valid(p) or quarry == null or not _valid_target(quarry) or global_position.distance_to(p.global_position) > float(stats.radius) + 40.0:
		_siege_cell = NO_POST
		return Vector2.INF
	state = "attack"
	_face(global_position.direction_to(p.global_position), true)
	_siege_swing -= delta
	if _siege_swing <= 0.0:
		_siege_swing = 1.5
		var clip := ""
		for m in moves.moves():
			if DinoArt.has_clip(art_key, str(m.clip)):
				clip = str(m.clip)
				break
		if clip != "": play_action(clip)
		_play_fx("thud", -9.0, 0.9)
		_shake_near(0.1, 180.0)
	var tree: bool = str(p.kind) in TREES
	var seconds: float = TREE_SECONDS if tree else float(SIEGE_SECONDS.get(species, 90.0)) * (STONE_SLOW if str(p.kind) in STONE_BUILT else 1.0)
	if _world.siege_hit(_siege_cell, float(p.max_hp) / seconds * delta, str(stats.name)):
		_siege_cell = NO_POST
		_stuck_clock = 0.0
		return Vector2.INF
	return Vector2.ZERO

## The quarry got away: back to its own business for a while.
func _give_up() -> void:
	provoked_time = 0.0
	_threat = null
	_hunt_target = null
	_hunt_none = true
	_hunt_scan = 6.0
	sated = maxf(sated, 25.0)


## This raptor's side of the prey (+1/-1): alternates through the pack
## hunting the same target so they come at it from both flanks.
func _pack_side(target: Node2D) -> float:
	var mates: Array = []
	for other in roster(get_tree()):
		if other.species == species and not other.is_dead and other.tamed == tamed and other._attack_target_or_threat() == target:
			mates.append(other)
	mates.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	var slot := maxi(0, mates.find(self))
	return 1.0 if slot % 2 == 0 else -1.0

func _attack_target_or_threat() -> Node2D:
	if moves.busy() and is_instance_valid(moves.target): return moves.target
	if provoked_time > 0 and _valid_target(_threat): return _threat
	return _current_target() if not tamed else _companion_target()

## Push away from pack-mates that are too close (never stack on one spot).
func _pack_spread() -> Vector2:
	var push := Vector2.ZERO
	for other in near(get_tree(), global_position, 24.0):
		if other == self or other.is_dead or other.species != species: continue
		var off: Vector2 = global_position - other.global_position
		if off.length() < 22.0 and off.length() > 0.01: push += off.normalized() * (1.0 - off.length() / 22.0)
	return push.limit_length(1.0)

func _update_animation():
	if _sprite.sprite_frames == null: return
	# Netted: knocked down onto its side (its fall, held on the last frame),
	# then, when the net gives, it scrambles back up (the fall, backwards).
	if net_time > 0.0 and DinoArt.has_clip(art_key, "death"):
		if _clip != "death": _play_clip("death", true, 1.6)
		return
	if _clip == "death" and not is_dead:
		var fall := "death_" + _facing
		if _sprite.sprite_frames.has_animation(fall):
			_sprite.speed_scale = 2.4
			_sprite.play_backwards(fall)
			_clip = "rise"
			_action = "rise"
			_action_time = DinoArt.duration(art_key, "death") / 2.4
			return
	if _action == "rise" and _action_time > 0.0: return
	# Facing and stride follow the body's own motion, not a shove it takes.
	var facing_vector := velocity - _knock
	if _work_swing_time>0: facing_vector=_work_aim*10
	if moves.busy():
		_face(moves.facing_vector(), true)
		var flip = moves.flip_override()
		if flip != null: _sprite.flip_h = flip
		var clip := moves.clip_now()
		if clip == "": clip = "idle"
		_play_clip(clip, false, moves._speed_now() if moves.phase == "windup" else (1.45 if moves.phase == "dash" else 1.0))
		return
	if _flinch > 0.0:
		_play_clip("hurt", false)
		return
	if _work_swing_time > 0:
		_face(facing_vector, true)
		return
	if _action_time > 0.0 and _action != "":
		_play_clip(_action, false, _sprite.speed_scale)
		return
	if facing_vector.length() > 2: _face(facing_vector)
	if _facing != "side": _sprite.flip_h = false  # undo a sweep's mirroring
	var speed := facing_vector.length()
	# Ridden at a normal pace a mount walks; it gallops only when sprinted.
	var run_at := maxf(float(body.run_at), 72.0) if is_mounted() else float(body.run_at)
	if speed > 3:
		if speed >= run_at and DinoArt.has_clip(art_key, "run"):
			# Pass 12: hunters run down their quarry at up to twice their
			# drawn gait (chase speeds); the stride quickens to keep the feet
			# on the ground.
			_play_clip("run", false, clampf(speed / float(body.run), 0.6, 2.4))
		else:
			_play_clip("walk", false, clampf(speed / float(body.walk), 0.55, 1.8))
	else:
		_play_clip("idle", false)
	queue_redraw()

## Show a clip in the current facing. restart: from frame 0 even if playing.
func _play_clip(clip: String, restart := false, speed := 1.0) -> void:
	if _sprite.sprite_frames == null: return
	var anim := "%s_%s" % [clip, _facing]
	if not _sprite.sprite_frames.has_animation(anim):
		anim = "idle_" + _facing
		if not _sprite.sprite_frames.has_animation(anim): return
		clip = "idle"
	_sprite.speed_scale = speed
	if restart or _sprite.animation != anim:
		# Turning mid-clip keeps the progress through the clip.
		var keep := not restart and _clip == clip and _sprite.is_playing()
		var frame := _sprite.frame
		var progress := _sprite.frame_progress
		_sprite.play(anim)
		if keep: _sprite.set_frame_and_progress(mini(frame, _sprite.sprite_frames.get_frame_count(anim) - 1), progress)
		else: _sprite.set_frame_and_progress(0, 0.0)
	_clip = clip

## Face a direction: side (flipped for left), up or down. Without force a
## small hysteresis and a short hold stop diagonal travel from flickering.
func _face(direction: Vector2, force := false) -> void:
	if direction.length() < 0.01: return
	if not force and _face_hold > 0.0: return
	var next := _facing
	if absf(direction.y) > absf(direction.x) * (1.0 if force else 1.2): next = "up" if direction.y < 0 else "down"
	elif absf(direction.x) > absf(direction.y) * (1.0 if force else 1.2): next = "side"
	# Side-on art (the babies): always side, turned by the horizontal part.
	var side_only := not DinoArt.has_view(art_key, "walk", "down")
	if side_only:
		next = "side"
		if absf(direction.x) < 0.05:
			return
	var flip := next == "side" and direction.x < 0
	if next != _facing or (next == "side" and flip != _sprite.flip_h):
		_facing = next
		_sprite.flip_h = flip
		_face_hold = 0.18
		if _clip != "": _play_clip(_clip, false, _sprite.speed_scale)
	elif next == "side":
		_sprite.flip_h = flip

## Unit vector of the current facing.
func facing_vector() -> Vector2:
	match _facing:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
	return Vector2.LEFT if _sprite.flip_h else Vector2.RIGHT

## Heavy walkers shake the ground a little when the keeper is close.
## Footfalls: [volume dB (walk), pitch, shake walking, shake running, how far
## the shake reaches]. Light thumps for the plated herbivores; the rex stomps,
## and the ground (the camera) shakes with every step as it comes.
const STEPS := {
	"rex": [-14.0, 0.8, 0.1, 0.2, 230.0],
	"alpha": [-18.0, 0.95, 0.04, 0.09, 150.0],
	"allo": [-20.0, 1.0, 0.03, 0.06, 130.0],
	"longneck": [-22.0, 0.9, 0.05, 0.08, 120.0],
	"stego": [-27.0, 1.05, 0.0, 0.0, 0.0],
	"trike": [-27.0, 1.12, 0.0, 0.0, 0.0],
}
func _heavy_footsteps() -> void:
	if not STEPS.has(species) or not _clip in ["walk", "run"] or is_mounted(): return
	var count := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	var f := _sprite.frame
	if f == _step_frame: return
	_step_frame = f
	if f != 0 and f != count / 2: return
	var step: Array = STEPS[species]
	var feet := global_position + Vector2(0, 2)
	var running := _clip == "run"
	if float(step[2]) > 0.0: _shake_near(float(step[3]) if running else float(step[2]), float(step[4]))
	if is_instance_valid(_player) and feet.distance_to(_player.global_position) < 170.0 + float(step[4]) * 0.5:
		_play_fx("thud", float(step[0]) + (4.0 if running else 0.0), float(step[1]))
		if float(step[2]) > 0.0:
			var puff := Puff.new()
			puff.dust(Vector2.ZERO, velocity, moves._dust_palette(feet), 2, 2, 0.9)
			puff.spawn(_world if is_instance_valid(_world) else get_parent(), feet, -1.0)

## Camera trauma for the keeper, fading with distance.
func _shake_near(trauma: float, radius: float) -> void:
	if not is_instance_valid(_player) or _player.get("feel") == null: return
	var d := global_position.distance_to(_player.global_position)
	if d > radius: return
	var k := 1.0 - d / radius if radius < 900.0 else 1.0
	_player.feel.shake(trauma * k)

## A generated foley bank (thud, whoosh, ...) played at this creature.
func _play_fx(family: String, volume_db := -12.0, pitch := 1.0) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(_player): return
	if global_position.distance_to(_player.global_position) > _fx_audio.max_distance: return
	var bank = AudioManager._foley_bank(family) if AudioManager.has_method("_foley_bank") else null
	if bank == null: return
	_fx_audio.stream = bank
	_fx_audio.volume_db = volume_db
	_fx_audio.pitch_scale = pitch
	_fx_audio.play()

func play_work_strike(resource_position: Vector2, role: String) -> void:
	# Harvesting has its own short follow-through, never a combat target or hit.
	if is_dead or is_mounted() or _attack_time>0: return
	var clip := work_clip()
	# A tail fells trees from behind: the stego turns its back to the trunk.
	_work_aim=global_position.direction_to(resource_position)
	if clip == "tail_swing": _work_aim = -_work_aim
	stop()
	_face(_work_aim, true)
	# Begin on the contact pose: resource durability changed on this same tick.
	var hit := DinoArt.hit_frame(art_key, clip, _facing)
	var rest := DinoArt.duration(art_key, clip) - DinoArt.hit_time(art_key, clip, _facing)
	_work_swing_time = clampf(rest, 0.3, 0.55)
	_play_clip(clip, true, maxf(1.0, rest / _work_swing_time))
	_sprite.set_frame_and_progress(mini(hit, _sprite.sprite_frames.get_frame_count(_sprite.animation) - 1), 0)
	var path: String=AudioManager.get_foley_path("chop_wood",_rng.randi_range(0,4)) if role=="timber" else "res://Forest/audio/foley/impactSoft_medium_000.ogg"
	_work_audio.stream=load(path)
	_work_audio.pitch_scale=_rng.randf_range(0.94,1.06)
	if DisplayServer.get_name()!="headless": _work_audio.play()

## The clip a worker uses on a tree or a bush.
func work_clip() -> String:
	match species:
		"stego": return "tail_swing"
		"trike": return "gore"
		"longneck": return "tail_swing"
	return "eat"

## How fast it runs something down: the body's chase speed (scaled like its
## cruising speed for a variant or a baby), or cruising speed once winded.
## The dimetrodon warms in the sun: sluggish at night and first thing, quick
## at midday (every other beast: 1).
func _sun_pace() -> float:
	if species != "dimetrodon": return 1.0
	var sun := 1.0 - absf(float(TimeCycle.time_of_day) - 0.5) * 2.0
	return lerpf(0.6, 1.15, clampf(sun, 0.0, 1.0))


## By day a dimetrodon with nothing to hunt stands side-on to the sun on open
## ground and soaks it up for a while (its sail broadside), then moves on.
var _bask_time := 0.0
var _bask_rest := 0.0
func _basking(delta: float) -> bool:
	_bask_rest = maxf(0.0, _bask_rest - delta)
	if TimeCycle.is_night() or (life and str(life.goal) in ["drink"]):
		_bask_time = 0.0
		return false
	if _bask_time > 0.0:
		_bask_time -= delta
		if _bask_time <= 0.0: _bask_rest = _rng.randf_range(20.0, 40.0)
		state = "bask"
		if velocity.length() < 4.0:
			_face(Vector2.RIGHT if int(get_instance_id()) % 2 == 0 else Vector2.LEFT, true)
		return true
	if _bask_rest <= 0.0 and velocity.length() < 8.0:
		_bask_time = _rng.randf_range(18.0, 36.0)
	return false


## A rival hunter on its ground, if there's one worth a fight.
func _find_rival() -> Node2D:
	if tamed or baby or is_instance_valid(master) or bool(stats.get("boss", false)) or _dispute_rest > 0.0: return null
	if _retreat_time > 0.0: return null
	for other in near(get_tree(), global_position, DISPUTE_RANGE):
		if other == self or other.is_dead or other.tamed or other.baby or is_instance_valid(other.master): continue
		if not other.species in RIVALS[species] or other._dispute_rest > 0.0 or other._retreat_time > 0.0: continue
		if other.dormant or bool(other.stats.get("boss", false)): continue
		if global_position.distance_to(other.global_position) > DISPUTE_RANGE: continue
		return other
	return null


## Square up to a rival: each takes the other as its quarry.
func _start_dispute(rival: Node2D) -> void:
	for pair in [[self, rival], [rival, self]]:
		var a = pair[0]
		a._disputing = pair[1]
		a._threat = pair[1]
		a.provoked_time = 14.0
		a._roared = false


## The Ashmane's roar: a blast of ash that slows a keeper close by a moment.
func _ash_roar() -> void:
	if not is_instance_valid(_player) or global_position.distance_to(_player.global_position) > 130.0: return
	if _player.has_method("apply_ash"): _player.apply_ash(3.0)


## A tribe's beast: keeps close to its tribesman, fights their fight, and a
## raiding tribe's beast comes for the keeper when they're near.
func _tribe_behaviour(delta: float) -> Vector2:
	var foe: Node2D = master.get("foe")
	if not _valid_target(foe) or foe.global_position.distance_to(master.global_position) > 240.0: foe = null
	if foe == null and provoked_time > 0 and _valid_target(_threat): foe = _threat
	var against_keeper: bool = master.is_hostile_to_keeper() if master.has_method("is_hostile_to_keeper") else bool(master.get("hostile"))
	if foe == null and against_keeper and _valid_target(_player) and global_position.distance_to(_player.global_position) < 150.0:
		foe = _player
	if foe:
		state = "hunt"
		return _hunt(foe, delta)
	state = "follow"
	var side := Vector2(-18.0 if int(get_instance_id()) % 2 == 0 else 18.0, 10.0)
	var goal: Vector2 = master.global_position + side
	var d := global_position.distance_to(goal)
	if d < 14.0:
		_resting_behaviour(delta, Vector2.ZERO)
		return Vector2.ZERO
	var pace := float(stats.speed) * (1.6 if d > 90.0 else 1.0)
	return _navigate_to(goal, delta).normalized() * pace


func _chase_speed() -> float:
	var cruise := float(stats.speed)
	if _winded > 0.0 or baby: return cruise
	# The kind's and the individual's speed apply to the chase as well.
	var scale := cruise / maxf(1.0, float(SPECIES[species].speed) * PACE)
	return maxf(cruise, float(body.get("chase", cruise)) * scale)


func _approach_or_attack(target: Node2D) -> Vector2:
	_work_swing_time=0
	if baby: return Vector2.ZERO
	if not _can_attack(target): return Vector2.ZERO
	if moves.busy(): return Vector2.ZERO
	var m := moves.choose(target)
	if not m.is_empty() and _has_line_of_sight(target.global_position):
		_attack_target = target
		_attack_aim = global_position.direction_to(target.global_position)
		_action_time = 0.0
		_action = ""
		moves.start(m, target)
		_attack_time = moves.remaining()
		_attack_duration = _attack_time
		_attack_hit = false
		return Vector2.ZERO
	var offset := target.global_position - global_position
	# Hold at striking distance while every close move is cooling down.
	if moves.gap(target) <= moves.close_reach() - 2.0 and moves.reach_now() < moves.gap(target): return Vector2.ZERO
	if moves.gap(target) <= 1.0: return Vector2.ZERO
	# Recently wedged against rocks: find a way round rather than push.
	if _path_boost > 0.0 and offset.length() > 40.0:
		return _navigate_to(target.global_position, get_physics_process_delta_time()).normalized() * _chase_speed()
	# Closing from afar at a run; the last stride at cruising pace so it
	# doesn't overshoot.
	var pace := _chase_speed() if moves.gap(target) > moves.close_reach() + 10.0 else minf(_chase_speed(), float(stats.speed) * 1.5)
	return offset.normalized() * pace

func _has_line_of_sight(target_position: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, 16)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _avoid_obstacles(desired: Vector2) -> Vector2:
	# Multi-ray local steering handles freshly built walls without a stale navmesh.
	# The way found is kept for a few ticks while the heading holds.
	var heading := desired.normalized()
	if _avoid_for > 0 and heading.dot(_avoid_last) > 0.96:
		_avoid_for -= 1
		return desired.rotated(_avoid_angle)
	_avoid_last = heading
	var probe := float(stats.radius) + 14.0
	for angle in [0.0, 0.55, -0.55, 1.05, -1.05, 1.57, -1.57, 2.2, -2.2]:
		var candidate := desired.rotated(angle)
		var ahead := global_position + candidate.normalized() * probe
		var blocked := false
		for side in [-0.7, 0.0, 0.7]:
			var point: Vector2 = ahead + candidate.normalized().orthogonal() * float(stats.radius) * float(side)
			if _world.has_method("is_blocked_at") and _world.is_blocked_at(point):
				blocked = true
				break
		if not blocked:
			_avoid_angle = angle
			_avoid_for = 3
			return candidate
	_avoid_for = 0
	return Vector2.ZERO

func _is_hostile() -> bool:
	return not tamed and species != "dodo" and (bool(stats.predator) or bool(stats.get("predator_like", false)) or provoked_time > 0)

func _valid_target(target: Variant) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.get("is_dead") != true and target.get("respawning") != true

func _can_attack(target: Variant) -> bool:
	if not _valid_target(target) or (tamed and stance == "passive"): return false
	if tamed and (target == _player or (target.is_in_group("forest_creatures") and target.tamed)): return false
	return target.has_method("take_damage")

func _contact_range(target: Node2D) -> float:
	var target_radius := float(target.stats.radius) if target.is_in_group("forest_creatures") else 8.0
	return float(stats.radius) + target_radius + 13.0

func _wild_target() -> Node2D:
	if provoked_time > 0 and _valid_target(_threat):
		return _threat
	if dormant or not _is_hostile(): return null
	# The keeper and companions within its reach; prey (whatever this hunter
	# takes, wild or tamed) out to its hunting range: the rex never stops, the
	# others rest after a kill. The nearest of them all.
	# Far out of its own ground, a hunter picks no new quarry: it heads home.
	if _out_of_territory(0.0): return null
	var reach: float = float(NOTICE.get(species, 105.0)) * Genes.temper(genes, "notice")
	var prey: Array = PREY.get(species, [])
	var hungry := species == "rex" or sated <= 0.0
	var hunting := 200.0 if hungry else 0.0
	var pack := _pack_size() if species in ["raptor", "deino"] else 0
	var closest: Node2D
	var distance := INF
	var shadowed: bool = species in ["raptor", "allo", "compy"] and _rex_shadow()
	# A compy only comes for the keeper with the swarm about it.
	if species == "compy" and _pack_size() < 3: shadowed = true
	# Pass 13: noticing is not hunting. Fed, it lets the keeper be unless they
	# walk into its DANGER ring; hungry, the keeper is prey within NOTICE.
	var keeper_reach: float = reach if (sated <= 0.0 or bool(stats.get("predator_like", false))) else float(DANGER.get(species, reach * 0.45)) * Genes.temper(genes, "notice")
	# Pass 13: in its kin's armour the keeper smells like one of its own; a beast
	# the keeper has earned (respect, a dodged charge) lets them be.
	if wearing_kin() or (Ways.marks_needed(species) > 0 and tame_marks >= Ways.marks_needed(species) and Ways.way(species) in ["respect", "dodge"]): keeper_reach = 0.0
	# Basking, a dimetrodon is slow and sleepy in the sun: it lets a keeper walk
	# up to it (that's when it takes food from the hand: TamingWays "basking").
	if species == "dimetrodon" and _bask_time > 0.0 and not TimeCycle.is_night(): keeper_reach = 0.0
	if not shadowed and _valid_target(_player) and global_position.distance_to(_player.global_position) < keeper_reach:
		closest = _player
		distance = global_position.distance_to(_player.global_position)
	# The tribes' folk are fair game too (pass 12), as near as the keeper.
	if not shadowed:
		for person in folk(get_tree()):
			if not _valid_target(person): continue
			var fd: float = global_position.distance_to(person.global_position)
			if fd < minf(reach, 150.0) and fd < distance:
				closest = person
				distance = fd
	for other in near(get_tree(), global_position, maxf(reach, hunting)):
		if other == self or not _valid_target(other): continue
		var d := global_position.distance_to(other.global_position)
		# Hungry, it takes the wild prey it knows before a keeper not much
		# nearer (a third again as far off).
		var wild_prey: bool = not other.tamed and d < hunting and (other.species in prey or (pack >= 3 and other.species in PACK_PREY))
		if d >= (distance * 1.35 if closest == _player and wild_prey else distance): continue
		if other.tamed:
			if d < reach:
				closest = other
				distance = d
		elif wild_prey:
			closest = other
			distance = d
	return closest


## How far a hunter strays from its own ground (home) after quarry; past it,
## it lets the chase go and heads back.
const TERRITORY := {"raptor": 420.0, "allo": 480.0, "rex": 560.0, "carno": 560.0, "yuty": 480.0,
	"utah": 460.0, "deino": 380.0, "sucho": 260.0, "spino": 520.0,
	"dimetrodon": 240.0, "compy": 320.0}

func _out_of_territory(extra: float) -> bool:
	if not TERRITORY.has(species) or tamed or bool(stats.get("boss", false)) or is_instance_valid(master): return false
	return global_position.distance_to(home) > float(TERRITORY[species]) + extra


## How far off a hungry hunter takes the keeper for prey (pass 13: nearer than
## pass 12's, which had every hunter in sight coming).
const NOTICE := {"raptor": 150.0, "allo": 150.0, "rex": 170.0, "alpha": 200.0, "ossuar": 220.0,
	"utah": 160.0, "deino": 140.0, "sucho": 90.0, "spino": 180.0,
	"carno": 160.0, "yuty": 170.0, "dimetrodon": 64.0, "compy": 110.0}
## How near a fed hunter lets the keeper come before it warns them off and
## attacks (the rex has little patience).
const DANGER := {"raptor": 70.0, "allo": 80.0, "rex": 120.0, "carno": 90.0, "yuty": 95.0,
	"utah": 80.0, "deino": 65.0, "sucho": 70.0, "spino": 120.0,
	"dimetrodon": 50.0, "compy": 48.0, "alpha": 200.0, "ossuar": 220.0}


## The target this one is after, looked for afresh a few times a second
## rather than every tick (a threat that just struck is answered at once).
func _current_target() -> Node2D:
	if provoked_time > 0 and _valid_target(_threat): return _threat
	if dormant or not _is_hostile(): return null
	if RIVALS.has(species) and _dispute_scan <= 0.0:
		_dispute_scan = 1.0 + float(get_instance_id() % 7) * 0.05
		var rival := _find_rival()
		if rival:
			_start_dispute(rival)
			return rival
	if _hunt_scan > 0.0:
		if _hunt_none: return null
		if _valid_target(_hunt_target): return _hunt_target
	_hunt_scan = 0.2 + float(get_instance_id() % 5) * 0.02
	_hunt_target = _wild_target()
	_hunt_none = _hunt_target == null
	return _hunt_target


## _hunter_near, a few times a second.
func _hunter_nearby() -> Node2D:
	if _hunter_scan <= 0.0:
		_hunter_scan = 0.2 + float(get_instance_id() % 5) * 0.02
		_hunter = _hunter_near()
	return _hunter if is_instance_valid(_hunter) and not _hunter.is_dead else null


## A tamed rex walks with the keeper: the smaller hunters keep away (Buffs.gd).
## Judged once a physics tick for every hunter (each asks several times a second).
static var _shadow_tick := -1
static var _shadow := false

func _rex_shadow() -> bool:
	var tick := Engine.get_physics_frames()
	if tick != _shadow_tick:
		_shadow_tick = tick
		var gifts = get_tree().get_first_node_in_group("companion_buffs")
		# The whole Tyrant set does the same (pass 12, SetBonus).
		_shadow = (gifts != null and gifts.has("tyrants_shadow")) or (is_instance_valid(_player) and SetBonus.has_shadow(_player))
	return _shadow


## The tribes' folk, listed once a physics tick (like the roster).
static var _folk_tick := -1
static var _folk: Array = []

static func folk(tree: SceneTree) -> Array:
	var tick := Engine.get_physics_frames()
	if tick != _folk_tick:
		_folk_tick = tick
		_folk = tree.get_nodes_in_group("tribesmen")
	return _folk


## Raptors near this one (itself included): a pack takes bigger prey.
func _pack_size() -> int:
	var n := 0
	for other in near(get_tree(), global_position, 150.0):
		if other.species == species and not other.is_dead and other.tamed == tamed and other.global_position.distance_to(global_position) < 150.0: n += 1
	return n


## A wild hunter coming for this one (for the small ones, who run).
func _hunter_near() -> Node2D:
	for other in near(get_tree(), global_position, 110.0):
		if other == self or other.is_dead or other.tamed or not bool(other.stats.predator): continue
		# Kin never hunt kin: a pack hunting beside one of its young is no
		# danger to it (and must not set the pack on its own).
		if other.species == species: continue
		if other.global_position.distance_to(global_position) > 110.0: continue
		if other.get("_attack_target") == self or (other.state == "hunt" and other.global_position.distance_to(global_position) < 70.0): return other
	return null


## A kill: a wild hunter rests from hunting for a while.
func on_kill(_victim: Node) -> void:
	if tamed: return
	sated = _rng.randf_range(90.0, 150.0)
	_threat = null
	provoked_time = 0.0
	_hunt_scan = 0.0

func _companion_target() -> Node2D:
	if stance == "passive" or baby or order == "lead": return null
	if provoked_time > 0 and _can_attack(_threat):
		if order != "guard" or _order_anchor.distance_to(_threat.global_position) < 120.0: return _threat
	return _find_hostile()

func _find_hostile() -> Node2D:
	var closest: Node2D
	var distance := 100.0
	for other in near(get_tree(), global_position, 100.0):
		if other == self or other.tamed or not _can_attack(other): continue
		if order == "guard" and _order_anchor.distance_to(other.global_position) > 110.0: continue
		# Neutral follows defend against an active threat. Guard intercepts predators
		# in the guarded clearing; aggressive seeks nearby hostile creatures.
		var its: Node2D = other._attack_target if other._attack_time > 0 and _valid_target(other._attack_target) else (other._threat if other.provoked_time > 0 and _valid_target(other._threat) else null)
		if its == null and other.state == "hunt": its = other._current_target()
		var targeting_friend: bool = its != null and (its == _player or its.get("tamed") == true)
		if not (other._is_hostile() and (stance == "aggressive" or order == "guard" or targeting_friend)): continue
		var d := global_position.distance_to(other.global_position)
		if d < distance:
			distance = d
			closest = other
	return closest

## Past the world's walls (a shove through a gap): steer home.
func _outside_world() -> bool:
	if not is_instance_valid(_world) or not _world.has_method("bounds"): return absf(global_position.x) > 865 or absf(global_position.y) > 865
	var b: Rect2i = _world.bounds()
	return not Rect2(Vector2(b.position * 16) + Vector2(31, 31), Vector2(b.size * 16) - Vector2(62, 62)).has_point(global_position)


## Wander around a centre; herds drift back toward their own kind.
func _wander_velocity(delta: float, center: Vector2, radius: float) -> Vector2:
	_wander_time -= delta
	if _wander_time <= 0:
		_wander_time = _rng.randf_range(1.8, 4.0)
		# Grazers stop more than they walk (pass 13): half their legs are a
		# stop, and a stop is for eating, a bite soon after they come to rest.
		var grazer: bool = str(body.get("idle", "")) == "eat" and not bool(stats.predator)
		_wander = Vector2.from_angle(_rng.randf_range(0, TAU)) if _rng.randf() > (0.5 if grazer else 0.38) else Vector2.ZERO
		if grazer and _wander == Vector2.ZERO: _idle_timer = minf(_idle_timer, _rng.randf_range(0.3, 1.0))
		var herd := _herd_centre()
		if _wander != Vector2.ZERO and herd != Vector2.INF and global_position.distance_to(herd) > 46.0:
			_wander = (_wander + global_position.direction_to(herd) * 1.4).normalized()
	var from_home := global_position.distance_to(center)
	if from_home > radius: _wander = global_position.direction_to(center)
	# Well off its ground (a chase let go, a warding done), it walks back with
	# purpose rather than drifting (pass 13).
	if from_home > radius + 60.0: return _wander * float(stats.speed) * 0.8
	return _wander * float(stats.speed) * 0.35

## Mean position of wild same-species creatures nearby (INF when alone).
func _herd_centre() -> Vector2:
	if tamed or bool(stats.predator): return Vector2.INF
	var sum := Vector2.ZERO
	var n := 0
	for other in near(get_tree(), global_position, 150.0):
		if other == self or other.is_dead or other.tamed or other.species != species: continue
		if other.global_position.distance_to(global_position) < 150.0:
			sum += other.global_position
			n += 1
	return sum / n if n > 0 else Vector2.INF

func set_order(value: String) -> bool:
	if value not in ORDERS or not tamed or is_dead: return false
	if value in ["work","return"] and worker.role().is_empty(): return false
	# The lead rope: taken from the satchel for a lead or a tether, given back after.
	var roped := order in ["lead", "tether"]
	if value == "tether":
		var post := _post_near(72.0)
		if post == NO_POST: return false
		if not roped and not InventoryManager.remove_item("lead_rope", 1): return false
		tether_cell = post
	elif value == "lead":
		if not roped and not InventoryManager.remove_item("lead_rope", 1): return false
	if roped and value not in ["lead", "tether"]:
		_give_rope()
		tether_cell = NO_POST
	order = value
	_order_anchor = global_position
	_wander_time = 0
	moves.cancel()
	_attack_time = 0
	_attack_target = null
	_threat = null
	provoked_time = 0
	stop()
	_path.clear()
	_work_swing_time=0
	return true

## The nearest hitching post (its cell) within `reach` px, NO_POST if none.
func _post_near(reach: float) -> Vector2i:
	if not is_instance_valid(_world): return NO_POST
	var here: Vector2i = _world.to_cell(global_position)
	var best := NO_POST
	var best_d := reach
	var r := int(ceil(reach / 16.0))
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var c := here + Vector2i(x, y)
			var p = _world.props.get(c)
			if not is_instance_valid(p) or p.kind != "hitching_post": continue
			var d := global_position.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = c
	return best

func _give_rope() -> void:
	var rope: Item = ItemDB.make("lead_rope")
	if rope and not InventoryManager.add_item(rope, 1) and is_instance_valid(_world):
		_world._drop("lead_rope", 1, global_position + Vector2(0, 6))

## Saddlebags: slots by the beast's size, more with the Saddlebags perk.
func bag_slots() -> int:
	var size := "small" if float(stats.radius) < 8.0 else ("medium" if float(stats.radius) < 12.0 else "large")
	var sk := skills()
	return int(BEAST_BAG.SLOTS[size]) + (int(sk.value("bag_slots")) if sk else 0)

## Fit saddlebags from the keeper's satchel ("" when done, else why not).
func fit_bag() -> String:
	if not tamed or is_dead: return "Only a companion carries bags."
	if baby: return "It's too small for saddlebags yet."
	if bag: return "It already carries saddlebags."
	if not InventoryManager.remove_item("saddlebag", 1): return "Make saddlebags at a workbench first (Taming: Saddlebags)."
	_make_bag()
	return ""

func _make_bag() -> void:
	bag = BEAST_BAG.new()
	bag.name = "Saddlebags"
	add_child(bag)
	var words := str(stats.name).split(" ")
	bag.setup(bag_slots(), ("%s's bags" % words[words.size() - 1]).to_upper())

## Take the bags back (only empty ones).
func remove_bag() -> String:
	if not bag: return "It carries no saddlebags."
	if not bag.is_empty(): return "Empty the saddlebags first."
	if not InventoryManager.add_item(ItemDB.make("saddlebag"), 1): return "No room in your satchel."
	bag.queue_free()
	bag = null
	return ""

## A little training (Genes: +1.7% a rank, three ranks a stat at most).
func train(stat: String) -> String:
	if not tamed or genes.is_empty(): return "Only a companion can be trained."
	if baby: return "Let it grow up first."
	if not Genes.can_train(genes, stat): return "It has trained all it can in that."
	if _train_rest > 0.0: return "It needs rest. Train again in %d s." % int(ceil(_train_rest))
	var food := str(stats.food)
	if InventoryManager.get_item_count(food) < TRAIN_FOOD: return "Training takes %d %s." % [TRAIN_FOOD, Ways.food_name(food)]
	InventoryManager.remove_item(food, TRAIN_FOOD)
	var g := genes.duplicate(true)
	var ranks: Dictionary = g.get("train", {})
	ranks[stat] = int(ranks.get(stat, 0)) + 1
	g["train"] = ranks
	set_genes(g)
	_train_rest = TRAIN_REST
	var sk := skills()
	if sk: sk.gain("taming", 8.0)
	return ""

func set_work_home() -> bool:
	if not tamed or is_dead or worker.role().is_empty(): return false
	worker.set_home()
	return true

func assign_nearest_work_chest() -> bool:
	return tamed and not is_dead and worker.assign_chest()

func _follow_position() -> Vector2:
	var followers: Array=[]
	for other in roster(get_tree()):
		if other.tamed and not other.is_dead and other.order=="follow": followers.append(other)
	var index:=maxi(0,followers.find(self))
	var angle:=TAU*float(index)/maxi(1,followers.size())+PI*0.5
	return _player.global_position+Vector2.from_angle(angle)*(38+float(stats.radius)+floori(index/6.0)*24)

func _navigate_to(goal: Vector2, delta: float) -> Vector2:
	if not is_instance_valid(_world) or not _world.has_method("to_cell"): return global_position.direction_to(goal)*float(stats.speed)
	_path_refresh-=delta
	if _path_refresh<=0 or _path_goal.distance_to(goal)>24:
		_path_refresh=1.2
		_path_goal=goal
		var start:Vector2i=_world.to_cell(global_position)
		var end:Vector2i=_world.to_cell(goal)
		var lo:=Vector2i(mini(start.x,end.x)-5,mini(start.y,end.y)-5)
		var hi:=Vector2i(maxi(start.x,end.x)+6,maxi(start.y,end.y)+6)
		if (hi-lo).x<=48 and (hi-lo).y<=48:
			var grid:=AStarGrid2D.new()
			grid.region=Rect2i(lo,hi-lo);grid.cell_size=Vector2(16,16);grid.offset=Vector2(8,8)
			grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
			grid.update()
			for y in range(lo.y,hi.y):
				for x in range(lo.x,hi.x):
					var c:=Vector2i(x,y)
					var point:=Vector2(c*16)+Vector2(8,8)
					var blocked:=false
					for offset in [Vector2.ZERO,Vector2(stats.radius,0),Vector2(-stats.radius,0),Vector2(0,stats.radius),Vector2(0,-stats.radius)]:
						if _world.is_blocked_at(point+offset): blocked=true;break
					grid.set_point_solid(c,blocked)
			grid.set_point_solid(start,false)
			_path=grid.get_point_path(start,end,true)
		else: _path=PackedVector2Array([goal])
	while _path.size()>0 and global_position.distance_to(_path[0])<10: _path.remove_at(0)
	return global_position.direction_to(_path[0])*float(stats.speed) if not _path.is_empty() else Vector2.ZERO

func set_stance(value: String) -> bool:
	if value not in STANCES or not tamed or is_dead: return false
	stance = value
	if value == "passive":
		moves.cancel()
		_attack_time = 0
		_attack_target = null
		_threat = null
		stop()
	return true

func can_mount() -> bool:
	return tamed and not baby and not is_dead and species in ["stego", "trike"] and saddle != null and saddle.id == species + "_saddle" and net_time <= 0 and not is_mounted()

func is_mounted() -> bool:
	return is_instance_valid(_mount_controller) and _mount_controller.is_mounted()

func mount(rider: Node2D) -> bool:
	return _mount_controller.mount(rider) if is_instance_valid(_mount_controller) else false

func dismount() -> bool:
	return _mount_controller.dismount() if is_instance_valid(_mount_controller) else false

func mount_attack(aim_world: Vector2) -> bool:
	return _mount_controller.mount_attack(aim_world) if is_instance_valid(_mount_controller) else false

## The rider's strike button down / up (a held trike charges a ram).
func mount_press(aim_world: Vector2) -> bool:
	return _mount_controller.mount_press(aim_world) if is_instance_valid(_mount_controller) else false

func mount_release(aim_world: Vector2) -> bool:
	return _mount_controller.mount_release(aim_world) if is_instance_valid(_mount_controller) else false

func feed_mount() -> bool:
	return _mount_controller.feed_mount() if is_instance_valid(_mount_controller) else false

func equip_saddle_from_inventory(index: int) -> bool:
	if not tamed or baby or is_dead or species not in ["stego", "trike"] or is_mounted(): return false
	if index < 0 or index >= InventoryManager.inventory.size(): return false
	var entry: Dictionary = InventoryManager.inventory[index]
	var item: Item = entry.item
	if not item or item.id != species + "_saddle" or int(entry.quantity) != 1: return false
	InventoryManager.inventory[index] = {"item":saddle,"quantity":1 if saddle else 0}
	saddle = item
	AudioManager.play_sfx("equip_gear")
	_mount_controller.refresh_appearance()
	InventoryManager.inventory_changed.emit()
	queue_redraw()
	return true

func unequip_saddle() -> bool:
	if is_dead or not saddle or is_mounted() or not InventoryManager.add_item(saddle,1): return false
	saddle = null
	AudioManager.play_sfx("equip_gear")
	_mount_controller.refresh_appearance()
	queue_redraw()
	return true

func get_status_summary() -> String:
	if order in ["work","return"]: return "%s · %s · %d/%d carried"%[order.capitalize(),worker.status,worker.count(),worker.CAPACITY]
	var looks := Genes.looks(genes)
	return "%s · %s%s%s" % [order.capitalize(), stance.capitalize(), " · Wading" if in_water else "", (" · " + looks) if looks != "" else ""]

## Its stats against its kind, readable through the Sky-Fang lens ("" until then).
func stat_reading() -> String:
	if genes.is_empty() or not is_inside_tree() or not Genes.lens(get_tree()): return ""
	return Genes.stat_line(genes)

func get_role_description() -> String:
	match species:
		"raptor": return "Swift pack hunter. Circles its prey, darts in and pounces from range."
		"rex": return "Apex predator. Crushing bites and a roaring charge; high vitality."
		"stego": return "Timber worker. Its spiked tail sweeps foes aside and fells wild trees."
		"trike": return "Vegetation worker. Gores up close and rams anything in its lane."
		"longneck": return "Gentle giant. Stomps the ground and sweeps its long tail."
		"allo": return "Big hunter. Fast bites and a crushing chomp; its scales make the finest armour."
		"lystro": return "Burrowing grazer. Small, stout and loyal; quick to trust."
		"alpha": return "The pack's alpha. Leaps from afar, rakes up close, and calls its pack."
		_: return "Nest worker. Produces an egg each active minute; carries up to 12."

## A wild grown-up of its kind close by (for a baby: they must be dealt with
## before it can be tamed).
func _kin_guarding() -> bool:
	for other in near(get_tree(), global_position, 200.0):
		if other != self and not other.is_dead and not other.tamed and not other.baby and other.species == species and other.global_position.distance_to(global_position) < 200.0:
			return true
	return false


func _separation() -> Vector2:
	var result := Vector2.ZERO
	var here := global_position
	for other in near(get_tree(), here, 40.0):
		if other == self or other.is_dead: continue
		var offset: Vector2 = here - other.global_position
		# No two bodies touch from further than 40 (radii are 14 at most).
		if absf(offset.x) > 40.0 or absf(offset.y) > 40.0: continue
		if offset.length() < body_radius + float(other.body_radius) + 5.0: result += offset.normalized()
	return result.limit_length(1.0)

func interact(item_id: String = "") -> Dictionary:
	if is_dead: return _result(false, false, "This creature has fallen.")
	if tamed:
		set_order({"follow":"stay", "stay":"guard", "guard":"roam", "roam":"follow"}.get(order, "follow"))
		return _result(true, false, "%s: %s" % [stats.name, order.capitalize()])
	if int(stats.feeds) <= 0: return _result(false, false, "%s will never eat from your hand." % stats.name)
	if item_id == "net":
		if baby: return _result(false, false, "It's only a baby: feed it from your hand.")
		if not bool(stats.predator): return _result(false, false, "Gentle feeding is enough for this herbivore.")
		if net_time > 1.0: return _result(false, false, "The net is still holding.")
		net_time = float(NET_TIME.get(species, 12.0))
		var tamer := skills()
		if tamer: net_time *= 1.0 + tamer.value("net_time")
		moves.cancel()
		_attack_time = 0.0
		stop()
		return _result(true, true, "Netted and down! Offer raw meat before it tears free.")
	# Pass 13: the Taming tree's lore decides which beasts will take the keeper
	# (a net still restrains any hunter: that's a fight, not a bond).
	var sk := skills()
	if sk and not sk.knows(species):
		return _result(false, false, "You don't know the %s well enough to win one. (Taming: %s)" % [stats.name, sk.lore_needed(species)])
	if baby and _kin_guarding():
		# Pass 13: reaching for a guarded baby is what brings its kin.
		if life: life.disturbed(_player)
		return _result(false, false, "Its kin rush to its side! Drive them off first.")
	if item_id != str(stats.food): return _result(false, false, get_interaction_hint())
	if not baby:
		var why: String = Ways.refusal(self)
		if why != "": return _result(false, false, why)
		if Ways.sets_down(species): return _set_offering(item_id)
	if Ways.way(species) == "net" and not baby and net_time <= 0: return _result(false, false, "Net this predator first.")
	if feed_cooldown > 0: return _result(false, false, "Let it eat. Feed again in %.0fs." % ceilf(feed_cooldown))
	if settle > 0.0 and net_time <= 0.0 and not baby:
		return _result(false, false, "It's watching you. Step back and give it room for a while.")
	trust += 1
	feed_cooldown = float(FEED_WAIT.get(species, 5.0))
	settle = 0.0 if species in EASY or net_time > 0.0 or baby else SETTLE
	unease = 0.0
	provoked_time = 0
	if not bool(stats.predator) or DinoArt.has_clip(art_key, "eat"): play_action("eat")
	if sk: sk.gain("taming", float(sk.XP.feed))
	if trust >= feeds_needed():
		_become_tamed()
		return _result(true, true, "%s trusts you! Interact to give orders." % stats.name)
	return _result(true, true, "%s trust: %d/%d" % [stats.name, trust, feeds_needed()])

## Won over: the bond is made.
func _become_tamed() -> void:
	tamed = true
	wake()
	_threat = null
	moves.cancel()
	_attack_time = 0
	_attack_target = null
	_order_anchor = global_position
	net_time = 0.0
	provoked_time = 0.0
	health = int(stats.hp)
	var sk := skills()
	if sk: sk.gain("taming", float(sk.XP.tame) + 2.0 * float(feeds_needed()))
	SignalBus.creature_tamed.emit(self)

## The keeper's skills (pass 13), or null (a bare test scene).
func skills() -> Node:
	return get_tree().get_first_node_in_group("skills") if is_inside_tree() else null

## Feeds it needs from this keeper: their handling cuts it (Skills.feeds_for).
func feeds_needed() -> int:
	var base := maxi(1, int(round(float(stats.feeds) * Genes.temper(genes, "feeds")))) if not baby else int(stats.feeds)
	var sk := skills()
	return sk.feeds_for(base) if sk and not baby else base

## Asleep: a herbivore settled for the night (the stego's way).
func asleep() -> bool:
	return life != null and str(life.goal) == "rest" and state == "rest" and TimeCycle.is_night()

## The keeper wears this beast's kin-smell (the allosaur's Rustback...).
func wearing_kin() -> bool:
	return Ways.KIN_SET.has(species) and is_instance_valid(_player) and SetBonus.active(_player) == str(Ways.KIN_SET[species])

## Food set down at the keeper's feet for a beast that won't eat from a hand.
func _set_offering(item_id: String) -> Dictionary:
	for other in get_tree().get_nodes_in_group("offerings"):
		if other.global_position.distance_to(global_position) < Ways.OFFER_SIGHT and other.item_id == item_id:
			return _result(false, false, "There's food down for it already. Back away and let it come.")
	var o := OFFERING.new()
	o.setup(item_id)
	var at: Vector2 = _player.global_position + Vector2(0, 6) if is_instance_valid(_player) else global_position
	o.global_position = at
	(_world if is_instance_valid(_world) else get_parent()).add_child(o)
	o.global_position = at
	return _result(true, true, "You set the %s down. Back away and let it come." % Ways.food_name(item_id))

## Going to an offering and eating it (Vector2.INF: nothing to go to).
func _offer_steer(delta: float) -> Vector2:
	if tamed or baby or provoked_time > 0.0 or not Ways.sets_down(species): return Vector2.INF
	if Ways.way(species) == "kin" and not wearing_kin():
		# It lets the food go, and its claim on it: it (or another) can come back.
		if is_instance_valid(_offer) and _offer.claimed_by == self: _offer.claimed_by = null
		_offer = null
		return Vector2.INF
	if not is_instance_valid(_offer) or _offer.is_queued_for_deletion():
		_offer = null
		_offer_scan -= delta
		if _offer_scan > 0.0: return Vector2.INF
		_offer_scan = 0.8
		for o in get_tree().get_nodes_in_group("offerings"):
			if o.item_id == str(stats.food) and o.global_position.distance_to(global_position) < Ways.OFFER_SIGHT and not is_instance_valid(o.claimed_by):
				_offer = o
				o.claimed_by = self
				break
		if _offer == null: return Vector2.INF
	# The keeper hanging over the food: it waits, watching.
	if is_instance_valid(_player) and _player.global_position.distance_to(_offer.global_position) < Ways.OFFER_SHY:
		state = "wary"
		if velocity.length() < 6.0: _face(global_position.direction_to(_player.global_position))
		return Vector2.ZERO
	var to := _offer.global_position - global_position
	if to.length() > float(stats.radius) + 6.0:
		state = "offering"
		return to.normalized() * float(stats.speed) * 0.7
	# It eats.
	_face(to, true)
	play_action("eat")
	_offer.eaten()
	_offer = null
	trust += int(Ways.OFFER_TRUST.get(species, 1))
	unease = 0.0
	var sk := skills()
	if sk: sk.gain("taming", float(sk.XP.feed))
	if trust >= feeds_needed():
		_become_tamed()
		notice.emit("%s trusts you! Interact to give orders." % stats.name)
	else:
		notice.emit("%s takes the offering. Trust %d/%d" % [stats.name, trust, feeds_needed()])
	return Vector2.ZERO

## Per-tick checks of the taming ways: a calm beast startled by a running
## keeper, a trike's stand, a respect run.
func _tick_taming(delta: float) -> void:
	_startle_wait = maxf(0.0, _startle_wait - delta)
	_train_rest = maxf(0.0, _train_rest - delta)
	if tamed or is_dead or not is_instance_valid(_player): return
	var calm_watch: bool = trust > 0 and _startle_wait <= 0.0 and Ways.way(species) == "calm"
	if not calm_watch and _stand_watch <= 0.0 and _respect_run <= 0.0: return
	var d := global_position.distance_to(_player.global_position)
	if calm_watch:
		if d < 90.0 and str(_player.state) == "run" and _player.velocity.length() > 60.0:
			trust = maxi(0, trust - 1)
			_startle_wait = 3.0
			settle = SETTLE
			_flee_time = 1.4
			if is_instance_valid(voice): voice.play_cue("hurt")
			notice.emit("The %s startles: walk up to it, don't run. Trust %d/%d" % [stats.name, trust, feeds_needed()])
	if _stand_watch > 0.0:
		_stand_watch -= delta
		var ring: float = float(COMFORT.get(species, 50.0)) + float(stats.radius) + 40.0
		if d > ring:
			_stand_watch = 0.0
			notice.emit("You gave ground. The %s doesn't think much of you yet." % stats.name)
		elif _stand_watch <= 0.0:
			tame_marks = maxi(tame_marks, Ways.marks_needed(species))
			trust += 1
			var sk := skills()
			if sk: sk.gain("taming", float(sk.XP.feed))
			notice.emit("The %s snorts and lets you be: you stood your ground. It will take berries now." % stats.name)
	if _respect_run > 0.0:
		_respect_run -= delta
		if d > Ways.RESPECT_GAP:
			_respect_run = 0.0
			tame_marks += 1
			_give_up()
			var need := Ways.marks_needed(species)
			var sk := skills()
			if sk: sk.gain("taming", float(sk.XP.feed) * 2.0)
			if tame_marks >= need: notice.emit("The %s lets you go: it has taken your measure. It will eat from your hand now." % stats.name)
			else: notice.emit("The %s lets you go: it has taken your measure. Respect %d/%d" % [stats.name, tame_marks, need])

## The keeper struck it (respect: now get away unhurt).
func _respect_struck() -> void:
	if tamed or baby or Ways.way(species) != "respect" or tame_marks >= Ways.marks_needed(species): return
	var sk := skills()
	if sk and not sk.knows(species): return
	# A blow struck up close (an arrow from afar proves nothing).
	if not is_instance_valid(_player) or _player.global_position.distance_to(global_position) > float(stats.radius) + 70.0: return
	_respect_run = Ways.RESPECT_TIME

## It landed a blow on the keeper: a respect run fails.
func on_struck_keeper() -> void:
	if _respect_run > 0.0:
		_respect_run = 0.0
		notice.emit("It caught you. No respect earned for that.")

## The keeper rolled clear of its charge (the Scarhorn's way).
func on_dodged() -> void:
	if tamed or Ways.way(species) != "dodge" or tame_marks >= Ways.marks_needed(species): return
	var sk := skills()
	if sk and not sk.knows(species): return
	tame_marks += 1
	if sk: sk.gain("taming", float(sk.XP.feed) * 2.0)
	var need := Ways.marks_needed(species)
	if tame_marks >= need:
		_give_up()
		notice.emit("You rolled clear again. The %s snorts and stands off: it will eat from your hand now." % stats.name)
	else:
		notice.emit("You rolled clear of the %s's charge. Respect %d/%d" % [stats.name, tame_marks, need])

## A rock broken near it (the club-tail's way: it roots through the rubble).
func on_rock_cleared(at: Vector2) -> void:
	if tamed or baby or is_dead or Ways.way(species) != "clearing" or provoked_time > 0.0: return
	if not is_instance_valid(_player) or _player.global_position.distance_to(global_position) > 220.0: return
	var sk := skills()
	if sk and not sk.knows(species): return
	tame_marks += 1
	trust += 1
	if sk: sk.gain("taming", float(sk.XP.feed))
	_face(global_position.direction_to(at), true)
	play_action("eat")
	var need := Ways.marks_needed(species)
	if trust >= feeds_needed():
		_become_tamed()
		notice.emit("%s trusts you! Interact to give orders." % stats.name)
	else:
		if tame_marks >= need: notice.emit("The %s noses through the rubble for grubs. It will take berries now. Trust %d/%d" % [stats.name, trust, feeds_needed()])
		else: notice.emit("The %s noses through the rubble for grubs (%d/%d)." % [stats.name, tame_marks, need])

func _result(ok: bool, consume: bool, message: String) -> Dictionary:
	notice.emit(message)
	return {"ok":ok, "consume":consume, "message":message}

func get_interaction_hint() -> String:
	if tamed and baby: return "%s · growing (%d%%) · %s · E: next order" % [stats.name, int(growth * 100.0), order.capitalize()]
	if tamed: return "%s · %s · E: next order" % [stats.name, order.capitalize()]
	if int(stats.feeds) <= 0: return "%s · Untameable" % stats.name
	if not baby and settle <= 0.0: return Ways.hint(self)
	if baby: return "%s · Hand-feed %s (mind its parents) · Trust %d/%d" % [stats.name, "raw meat" if str(stats.food) == "trex_meat" else "berries", trust, int(stats.feeds)]
	if bool(stats.predator): return "%s · Net, then raw meat · Trust %d/%d" % [stats.name, trust, int(stats.feeds)]
	if settle > 0.0: return "%s · Back off and let it settle · Trust %d/%d" % [stats.name, trust, int(stats.feeds)]
	return "%s · Hand-feed berries · Trust %d/%d" % [stats.name, trust, int(stats.feeds)]


## Taming patience (see SETTLE/UNEASE): a beast that has started to trust the
## keeper settles only while they keep their distance, and one crowded while it
## isn't eating grows uneasy and at last lashes out, forgetting two feeds.
func _tick_patience(delta: float) -> void:
	if tamed or baby or species in EASY or trust <= 0 or net_time > 0.0 or not is_instance_valid(_player):
		unease = 0.0
		return
	var d := global_position.distance_to(_player.global_position) - float(stats.radius)
	if d > SPACE * 1.5: settle = maxf(0.0, settle - delta)
	if d < SPACE and feed_cooldown <= 0.0 and settle > 0.0:
		unease += delta
		if unease >= UNEASE:
			unease = 0.0
			trust = maxi(0, trust - 2)
			_threat = _player
			provoked_time = 4.0
			notice.emit("%s lashes out: you crowded it. Trust %d/%d" % [stats.name, trust, int(stats.feeds)])
	else:
		unease = maxf(0.0, unease - delta * 2.0)

## knockback: shove in px/s away from the source (-1 = the default nudge).
func take_damage(amount: int, source: Variant = null, knockback := -1.0) -> void:
	if is_dead or amount <= 0 or untouchable: return
	wake()
	_struck_clock = 1.0
	_alert_left = minf(_alert_left, 0.2)
	if source is Node and is_instance_valid(_player) and source == _player: _respect_struck()
	# A struck baby cries for its kin.
	if baby and not tamed and life and source is Node2D and is_instance_valid(source): life.disturbed(source)
	# Bony plates (the ankylosaur): light blows barely scratch it.
	if PLATED.has(species) and not baby: amount = maxi(1, amount - int(PLATED[species]))
	# A thick hide (pass 13, Genes).
	if not genes.is_empty(): amount = maxi(1, int(round(float(amount) * Genes.temper(genes, "harm"))))
	# A keeper's companions are hardier for a Beastfriend, a mount for a Beastmaster (pass 13).
	if tamed:
		var sk := skills()
		if sk:
			var guard: float = 1.0 + sk.value("companion_hp")
			if is_mounted(): guard /= maxf(0.1, 1.0 - sk.value("mount_guard"))
			amount = maxi(1, int(ceil(float(amount) / guard)))
	health = maxi(0, health - amount)
	_hurt_time = 0.14
	if is_instance_valid(voice): voice.play_cue("hurt")
	provoked_time = 10.0
	var source_position := Vector2.ZERO
	if source is Node2D and is_instance_valid(source):
		_threat = source
		source_position = source.global_position
	elif source is Vector2:
		source_position = source
		# Compatibility for legacy position-only attacks: resolve the nearest
		# actual attacker, not always the player.
		var nearest := 12.0
		for candidate in roster(get_tree()):
			if candidate == self or not _valid_target(candidate): continue
			var d: float = candidate.global_position.distance_to(source_position)
			if d < nearest:
				nearest = d
				_threat = candidate
	else:
		_threat = _player
	if source_position != Vector2.ZERO and not (tamed and order == "stay"):
		# A keeper's blow (no explicit shove) knocks a dodo about and barely
		# rocks a longneck.
		var shove := (110.0 if knockback < 0.0 else knockback) * float(DinoMoves.MASS.get(species, 0.5))
		_knock = source_position.direction_to(global_position) * shove
	# Light bodies flinch and lose a blow they were winding up; heavy ones shrug
	# a hit off mid-attack, and between moves flinch briefly at most once every
	# 1.2 s so quick blows cannot stun-lock them.
	var heavy := bool(body.armour)
	if (not moves.busy() or not heavy) and (not heavy or _flinch_ready <= 0.0):
		if moves.busy() and not moves.mounted: moves.cancel()
		if health > 0 and DinoArt.has_clip(art_key, "hurt"):
			_flinch = minf(0.2 if heavy else 0.32, DinoArt.duration(art_key, "hurt"))
			_flinch_ready = 1.2 if heavy else 0.0
			_play_clip("hurt", true)
	_rally(source)
	_rival_check(source)
	_action_time = 0.0
	_action = ""
	if not tamed and trust > 0: trust = maxi(0, trust - 1)
	if health <= 0: _die()
	queue_redraw()

## A heavy blow (a maul's smash, pass 13) staggers even an armoured beast: it
## loses whatever it was winding up and reels a moment (a boss, much less).
func stagger(seconds: float) -> void:
	if is_dead or tamed or untouchable: return
	var t := seconds * (0.35 if bool(stats.get("boss", false)) else 1.0)
	if moves.busy() and not moves.mounted: moves.cancel()
	_flinch = maxf(_flinch, t)
	if DinoArt.has_clip(art_key, "hurt"): _play_clip("hurt", true)

## A cut that keeps bleeding (the stego's spiked tail): DinoMoves applies it.
func apply_bleed(damage_per_second: float, seconds: float, source: Node = null) -> void:
	if is_dead or damage_per_second <= 0.0: return
	bleed.apply(damage_per_second, seconds, source)
	queue_redraw()

## A bleed tick drains health without a shove, a flinch or a new target.
func _bleed_hurt(amount: int) -> void:
	if untouchable: return
	health = maxi(0, health - amount)
	_bleed_flash = 0.1
	if health <= 0: _die()
	queue_redraw()

## A territorial fight between wild beasts ends before a death: badly hurt by
## another wild creature (not the keeper, not a companion), a beast breaks off
## and runs, and the winner lets it go. Against the keeper they fight on.
func _rival_check(source: Variant) -> void:
	if tamed or baby or bool(stats.get("boss", false)) or not (source is Node2D) or not is_instance_valid(source): return
	if not source.is_in_group("forest_creatures") or source.tamed: return
	if float(health) > float(stats.hp) * 0.35: return
	_retreat_from = source
	_retreat_time = 7.0
	_threat = null
	provoked_time = 0.0
	moves.cancel()
	_disputing = null
	_dispute_rest = 120.0
	if source.get("_threat") == self:
		source._threat = null
		source.provoked_time = 0.0
		source._give_up()
		# The winner holds its ground and roars it off (pass 12).
		if source.get("_disputing") == self:
			source._disputing = null
			source._dispute_rest = 90.0
			source.play_action("roar", 1.1)


## Wild kin react together: a hurt raptor calls its pack onto the attacker, a
## hurt herbivore brings its herd round to defend it, a startled dodo
## scatters the flock.
func _rally(source: Variant) -> void:
	if tamed or not (source is Node2D) or not is_instance_valid(source): return
	for other in roster(get_tree()):
		if other == self or other.is_dead or other.tamed or other.species != species: continue
		if other.global_position.distance_to(global_position) > 160.0: continue
		other.wake()
		if species == "dodo":
			other._flee_time = maxf(other._flee_time, 1.6)
		else:
			other._threat = source
			other.provoked_time = maxf(other.provoked_time, 8.0)

func get_attack_damage() -> int:
	return int(stats.damage)

func _die() -> void:
	if is_mounted(): _mount_controller.dismount(true)
	is_dead = true
	bleed.clear()
	moves.cancel()
	_attack_time = 0.0
	stop()
	collision_layer = 0
	$Hurtbox.set_deferred("monitorable", false)
	SignalBus.creature_defeated.emit(self)
	var loot := {"trex_meat": 1 if species == "dodo" or baby else 2}
	# Nothing to eat on a skeleton.
	if species == "ossuar" or bool(VARIANTS.get(variant, {}).get("bone", false)): loot.clear()
	for id in worker.cargo: loot[id]=int(loot.get(id,0))+int(worker.cargo[id])
	worker.cargo.clear()
	if bag:
		var carried: Dictionary = bag.contents()
		for id in carried: loot[id] = int(loot.get(id, 0)) + int(carried[id])
		loot["saddlebag"] = int(loot.get("saddlebag", 0)) + 1
	if saddle: loot[saddle.id] = 1
	if baby:
		_drop_loot(loot)
		_fall_and_fade()
		return
	# Wildlife never respawns, so these are a journey's whole supply (see
	# docs/ARMOR_PROGRESSION.md): one raptor covers the Fangbound set (1 fang per
	# piece) even if the other is tamed; the rex covers the Tyrant set plus a bed.
	# Pass 12: every beast gives what its own armour and weapons are made of,
	# a little at a time (a set is a hunt of several).
	if species == "raptor":
		loot["raptor_fang"] = 2
		loot["raptor_hide"] = 1
	if species == "trike":
		loot["trike_horn"] = 1
		loot["trike_hide"] = 2
	if species == "stego": loot["stego_plate"] = 2
	if species == "parasaur": loot["parasaur_crest"] = 1
	if species == "longneck": loot["longneck_hide"] = 3
	# The allosaurus is where a keeper gets crystal scale for the finest
	# armour; the rex (all but unkillable) drops a hoard of it.
	if species == "allo":
		loot["trex_scale"] = 3
		loot["allo_tooth"] = 1
	if species == "rex": loot["trex_scale"] = 8
	# Pass 12: the dunes' and the Pale Lands' beasts.
	if species == "dimetrodon": loot["sail_scale"] = 2
	if species == "anky": loot["anky_plate"] = 3
	if species == "proto": loot["proto_frill"] = 1
	if species == "carno":
		loot["carno_horn"] = 2
		loot["trex_scale"] = 4
	if species == "yuty":
		loot["ashmane_fur"] = 4
		loot["trex_scale"] = 5
	if species == "compy": loot = {"trex_meat": 1} if _rng.randf() < 0.35 else {}
	# Pass 13: the new beasts' spoils (their weapons are made of these and
	# their lands' ores).
	if species == "utah":
		loot["sickle_claw"] = 2
		loot["raptor_hide"] = 2
	if species == "deino": loot["deino_claw"] = 1
	if species == "sucho":
		loot["sucho_claw"] = 2
		loot["reed_perch"] = 2
	if species == "spino":
		loot["spino_spine"] = 4
		loot["trex_scale"] = 6
		loot["reed_perch"] = 4
	if species == "alpha":
		loot["raptor_fang"] = 6
		loot["alpha_crest"] = 1
	# The Buried King: its crown, and a heap of old bone and crystal.
	if species == "ossuar":
		loot["bone_crown"] = 1
		loot["old_bone"] = 10
		loot["fossil_bone"] = 6
		loot["prism_crystal"] = 3
		loot["crystal_shard"] = 8
	for id in VARIANTS.get(variant, {}).get("loot", {}):
		loot[id] = int(loot.get(id, 0)) + int(VARIANTS[variant].loot[id])
	_drop_loot(loot)
	_fall_and_fade()


func _drop_loot(loot: Dictionary) -> void:
	for id in loot:
		var item = ItemDB.make(id)
		if item:
			var drop = preload("res://Items/DroppedItem.tscn").instantiate()
			drop.setup_item(item, loot[id])
			drop.position = position + Vector2(_rng.randf_range(-8,8), 4)
			get_parent().call_deferred("add_child", drop)


## Fall over, lie still for a moment, then fade away.
func _fall_and_fade() -> void:
	var fall := 0.0
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("death_" + _facing):
		_sprite.speed_scale = 1.0
		_sprite.play("death_" + _facing)
		_clip = "death"
		fall = DinoArt.duration(art_key, "death")
		_shake_near(0.4 if species == "ossuar" else (0.12 if species in ["rex", "longneck"] else 0.0), 220.0 if species == "ossuar" else 160.0)
	var tween := create_tween()
	tween.tween_interval(fall + 0.9)
	tween.tween_property(_sprite, "modulate", Color(0.45, 0.52, 0.49, 0.0), 0.8)
	tween.tween_callback(queue_free)

func serialize() -> Dictionary:
	var data := {"species":species, "x":position.x, "y":position.y, "health":health, "tamed":tamed, "trust":trust, "order":order, "stance":stance, "saddle":saddle.id if saddle else "", "anchor_x":_order_anchor.x, "anchor_y":_order_anchor.y, "dead":is_dead,"worker":worker.serialize()}
	if baby:
		data.baby = true
		data.growth = growth
	if variant != "": data.variant = variant
	if life and life.has_nest(): data.nest = [life.nest.x, life.nest.y]
	if tame_marks > 0: data.marks = tame_marks
	if not genes.is_empty(): data.genes = genes
	if bag: data.bag = bag.get_save_data()
	if tether_cell != NO_POST: data.tether = [tether_cell.x, tether_cell.y]
	if _train_rest > 0.0: data.train_rest = _train_rest
	return data

func restore(data: Dictionary) -> void:
	_worker_restore=data.get("worker",{})
	species = str(data.get("species", "raptor"))
	position = Vector2(float(data.get("x",0)), float(data.get("y",0)))
	if bool(data.get("baby", false)) or baby: set_baby(bool(data.get("baby", false)), float(data.get("growth", 0.0)))
	if str(data.get("variant", "")) != "": set_variant(str(data.variant))
	var nest_at: Array = data.get("nest", [])
	if life and nest_at.size() == 2: life.nest = Vector2i(int(nest_at[0]), int(nest_at[1]))
	if worker.creature: worker.restore(_worker_restore)
	home = position
	health = int(data.get("health",0))
	tamed = bool(data.get("tamed",false))
	trust = int(data.get("trust",0))
	tame_marks = int(data.get("marks", 0))
	var tether: Array = data.get("tether", []) if data.get("tether", []) is Array else []
	if tether.size() == 2: tether_cell = Vector2i(int(tether[0]), int(tether[1]))
	_train_rest = float(data.get("train_rest", 0.0))
	if data.get("bag", null) is Dictionary:
		if not bag: _make_bag()
		bag.apply_save_data(data.bag)
	if data.get("genes", null) is Dictionary and not (data.genes as Dictionary).is_empty():
		set_genes(data.genes, true)
	elif not bool(SPECIES[species].get("boss", false)):
		# A beast from before pass 13: its own genes, from where it stands.
		var grng := RandomNumberGenerator.new()
		grng.seed = int(position.x * 735 + position.y * 97) + species.hash() + 7919
		set_genes(Genes.roll(grng, clampf(position.length() / FAR_EDGE, 0.0, 1.0)), true)
	order = str(data.get("order","follow"))
	if order not in ORDERS: order = "follow"
	var saddle_id := str(data.get("saddle", ""))
	saddle = ItemDB.make(saddle_id) if tamed and species in ["stego","trike"] and saddle_id == species + "_saddle" else null
	if is_mounted(): _mount_controller.dismount(true)
	stance = str(data.get("stance", "neutral"))
	if stance not in STANCES: stance = "neutral"
	_order_anchor = Vector2(float(data.get("anchor_x", position.x)), float(data.get("anchor_y", position.y)))
	_anchor_restored = true
	if bool(data.get("dead",false)) or (data.has("health") and health <= 0):
		is_dead = true
		queue_free()

func _draw() -> void:
	if stats == null or is_dead: return
	draw_ellipse_shadow()
	if in_water:
		var ripple := float(stats.radius) + fmod(_clock * 9.0, 7.0)
		draw_arc(Vector2(0, 3), ripple, 0.1, PI - 0.1, 18, Color(0.55, 0.94, 0.95, 0.5), 1)
	_draw_telegraph()
	if _alert_mark > 0.0: _draw_alert_mark()
	if tamed and order in ["lead", "tether"]: _draw_rope()
	if not tamed and asleep(): _draw_sleep_mark()
	if net_time > 0:
		var r := float(stats.radius) + 6
		for i in range(-2,3):
			draw_line(Vector2(-r,i*4), Vector2(r,i*4+7), Color("e4ca8b"), 1)
			draw_line(Vector2(i*4,-r), Vector2(i*4+7,r), Color("e4ca8b"), 1)
	if health < int(stats.hp) or trust > 0 or tamed:
		var y := -58.0 if is_mounted() else -float(stats.height) - 3
		draw_rect(Rect2(-13,y,26,4),Color("10282b"))
		draw_rect(Rect2(-12,y+1,24.0*float(health)/float(stats.hp),2),Color("8bd3a2") if tamed else Color("ed9a72"))
		if trust > 0 and not tamed: draw_rect(Rect2(-12,y-3,24.0*minf(1.0,float(trust)/float(feeds_needed())),2),Color("62e1d7"))
		if tamed: draw_circle(Vector2(0,y-4),2,Color("76ead7"))
		if bleed.active():
			# A blood drop beside the bar while the cut is bleeding.
			draw_rect(Rect2(15,y,2,3),Color("b8323f"))
			draw_rect(Rect2(15.5,y-1,1,1),Color("d4545c"))
	if moves.holding:
		# The ram's charge, over the rider's head: gold while building, bright when full.
		var cy := -66.0 if is_mounted() else -float(stats.height) - 9
		var full := moves.charge >= 1.0
		draw_rect(Rect2(-13,cy,26,4),Color("10282b"))
		draw_rect(Rect2(-12,cy+1,24.0*moves.charge,2),Color("fff1b8") if full and int(_clock*10.0)%2==0 else Color("e8b84a"))

## Asleep (pass 13: the stego's way is to feed it asleep): a small "z" rising
## over its head now and then.
func _draw_sleep_mark() -> void:
	var t := fmod(_clock + float(get_instance_id() % 7), 2.4) / 2.4
	var top := Vector2(float(stats.radius) * 0.5, -float(stats.height) - 4.0 - t * 8.0).round()
	var a := clampf(1.0 - t, 0.0, 1.0) * 0.9
	var ink := Color(0.12, 0.14, 0.2, a)
	var fill := Color(0.86, 0.92, 1.0, a)
	for p in [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(1, 1), Vector2(0, 2), Vector2(1, 2), Vector2(2, 2)]:
		draw_rect(Rect2(top + p + Vector2(1, 1), Vector2.ONE), ink)
	for p in [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(1, 1), Vector2(0, 2), Vector2(1, 2), Vector2(2, 2)]:
		draw_rect(Rect2(top + p, Vector2.ONE), fill)

## The lead rope or the tether: a sagging line from its neck to the keeper's
## hand or the post's ring.
func _draw_rope() -> void:
	var anchor := Vector2.INF
	if order == "lead" and is_instance_valid(_player): anchor = to_local(_player.global_position + Vector2(0, -8))
	elif order == "tether": anchor = to_local(Vector2(tether_cell * 16) + Vector2(8, -18))
	if anchor == Vector2.INF: return
	var neck := Vector2(0.0, -float(stats.height) * 0.45)
	var span := neck.distance_to(anchor)
	var sag := clampf(span * 0.12, 2.0, 9.0)
	var points := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		points.append((neck.lerp(anchor, t) + Vector2(0.0, sin(t * PI) * sag)).round())
	draw_polyline(points, Color("3b2a1a"), 2.0)
	draw_polyline(points, Color("9a7a4a"), 1.0)

## The "!" of the alert: a pixel mark over the head that pops up, bobs while
## the display lasts and fades as the beast comes.
func _draw_alert_mark() -> void:
	var top := (-58.0 if is_mounted() else -float(stats.height)) - 16.0
	var rise := clampf((_alert_mark - _alert_left) * 12.0, 0.0, 3.0) if _alert_left > 0.0 else 3.0
	var bob := -1.0 if _alert_left > 0.0 and int(_clock * 6.0) % 2 == 0 else 0.0
	var a := clampf(_alert_mark / 0.45, 0.0, 1.0) if _alert_left <= 0.0 else 1.0
	var at := Vector2(0, top - rise + bob).round()
	var ink := Color(0.1, 0.05, 0.05, 0.9 * a)
	var fill := Color(1.0, 0.36, 0.24, a)
	draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 11)), ink)
	draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 6)), fill)
	draw_rect(Rect2(at + Vector2(-1, 7), Vector2(2, 2)), fill)


## Faint ground warnings for the big telegraphed moves: the charge lane and
## the stomp ring grow brighter as the blow approaches.
func _draw_telegraph() -> void:
	if moves == null: return
	var tg := moves.telegraph()
	if tg.is_empty(): return
	var p := float(tg.progress)
	var color := Color(1.0, 0.86, 0.62, 0.08 + 0.22 * p)
	match str(tg.shape):
		"lane":
			var aim: Vector2 = tg.aim
			var side := aim.orthogonal() * float(tg.width) * 0.5
			var length := float(tg.length) * (0.35 + 0.65 * p)
			for s in [-1.0, 1.0]:
				var a: Vector2 = (side * s + Vector2(0, 2)).round()
				draw_line(a, (a + aim * length).round(), color, 1)
		"ring":
			var centre: Vector2 = tg.centre + Vector2(0, 2)
			var r := float(tg.radius)
			var points := PackedVector2Array()
			for i in 33:
				var a := TAU * float(i) / 32.0
				points.append((centre + Vector2(cos(a) * r, sin(a) * r * 0.45)).round())
			draw_polyline(points, color, 1)
			var inner := r * p
			if inner > 4.0:
				var pts2 := PackedVector2Array()
				for i in 25:
					var a := TAU * float(i) / 24.0
					pts2.append((centre + Vector2(cos(a) * inner, sin(a) * inner * 0.45)).round())
				draw_polyline(pts2, Color(color, color.a * 0.6), 1)

func draw_ellipse_shadow() -> void:
	var points := PackedVector2Array()
	# Off the ground (a leap), the shadow draws in and pales.
	var lift := clampf(hop / 24.0, 0.0, 0.5)
	for i in range(16): points.append(Vector2(cos(i*TAU/16.0)*float(stats.radius)*1.3*(1.0-lift),sin(i*TAU/16.0)*4*(1.0-lift)))
	draw_colored_polygon(points,Color(0.03,0.10,0.09,0.27*(1.0-lift*0.6)))
