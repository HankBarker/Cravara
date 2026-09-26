"""The keeper's skills as constellations (pass 14): the stars, their links and
the figure each skill's stars draw in the sky.

    python tools/skills/constellations.py preview   # a PNG sheet in the scratch dir
    python tools/skills/constellations.py write     # game/Forest/progress/SkillStars.gd

Every skill is a true tree drawn as a figure in the manner of Skyrim's
constellations: Combat a sword, Archery a drawn bow, Taming a trike's skull,
Breeding an egg, Farming a pitchfork, Gathering a crossed pick and axe,
Fishing a leaping fish on a line.

A star opens when the skill reaches its level (needs) and ANY star it hangs
from (after) is learned; the root has no after. A star costs one of that
skill's points. A skill earns a point a level and one more every tenth
(pass 15: fifty levels, a long road).

Pass 15 (Hank: "the trees need to be much more expansive... the sword offers
many more opportunities"): every constellation has 28 stars, and many can be
lit again (ranks: each rank a point, RANK_STEP more levels than the last, the
star's effects again). A whole constellation costs 54 points, what a skill
earns by level 50: a mastered skill lights it all, and on the way there every
point is a choice.

Coordinates are on a 150 x 90 sky (x right, y down); the panel draws it at 2x.
Effects are summed by Skills.value(effect). An effect named in
Trinkets.EFFECTS (defense, bleed, speed, luck, ...) also reaches every system
a trinket touches, through Trinkets.value.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "game", "Forest", "progress", "SkillStars.gd")
SCRATCH = os.environ.get("CRAVERA_SCRATCH", os.path.join(ROOT, "art", "skills-preview"))

W, H = 150, 90


def S(id_, name, at, needs, after, effects, text, ranks=1):
    return {"id": id_, "name": name, "at": at, "needs": needs, "after": after, "effects": effects, "text": text, "ranks": ranks}


## Each rank of a star needs this many more levels than the last.
RANK_STEP = 5
## What a whole constellation costs (a skill's points at level 50).
TREE_COST = 54
## Effects that are a thing learned, not an amount: never ranked.
BINARY = {"soak", "keep_water", "lore", "rope", "arrow_pierce", "arrow_craft", "quick_loose", "smash_plates", "cold"}


def ellipse(cx, cy, rx, ry, a0=0.0, a1=360.0, step=15.0):
    pts = []
    a = a0
    while a <= a1 + 1e-6:
        r = math.radians(a)
        pts.append((round(cx + rx * math.cos(r), 1), round(cy + ry * math.sin(r), 1)))
        a += step
    return pts


def egg(cx=75.0, cy=48.0, rx_top=26.0, rx_bot=31.0, ry_top=44.0, ry_bot=40.0, step=15.0):
    pts = []
    a = 0.0
    while a <= 360.0 + 1e-6:
        r = math.radians(a)
        s, c = math.sin(r), math.cos(r)
        top = s < 0
        pts.append((round(cx + (rx_top if top else rx_bot) * c, 1), round(cy + (ry_top if top else ry_bot) * s, 1)))
        a += step
    return pts


FIGURES = {
    "combat": {"title": "The Blade", "lines": [
        [(67, 64), (67, 15), (75, 2), (83, 15), (83, 64)],
        [(36, 61), (43, 71), (107, 71), (114, 61)],
        [(72, 72), (72, 82)], [(78, 72), (78, 82)],
        [(75, 82), (79, 86), (75, 90), (71, 86), (75, 82)],
    ]},
    "archery": {"title": "The Drawn Bow", "lines": [
        [(137, 40), (146, 45), (137, 50)],
        [(56, 45), (43, 35)], [(56, 45), (43, 55)],
        [(95, 7), (91, 2)], [(95, 83), (91, 88)],
    ]},
    "taming": {"title": "The Horned Skull", "lines": [
        ellipse(75, 58, 46, 55, 180, 360, 12),
        [(33, 58), (47, 62), (62, 80), (75, 89), (88, 80), (103, 62), (117, 58)],
        ellipse(64, 47, 5, 4, 0, 360, 45), ellipse(86, 47, 5, 4, 0, 360, 45),
        [(71, 72), (75, 62), (79, 72)],
    ]},
    "breeding": {"title": "The Egg", "lines": [
        egg(),
    ]},
    "farming": {"title": "The Pitchfork", "lines": [
        [(47, 47), (51, 42)], [(103, 47), (99, 42)],
        [(51, 6), (51, 2)], [(75, 6), (75, 1)], [(99, 6), (99, 2)],
        [(73, 88), (75, 90), (77, 88)],
    ]},
    "gathering": {"title": "Pick and Axe", "lines": [
        [(75, 47), (35, 85)], [(75, 47), (115, 85)],
        [(99, 3), (108, 15), (119, 26)],
        [(42, 15), (32, 5), (25, 14), (28, 25), (42, 15)],
    ]},
    "fishing": {"title": "The Leaping Fish", "lines": [
        ellipse(70, 46, 42, 22, 0, 360, 15),
        [(110, 40), (136, 21), (128, 46), (136, 71), (110, 52)],
        [(53, 27), (63, 14), (74, 7), (86, 26)],
        [(24, 0), (24, 50), (25, 55), (29, 57), (33, 53)],
        ellipse(40, 41, 3, 3, 0, 360, 45),
    ]},
}

STARS = {
    # ---------------------------------------------------------------- Combat: a sword
    "combat": [
        S("blade_sense", "Blade-sense", (75, 69), 1, [], {"melee_damage": 0.05}, "+5% melee damage."),
        S("hardened", "Hardened", (75, 77), 6, ["blade_sense"], {"defence": 4.0}, "+4 defence."),
        S("second_wind", "Second Wind", (75, 86), 17, ["hardened"], {"feast": 4.0}, "+4 health each time a foe falls."),
        S("sweep_arc", "Wide Arc", (61, 69), 6, ["blade_sense"], {"sweep_arc": 20.0}, "Sweeping blows cut 20 degrees wider."),
        S("sweep_cleave", "Cleave", (48, 65), 17, ["sweep_arc"], {"sweep_more": 0.25}, "Every foe in a sweep takes its full weight."),
        S("bloodletter", "Bloodletter", (40, 57), 28, ["sweep_cleave"], {"bleed": 1.0}, "Your blows open wounds that bleed 1 a second."),
        S("smash_quake", "Quake", (89, 69), 6, ["blade_sense"], {"smash_spot": 8.0, "smash_knock": 0.25}, "Smashes land wider (+8) and shove a quarter harder."),
        S("smash_bones", "Bonebreaker", (102, 65), 17, ["smash_quake"], {"smash_plates": 1.0, "smash_stagger": 0.3}, "Smashes go through bony plates and stagger longer."),
        S("thunderclap", "Thunderclap", (110, 57), 28, ["smash_bones"], {"knock": 0.3}, "+30% knockback."),
        S("stab_quick", "Quick Hands", (70, 59), 6, ["blade_sense"], {"stab_speed": 0.25}, "Stabs come a quarter faster."),
        S("stab_vitals", "Vitals", (70, 46), 17, ["stab_quick"], {"stab_crit": 0.2}, "One stab in five finds a vital spot: double damage."),
        S("thrust_reach", "Long Reach", (80, 59), 6, ["blade_sense"], {"thrust_reach": 14.0}, "Spears reach 14 further."),
        S("thrust_skewer", "Skewer", (80, 46), 17, ["thrust_reach"], {"thrust_most": 2.0, "thrust_damage": 0.15}, "A thrust runs through five and bites 15% deeper."),
        S("riposte", "Riposte", (75, 52), 12, ["stab_quick", "thrust_reach"], {"thorns": 5.0}, "Foes that strike you up close take 5."),
        S("duelist", "Duelist", (75, 38), 23, ["riposte", "stab_vitals", "thrust_skewer"], {"duel_damage": 0.12}, "+12% damage when a single foe is near."),
        S("brawler", "Brawler", (75, 28), 23, ["duelist"], {"brawl_damage": 0.06}, "+6% damage for each other foe close by (up to +18%)."),
        S("warden", "Warden", (75, 18), 39, ["brawler"], {"defence": 15.0}, "+15 defence."),
        S("berserker", "Berserker", (75, 7), 50, ["warden"], {"rage_damage": 0.25}, "+25% damage while below half health."),
    ],
    # ---------------------------------------------------------------- Archery: a drawn bow
    "archery": [
        S("arch_eye", "Hunter's Eye", (56, 45), 1, [], {"bow_damage": 0.05}, "+5% arrow damage."),
        S("arch_far", "Far Shot", (77, 45), 6, ["arch_eye"], {"arrow_range": 0.3}, "Arrows fly 30% further."),
        S("arch_pierce", "Piercing Shot", (98, 45), 17, ["arch_far"], {"arrow_pierce": 1.0}, "A full-drawn arrow goes through its first beast into a second."),
        S("windreader", "Windreader", (118, 45), 28, ["arch_pierce", "sky_heads"], {"full_draw_damage": 0.1}, "Full-drawn arrows strike 10% harder."),
        S("trophy_hunter", "Trophy Hunter", (130, 45), 39, ["windreader"], {"luck": 0.1}, "+10% rare finds."),
        S("marksman", "Marksman", (142, 45), 50, ["trophy_hunter"], {"arrow_crit": 0.25}, "A full-drawn arrow strikes double one time in four."),
        S("arch_steady", "Steady Draw", (68, 33), 6, ["arch_eye"], {"draw_speed": 0.2}, "A full draw comes 20% sooner."),
        S("arch_heavy", "Heavy Draw", (81, 20), 17, ["arch_steady"], {"full_draw_damage": 0.15}, "Full-drawn arrows strike 15% harder."),
        S("skirmisher", "Skirmisher", (95, 7), 23, ["arch_heavy"], {"draw_speed": 0.3, "quick_loose": 1.0}, "Draw 30% faster and loose again at once."),
        S("hunter", "Hunter", (109, 15), 23, ["skirmisher"], {"beast_arrows": 0.2}, "Arrows strike beasts 20% harder."),
        S("sky_heads", "Sky-Fang Heads", (116, 29), 28, ["hunter"], {"crystal_bane": 0.3}, "+30% damage to crystal beasts."),
        S("arch_nimble", "Light Feet", (68, 57), 6, ["arch_eye"], {"dodge": 0.2}, "Rolls keep you clear 20% longer."),
        S("stalker", "Stalker", (81, 70), 17, ["arch_nimble"], {"speed": 0.05}, "+5% move speed."),
        S("fletcher", "Fletcher", (95, 83), 45, ["stalker", "barbed_heads"], {"arrow_craft": 1.0}, "Arrows are made twice over."),
        S("keen_heads", "Keen Heads", (116, 61), 28, ["windreader"], {"arrow_crit": 0.1}, "One full-drawn arrow in ten strikes double."),
        S("barbed_heads", "Barbed Heads", (109, 75), 34, ["keen_heads"], {"arrows": 0.1}, "+10% arrow damage."),
        S("still_breath", "Still Breath", (47, 38), 12, ["arch_eye"], {"draw": 0.1}, "Bows draw 10% faster."),
        S("quarry", "Quarry", (47, 52), 12, ["arch_eye"], {"beast_arrows": 0.1}, "Arrows strike beasts 10% harder."),
    ],
    # ---------------------------------------------------------------- Taming: a trike's skull
    "taming": [
        S("calm_voice", "Calm Voice", (75, 56), 1, [], {"feeds_cut": 0.1}, "Beasts need 10% fewer feeds to trust you."),
        S("lore_pack", "Pack-lore", (64, 47), 6, ["calm_voice"], {"lore": 1.0}, "Raptors and deinonychus will take you, and their eggs will hatch for you."),
        S("lore_hunter", "Hunter-lore", (57, 30), 23, ["lore_pack"], {"lore": 1.0}, "Allosaurs, Scarhorns, Sandblades, Suchomimus and the Ashmane."),
        S("lore_apex", "Apex-lore", (50, 13), 39, ["lore_hunter"], {"lore": 1.0}, "The tyrants: the rex and the spinosaur."),
        S("hand_gentle", "Gentle Hand", (86, 47), 6, ["calm_voice"], {"feeds_cut": 0.15}, "Beasts need 15% fewer feeds to trust you."),
        S("hand_rope", "Rope-craft", (93, 30), 12, ["hand_gentle"], {"rope": 1.0}, "Learn the lead rope and the hitching post."),
        S("hand_bags", "Saddlebags", (100, 13), 17, ["hand_rope"], {"bag_slots": 4.0}, "Learn the saddlebag; your beasts carry 4 more slots."),
        S("tamer", "Tamer", (75, 68), 17, ["calm_voice"], {"feeds_cut": 0.25, "net_time": 0.5}, "Taming needs a quarter fewer feeds; nets hold half again as long."),
        S("beastmaster", "Beastmaster", (75, 82), 50, ["tamer"], {"mount_speed": 0.15, "mount_guard": 0.15}, "Mounts carry you 15% faster and shrug off 15% of blows."),
        S("ride_seat", "Sure Seat", (61, 65), 12, ["calm_voice"], {"mount_speed": 0.1}, "Mounts carry you 10% faster."),
        S("ride_spur", "Spur", (46, 61), 23, ["ride_seat"], {"mount_sprint": 0.15}, "A mount's gallop runs 15% faster."),
        S("iron_seat", "Iron Seat", (32, 48), 28, ["ride_spur"], {"mount_guard": 0.1}, "Mounts shrug off 10% of blows."),
        S("wild_heart", "Wild Heart", (37, 24), 34, ["iron_seat"], {"net_time": 0.25}, "Nets hold a quarter longer."),
        S("pack_bond", "Pack Bond", (89, 65), 12, ["calm_voice"], {"companion_hp": 0.1}, "Your companions have 10% more health."),
        S("war_cry", "War Cry", (104, 61), 23, ["pack_bond"], {"pack_damage": 0.1}, "Your companions strike 10% harder."),
        S("beastfriend", "Beastfriend", (118, 48), 28, ["war_cry"], {"companion_hp": 0.15}, "Your companions have 15% more health."),
        S("herd_call", "Herd-call", (113, 24), 34, ["beastfriend"], {"pack_guard": 0.1}, "Your companions take 10% less harm."),
        S("packleader", "Packleader", (75, 4), 50, ["lore_apex", "hand_bags", "wild_heart", "herd_call"], {"companion_damage": 0.15}, "Your companions strike 15% harder."),
    ],
    # ---------------------------------------------------------------- Breeding: an egg
    "breeding": [
        S("nest_sense", "Nest-sense", (75, 86), 1, [], {"hatch_speed": 0.1}, "Eggs hatch 10% sooner."),
        S("breed_warm", "Warm Nest", (56, 80), 6, ["nest_sense"], {"hatch_speed": 0.25}, "Eggs hatch a quarter sooner."),
        S("hatcher", "Hatcher", (46, 64), 23, ["breed_warm"], {"hatch_speed": 0.5}, "Eggs hatch in half the time."),
        S("twin_clutch", "Twin Clutch", (45, 45), 28, ["hatcher"], {"twins": 0.15}, "One clutch in seven brings twin eggs."),
        S("brood", "Brood", (49, 26), 39, ["twin_clutch"], {"twins": 0.15}, "Twin eggs come twice as often."),
        S("egg_finder", "Egg-finder", (60, 11), 39, ["brood"], {"luck": 0.1}, "+10% rare finds."),
        S("warm_blood", "Warm Blood", (94, 80), 6, ["nest_sense"], {"growth_speed": 0.15}, "Young grow 15% faster."),
        S("breed_growth", "Good Feed", (104, 64), 12, ["warm_blood"], {"growth_speed": 0.3}, "Young grow 30% faster."),
        S("hardy_stock", "Hardy Stock", (106, 45), 23, ["breed_growth"], {"companion_hp": 0.1}, "Your companions have 10% more health."),
        S("stockman", "Stockman", (101, 26), 39, ["hardy_stock"], {"growth_speed": 1.0}, "Young grow twice as fast."),
        S("love_match", "Love-match", (90, 11), 39, ["stockman"], {"court": 0.25}, "Pairs court a quarter sooner and rest a quarter less."),
        S("courtship", "Courtship", (75, 74), 12, ["nest_sense"], {"court": 0.25}, "Pairs court a quarter sooner and rest a quarter less."),
        S("breed_eye", "Keen Eye", (67, 63), 17, ["courtship"], {"mutation": 1.0}, "Mutations come twice as often."),
        S("wild_blood", "Wild Blood", (82, 53), 23, ["breed_eye"], {"mutation": 0.5}, "Mutations come half again as often."),
        S("breed_blood", "Bloodlines", (68, 43), 28, ["wild_blood"], {"inherit": 0.2}, "Young take the better parent's gifts three times in four."),
        S("strong_line", "Strong Line", (82, 33), 34, ["breed_blood"], {"inherit": 0.1}, "Young take the better parent's gifts a little more often."),
        S("mutationist", "Mutationist", (69, 22), 39, ["strong_line"], {"mutation": 2.0}, "Mutations come three times as often."),
        S("breeder", "Breeder", (75, 5), 50, ["egg_finder", "love_match", "mutationist"], {"inherit": 0.5}, "Young always take the better parent's gifts."),
    ],
    # ---------------------------------------------------------------- Farming: a pitchfork
    "farming": [
        S("good_earth", "Good Earth", (75, 87), 1, [], {"crop_speed": 0.1}, "Crops grow 10% faster."),
        S("farm_green", "Green Thumb", (75, 76), 6, ["good_earth"], {"crop_speed": 0.2}, "Crops grow 20% faster."),
        S("wide_can", "Wide Can", (75, 65), 12, ["farm_green"], {"soak": 1.0}, "Watering soaks the patches beside it too."),
        S("farm_seed", "Rich Soil", (75, 54), 12, ["wide_can"], {"keep_water": 1.0}, "A harvested patch stays watered for the next crop."),
        S("sun_kissed", "Sun-kissed", (75, 42), 17, ["farm_seed"], {"crop_speed": 0.15}, "Crops grow 15% faster."),
        S("seed_saver", "Seed-saver", (63, 42), 17, ["sun_kissed"], {"seed_extra": 0.5}, "Half your harvests give back a second seed."),
        S("forager", "Forager", (51, 42), 23, ["seed_saver"], {"forage_extra": 1.0}, "Wild berries, mushrooms and fibre give one more."),
        S("farm_bounty", "Bountiful", (51, 30), 23, ["forager"], {"harvest_extra": 0.5}, "Half your harvests bring one more."),
        S("full_basket", "Full Basket", (51, 18), 34, ["farm_bounty"], {"harvest": 0.2}, "+20% crop yield."),
        S("harvester", "Harvester", (51, 6), 50, ["full_basket"], {"harvest_extra": 1.0}, "Every harvest brings one more."),
        S("tiller", "Tiller", (75, 30), 23, ["sun_kissed"], {"crop_speed": 0.25}, "Crops grow 25% faster."),
        S("bumper_crop", "Bumper Crop", (75, 18), 34, ["tiller"], {"harvest": 0.2}, "+20% crop yield."),
        S("sky_soil", "Sky-Fang Soil", (75, 6), 45, ["bumper_crop"], {"crop_speed": 0.2}, "Crops grow 20% faster."),
        S("field_hands", "Field Hands", (87, 42), 17, ["sun_kissed"], {"regen": 0.5}, "+0.5 vitality a second while fed."),
        S("wild_fare", "Wild Fare", (99, 42), 23, ["field_hands"], {"hunger": 0.1}, "Hunger comes 10% slower."),
        S("hearty_meals", "Hearty Meals", (99, 30), 23, ["wild_fare"], {"food_heal": 0.15}, "Food heals 15% more."),
        S("well_fed", "Well Fed", (99, 18), 34, ["hearty_meals"], {"hunger": 0.15}, "Hunger comes 15% slower."),
        S("herbalist", "Herbalist", (99, 6), 45, ["well_fed"], {"food_heal": 0.25}, "Food heals a quarter more."),
    ],
    # ---------------------------------------------------------------- Gathering: pick and axe, crossed
    "gathering": [
        S("sure_grip", "Sure Grip", (75, 47), 1, [], {"gather": 1.0}, "+1 gathering power."),
        # The pick: stone and ore.
        S("gath_pick", "Stonecutter", (84, 38), 6, ["sure_grip"], {"stone_power": 1.0}, "+1 power against rock and ore."),
        S("gath_ore", "Prospector", (95, 27), 17, ["gath_pick"], {"ore_extra": 0.33}, "Ore veins give one more, a third of the time."),
        S("miner", "Miner", (108, 15), 23, ["gath_ore"], {"stone_extra": 1.0}, "Every rock and vein gives one more."),
        S("gath_crystal", "Crystal-seer", (99, 3), 28, ["miner"], {"prism_chance": 0.125}, "Any vein may give up a prism crystal (1 in 8)."),
        S("geologist", "Geologist", (119, 26), 45, ["miner"], {"prism_chance": 0.166}, "Prism crystals turn up in any vein (1 in 6)."),
        # The axe: timber.
        S("gath_axe", "Woodsman's Swing", (66, 38), 6, ["sure_grip"], {"tree_power": 1.0}, "+1 power against trees."),
        S("heartwood", "Heartwood", (55, 27), 17, ["gath_axe"], {"tree_power": 1.0}, "+1 more power against trees."),
        S("woodsman", "Woodsman", (42, 15), 23, ["heartwood"], {"log_extra": 1.0}, "Every tree gives one more log."),
        S("lumberjack", "Lumberjack", (32, 5), 45, ["woodsman"], {"tree_power": 2.0}, "Trees fall in half the swings."),
        S("feller", "Feller", (28, 25), 34, ["woodsman"], {"log_extra": 1.0}, "Every tree gives one more log again."),
        # The handles: the wanderer's way.
        S("pathfinder", "Pathfinder", (65, 57), 6, ["sure_grip"], {"speed": 0.05}, "+5% move speed."),
        S("iron_belly", "Iron Belly", (55, 66), 12, ["pathfinder"], {"hunger": 0.15}, "Hunger comes 15% slower."),
        S("wader", "Wader", (45, 76), 17, ["iron_belly"], {"wading": 0.3}, "+30% wading pace."),
        S("thick_skin", "Thick Skin", (35, 85), 28, ["wader"], {"cold": 1.0}, "The snow's cold can't touch you."),
        S("night_eyes", "Night Eyes", (87, 59), 12, ["sure_grip"], {"light": 0.5}, "A glow 50% wider around you."),
        S("fire_walker", "Fire-walker", (101, 72), 23, ["night_eyes"], {"fire": 0.3}, "30% less harm from fire."),
        S("ash_lungs", "Ash-lungs", (115, 85), 34, ["fire_walker"], {"ash_guard": 0.5}, "Keeps out half the ash."),
    ],
    # ---------------------------------------------------------------- Fishing: a leaping fish on a line
    "fishing": [
        S("angler", "Angler's Patience", (40, 41), 1, [], {"fishing": 0.05}, "The fish tire 5% sooner."),
        S("steady_line", "Steady Line", (30, 48), 6, ["angler"], {"fish_cradle": 0.15}, "Your line holds a fish from a 15% wider band."),
        S("long_line", "Long Line", (24, 33), 12, ["steady_line"], {"fish_time": 0.25}, "A fish takes a quarter longer to slip the hook."),
        S("lure_craft", "Lure-craft", (24, 18), 23, ["long_line"], {"fishing": 0.1}, "The fish tire 10% sooner."),
        S("patient_soul", "Patient Soul", (24, 4), 34, ["lure_craft"], {"wisdom": 0.1}, "+10% skill experience."),
        S("light_touch", "Light Touch", (53, 27), 6, ["angler"], {"fishing": 0.1}, "The fish tire 10% sooner."),
        S("sun_on_water", "Sun on the Water", (63, 14), 12, ["light_touch"], {"fish_cradle": 0.1}, "Your line holds a fish from a 10% wider band."),
        S("still_water", "Still Water", (74, 7), 23, ["sun_on_water"], {"fish_rest": 0.25}, "Fishing holes rest a quarter less."),
        S("quiet_bank", "Quiet Bank", (86, 26), 28, ["still_water"], {"fish_rest": 0.25}, "Fishing holes rest a quarter less again."),
        S("fishers_luck", "Fisher's Luck", (101, 33), 34, ["quiet_bank"], {"luck": 0.05}, "+5% rare finds."),
        S("broad_hook", "Broad Hook", (52, 65), 6, ["angler"], {"fish_cradle": 0.15}, "Your line holds a fish from a 15% wider band."),
        S("double_hook", "Double Hook", (70, 69), 17, ["broad_hook"], {"fish_extra": 0.15}, "One catch in seven brings a second fish."),
        S("schooling", "Schooling", (88, 66), 23, ["double_hook"], {"fish_extra": 0.15}, "Second fish come twice as often."),
        S("river_legs", "River Legs", (102, 58), 28, ["schooling"], {"wading": 0.25}, "+25% wading pace."),
        S("deep_breath", "Deep Breath", (121, 33), 39, ["fishers_luck"], {"regen": 0.3}, "+0.3 vitality a second while fed."),
        S("big_one", "The Big One", (136, 21), 45, ["deep_breath"], {"fish_extra": 0.2}, "One catch in five brings a second fish."),
        S("cooks_knack", "Cook's Knack", (121, 59), 34, ["river_legs"], {"food_heal": 0.1}, "Food heals 10% more."),
        S("master_angler", "Master Angler", (136, 71), 50, ["cooks_knack", "big_one"], {"fishing": 0.15, "fish_cradle": 0.1}, "The fish tire 15% sooner and your line holds from a 10% wider band."),
    ],
}

# ---------------------------------------------------------------- pass 15: more stars
MORE = {
    "combat": [
        # The blood edge (from Bloodletter, out along the guard to the left).
        S("crimson_tide", "Crimson Tide", (30, 50), 34, ["bloodletter"], {"leech": 0.03}, "Your blows heal you 3% of the harm they deal.", 2),
        S("whirlwind", "Whirlwind", (21, 42), 39, ["crimson_tide"], {"sweep_damage": 0.1}, "Sweeping blows strike 10% harder.", 3),
        S("executioner", "Executioner", (13, 32), 44, ["whirlwind"], {"execute": 0.25}, "+25% damage to a foe below a third of its health.", 2),
        # The heavy edge (from Thunderclap, out to the right).
        S("earthshaker", "Earthshaker", (120, 50), 34, ["thunderclap"], {"smash_damage": 0.1}, "Smashes strike 10% harder.", 3),
        S("titans_grip", "Titan's Grip", (129, 42), 39, ["earthshaker"], {"knock": 0.2, "steady": 0.2}, "+20% knockback; you take 20% less of it."),
        S("juggernaut", "Juggernaut", (137, 32), 44, ["titans_grip"], {"vigor": 15.0}, "+15 vitality at most.", 2),
        # The blade's back: rhythm and nerve.
        S("blood_rush", "Blood Rush", (58, 24), 28, ["brawler"], {"combo": 0.05}, "Each blow in a quick string lands 5% harder (up to three).", 3),
        S("last_stand", "Last Stand", (92, 24), 28, ["brawler"], {"rage_damage": 0.1, "defence": 3.0}, "Below half health: +10% damage and +3 defence."),
        # The grip: staying alive.
        S("iron_hide", "Iron Hide", (61, 82), 12, ["hardened"], {"defence": 2.0}, "+2 defence.", 3),
        S("vital_surge", "Vital Surge", (89, 82), 17, ["hardened"], {"vigor": 5.0}, "+5 vitality at most.", 3),
    ],
    "archery": [
        S("volley", "Volley", (35, 28), 17, ["still_breath"], {"draw": 0.1}, "Bows draw 10% faster.", 3),
        S("eagle_eye", "Eagle Eye", (25, 18), 28, ["volley"], {"arrow_range": 0.2}, "Arrows fly 20% further.", 2),
        S("deadeye", "Deadeye", (14, 9), 39, ["eagle_eye"], {"arrow_crit": 0.08}, "A full-drawn arrow strikes double 8% more often.", 2),
        S("tracker", "Tracker", (35, 62), 17, ["quarry"], {"beast_arrows": 0.08}, "Arrows strike beasts 8% harder.", 3),
        S("skinner", "Skinner", (25, 72), 28, ["tracker"], {"luck": 0.05}, "+5% rare finds.", 2),
        S("hunters_meal", "Hunter's Meal", (14, 81), 39, ["skinner"], {"feast": 3.0}, "+3 health when a foe falls.", 2),
        S("wind_step", "Wind-step", (62, 80), 23, ["stalker"], {"speed": 0.03}, "+3% move speed.", 2),
        S("bone_fletching", "Bone Fletching", (127, 82), 39, ["barbed_heads"], {"arrows": 0.05}, "+5% arrow damage.", 3),
        S("storm_quiver", "Storm Quiver", (130, 62), 34, ["keen_heads"], {"full_draw_damage": 0.05}, "Full-drawn arrows strike 5% harder.", 3),
        S("sky_hunter", "Sky Hunter", (128, 20), 34, ["hunter"], {"crystal_bane": 0.1}, "+10% damage to crystal beasts."),
    ],
    "taming": [
        S("soothing", "Soothing Words", (68, 32), 17, ["lore_pack"], {"feeds_cut": 0.03}, "Beasts need 3% fewer feeds to trust you.", 2),
        S("beast_whisper", "Beast Whisperer", (82, 32), 23, ["hand_gentle"], {"taming": 0.05}, "5% fewer feeds to win a beast.", 2),
        S("saddle_master", "Saddle Master", (22, 66), 28, ["ride_spur"], {"mount_speed": 0.05}, "Mounts carry you 5% faster.", 3),
        S("trample", "Trample", (14, 78), 39, ["saddle_master"], {"mount_guard": 0.05}, "Mounts shrug off 5% of blows.", 2),
        S("alpha_bond", "Alpha Bond", (128, 66), 34, ["war_cry"], {"companion_damage": 0.05}, "Your companions strike 5% harder.", 3),
        S("thick_hide", "Thick Hide", (136, 78), 44, ["alpha_bond"], {"companion_hp": 0.05}, "Your companions have 5% more health.", 2),
        S("herd_guard", "Herd Guard", (136, 36), 39, ["beastfriend"], {"pack_guard": 0.05}, "Your companions take 5% less harm.", 2),
        S("net_weaver", "Net Weaver", (22, 34), 39, ["iron_seat"], {"net_time": 0.15}, "Nets hold 15% longer.", 2),
        S("bag_mule", "Pack Mule", (122, 10), 28, ["hand_bags"], {"bag_slots": 2.0}, "Your beasts' saddlebags carry 2 more.", 2),
        S("gentle_giant", "Gentle Giant", (58, 80), 28, ["tamer"], {"feeds_cut": 0.05}, "Beasts need 5% fewer feeds to trust you.", 2),
    ],
    "breeding": [
        S("fertile", "Fertile Ground", (32, 72), 28, ["hatcher"], {"hatch_speed": 0.05}, "Eggs hatch 5% sooner.", 3),
        S("warm_hands", "Warm Hands", (22, 58), 34, ["fertile"], {"hatch_speed": 0.1}, "Eggs hatch 10% sooner.", 2),
        S("twin_blood", "Twin Blood", (30, 40), 34, ["twin_clutch"], {"twins": 0.05}, "Twin eggs come a little more often.", 2),
        S("lucky_clutch", "Lucky Clutch", (20, 26), 44, ["twin_blood"], {"luck": 0.03}, "+3% rare finds.", 2),
        S("quick_growth", "Quick Growth", (120, 70), 28, ["breed_growth"], {"growth_speed": 0.1}, "Young grow 10% faster.", 3),
        S("sturdy_young", "Sturdy Young", (130, 56), 34, ["quick_growth"], {"growth_speed": 0.1}, "Young grow 10% faster.", 2),
        S("noble_line", "Noble Line", (120, 40), 34, ["hardy_stock"], {"inherit": 0.05}, "Young take the better parent's gifts a little more often.", 3),
        S("nest_guard", "Nest Guard", (130, 26), 44, ["noble_line"], {"companion_hp": 0.05}, "Your companions have 5% more health.", 2),
        S("rare_bloom", "Rare Bloom", (58, 52), 23, ["breed_eye"], {"mutation": 0.25}, "Mutations come a quarter more often.", 2),
        S("courtly", "Courtly", (90, 64), 17, ["courtship"], {"court": 0.1}, "Pairs court 10% sooner."),
    ],
    "farming": [
        S("deep_roots", "Deep Roots", (60, 62), 17, ["wide_can"], {"crop_speed": 0.05}, "Crops grow 5% faster.", 3),
        S("rain_caller", "Rain-caller", (45, 68), 23, ["deep_roots"], {"crop_speed": 0.05}, "Crops grow 5% faster.", 2),
        S("loamwright", "Loamwright", (30, 74), 34, ["rain_caller"], {"harvest": 0.05}, "+5% crop yield.", 2),
        S("seed_keeper", "Seed Keeper", (35, 30), 28, ["farm_bounty"], {"seed_extra": 0.1}, "A tenth more harvests give back a second seed.", 2),
        S("bee_friend", "Bee Friend", (25, 18), 39, ["seed_keeper"], {"harvest": 0.05}, "+5% crop yield.", 2),
        S("sun_hat", "Sun Hat", (90, 62), 12, ["wide_can"], {"regen": 0.1}, "+0.1 vitality a second while fed.", 2),
        S("camp_cook", "Camp Cook", (105, 68), 23, ["sun_hat"], {"food_heal": 0.05}, "Food heals 5% more.", 3),
        S("pantry", "Pantry", (120, 74), 34, ["camp_cook"], {"hunger": 0.05}, "Hunger comes 5% slower.", 2),
        S("stout_gut", "Stout Gut", (115, 30), 28, ["hearty_meals"], {"vigor": 5.0}, "+5 vitality at most.", 3),
        S("orchard_hand", "Orchard Hand", (125, 18), 44, ["stout_gut"], {"harvest_extra": 0.25}, "A quarter of your harvests bring one more."),
    ],
    "gathering": [
        S("rock_breaker", "Rockbreaker", (130, 12), 34, ["miner"], {"stone_power": 1.0}, "+1 power against rock and ore.", 2),
        S("deep_vein", "Deep Vein", (138, 28), 39, ["rock_breaker"], {"ore_extra": 0.1}, "Ore veins give one more a tenth of the time.", 3),
        S("gem_eye", "Gem Eye", (82, 12), 39, ["gath_crystal"], {"prism_chance": 0.03}, "Prism crystal turns up a little more often.", 2),
        S("timber_sense", "Timber Sense", (15, 10), 39, ["lumberjack"], {"tree_power": 1.0}, "+1 power against trees.", 2),
        S("bark_peeler", "Bark Peeler", (12, 30), 44, ["feller"], {"log_extra": 1.0}, "Every tree gives one more log."),
        S("strong_back", "Strong Back", (75, 62), 17, ["sure_grip"], {"gather": 1.0}, "+1 gathering power.", 3),
        S("long_stride", "Long Stride", (68, 76), 23, ["strong_back"], {"speed": 0.03}, "+3% move speed.", 3),
        S("camel_belly", "Camel Belly", (82, 86), 34, ["long_stride"], {"hunger": 0.05}, "Hunger comes 5% slower.", 2),
        S("ember_skin", "Ember Skin", (122, 62), 28, ["fire_walker"], {"fire": 0.1}, "10% less harm from fire.", 3),
        S("ash_cloak", "Ash Cloak", (137, 76), 34, ["ember_skin"], {"ash_guard": 0.15}, "Keeps out 15% of the ash.", 3),
    ],
    "fishing": [
        S("reel_master", "Reel Master", (12, 26), 23, ["long_line"], {"fish_time": 0.1}, "A fish takes 10% longer to slip the hook.", 2),
        S("tide_reader", "Tide Reader", (10, 44), 28, ["reel_master"], {"fish_cradle": 0.05}, "Your line holds a fish from a 5% wider band.", 2),
        S("bait_maker", "Bait Maker", (60, 42), 12, ["angler"], {"fishing": 0.05}, "The fish tire 5% sooner.", 3),
        S("lucky_float", "Lucky Float", (75, 50), 23, ["bait_maker"], {"luck": 0.03}, "+3% rare finds.", 2),
        S("quiet_cast", "Quiet Cast", (92, 46), 34, ["lucky_float"], {"fish_rest": 0.1}, "Fishing holes rest 10% less.", 2),
        S("wide_net", "Wide Net", (36, 80), 17, ["broad_hook"], {"fish_extra": 0.05}, "Now and then a second fish on the line.", 2),
        S("deep_diver", "Deep Diver", (55, 86), 28, ["wide_net"], {"wading": 0.1}, "+10% wading pace.", 2),
        S("river_cook", "River Cook", (100, 80), 39, ["river_legs"], {"food_heal": 0.05}, "Food heals 5% more.", 2),
        S("fish_supper", "Fish Supper", (84, 86), 44, ["river_cook"], {"regen": 0.1}, "+0.1 vitality a second while fed.", 2),
        S("sea_legs", "Sea Legs", (110, 8), 39, ["fishers_luck"], {"speed": 0.03}, "+3% move speed.", 2),
    ],
}
## Ranks for the first eighteen stars of each (the rest are 1).
RANKS = {
    "combat": {"blade_sense": 3, "hardened": 3, "sweep_arc": 2, "bloodletter": 3, "smash_quake": 2, "stab_quick": 2, "stab_vitals": 2, "riposte": 3, "duelist": 2},
    "archery": {"arch_eye": 3, "arch_far": 2, "windreader": 2, "arch_steady": 2, "arch_heavy": 2, "hunter": 2, "arch_nimble": 2, "stalker": 2, "keen_heads": 2, "barbed_heads": 2, "still_breath": 2, "quarry": 2},
    "taming": {"calm_voice": 3, "hand_gentle": 2, "tamer": 2, "ride_seat": 3, "ride_spur": 2, "iron_seat": 2, "wild_heart": 2, "pack_bond": 3, "war_cry": 2, "beastfriend": 2, "herd_call": 2},
    "breeding": {"nest_sense": 3, "breed_warm": 2, "twin_clutch": 2, "egg_finder": 2, "warm_blood": 3, "breed_growth": 2, "hardy_stock": 2, "courtship": 2, "breed_eye": 2, "wild_blood": 2, "breed_blood": 2, "strong_line": 2},
    "farming": {"good_earth": 3, "farm_green": 2, "sun_kissed": 2, "seed_saver": 2, "farm_bounty": 2, "full_basket": 2, "tiller": 2, "bumper_crop": 2, "field_hands": 3, "wild_fare": 2, "hearty_meals": 2, "well_fed": 2},
    "gathering": {"sure_grip": 3, "gath_pick": 2, "gath_ore": 2, "gath_axe": 2, "heartwood": 2, "pathfinder": 3, "iron_belly": 2, "wader": 2, "night_eyes": 2, "fire_walker": 2},
    "fishing": {"angler": 3, "steady_line": 2, "long_line": 2, "lure_craft": 2, "patient_soul": 2, "light_touch": 2, "sun_on_water": 2, "still_water": 2, "fishers_luck": 2, "broad_hook": 2, "double_hook": 2, "river_legs": 2, "deep_breath": 2, "cooks_knack": 2},
}
for _skill, _extra in MORE.items():
    for _s in STARS[_skill]:
        _s["ranks"] = RANKS.get(_skill, {}).get(_s["id"], _s.get("ranks", 1))
    STARS[_skill].extend(_extra)

ORDER = ["combat", "archery", "taming", "breeding", "farming", "gathering", "fishing"]


def check():
    seen = {}
    for skill in ORDER:
        stars = STARS[skill]
        ids = {s["id"] for s in stars}
        assert len(stars) == 28, (skill, len(stars))
        cost = sum(st["ranks"] for st in stars)
        assert cost == TREE_COST, (skill, "costs", cost)
        roots = [s for s in stars if not s["after"]]
        assert len(roots) == 1, (skill, [r["id"] for r in roots])
        for s in stars:
            assert s["id"] not in seen, ("duplicate", s["id"], seen.get(s["id"]))
            seen[s["id"]] = skill
            for a in s["after"]:
                assert a in ids, (skill, s["id"], "after", a)
            x, y = s["at"]
            assert 0 <= x <= W and 0 <= y <= H, (s["id"], s["at"])
            assert 1 <= s["needs"] <= 50, s["id"]
            assert s["needs"] + (s["ranks"] - 1) * RANK_STEP <= 50, (s["id"], "last rank past 50")
            assert s["ranks"] == 1 or not (set(s["effects"]) & BINARY), (s["id"], "a learned thing can't be ranked")
        # Everything reachable from the root.
        reach = {roots[0]["id"]}
        grew = True
        while grew:
            grew = False
            for s in stars:
                if s["id"] not in reach and any(a in reach for a in s["after"]):
                    reach.add(s["id"])
                    grew = True
        assert reach == ids, (skill, ids - reach)
        # No two stars on top of each other.
        for i, a in enumerate(stars):
            for b in stars[i + 1:]:
                d = math.dist(a["at"], b["at"])
                assert d >= 7.0, (skill, a["id"], b["id"], round(d, 1))
    return seen


def preview(path):
    from PIL import Image, ImageDraw
    k = 4
    pad = 10
    cols = 2
    rows = (len(ORDER) + cols - 1) // cols
    cw, ch = W * k + pad * 2, H * k + pad * 2 + 18
    img = Image.new("RGB", (cw * cols, ch * rows), (12, 10, 22))
    d = ImageDraw.Draw(img)
    for n, skill in enumerate(ORDER):
        ox = (n % cols) * cw + pad
        oy = (n // cols) * ch + pad + 18
        d.text((ox, oy - 16), "%s: %s" % (skill, FIGURES[skill]["title"]), fill=(232, 194, 122))
        d.rectangle([ox, oy, ox + W * k, oy + H * k], outline=(40, 40, 70))
        P = lambda p: (ox + p[0] * k, oy + p[1] * k)
        for line in FIGURES[skill]["lines"]:
            d.line([P(p) for p in line], fill=(60, 70, 110), width=2)
        by = {s["id"]: s for s in STARS[skill]}
        for s in STARS[skill]:
            for a in s["after"]:
                d.line([P(by[a]["at"]), P(s["at"])], fill=(150, 160, 210), width=2)
        for s in STARS[skill]:
            x, y = P(s["at"])
            r = 5 if not s["after"] else 4
            col = (255, 230, 150) if s["needs"] >= 8 else (200, 225, 255)
            d.ellipse([x - r, y - r, x + r, y + r], fill=col)
            d.text((x + 6, y - 5), "%s %d%s" % (s["name"], s["needs"], (" x%d" % s["ranks"]) if s["ranks"] > 1 else ""), fill=(150, 150, 170))
    img.save(path)
    print("wrote", path)


def gd_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return '"%s"' % v.replace('"', '\\"')
    raise TypeError(v)


def write():
    lines = [
        "extends RefCounted",
        "## GENERATED by tools/skills/constellations.py (pass 14): the stars of each",
        "## skill's constellation. Edit the tool and run `python tools/skills/constellations.py write`.",
        "##",
        "## FIGURES[skill]: the constellation's name and the faint lines that finish its",
        "## figure. PERKS[id]: skill, name, at (on a 150 x 90 sky), needs (skill level),",
        "## after (opens once ANY of these is learned; the root has none), effects, text,",
        "## ranks (pass 15: a star lit again, RANK_STEP more levels a rank, its effects again).",
        "",
        "const RANK_STEP := %d" % RANK_STEP,
        "",
        "const SKY := Vector2(%d, %d)" % (W, H),
        "",
        "const ORDER := [%s]" % ", ".join('"%s"' % s for s in ORDER),
        "",
        "const FIGURES := {",
    ]
    for skill in ORDER:
        f = FIGURES[skill]
        polys = []
        for line in f["lines"]:
            polys.append("[%s]" % ", ".join("Vector2(%s, %s)" % (gd_num(p[0]), gd_num(p[1])) for p in line))
        lines.append('\t"%s": {"title": "%s", "lines": [' % (skill, f["title"]))
        for p in polys:
            lines.append("\t\t%s," % p)
        lines.append("\t]},")
    lines.append("}")
    lines.append("")
    lines.append("const PERKS := {")
    for skill in ORDER:
        lines.append("\t# %s: %s" % (skill.capitalize(), FIGURES[skill]["title"]))
        for s in STARS[skill]:
            fx = ", ".join('"%s": %s' % (k, gd_value(float(v))) for k, v in s["effects"].items())
            after = ", ".join('"%s"' % a for a in s["after"])
            lines.append('\t"%s": {"skill": "%s", "name": %s, "at": Vector2(%s, %s), "needs": %d, "ranks": %d, "after": [%s], "text": %s, "effects": {%s}},' % (
                s["id"], skill, gd_value(s["name"]), gd_num(s["at"][0]), gd_num(s["at"][1]), s["needs"], s["ranks"], after, gd_value(s["text"]), fx))
    lines.append("}")
    lines.append("")
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote", os.path.relpath(OUT, ROOT))


def gd_num(v):
    return ("%g" % v) if float(v) != int(v) else "%d" % int(v)


if __name__ == "__main__":
    check()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "preview"
    if cmd == "preview":
        os.makedirs(SCRATCH, exist_ok=True)
        preview(os.path.join(SCRATCH, "constellations.png"))
    elif cmd == "write":
        write()
    else:
        print(__doc__)
