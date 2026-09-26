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
skill's points. Each skill has 18 stars and a skill earns 2 points a level
(18 at level 10), so a mastered skill lights its whole constellation:
everything is unlockable, nothing is a one-or-the-other choice.

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


def S(id_, name, at, needs, after, effects, text):
    return {"id": id_, "name": name, "at": at, "needs": needs, "after": after, "effects": effects, "text": text}


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
        S("hardened", "Hardened", (75, 77), 2, ["blade_sense"], {"defence": 4.0}, "+4 defence."),
        S("second_wind", "Second Wind", (75, 86), 4, ["hardened"], {"feast": 4.0}, "+4 health each time a foe falls."),
        S("sweep_arc", "Wide Arc", (61, 69), 2, ["blade_sense"], {"sweep_arc": 20.0}, "Sweeping blows cut 20 degrees wider."),
        S("sweep_cleave", "Cleave", (48, 65), 4, ["sweep_arc"], {"sweep_more": 0.25}, "Every foe in a sweep takes its full weight."),
        S("bloodletter", "Bloodletter", (40, 57), 6, ["sweep_cleave"], {"bleed": 1.0}, "Your blows open wounds that bleed 1 a second."),
        S("smash_quake", "Quake", (89, 69), 2, ["blade_sense"], {"smash_spot": 8.0, "smash_knock": 0.25}, "Smashes land wider (+8) and shove a quarter harder."),
        S("smash_bones", "Bonebreaker", (102, 65), 4, ["smash_quake"], {"smash_plates": 1.0, "smash_stagger": 0.3}, "Smashes go through bony plates and stagger longer."),
        S("thunderclap", "Thunderclap", (110, 57), 6, ["smash_bones"], {"knock": 0.3}, "+30% knockback."),
        S("stab_quick", "Quick Hands", (70, 59), 2, ["blade_sense"], {"stab_speed": 0.25}, "Stabs come a quarter faster."),
        S("stab_vitals", "Vitals", (70, 46), 4, ["stab_quick"], {"stab_crit": 0.2}, "One stab in five finds a vital spot: double damage."),
        S("thrust_reach", "Long Reach", (80, 59), 2, ["blade_sense"], {"thrust_reach": 14.0}, "Spears reach 14 further."),
        S("thrust_skewer", "Skewer", (80, 46), 4, ["thrust_reach"], {"thrust_most": 2.0, "thrust_damage": 0.15}, "A thrust runs through five and bites 15% deeper."),
        S("riposte", "Riposte", (75, 52), 3, ["stab_quick", "thrust_reach"], {"thorns": 5.0}, "Foes that strike you up close take 5."),
        S("duelist", "Duelist", (75, 38), 5, ["riposte", "stab_vitals", "thrust_skewer"], {"duel_damage": 0.12}, "+12% damage when a single foe is near."),
        S("brawler", "Brawler", (75, 28), 5, ["duelist"], {"brawl_damage": 0.06}, "+6% damage for each other foe close by (up to +18%)."),
        S("warden", "Warden", (75, 18), 8, ["brawler"], {"defence": 15.0}, "+15 defence."),
        S("berserker", "Berserker", (75, 7), 10, ["warden"], {"rage_damage": 0.25}, "+25% damage while below half health."),
    ],
    # ---------------------------------------------------------------- Archery: a drawn bow
    "archery": [
        S("arch_eye", "Hunter's Eye", (56, 45), 1, [], {"bow_damage": 0.05}, "+5% arrow damage."),
        S("arch_far", "Far Shot", (77, 45), 2, ["arch_eye"], {"arrow_range": 0.3}, "Arrows fly 30% further."),
        S("arch_pierce", "Piercing Shot", (98, 45), 4, ["arch_far"], {"arrow_pierce": 1.0}, "A full-drawn arrow goes through its first beast into a second."),
        S("windreader", "Windreader", (118, 45), 6, ["arch_pierce", "sky_heads"], {"full_draw_damage": 0.1}, "Full-drawn arrows strike 10% harder."),
        S("trophy_hunter", "Trophy Hunter", (130, 45), 8, ["windreader"], {"luck": 0.1}, "+10% rare finds."),
        S("marksman", "Marksman", (142, 45), 10, ["trophy_hunter"], {"arrow_crit": 0.25}, "A full-drawn arrow strikes double one time in four."),
        S("arch_steady", "Steady Draw", (68, 33), 2, ["arch_eye"], {"draw_speed": 0.2}, "A full draw comes 20% sooner."),
        S("arch_heavy", "Heavy Draw", (81, 20), 4, ["arch_steady"], {"full_draw_damage": 0.15}, "Full-drawn arrows strike 15% harder."),
        S("skirmisher", "Skirmisher", (95, 7), 5, ["arch_heavy"], {"draw_speed": 0.3, "quick_loose": 1.0}, "Draw 30% faster and loose again at once."),
        S("hunter", "Hunter", (109, 15), 5, ["skirmisher"], {"beast_arrows": 0.2}, "Arrows strike beasts 20% harder."),
        S("sky_heads", "Sky-Fang Heads", (116, 29), 6, ["hunter"], {"crystal_bane": 0.3}, "+30% damage to crystal beasts."),
        S("arch_nimble", "Light Feet", (68, 57), 2, ["arch_eye"], {"dodge": 0.2}, "Rolls keep you clear 20% longer."),
        S("stalker", "Stalker", (81, 70), 4, ["arch_nimble"], {"speed": 0.05}, "+5% move speed."),
        S("fletcher", "Fletcher", (95, 83), 9, ["stalker", "barbed_heads"], {"arrow_craft": 1.0}, "Arrows are made twice over."),
        S("keen_heads", "Keen Heads", (116, 61), 6, ["windreader"], {"arrow_crit": 0.1}, "One full-drawn arrow in ten strikes double."),
        S("barbed_heads", "Barbed Heads", (109, 75), 7, ["keen_heads"], {"arrows": 0.1}, "+10% arrow damage."),
        S("still_breath", "Still Breath", (47, 38), 3, ["arch_eye"], {"draw": 0.1}, "Bows draw 10% faster."),
        S("quarry", "Quarry", (47, 52), 3, ["arch_eye"], {"beast_arrows": 0.1}, "Arrows strike beasts 10% harder."),
    ],
    # ---------------------------------------------------------------- Taming: a trike's skull
    "taming": [
        S("calm_voice", "Calm Voice", (75, 56), 1, [], {"feeds_cut": 0.1}, "Beasts need 10% fewer feeds to trust you."),
        S("lore_pack", "Pack-lore", (64, 47), 2, ["calm_voice"], {"lore": 1.0}, "Raptors and deinonychus will take you, and their eggs will hatch for you."),
        S("lore_hunter", "Hunter-lore", (57, 30), 5, ["lore_pack"], {"lore": 1.0}, "Allosaurs, Scarhorns, Sandblades, Suchomimus and the Ashmane."),
        S("lore_apex", "Apex-lore", (50, 13), 8, ["lore_hunter"], {"lore": 1.0}, "The tyrants: the rex and the spinosaur."),
        S("hand_gentle", "Gentle Hand", (86, 47), 2, ["calm_voice"], {"feeds_cut": 0.15}, "Beasts need 15% fewer feeds to trust you."),
        S("hand_rope", "Rope-craft", (93, 30), 3, ["hand_gentle"], {"rope": 1.0}, "Learn the lead rope and the hitching post."),
        S("hand_bags", "Saddlebags", (100, 13), 4, ["hand_rope"], {"bag_slots": 4.0}, "Learn the saddlebag; your beasts carry 4 more slots."),
        S("tamer", "Tamer", (75, 68), 4, ["calm_voice"], {"feeds_cut": 0.25, "net_time": 0.5}, "Taming needs a quarter fewer feeds; nets hold half again as long."),
        S("beastmaster", "Beastmaster", (75, 82), 10, ["tamer"], {"mount_speed": 0.15, "mount_guard": 0.15}, "Mounts carry you 15% faster and shrug off 15% of blows."),
        S("ride_seat", "Sure Seat", (61, 65), 3, ["calm_voice"], {"mount_speed": 0.1}, "Mounts carry you 10% faster."),
        S("ride_spur", "Spur", (46, 61), 5, ["ride_seat"], {"mount_sprint": 0.15}, "A mount's gallop runs 15% faster."),
        S("iron_seat", "Iron Seat", (32, 48), 6, ["ride_spur"], {"mount_guard": 0.1}, "Mounts shrug off 10% of blows."),
        S("wild_heart", "Wild Heart", (37, 24), 7, ["iron_seat"], {"net_time": 0.25}, "Nets hold a quarter longer."),
        S("pack_bond", "Pack Bond", (89, 65), 3, ["calm_voice"], {"companion_hp": 0.1}, "Your companions have 10% more health."),
        S("war_cry", "War Cry", (104, 61), 5, ["pack_bond"], {"pack_damage": 0.1}, "Your companions strike 10% harder."),
        S("beastfriend", "Beastfriend", (118, 48), 6, ["war_cry"], {"companion_hp": 0.15}, "Your companions have 15% more health."),
        S("herd_call", "Herd-call", (113, 24), 7, ["beastfriend"], {"pack_guard": 0.1}, "Your companions take 10% less harm."),
        S("packleader", "Packleader", (75, 4), 10, ["lore_apex", "hand_bags", "wild_heart", "herd_call"], {"companion_damage": 0.15}, "Your companions strike 15% harder."),
    ],
    # ---------------------------------------------------------------- Breeding: an egg
    "breeding": [
        S("nest_sense", "Nest-sense", (75, 86), 1, [], {"hatch_speed": 0.1}, "Eggs hatch 10% sooner."),
        S("breed_warm", "Warm Nest", (56, 80), 2, ["nest_sense"], {"hatch_speed": 0.25}, "Eggs hatch a quarter sooner."),
        S("hatcher", "Hatcher", (46, 64), 5, ["breed_warm"], {"hatch_speed": 0.5}, "Eggs hatch in half the time."),
        S("twin_clutch", "Twin Clutch", (45, 45), 6, ["hatcher"], {"twins": 0.15}, "One clutch in seven brings twin eggs."),
        S("brood", "Brood", (49, 26), 8, ["twin_clutch"], {"twins": 0.15}, "Twin eggs come twice as often."),
        S("egg_finder", "Egg-finder", (60, 11), 8, ["brood"], {"luck": 0.1}, "+10% rare finds."),
        S("warm_blood", "Warm Blood", (94, 80), 2, ["nest_sense"], {"growth_speed": 0.15}, "Young grow 15% faster."),
        S("breed_growth", "Good Feed", (104, 64), 3, ["warm_blood"], {"growth_speed": 0.3}, "Young grow 30% faster."),
        S("hardy_stock", "Hardy Stock", (106, 45), 5, ["breed_growth"], {"companion_hp": 0.1}, "Your companions have 10% more health."),
        S("stockman", "Stockman", (101, 26), 8, ["hardy_stock"], {"growth_speed": 1.0}, "Young grow twice as fast."),
        S("love_match", "Love-match", (90, 11), 8, ["stockman"], {"court": 0.25}, "Pairs court a quarter sooner and rest a quarter less."),
        S("courtship", "Courtship", (75, 74), 3, ["nest_sense"], {"court": 0.25}, "Pairs court a quarter sooner and rest a quarter less."),
        S("breed_eye", "Keen Eye", (67, 63), 4, ["courtship"], {"mutation": 1.0}, "Mutations come twice as often."),
        S("wild_blood", "Wild Blood", (82, 53), 5, ["breed_eye"], {"mutation": 0.5}, "Mutations come half again as often."),
        S("breed_blood", "Bloodlines", (68, 43), 6, ["wild_blood"], {"inherit": 0.2}, "Young take the better parent's gifts three times in four."),
        S("strong_line", "Strong Line", (82, 33), 7, ["breed_blood"], {"inherit": 0.1}, "Young take the better parent's gifts a little more often."),
        S("mutationist", "Mutationist", (69, 22), 8, ["strong_line"], {"mutation": 2.0}, "Mutations come three times as often."),
        S("breeder", "Breeder", (75, 5), 10, ["egg_finder", "love_match", "mutationist"], {"inherit": 0.5}, "Young always take the better parent's gifts."),
    ],
    # ---------------------------------------------------------------- Farming: a pitchfork
    "farming": [
        S("good_earth", "Good Earth", (75, 87), 1, [], {"crop_speed": 0.1}, "Crops grow 10% faster."),
        S("farm_green", "Green Thumb", (75, 76), 2, ["good_earth"], {"crop_speed": 0.2}, "Crops grow 20% faster."),
        S("wide_can", "Wide Can", (75, 65), 3, ["farm_green"], {"soak": 1.0}, "Watering soaks the patches beside it too."),
        S("farm_seed", "Rich Soil", (75, 54), 3, ["wide_can"], {"keep_water": 1.0}, "A harvested patch stays watered for the next crop."),
        S("sun_kissed", "Sun-kissed", (75, 42), 4, ["farm_seed"], {"crop_speed": 0.15}, "Crops grow 15% faster."),
        S("seed_saver", "Seed-saver", (63, 42), 4, ["sun_kissed"], {"seed_extra": 0.5}, "Half your harvests give back a second seed."),
        S("forager", "Forager", (51, 42), 5, ["seed_saver"], {"forage_extra": 1.0}, "Wild berries, mushrooms and fibre give one more."),
        S("farm_bounty", "Bountiful", (51, 30), 5, ["forager"], {"harvest_extra": 0.5}, "Half your harvests bring one more."),
        S("full_basket", "Full Basket", (51, 18), 7, ["farm_bounty"], {"harvest": 0.2}, "+20% crop yield."),
        S("harvester", "Harvester", (51, 6), 10, ["full_basket"], {"harvest_extra": 1.0}, "Every harvest brings one more."),
        S("tiller", "Tiller", (75, 30), 5, ["sun_kissed"], {"crop_speed": 0.25}, "Crops grow 25% faster."),
        S("bumper_crop", "Bumper Crop", (75, 18), 7, ["tiller"], {"harvest": 0.2}, "+20% crop yield."),
        S("sky_soil", "Sky-Fang Soil", (75, 6), 9, ["bumper_crop"], {"crop_speed": 0.2}, "Crops grow 20% faster."),
        S("field_hands", "Field Hands", (87, 42), 4, ["sun_kissed"], {"regen": 0.5}, "+0.5 vitality a second while fed."),
        S("wild_fare", "Wild Fare", (99, 42), 5, ["field_hands"], {"hunger": 0.1}, "Hunger comes 10% slower."),
        S("hearty_meals", "Hearty Meals", (99, 30), 5, ["wild_fare"], {"food_heal": 0.15}, "Food heals 15% more."),
        S("well_fed", "Well Fed", (99, 18), 7, ["hearty_meals"], {"hunger": 0.15}, "Hunger comes 15% slower."),
        S("herbalist", "Herbalist", (99, 6), 9, ["well_fed"], {"food_heal": 0.25}, "Food heals a quarter more."),
    ],
    # ---------------------------------------------------------------- Gathering: pick and axe, crossed
    "gathering": [
        S("sure_grip", "Sure Grip", (75, 47), 1, [], {"gather": 1.0}, "+1 gathering power."),
        # The pick: stone and ore.
        S("gath_pick", "Stonecutter", (84, 38), 2, ["sure_grip"], {"stone_power": 1.0}, "+1 power against rock and ore."),
        S("gath_ore", "Prospector", (95, 27), 4, ["gath_pick"], {"ore_extra": 0.33}, "Ore veins give one more, a third of the time."),
        S("miner", "Miner", (108, 15), 5, ["gath_ore"], {"stone_extra": 1.0}, "Every rock and vein gives one more."),
        S("gath_crystal", "Crystal-seer", (99, 3), 6, ["miner"], {"prism_chance": 0.125}, "Any vein may give up a prism crystal (1 in 8)."),
        S("geologist", "Geologist", (119, 26), 9, ["miner"], {"prism_chance": 0.166}, "Prism crystals turn up in any vein (1 in 6)."),
        # The axe: timber.
        S("gath_axe", "Woodsman's Swing", (66, 38), 2, ["sure_grip"], {"tree_power": 1.0}, "+1 power against trees."),
        S("heartwood", "Heartwood", (55, 27), 4, ["gath_axe"], {"tree_power": 1.0}, "+1 more power against trees."),
        S("woodsman", "Woodsman", (42, 15), 5, ["heartwood"], {"log_extra": 1.0}, "Every tree gives one more log."),
        S("lumberjack", "Lumberjack", (32, 5), 9, ["woodsman"], {"tree_power": 2.0}, "Trees fall in half the swings."),
        S("feller", "Feller", (28, 25), 7, ["woodsman"], {"log_extra": 1.0}, "Every tree gives one more log again."),
        # The handles: the wanderer's way.
        S("pathfinder", "Pathfinder", (65, 57), 2, ["sure_grip"], {"speed": 0.05}, "+5% move speed."),
        S("iron_belly", "Iron Belly", (55, 66), 3, ["pathfinder"], {"hunger": 0.15}, "Hunger comes 15% slower."),
        S("wader", "Wader", (45, 76), 4, ["iron_belly"], {"wading": 0.3}, "+30% wading pace."),
        S("thick_skin", "Thick Skin", (35, 85), 6, ["wader"], {"cold": 1.0}, "The snow's cold can't touch you."),
        S("night_eyes", "Night Eyes", (87, 59), 3, ["sure_grip"], {"light": 0.5}, "A glow 50% wider around you."),
        S("fire_walker", "Fire-walker", (101, 72), 5, ["night_eyes"], {"fire": 0.3}, "30% less harm from fire."),
        S("ash_lungs", "Ash-lungs", (115, 85), 7, ["fire_walker"], {"ash_guard": 0.5}, "Keeps out half the ash."),
    ],
    # ---------------------------------------------------------------- Fishing: a leaping fish on a line
    "fishing": [
        S("angler", "Angler's Patience", (40, 41), 1, [], {"fishing": 0.05}, "The fish tire 5% sooner."),
        S("steady_line", "Steady Line", (30, 48), 2, ["angler"], {"fish_cradle": 0.15}, "Your line holds a fish from a 15% wider band."),
        S("long_line", "Long Line", (24, 33), 3, ["steady_line"], {"fish_time": 0.25}, "A fish takes a quarter longer to slip the hook."),
        S("lure_craft", "Lure-craft", (24, 18), 5, ["long_line"], {"fishing": 0.1}, "The fish tire 10% sooner."),
        S("patient_soul", "Patient Soul", (24, 4), 7, ["lure_craft"], {"wisdom": 0.1}, "+10% skill experience."),
        S("light_touch", "Light Touch", (53, 27), 2, ["angler"], {"fishing": 0.1}, "The fish tire 10% sooner."),
        S("sun_on_water", "Sun on the Water", (63, 14), 3, ["light_touch"], {"fish_cradle": 0.1}, "Your line holds a fish from a 10% wider band."),
        S("still_water", "Still Water", (74, 7), 5, ["sun_on_water"], {"fish_rest": 0.25}, "Fishing holes rest a quarter less."),
        S("quiet_bank", "Quiet Bank", (86, 26), 6, ["still_water"], {"fish_rest": 0.25}, "Fishing holes rest a quarter less again."),
        S("fishers_luck", "Fisher's Luck", (101, 33), 7, ["quiet_bank"], {"luck": 0.05}, "+5% rare finds."),
        S("broad_hook", "Broad Hook", (52, 65), 2, ["angler"], {"fish_cradle": 0.15}, "Your line holds a fish from a 15% wider band."),
        S("double_hook", "Double Hook", (70, 69), 4, ["broad_hook"], {"fish_extra": 0.15}, "One catch in seven brings a second fish."),
        S("schooling", "Schooling", (88, 66), 5, ["double_hook"], {"fish_extra": 0.15}, "Second fish come twice as often."),
        S("river_legs", "River Legs", (102, 58), 6, ["schooling"], {"wading": 0.25}, "+25% wading pace."),
        S("deep_breath", "Deep Breath", (121, 33), 8, ["fishers_luck"], {"regen": 0.3}, "+0.3 vitality a second while fed."),
        S("big_one", "The Big One", (136, 21), 9, ["deep_breath"], {"fish_extra": 0.2}, "One catch in five brings a second fish."),
        S("cooks_knack", "Cook's Knack", (121, 59), 7, ["river_legs"], {"food_heal": 0.1}, "Food heals 10% more."),
        S("master_angler", "Master Angler", (136, 71), 10, ["cooks_knack", "big_one"], {"fishing": 0.15, "fish_cradle": 0.1}, "The fish tire 15% sooner and your line holds from a 10% wider band."),
    ],
}

