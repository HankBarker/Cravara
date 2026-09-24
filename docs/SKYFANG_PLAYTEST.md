# Cravera: The Skyfang Wilds

## Eighth pass: Keeper v2 hero, six armour sets and game feel

The keeper was rebuilt as **Keeper v2**, a taller (~30 px) PixelLab-drawn hero rendered by a
skeletal pixel rig. Helmet, chest and legs are now *parts of the body* in every frame, so
armour can no longer slide off or vanish (the old run-left/right bug) in any animation, facing,
tool action or while riding.

1. **Armour.** Six mix-and-match sets, crafted at a workbench (tier order):
   Mossweave Warden (forage), Trail Leather (reed perch skins), Fangbound (raptor fangs),
   Skyshard (prism crystal), Moonscale Tidecaller (moonscale + shardfin from fishing) and
   Emerald Tyrant (the rex's crystal scales). See [ARMOR_PROGRESSION.md](ARMOR_PROGRESSION.md).
   Skyshard, Tidecaller and Tyrant gems glow softly at night. `tools/playtest_forest.ps1
   -ArmorPreview` grants all 18 pieces.
2. **Keeper's Atelier (K → Appearance).** Six hairstyles now redrawn for the new hero, skin,
   hair, tunic and trouser colours, blinking eyes, and a Wardrobe tab that previews all six
   sets piece by piece across 14 motions (idle, run, tools, bow, fishing, roll, cheer, eat…).
3. **In hand.** The selected hotbar tool is held in the keeper's hand while walking, rests on
   the shoulder in profile, and every swing (axe, pickaxe, dagger, sword, hoe, net) has an
   anticipation, a clear impact frame (hits still land at the same moments) and
   follow-through. Bow and fishing lines leave from the real bow and rod.
4. **Feel.** Walking accelerates and brakes instead of snapping, footsteps kick up
   surface-coloured dust with quiet footfalls, wading shows a waterline and splashes, hits
   flash white with a short hitstop and gentle screen shake (toggle in Settings), and the
   keeper turns to face whatever hit them.
5. **New moves.** **SPACE (or Ctrl) dodge-rolls** with brief invulnerability. The keeper now
   visibly eats, crafts (hammers at a workbench), places structures, reaches to open chests
   and doors, cheers when a creature is tamed, and falls over on death facing any direction.
6. **Riding.** The rider is drawn by the same rig in a seated pose on stego and trike, wearing
   exactly the equipped armour, and keeps its legs seated while aiming the bow.
7. **In the world.** The keeper now layers against trees, rocks and creatures by where their
   feet stand (like everything else in the forest), so walking past a trunk no longer tucks
   them behind it. Raised fists stay in front of shoulder guards, and skin tones reach the
   nape under the Fangbound and Tyrant helmets.

Art and code live in `game/Forest/keeper/` and `tools/keeper/`; review boards are in
`art/keeper-v2/review/` and in-game captures in `art/keeper-v2/world/` and `art/keeper-v2/feel/`.

## Seventh-pass character wardrobe

Press **K → Appearance** to open the upgraded keeper editor. Choose among six hairstyles,
change skin/hair/fabric colors, and use **Wardrobe** to preview independent head, chest and
leg pieces from Trail leather, Fangbound bone and Skyshard crystal. Turn the keeper and
cycle the motion button to inspect walking, running and tool actions with held props.
Wardrobe previews are cosmetic studies; saving applies appearance only. Craft the actual
armor pieces at a workbench and equip them through Gear. Existing saves and equipment IDs
remain compatible. Armor follows the keeper through idle glances, actions and riding.

See [the character review guide](../art/character-pass7/REVIEW.md) for screenshots,
recipes, PixelLab provenance and verification details. Editable layered artwork lives in
`game/Forest/equipment/art/wardrobe/`.

## Sixth-pass review route

1. **Keep your journey:** Continue as usual, press **K**, then **Appearance**. Choose skin, hair color, three hairstyles, tunic and trousers. Turn the animated preview; compare clothing and equipped armor. Apply saves your look with the journey; Cancel discards only the draft. New Expedition also opens this creator. Cosmetic changes do not alter defense or inventory.
2. **Watch your keeper:** axe chopping, overhead pickaxe strikes, dagger thrusts, sword sweeps, bow draw/release, fishing cast/reel, hoe, net, bucket, pet and pickup each have authored four-direction body clips. Leather has fitted ear guards, shoulder caps, wrist wraps and shin guards. Equipment is composed into every pose; mounted actions use the same dressed keeper with seated legs.
3. **Try archery:** craft a Reedwood Bow at a workbench (5 logs, 8 fiber). Craft eight Bone Arrows from a log and raptor fang. Select the bow, hold left-click to draw, release to fire; a longer draw hits harder. Stego and trike saddles support shooting. With a bow selected, left-click fires the survivor's weapon instead of the mount attack. Switching tools, opening menus or taking a hit cancels the draw without consuming an arrow. Arrows stop at solid obstacles.
4. **Plant a small garden:** craft a Stone Hoe (3 logs, 2 stone). Right-click clear nearby earth to till it. Craft two Berry Seeds from one berry, or two Mushroom Spores from one mushroom; select them and right-click the soil. Use a Water Bucket once on each planted plot. Berries grow in 90 active seconds, mushrooms in 120. Aim and press E to harvest three produce and one replacement seed. The emptied bucket remains yours. Growth and watering persist; paused/offline time does not grow crops. Harvest before building over a planted plot.
5. **Give companions jobs:** in the companion commands choose **Set work home**, **Assign chest**, then **Work**. Stegos gather wild timber, trikes gather wild berries/fiber, and dodos lay an egg per active minute while nesting. Cargo holds 12 items. Workers return to a nearby assigned chest when loaded; **Return** calls for an immediate delivery. Full or obstructed chests retain cargo. Jobs never dismantle placed structures. Raptors remain hunting followers. Work stays within a small local area rather than managing a whole colony.
6. **Cook the harvest:** a Forest Omelet uses one dodo egg and two mushrooms at a campfire (75 hunger, 150 walking seconds of fullness, 24 vitality over 24 seconds). Warm Berry Compote uses three berries (40 hunger, 90 seconds of fullness, 10 vitality over 20 seconds).
7. **Upgrade tools:** hover items or crafting outputs for damage and mining/chopping power. Shardbound tools cost the basic tool, 6 crystal shards and 3 fiber at a workbench. Power 2 mines/chops faster and unlocks violet dense crystal seams farther into the forest. Three Prism Crystals, two planks and two fiber make the Skyshard Sword.
8. **Organize supplies:** Satchel **Sort pack** merges and sorts the backpack while protecting the currently selected hotbar pouch. **Stack nearby** deposits matching backpack materials into nearby visible chests; it keeps overflow and cannot deposit through walls. **Pet** is available beside bonded animals. Species now have separate ambient, hurt and attack voices with distance fading and quiet hurt calls.

The forest remains the focused playtest biome. Character artwork is based on the existing keeper identity; no external replacement pack is required. Spell casting and story progression remain future work. Original dinosaur sheets are preserved. See [sixth-pass validation](../art/forest-pass6/VALIDATION.md).

## Fifth-pass review route

1. Equip and remove a **Leather Helmet**. Darker leather should stand apart from skin. The default hero wears a basic cloth wrap with no defense bonus. Ride a saddled stego or trike in all four directions: seated poses now use the actual hero's head, torso, arms and palette, including the authored left-facing character. The rider remains a separate living target. Small hits hurt the rider; a hit of at least 10 damage after armor can knock them off. Death detaches the rider and starts normal respawning.
2. Only **Vitality** and **Hunger** remain. Sprinting and attacking have no energy restriction. Without a meal buffer, one minute costs about 0.7 hunger standing, 2.1 walking, or 9.6 sprinting. Each tool swing adds 0.1 hunger exertion. Riding conserves the survivor's exertion.
3. Roast meat at a fire. It fills hunger completely, then holds it full for 3 minutes of walking, 6 idle minutes, or 90 sprinting seconds. Berries give 8 hunger and an 8-second walking buffer; raw meat gives 25 hunger and 25 seconds. Meals retain distinct timed vitality recovery. Eating the same food refreshes its healing effect instead of stacking it. The Skyfang Pendant now improves fed vitality recovery instead of energy.
4. At a workbench, craft a **Reed Fishing Rod** from 6 logs, 8 fiber and 2 crystal shards. Select it and find bright silver ripples near a river bank. Aim at a ripple and **right-click** within four tiles. Hold Space to lift the green cradle; release it to lower it. Keep the fish inside until the gold catch meter fills. Reed Perch are gentle, Jade Shardfin restless, and Moonscale wild. Escape or right-click cancels without consuming anything. A successful hole rests for 90 seconds. A full satchel puts the catch on the bank for later pickup.
5. Roast a Reed Perch at a campfire for **Roasted Perch**: 55 hunger, 2 walking minutes of fullness, and 18 vitality over 20 seconds. Other fish can be eaten with their own food values.
6. Break mushrooms for real **Mushrooms**. Craft a **Crystal Flask** at a workbench (2 crystal shards, 1 stone), select it and right-click nearby water. At a fire, combine 2 mushrooms, 1 berry and the filled flask into a **Mushroom Tonic**. Drink it for 40 vitality over 8 seconds. It works even at empty hunger and returns the reusable flask to its exact slot, including in a full satchel.
7. Inspect the compact overhead workbench, animated chest lid and overhead hearth. Chests still fit beside neighboring wall cells. Open and close a chest with E and check its lid. Break an existing **Hide Tent** by hand or tool, collect it and place it elsewhere. A new tent costs 6 planks, 12 fiber and 3 scales at a workbench. Separate enterable tent interiors remain future work.
8. Use companion commands: button feedback now uses leather equipment foley instead of the electronic pop. Save and continue to check food fullness, potion effects, fishing-hole cooldowns and existing world/gear data.

The original hero was retained after comparing licensed alternatives. This historical pass established the rider identity and survival foundation; the sixth pass above adds character creation and net/body action clips. See [fifth-pass validation](../art/forest-pass5/VALIDATION.md) for its evidence.

This is the new default game entry point: a playable, single-biome forest survival slice built around the Fall of the Sky-Fangs. The earlier playground, character-studio raptor, and original source artwork are preserved.

## Play

Double-click **Play Cravera.cmd** in the repository root, or run `tools/playtest_forest.ps1`. In Godot, open `game/project.godot` and press F5. The title menu offers New Expedition and, after saving, Continue Journey.

The launcher uses the installed Godot 4.6.1 and OpenGL compatibility rendering. A 1440×810 window gives an exact 3× scale of the 480×270 interface. To run a disposable forest session without loading or writing a journey, use `tools/playtest_forest.ps1 -FreshPreview`.

## First ten minutes

1. Explore the starting camp. The workbench sits northwest of you; the fire is northeast. The original main theme plays at the title and your Plains travel music plays in the forest.
2. Select the axe with **1**, aim at a nearby tree, and left-click three times. Walk into the dropped timber to collect it. Select **2** to mine the stone/crystal seam southwest of camp.
3. Press **Tab**, **I**, or **C** to open the satchel. Craft planks, walls, and flooring. Stand close to the workbench for bucket, chest, and armor recipes, or close to a fire for cooking. Search and “Ready only” help filter recipes.
4. Drag a crafted structure to a hotbar slot, select it, and right-click dry ground within reach. Walls block movement. Chests can be opened with **E** while aiming at them. Shift-click transfers whole stacks; drag moves or merges stacks.
5. Select the bucket with **7** and right-click river water east of camp. Right-click empty dry ground to place the water. Wading slows movement and shows surface ripples. The ford crosses the river without wading.
6. Select berries with **4** and approach a dodo or herbivore. Press **E**, let it finish eating, then feed again. Dodos need two feeds; trikes and stegosaurs four; longnecks five. They become followers. Hold E or Q near a bonded dinosaur for its command menu; hold Q away from companions for group orders. Tap E beside a saddled stego/trike to ride. P opens the companion roster. Choose Follow, Stay, Guard or Roam independently from Passive, Neutral or Aggressive temperament.
7. Raptors live northeast; the larger Rex ranges farther southeast. Select a net with **5**, approach within interaction distance and press **E**. Switch to raw meat with **6** and feed while restrained. Raptors need three feeds, Rex six. There is a 3.2-second feeding cooldown; Rex requires re-netting. Bring supplies and watch the attack windup.
8. Press **J** for the first-camp journal, **M** for the overview map, **Escape** to pause, and **F5** to save. Death shows a five-second countdown, then returns you to your bound hide bed or the starting camp with your inventory intact.

Other controls: WASD move, Shift sprint, 1–8 or mouse wheel select tools. Left-click attacks toward the cursor. Right-click food to eat it. Press K or click Gear for a live character portrait and seven equipment slots: head, chest, legs, three trinkets and a carried torch/lantern. Select a slot, then a compatible item; Unequip returns it to your satchel. Armor appears on your character in the world. Duplicate copies of the same trinket cannot be worn together. Tab closes the inventory even when the search box has focus.

## What is implemented

- Original illustrated title screen, drifting motes, menu/field guide, music volume settings, pause and return-to-title flow.
- Seeded 112×112 world on a 16-pixel grid: forest, grassy clearings, branching paths, a river/ford/lake, mineable banks and crystal seams, a starting tribe camp and abandoned landmarks.
- Existing native pixel-art foliage, rocks, and mushrooms integrated with new flowers, tribal tents, workbenches, crystal growths, timber construction, textured shoreline, reeds, animated fire and water.
- Six distinct crystalline dinosaur designs, real front/rear/side artwork, idle/walk/attack clips, collision, wandering, obstacle steering, attack windup/contact, loot, net restraint, feeding, trust, and companion orders.
- Existing player character and combat state machine retained. Forest integration adds cursor aiming, visible equipped tool swing, wading speed, attack/placement obstruction checks, UI input locks, and respawn.
- 35 inventory slots, an eight-slot hotbar, vitality and hunger bars, readable item icons, armor and chests. Inventory and crafting transactions account for every stack and fail without partial loss when capacity is insufficient.
- Seven recipe categories with 30 recipes, output quantities, ingredient counts, capacity checks and station restrictions. The Relics category adds Skyfang Pendant (+0.2 vitality recovery per second while fed), Hunter's Fang (+2 damage), River Totem (faster wading) and Shard Lantern (equipped light), all made at a workbench.
- Separate persistent forest journey: inventory, armor, accessories/light, player condition, time, milestones, mined resources, placed construction, water edits, chest contents, wild creatures and tamed companions. Autosave every 60 seconds, explicit save, and quit/save-to-title.

## Scope and honest limits

This is a reviewable vertical slice, not a finished survival game. Creature animations have distinct directional artwork and restrained source-based motion; they still need the detailed limb articulation and animation polish of the older dedicated raptor workflow. Stego and trike riding are available in pass three. Breeding, multiplayer, quest NPCs, farming/hoe systems and additional biomes remain future work.

Water is editable cell-based water with animated ripples and wading, not a pressure/flow simulation. The map is an overview rather than fog-of-war exploration. Creatures use local obstacle steering rather than full long-distance pathfinding. The Rex is a stronger predator rather than a multi-phase boss. Respawn intentionally keeps inventory, and the starting kit is generous to make systems easy to review. Tool actions use weapon-free versions of the original directional body poses, with distinct pickaxe overhead strikes, axe sweeps and dagger thrusts. Contact and recovery timings differ; these remain refinements of the original body animation rather than fully hand-animated new skeletal poses.

Original forest population and resources are finite in this slice. Trees do not automatically regrow. Mining, wood chopping and placement use varied recorded Kenney impact samples; satchel and gear use recorded cloth/leather handling. Other short game cues remain synthesized; music comes from the supplied local tracks. Balance and long-session performance need human playtesting.

## Saves and files

Forest save: `user://skyfang_forest_v1.json` under Godot's Cravara user-data folder. It is separate from the existing `save.json`. Starting a new expedition replaces the forest save when that journey is saved; the menu warns when one exists. Validation uses an isolated temporary save and never modifies a real journey.

- Entry/menu: `game/Forest/MainMenu.tscn` and `MainMenu.gd`
- Integration: `game/Forest/ForestPlaytest.gd`, `ForestPlayer.gd`
- World: `game/Forest/ForestWorld.gd`, `ForestProp.gd`, `ForestWater.gd`
- Creatures: `game/Forest/creatures/ForestCreature.gd`, `art/forest-creatures/README.md`
- Interface: `game/UI/ForestHUD.gd`
- Inventory and recipes: `game/Player/Scripts/InventoryManager.gd`, `game/Scripts/CraftingManager.gd`
- Art review and verification logs: `art/forest-playtest/`

## Verification

The integration suite exercises real world mutations, actual player physics against placed walls, bucket exchanges, wading, taming restrictions, combat damage, save replacement, world/companion restoration, and journal layout. Separate world, inventory, creature, and GUI-input suites cover their detailed contracts. Rendered screens were inspected and revised, including the menu, forest, inventory, journal and creature directions.

Run `tools/verify_forest.ps1` for the complete reproducible suite. This does not replace a human playtest of responsiveness and art quality.

## References and provenance

- [Core Keeper, official Steam page](https://store.steampowered.com/app/1621690/Core_Keeper/): reference for readable top-down gathering, crafting and editable-world progression.
- [Emberville, official Steam page](https://store.steampowered.com/app/2295170/Emberville/): reference for dense environmental detail and expressive pixel-art creatures. No game artwork was copied.
- [Better Terrain, GitHub](https://github.com/Portponky/better-terrain): investigated as an open-source terrain option. This slice uses a small explicit editable grid and neighbor-aware rendering, without adding the plugin as a dependency.
- [Tiny5 font, Google Fonts](https://github.com/google/fonts/tree/main/ofl/tiny5): bundled under SIL Open Font License; full license in `game/Forest/fonts/OFL.txt`.
- Tree/rock/foliage art is the project's pre-existing `WorldObjects/Images/Objects.png` atlas. The player is the pre-existing character. Original title and dinosaur concepts were generated for this project and assembled into native assets; original files remain intact.
- Music: supplied `assets_raw/Music/Main Game Theme #1.mp3` and `Travel Music (Plains).mp3`, copied into the game so playback does not depend on external paths.

## Second-pass review route

- At spawn, compare the stone seams, workbench, campfire, tribal tent and quartz boulder. All 29 registered item icons now have original jungle/crystal artwork. Existing dinosaur art and world spacing are preserved.
- Swing an axe, pickaxe and dagger in different directions. Watch the lift/sweep/thrust and contact chips; listen for varied wood and stone impacts.
- Craft relics near the camp workbench and equip them using K. A torch from your starting kit can also be equipped in the light slot. View armor both in the portrait and while walking in four directions.
- Tame a stego, lead it across shallow water, then try Stay, Roam and Guard. Passive cancels aggression; Neutral defends against threats; Aggressive seeks hostile wildlife. Hold Q commands all surviving companions. These menus stay open after releasing the key so commands can be clicked deliberately.
- Challenge a Rex with a stego companion: both can now strike at their actual body sizes. A lone stego is no longer able to exploit a harmless bouncing Rex. Species have different speeds: raptor 53, Rex 44, trike 29, stego 23, longneck 20, dodo 18 (base world pixels/second before behavior and water modifiers).
- Save, return to title and continue. Equipment, companion order/temperament/guard anchor and existing terrain edits persist. Older forest saves default to empty accessory slots and neutral temperament.

## Recorded next directions

The next design pass should consider species utility (dodo eggs, stego timber harvesting, raptor hunting), Rex saddles/riding, companion capacity and earned trust/capability gates. Preserve the preference for perk/capability progression rather than a generic numerical leveling treadmill. Rex access should require a meaningful investment before it becomes a rideable early-game solution. Stego/trike saddles and riding were implemented in the third pass; the other systems in this paragraph remain future work.

## Second-pass source assets

- [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds): CC0 mining, wood and plank recordings. Fifteen variants bundled in `game/Forest/audio/foley`, with the original license.
- [Cinzel, Google Fonts](https://github.com/google/fonts/tree/main/ofl/cinzel): SIL Open Font License display type, bundled license beside the font.
- [Godot radial-menu control](https://github.com/jesuisse/godot-radial-menu-control): reviewed as an interaction reference. The companion interface uses native Godot Controls and introduces no dependency on this library.
- New original item/prop generation, master-palette conversion, Aseprite sources and rendered comparisons: `art/forest-v2/ART_NOTES.md`.
- Equipment body sheets retain the supplied character's layered Aseprite artwork, with baked sword/swing layers hidden. Export recipe: `art/forest-pass2/export-tool-body.lua`. Original source files are unchanged.

## Third-pass review route

1. Open **Settings** on the title screen or from Pause. Camera defaults to **Tight / steady**; optional smoothing, fullscreen, dynamic shadows and three audio sliders preview immediately. Save & return keeps changes; Cancel restores the previous settings.
2. Equip a helmet and run, walk, swing all three tools and turn in four directions. Gear is now composited into each animation frame using the original source head positions, so it cannot trail the character as an independent overlay.
3. Open the satchel and drag an item into an empty slot, over a different item or onto a matching stack. Armor drags as an item; click-release equips it. **Caps Lock** cycles five hotbar pouches without rotating your inventory. The last pouch contains three slots. Selected pouch/slot persist.
4. Mine a boulder: it now needs **8 hits**, compared with **3 for stone walls**. Watch chips, cracks, a brief shake/flash and the remaining durability. Placed wooden structures sound like wood regardless of the tool used. Punch or hit placed torch, workbench, fire, chest, wall, floor, door or roof to recover it. Empty chests first; occupied chests refuse reclamation without losing their contents. Ancient map tents/shrines remain landmarks.
5. Harvest mushrooms and cattails for plant fiber. Their decorative presence is now backed by a harvestable object. Tree collision follows the grounded trunk; tents and boulders have deeper footprints. Campfire stones block movement and the hot edge inflicts 3 damage per second of contact.
6. Build a small home: floor tiles, a wall perimeter, a **Timber Door** and **Thatch Roof** above the floor. Aim and press E to open/close doors; an occupied doorway cannot close onto you. Roofs fade when you step beneath them. Doors, roofing and partially damaged resources save correctly.
7. Observe shadows through the day and around campfire/torch/lantern light. Shadows are finite directional projections for the sun, with native occlusion for local lights. The shadow setting disables casts while preserving illumination.
8. Stay fed to recover vitality at **0.6 HP/second**. Berries add **5 HP over 10 seconds**, raw meat **8 over 20**, and cooked meat **30 over 30**, in addition to hunger restoration. Recovery stops at zero hunger and caps at maximum HP. Inventory panels do not stop survival time; Pause does.
9. Open **P**, then choose **Locate** for a bonded companion. A temporary amber direction marker, distance, pulsing ring and repeated tone help you find it without moving your character.
10. Craft a **Stego Saddle** or **Trike Saddle** at a workbench: each costs 8 planks, 12 plant fiber and 3 crystal shards. Tame that species, approach and hold E, choose Equip saddle, then Ride. WASD steers, Shift sprints without an energy gate, and E dismounts at a safe nearby spot. Water slows mounts. Saddles appear on the creature and persist; loading always returns you to your feet. You cannot dismount through walls or remove a saddle while riding.

The third pass kept the same single biome and original dinosaur artwork. Fourth-pass saddle variants and mounted combat extend this below. Harvesting utility, Rex riding, companion capacity, eggs and perks remain future work. Roofs are a simple fading tile layer, not an enclosed-room/weather simulation.

The earlier mounting implementation and its evidence are in `art/forest-playtest/v3/MOUNT_LOCATOR_QA.md`. It is superseded by the fourth-pass seated composite animations below.

Third-pass tests and evidence: `art/forest-pass3/VALIDATION.md`, `art/forest-v3/WORLD_PASS.md`, `art/forest-playtest/pass3-ui/VALIDATION.md`, and `art/forest-playtest/v3/equipment-motion-native.png`.

New source references: [Godot 2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html), [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) (CC0, license bundled), and the official Google Fonts repositories for [IM Fell English](https://github.com/google/fonts/tree/main/ofl/imfellenglish) and [Alegreya Sans](https://github.com/google/fonts/tree/main/ofl/alegreyasans) (OFL licenses bundled). No reference-game assets were copied.

## Fourth-pass review route

1. **Tap E** near a workbench, campfire, chest, door or hide bed to interact. You can stand beside a workbench without precisely aiming at it. A deliberately aimed nearby object takes priority; otherwise the nearest relevant object or animal does. Tap E beside your saddled stego/trike to mount, and tap E again to dismount. **Hold E or Q** near a companion for its menu. Hold Q away from companions for group orders.
2. Equip a saddle to see the new full animal artwork with leather harness and saddle. Mount to use seated rider poses baked into the same animation frames as the animal. Equipped gear remains visible. Check all directions and walking/running. Source dinosaur artwork remains available unchanged.
3. While riding, **left-click toward the cursor** to attack: the stego aims its tail sweep; the trike drives its horns forward. Strikes have no energy cost, have a windup and cooldown, respect obstacles, and spare bonded companions. **F** feeds one berry to recover up to 18 mount vitality, with a 2.5-second feeding cooldown. Full-health mounts do not consume food. Bows, spells and firing weapons from the saddle remain future systems.
4. Continue your saved house: old timber floors now occupy their own layer. Place a door or furniture on a floor, and put roofing over either. Roof graphics align to their selected cells; ground-level walls no longer reject nearby overhead roofing. Reclaim the top layer first. The old save migrates when loaded, preserving floors, existing roofs, chest stacks, water edits, damaged resources and open doors.
5. Craft a **Hide Bed** at a workbench for **4 planks, 8 plant fiber and 2 Rex scales**. Place it and press E beside it to bind home. After death, watch the five-second countdown and confirm movement works immediately on return. The bed binding persists. If the bed is reclaimed, respawn falls back to the first camp.
6. Inspect the new leaf/moss grass and earthen ground textures. Watch trees and boulders at noon: sun shadows connect to their visible ground contact. Put a torch beside the workbench: its silhouette casts onto the ground while the wood catches warm light. Point-light surface fill is a stylized 2D treatment to avoid a sprite blocking light from itself.
7. Reclaim a torch or drop loot: collectibles are now small floating icons above a fixed ground footprint. Satchel and equipment cues use natural leather/cloth recordings. Equip the helmet and let side-facing idle glances play; the helmet follows each head cel and covers the ears.
8. Open Settings and turn off **Corner shortcut buttons** for a cleaner HUD. Tab, K and P still work, and the hotbar stays visible. New corner buttons use stitched hide and crystal key shapes.

Evidence and limitations: `art/forest-pass4/VALIDATION.md`, `WORLD_ART_NOTES.md`, `art/forest-playtest/pass4-ui/VALIDATION.md`, and `art/forest-playtest/v4/`. The user's house was inspected and tested from a copied save, not edited in place.

New foley source: [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio), CC0. Original files, license and clip-editing provenance are bundled under `game/Forest/audio/leather/`.
