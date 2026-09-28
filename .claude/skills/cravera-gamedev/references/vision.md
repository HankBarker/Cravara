# Cravera's long-term vision (Hank, restated 2026-09-25)

Mid pass 12, Hank stopped work to restate the original vision: an older plan he pasted. It is
"the vision going forward", not a spec to copy exactly. Steer every pass toward it, and don't
abandon work in progress to force it.

## The mystery: the Fall of the Sky-Fangs
Crystalline objects fell from the sky and embedded themselves across Cravara. Their energy mutates
life:
- glowing veins, crystal growths and fungal mutations;
- speckles and tribal "war paint" markings;
- elemental adaptations, and huge mutated bosses.

Mutation is not cosmetic. The further from the cosy start, the stranger the world gets:
appearance, behaviour, resistances and taming needs all change.

Bosses reveal the mystery (what are the Sky-Fangs, why did they fall, what are they doing?), open
regions and unlock technology. The late game adds fossils, resurrection machines, genetics and
finally DNA fusion.

## Biomes: the plan, and today's map
The 10-biome plan:

| Tier | Biomes |
|---|---|
| 1 | Fractured Hollow, Mirefen Bog, Embercrack Ridge, Stonegrave Dens |
| 2 | Shiverstone Expanse (frozen), Glimmercap Canopy (glowing fungal jungle), Voidscar Barrens (corrupted) |
| 3 | Mirrorwild, Bloomspire Labs (old tech, genetics), Crown Crater (Sky-Fang epicentre) |

Glimmercap is the signature look ("a screenshot of a glowing fungal jungle with mutated dinosaurs
= that's Cravera").

Today's map, as Hank placed it (pass 12):

| Today | Plays the role of |
|---|---|
| The starting forest and plains | the Fractured Hollow |
| Glassmere | now **the Mirefen Bog** (swamp) |
| The Bonelands | already the Stonegrave Dens (the rocky barrens) |
| The Sunscar Dunes | now **more barren** (badlands) |
| The Pale Lands | stay, but pale with **ash**: the mountain beyond smoulders. They are the way to Embercrack Ridge (volcanic), with Sky-Fang crystal through the ash |

A tier-1 slot can become tier 2. Still to come: glowing jungle, frozen, volcanic (Embercrack,
beyond the Pale Lands) and a crystal/Sky-Fang region.

## Dinosaurs
**Keep the start lineup:** bronto, stego, trike, raptor, dodo, lystro.
- Allosaurus is the native desert apex.
- The rex is a rare roaming world threat.

**Species from the old plan** (pass 13 put in the rest of the named ones):
- Carnotaurus (the Scarhorn, pass 12; redrawn with PixelLab in pass 13).
- Suchomimus (pass 13: the Mirefang, lurking in the Mirefen's shallows).
- Ankylosaurus (pass 12; Thornback and crystal forms later).
- Utahraptor (pass 13: the Sandblade, Bonelands pairs).
- Deinonychus (pass 13: the Reedstalker, bog packs; the plan's name was Deathjaw).
- Spinosaurus (pass 13: the Sailking, the bog's apex, wading the deep mere; the plan's
  Infernospine / Embercrack's ember look is still to come).

**Other named ideas:** Brontoshade, Junglehorn Carnotaurus, Cracked Tyranno (mini-boss),
Crystalback Raptor, Blazehorn Ceratops, Glowspine Raptor.

**Regional forms** over new species: a feathered predator in the cold, an ankylosaur with
crystal growths. Pass 12's coats (the Dune and Ashfang raptors) are the start of this.

## System pillars (everything connects)
- **Every dino has a utility:**
  - lystro: farming
  - anky: mining (done in pass 12: the tamed ankylosaur's Rockbreaker gift)
  - parasaur: exploration and detection (done in pass 13: it hears ore, caches and nests, `Buffs._sense`)
  - trike: hauling and harvesting
  - raptor: combat and scouting
  - bronto: carrying and resources
  - swimmers: the water
- **Taming is trust:** feeding, following, protecting, healing, helping young, returning eggs,
  time together. The keeper's handling grows.
- **Individuality:** markings, colours, speckles, mutations, traits, temperament and stats, then
  inspectable genetics, breeding and DNA. (Pass 13: `Genes.gd`, readable after two bosses; the
  keeper's own pairs pass their genes on. DNA and fusion are still to come.)
- **Eggs and babies:** dangerous to get (the parents defend), easier to tame.
- **Fossils:** mined from caves, tar pits and bone fields. They lead to resurrection machines
  (some beasts exist only resurrected), then DNA fusion (40 hours in: "something that shouldn't
  exist").
- **Towns and tribes:** trade, diplomacy, quests, migration. Pass 12's Sunward and Ashen were the
  start. Pass 13 added named camps with standing, requests, totem offerings and moving camps.
- **Dynamic world events that change the ecosystem:**
  - meteor showers, eruptions, acid rain, tremors;
  - "Sky-Fang activity detected": mutants, aggression, migrations, a rare boss.
  - (Pass 13: quakes, snow, wildfire, meteors and the Sky-Fang surge, whose spire lets out crystal
    beasts, are in `world/WorldEvents.gd`. Eruptions, acid rain and a surge boss are still to come.)
- **Behavioural animation,** not just idle/walk/attack/die: grazing, sniffing, scanning,
  frill-shaking, threat displays, sleeping, nuzzling.

## Art pipeline direction
Try Blender as the animation factory. The game stays 2D pixel art: "3D controls motion, pixel art
controls appearance". See `blender-pipeline.md` for the pass-12 experiment and its playtest.
**Verdict (pass 13): retired.** Hank: "doesn't look that great". Stay with PixelLab and the
procedural fixers, and spend more care on each beast (redraws, QA by eye, hand fixes).