ORDER = ["combat", "archery", "taming", "breeding", "farming", "gathering", "fishing"]


def check():
    seen = {}
    for skill in ORDER:
        stars = STARS[skill]
        ids = {s["id"] for s in stars}
        assert len(stars) == 18, (skill, len(stars))
        roots = [s for s in stars if not s["after"]]
        assert len(roots) == 1, (skill, [r["id"] for r in roots])
        for s in stars:
            assert s["id"] not in seen, ("duplicate", s["id"], seen.get(s["id"]))
            seen[s["id"]] = skill
            for a in s["after"]:
                assert a in ids, (skill, s["id"], "after", a)
            x, y = s["at"]
            assert 0 <= x <= W and 0 <= y <= H, (s["id"], s["at"])
            assert 1 <= s["needs"] <= 10, s["id"]
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
                assert d >= 7.5, (skill, a["id"], b["id"], round(d, 1))
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
            d.text((x + 6, y - 5), "%s %d" % (s["name"], s["needs"]), fill=(150, 150, 170))
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
        "## after (opens once ANY of these is learned; the root has none), effects, text.",
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
            lines.append('\t"%s": {"skill": "%s", "name": %s, "at": Vector2(%s, %s), "needs": %d, "after": [%s], "text": %s, "effects": {%s}},' % (
                s["id"], skill, gd_value(s["name"]), gd_num(s["at"][0]), gd_num(s["at"][1]), s["needs"], after, gd_value(s["text"]), fx))
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
