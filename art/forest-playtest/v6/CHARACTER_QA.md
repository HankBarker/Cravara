# Character pass 6

Implemented on September 16, 2026. Character changes preserve the established hero's original head cels, body scale, blue eyes, directional identity and fixed 64×64 canvas. Original hero source files and saddled dinosaur artwork were not edited.

## Appearance and equipment

`Appearance.gd` provides five persistent cosmetic fields: skin, hair, hair_style, cloth and trousers. Unknown saved choices fall back to valid defaults. Root player/session code owns save/load and application; the creator owns draft editing. Cosmetic choices confer no defense.

The wrapped cloth outfit now has an ivory collar, diagonal wrap seam, split hem, belt and boots. Leather equipment adds stitched shoulder caps, chest fastening, turquoise/ivory pins, forearm wraps and knee/shin protection. The dark helmet follows each actual head cel's silhouette. Limbs and hand endpoints are preserved, and clothing is behind the jaw when the hero leans or crouches. `EquipmentSkin.build(source,armor,light,appearance={})` remains compatible with older callers.

Wardrobe design used a generated reference (`wardrobe-concept.png`) followed by native pixel construction against the current hero. The generated character anatomy was not substituted for the existing hero. Native Aseprite comparison files and all new action source cels are included.

## Actions and tools

Thirteen actions have four directions and eight authored frames each (52 clips, 416 frames): axe, pickaxe, dagger/weapon, sword, bow draw, bow release, fishing cast, fishing reel, hoe, net, bucket, pet and pickup. The pose keys differ: overhead lift/chop, two-handed pick strike, straight thrust, cross-body slash, bow pull/release, casting flick, circular reel, hoe pull, wide net throw, dip/lift, crouched touch and ground pickup. Original source feet remain grounded while body/head/arms move; the source head is never scaled frame by frame.

`ActionFrames.install(source)` adds the clips. `duration(kind)` and `contact_ratio(kind)` share the gameplay timeline. `EquipmentSkin.pose(clip,index)` exposes exact head/body offsets plus hand and offhand canvas coordinates. Root weapon, bow and fishing rendering uses those grip points. Existing attacks retain their real once-per-strike hit logic.

Mounted appearance uses the same customization and armor. Bow actions replace the seated hero's upper body with the actual dressed action frame while retaining seated thighs, boots and the saddle anchor. The player remains the independent gameplay actor; dinosaur animation and aiming direction remain separate.

## Verification

- `CharacterPass6.tscn`: **692 assertions, 0 failures**. Checks all clip durations, distinct action images/poses, all 416 exact head and grip metadata records, every action helmet fit, source immutability, palette changes, mounted identity/action rendering, and bounded caches.
- `CharacterPass6Render.tscn`: **30 assertions, 0 failures**, empty error log. Runs the real forest player/FSM, verifies frame progression for all 13 actions, captures actual tool graphics, rides a saddled stego, holds the real bow through full charge, releases an arrow and safely dismounts.
- `ForestRiderPass5.tscn`: **38 assertions, 0 failures** after initial wardrobe changes. Existing exact source identity, separate rider damage, substantial-hit knockoff and death dismount behavior remained intact.
- Godot import completed with no script errors. Tests use `--no-save-playtest` and leave real saves untouched.

Measured cold generation in the local headless build: full default skin 57.7 ms; full customized skin 126.9 ms; new mounted action composite 7.1 ms. These costs occur on new combinations, with cached reuse afterward. Skin caches cap at 12 entries and mounted composites at 24. Default coloring skips the remap scan; customized coloring visits only the opaque bounds.

## Visual evidence

- `wardrobe-native.png` / `wardrobe-review.png`: original, cloth, full leather, and custom example; columns down/right/left/up.
- `direction-action-native.png` / `direction-action-review.png`: all 13 action rows, in the order above. Direction groups down/right/left/up; four sampled frames per group (0,2,4,6). Fixed common crop, never per-frame rescaling.
- `actual-playback-native.png`: frames observed during real player playback, not a renamed static sheet.
- `in-game-action-axe.png`, `in-game-action-pickaxe.png`, `in-game-action-hoe.png`: real held tools with new poses.
- `in-game-mounted-custom-bow.png`, `in-game-mounted-bow-release.png`: customized rider, original saddle/dinosaur art and actual bow controller.
- `character-regression.log`, `character-render.log`, `character-render-errors.log`, `rider-compatibility.log`.

The wardrobe remains intentionally small native pixel art, with deliberately exaggerated fasteners and shoulder/boot edges. It is not a high-resolution replacement character. Fishing reel repeats; other action clips end or hold through their owning gameplay controller.

## Reference research and provenance

[Minecraft's official 23w04a notes](https://www.minecraft.net/en-us/article/minecraft-snapshot-23w04a) explicitly separate visual armor trims from gameplay benefits. [Minecraft's armor trim introduction](https://www.minecraft.net/en-us/article/armor-trims-coming-minecraft-1-20) also links motifs to where their patterns originate. Applied here: cosmetic cloth/hair choices remain independent from equipment stats, while native leather/shard details reflect this game's prehistoric crystal setting.

[Core Keeper's official June 2026 community update](https://steamcommunity.com/app/1621690/announcements/) describes the dresser's ability to hide or change armor appearance under “Vanity Slots Top Tip.” This supports a separate appearance layer and a clear gear preview. No Core Keeper or Minecraft artwork, textures or code was copied.

Existing project hero assets remain the anatomy/palette source; newly authored Lua/Aseprite action poses and runtime garment pixels are local project work. The generated wardrobe reference is design guidance. Prior open-source character alternative/license comparison remains in `../v5/CHARACTER_RESEARCH.md`; keeping the existing hero avoids an identity break and introducing a new character pack dependency.
