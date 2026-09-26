extends RefCounted
## Armour set bonuses (pass 12). A whole set (helm, chest and legs of one
## armour, by item id prefix: bone_helmet, bone_chestplate, bone_leggings)
## gives its bonus on top of the pieces' defence: the reason to grind a
## beast for every piece rather than mix and match.
##
## The keeper (ForestPlayer) and the bow ask these helpers; a creature asks
## has_shadow() (the Tyrant set keeps the smaller hunters off, like a tamed
## rex does).

const SETS := {
	"moss": {"name": "Mossweave", "text": "Wounds mend 20% faster"},
	"leather": {"name": "Trail Leather", "text": "You move 6% faster"},
	"bone": {"name": "Fangbound", "text": "You move 12% faster"},
	"crystal": {"name": "Skyshard", "text": "+4 defence"},
	"tide": {"name": "Tidecaller", "text": "You wade as fast as you walk"},
	"rex": {"name": "Tyrant", "text": "Blows 15% harder; raptors and allosaurs keep off"},
	"horn": {"name": "Hornguard", "text": "Blows barely move you; 10% less harm"},
	"plate": {"name": "Plateback", "text": "Your blows and spikes draw blood"},
	"rust": {"name": "Rustback", "text": "Blows 20% harder"},
	# Pass 12: the tribes' own dress.
	"sunward": {"name": "Sunward", "text": "The wraps keep out half the ash; quicker on sand"},
	"ashen": {"name": "Ashen", "text": "Raiders take you for one of their own"},
}
const PIECES := ["_helmet", "_chestplate", "_leggings"]


## The set an armour item belongs to ("" for anything else).
static func set_of(item) -> String:
	if item == null: return ""
	var id := str(item.id)
	for suffix in PIECES:
		if id.ends_with(suffix): return id.trim_suffix(suffix)
	return ""


## The whole set the keeper wears, or "".
static func active(player) -> String:
	if player == null or not player.get("equipped_armor"): return ""
	var armor: Dictionary = player.equipped_armor
	var first := set_of(armor.get("head"))
	if first == "" or not SETS.has(first): return ""
	if set_of(armor.get("chest")) != first or set_of(armor.get("legs")) != first: return ""
	return first


static func speed_mult(player) -> float:
	match active(player):
		"leather": return 1.06
		"bone": return 1.12
	return 1.0


## Sunward wraps: a quicker step on sand (the keeper asks with the ground).
static func sand_speed_mult(player) -> float:
	return 1.1 if active(player) == "sunward" else 1.0


## How much of the Pale Lands' ash the set keeps out (the head wraps).
static func ash_guard(player) -> float:
	return 0.5 if active(player) == "sunward" else 0.0


## The Ashen raiders' dress: raiders don't come for a keeper wearing it.
static func disguised(player) -> bool:
	return active(player) == "ashen"


static func damage_mult(player) -> float:
	match active(player):
		"rex": return 1.15
		"rust": return 1.2
	return 1.0


static func defense_bonus(player) -> int:
	return 4 if active(player) == "crystal" else 0


## Harm taken (Hornguard: a tenth less) and how far a blow shoves.
static func harm_mult(player) -> float:
	return 0.9 if active(player) == "horn" else 1.0


static func knockback_mult(player) -> float:
	return 0.3 if active(player) == "horn" else 1.0


static func recovery_mult(player) -> float:
	return 1.2 if active(player) == "moss" else 1.0


## Extra wading (added to the trinkets' wading_bonus).
static func wading_bonus(player) -> float:
	return 0.7 if active(player) == "tide" else 0.0


## Plateback: the keeper's blows bleed (per second, for 3 s), and so does
## whatever strikes the keeper up close.
static func bleeds(player) -> bool:
	return active(player) == "plate"


## The Tyrant set: the smaller hunters keep their distance.
static func has_shadow(player) -> bool:
	return active(player) == "rex"


## "Hornguard set: Blows barely move you; 10% less harm" (the Gear panel).
static func summary(player) -> String:
	var s := active(player)
	if s == "": return ""
	return "%s set: %s" % [SETS[s].name, SETS[s].text]
