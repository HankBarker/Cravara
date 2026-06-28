# Cravera Visual Pipeline & Game Feel Reference

Practical reference for the pixel-art visual pipeline of **Cravera** — a 2D top-down pixel-art
dinosaur survival/crafting game in **Godot 4.6**. Native render res **480x270** upscaled to 1080p,
nearest filtering, 2D pixel snapping ON. North stars: Core Keeper, Terraria, Stardew/Forager, ARK
creatures reimagined as 2D dino sprites. Art is **hybrid**: AI sprites + curated packs for bulk,
hand-authored pixel art for hero assets.

> Jump to **[How this maps to Cravera](#how-this-maps-to-cravera)** for the prioritized decisions.

---

## 1. Pixel-art fundamentals for a cohesive top-down game

**Pick ONE base unit and never break it.** At 480x270 the screen is ~30 tiles wide at 16px, or ~15
at 32px. The single biggest mistake in mixed-source pixel art is **mixing resolutions** (one sprite
at 16px density, another at 24px) or **non-integer scaling** (a 20px sprite squeezed to fit a 16px
grid). Everything must share one **pixels-per-unit (PPU)**: a pixel is a pixel everywhere. Scaling a
sprite by 1.5x or rotating it off-axis breaks the grid and reads as "fake" pixel art.

**Tile size.** 16x16 is the genre standard (Stardew, Core Keeper, most Kenney/itch packs) and gives a
30x15 tile playfield at 480x270 — a comfortable, readable survival-game density. 32x32 doubles detail
but halves how much world is on screen (15x8.4 tiles) and makes hand-authoring + AI cleanup far slower.
**Use 16x16 for tiles and world objects; reserve a 32x32 footprint only for large hero creatures**
(still on the same pixel grid — a big dino is 32px tall, not a 16px sprite scaled up).

**Palette discipline.** A cohesive look comes from a *shared, limited palette*, not from any single
asset. Stardew "feels unified" precisely because the whole world draws from one disciplined palette.
Start from a curated Lospec palette and force every source (AI, packs, hand art) into it.
- Lospec palette list: https://lospec.com/palette-list (filter by size; 32–48 colors is a good target)
- Strong cohesive starting points: **Resurrect 64**, **AAP-64**, **Endesga 32/64**, **Apollo (46)**.
- Keep a master `palette.png` / `.gpl` in the repo; it is the source of truth for recolors.

**Readability first.** Top-down survival lives or dies on instant readability of player, enemies,
loot, and hazards. Techniques:
- **Outlining / selout (selective outline):** dark outline around silhouettes for separation from the
  ground; *selout* = vary the outline color (lighter on lit edges) so it doesn't look stickered-on.
- **Silhouette test:** fill a sprite solid black — if you can't tell what it is, redesign it.
- **Value before hue:** establish light/dark contrast first; color second.

**Hue-shifting for shading.** Don't just darken a color toward black. Shift **shadows to a cooler
hue, highlights to a warmer hue** (green base → teal/blue shadow, yellow highlight). This is the
single technique that makes flat fills look like crafted pixel art.

**Dithering.** Gradient/texture via checkerboard pixels. Works best at 32px+; at 16px it reads as
noise. Use sparingly (ground texture, large creature bodies), not on small UI/items.

**Perspective: pick 3/4 vs true top-down.** Two conventions:
- **3/4 view (Stardew, Forager, Terraria-ish):** camera tilted; you see the *fronts* of trees, walls,
  characters. Warm, characterful, friendlier to read faces and creatures. More art per object (you
  draw a "front").
- **True top-down (Core Keeper, classic Zelda dungeons):** straight-down; objects show their *tops*.
  Cleaner tiling, easier autotiling, but flatter and less expressive for creatures.

**Recommendation for Cravera: 3/4 view.** A dino bestiary needs expressive, recognizable creatures
(ARK-reimagined silhouettes, biting animations facing the player) — 3/4 sells those far better than
true top-down, and matches the Stardew/Forager/Terraria north stars. Document this once and hold it:
every creature, prop, and the player are drawn at the same slight downward tilt.

Sources: [Lospec palettes](https://lospec.com/palette-list) ·
[Sprite-AI fundamentals](https://www.sprite-ai.art/guides/pixel-art-fundamentals) ·
[Lospec hue-shifting tutorials](https://lospec.com/pixel-art-tutorials/tags/hueshifting) ·
[Lospec shading](https://lospec.com/pixel-art-tutorials/tags/shading) ·
[Pixnote dithering guide](https://pixnote.net/en/learn/dithering/)

---

## 2. Character & creature sprite construction

**Directions: 4-dir.** Cravera's player already has 4-direction facing; keep the whole bestiary
4-directional (down/up/left/right). 8-dir quadruples art cost and is overkill for a survival/crafting
top-down. Mirror left↔right where the creature is symmetric to halve the work (note: mirroring flips
outline lighting — acceptable at this scale, fix only on hero assets).

**Frame counts (start lean, add only where it sells):**
| Animation        | Frames | Notes |
|------------------|--------|-------|
| idle             | 1–4    | subtle breathing bob; 2 frames is fine for minor creatures |
| walk / run       | 4–8    | 4 reads fine at 16px; 6–8 for hero dinos |
| attack / bite    | 3–6    | anticipation → contact → recovery |
| hurt / hit       | 1–2    | often just a white hit-flash (shader, §7) instead of unique frames |
| death            | 4–6    | distinct from hurt; can end on a corpse/bones frame |

Cravera's creature naming already follows `walk_down/up/left/right`, `bite_*`, `death` — keep that
SpriteFrames convention for every new creature so code stays generic.

**Anchor / pivot consistency.** This is the #1 cause of "jittery" sprites. Across *every* frame of a
creature, the **ground/feet point must sit at the same pixel** (typically bottom-center). Normalize
sprite height and center pivots so frames don't bob unintentionally. In Godot set the AnimatedSprite2D
`offset` so the feet anchor to the node origin; the node origin is what `snap_2d_transforms_to_pixel`
snaps. Inconsistent anchors = visible swimming even with snapping on.

**Animation principles at tiny scale.** With only a handful of pixels, exaggerate:
- **Squash & stretch:** a 1px squash on contact frames; stretch on a lunge/bite.
- **Anticipation:** 1 wind-up frame before a bite (pull back) makes attacks readable and telegraphs
  to the player — important for survival fairness.
- **Follow-through / overlap:** tail/jaw settles 1 frame after the body stops.
- **Secondary motion:** a 1px tail or head bob on idle gives life cheaply.

**Bestiary cohesion.** Keep dinos cohesive by fixing shared rules: same palette, same outline
treatment, same eye style/size, same ground-shadow ellipse, same lighting angle (top-left). Variety
comes from silhouette and color, not from changing the rendering style.

Sources: [PixelLab 8-dir docs](https://www.pixellab.ai/docs/tools/create-8-rotations-pro) ·
[I Love Sprites — Godot sprite best practices](https://ilovesprites.com/blog/godot-sprite-nuances-best-practices)

---

## 3. Tilesets

**16x16 tiles.** Matches the genre and the 30x15 playfield. Author tiles seamlessly: the right edge
must tile into the left edge, top into bottom — test by laying a 3x3 grid of the same tile.

**Autotiling — use the 47-tile "blob" set.** A 47-tile blob set has a dedicated tile for every edge
*and corner* combination (including inner corners and diagonal neighbors), so organic terrain —
coastlines, cave walls, biome borders — looks smooth rather than jagged. The simpler 16-tile autotile
only handles 4-bit edges (sharp 90° corners) and looks blocky on natural shapes.

Godot 4.6 supports this natively via **TileSet → Terrain Sets → terrains** ("Match Corners and Sides"
gives blob behavior). Paint with the Terrain tab and Godot picks the right tile from the bitmask.
- Generator/reference: https://github.com/itsjavi/autotiler (47-blob, exports for Godot)
- Bitmask reference + template: https://jaconir.online/blogs/bitmask-autotile-guide
- Interactive autotiling explainer: https://www.redblobgames.com/articles/autotile/claude/

**Biome transitions.** Each pair of adjacent biomes (e.g. forest↔swamp, beach↔jungle) needs a
transition: either a dedicated transition terrain in the same TileSet, or an overlay "edge" tile layer
drawn on top of the lower-priority biome. Keep biome terrains in **one TileSet resource** so the
terrain peering bits interoperate.

**Decorative variation (kill repetition).** A flat field of one grass tile reads as obviously tiled.
Fixes:
- Author 3–4 grass variants and use Godot's TileSet **alternative tiles** + scatter probability.
- Sprinkle non-grid **decorative props** (pebbles, tufts, bones, mushrooms — Cravera already has
  `Bush`, `Mushroom`, `Bones`, `DecorativeObject`) as separate scenes on top.
- Vary value subtly, not hue, so the field stays cohesive.

Sources: [Jaconir bitmask 47-tile guide](https://jaconir.online/blogs/bitmask-autotile-guide) ·
[itsjavi/autotiler](https://github.com/itsjavi/autotiler) ·
[Red Blob autotiling](https://www.redblobgames.com/articles/autotile/claude/)

---

## 4. The AI-assisted art pipeline (the hybrid workflow)

AI is for **volume and drafts** — enemy variants, props, tiles, item icons, NPC variations — the bulk
world-filling. Hero assets (player, key dinos, UI) stay hand-authored or are AI-drafted then heavily
hand-finished. The hard problem is **consistency across a set**; solve it with fixed palette, reference
images, style tokens, and pinned seeds/models.

### Tools (current, 2025–2026)
- **Retro Diffusion** — purpose-built pixel-art model (FLUX-based) that respects pixel grids, palette
  limits, and clean transparent backgrounds; style presets (game asset, portrait, texture, UI);
  Aseprite extension + API/Replicate. Best authentic-pixel output. https://retrodiffusion.ai/ ·
  https://astropulse.itch.io/retrodiffusion · https://replicate.com/retro-diffusion/rd-plus
- **PixelLab** — game-dev focused: upload a **concept + reference sprite** to generate **consistent
  4/8 directional views**, skeleton animation (generates animation frames from poses), rotation,
  inpainting; style-reference feature matches existing art; has an API and runs inside Aseprite.
  Strongest for *directional frames* and *consistency to a reference*. https://www.pixellab.ai/ ·
  https://www.pixellab.ai/pixellab-api · https://www.pixellab.ai/docs/tools/animate-with-skeleton
- **General image model + pixelization** (e.g. a diffusion model then downscale+quantize) — flexible
  but needs the most cleanup; only worth it when the dedicated tools can't get the concept.

### Enforcing consistency across a set
1. **Lock the palette.** Generate freely, then **quantize every output to the master Cravera palette**
   (Aseprite: `Sprite ▸ Color Mode ▸ Indexed` with your palette loaded, or `Edit ▸ Adjustments`/
   palette-map). Nothing enters the game until it's been forced to the shared palette.
2. **Fixed style tokens.** Prefix every prompt identically, e.g. `"16px top-down 3/4 pixel art, thick
   dark outline, hue-shifted shading, limited palette, transparent background, <subject>"`. Keep this
   prefix in a snippet file; never improvise it per-asset.
3. **Reference image + style reference.** Feed a finished hero sprite as the style/reference so new
   sprites inherit outline weight, lighting, and density. PixelLab's style-reference and Retro
   Diffusion's init image are built for this.
4. **Pin the model version and seed.** Same model + same seed family per asset set; record them so a
   variant can be regenerated to match months later.
5. **Generate in batches, curate hard.** Produce ~20 variants, keep 1–2, refine in Aseprite. AI is the
   draft; Aseprite is the finish.

### Clean transparent backgrounds & true-pixel output
- Prompt for "transparent background"; Retro Diffusion/PixelLab output alpha directly. For general
  models, generate on a flat chroma color and key it out.
- **Downscale + quantize** any non-native-pixel output: nearest-neighbor downscale to true target
  resolution (16/32px grid), then index to the palette. Never ship an AI image at "fake" high-res with
  soft anti-aliased edges — it won't match and will shimmer when snapped.

### Directional frames & animation
- Use PixelLab rotate/8-rotations to derive up/left/right from a down-facing reference, then hand-fix
  outline lighting. Skeleton-animation generates walk/bite frames from poses; treat as a draft, clean
  contact frames and fix the pivot by hand.

### Known limitations
- Temporal/frame consistency is still weak — expect to hand-fix anchor drift and flickering pixels
  between frames.
- AI loves to creep in off-palette colors and sub-pixel detail; the palette-quantize gate is
  mandatory, not optional.
- Small UI/iconography and anything needing exact silhouette legibility is usually faster by hand.

Sources: [Retro Diffusion](https://retrodiffusion.ai/) ·
[PixelLab](https://www.pixellab.ai/) ·
[Sprite-AI: best generators 2026](https://www.sprite-ai.art/blog/best-pixel-art-generators-2026) ·
[Sprite-AI: pixel art animation](https://www.sprite-ai.art/blog/pixel-art-animation)

---

## 5. Sourcing asset packs and unifying them

Use packs for bulk world-filling, then **recolor everything to the Cravera master palette** so packs,
AI output, and hand art match.

**Reputable sources (CC0 / commercial):**
- **Kenney** — huge CC0 bundles, safe for commercial use. Pixel Platformer, UI Pack (400+ sprites in
  5 colors), All-in-1 (60k+ assets). https://kenney.nl/assets · https://kenney-assets.itch.io/
- **itch.io top-down pixel packs** — e.g. *Cute Fantasy RPG (16x16 top-down)* by Kenmi, Seliel the
  Shaper biome tilesets. Filter itch by tag: https://itch.io/game-assets/tag-cc0/tag-pixel-art
- **Lospec** — palettes (the source of truth) plus tutorials. https://lospec.com/
- Always check each pack's license individually (CC0 vs attribution vs commercial-with-credit).

**Recolor / palette-unify workflow (Aseprite):**
1. Load `cravera_palette.gpl` as the active palette.
2. Open the pack art, `Sprite ▸ Color Mode ▸ Indexed`, choosing "map to nearest palette color", or
   use a palette-swap remap. This snaps the pack's colors onto Cravera's.
3. Hand-touch any color that mapped wrong (skin tones, key contrast colors).
4. Re-export PNG; import into Godot. Now the pack reads as native Cravera art.

Sources: [Kenney assets](https://kenney.nl/assets) ·
[itch CC0 pixel art](https://itch.io/game-assets/tag-cc0/tag-pixel-art) ·
[Cute Fantasy RPG 16x16](https://kenmi-art.itch.io/cute-fantasy-rpg)

---

## 6. Godot 4.6 import & rendering for crisp pixels

**Project-level (Cravera already has these — verify they stay set):**
- `rendering/textures/canvas_textures/default_texture_filter = 0` (Nearest). ✅ already set.
- `display/window/stretch/mode = "canvas_items"`, base size `480x270`. ✅ already set.
- `display/window/stretch/scale_mode = "integer"` — **set this** so the upscale to 1080p is whole-number
  (1080/270 = 4x exactly). Without it you get uneven pixels. (1920/480 = 4x too — clean.)
- `rendering/2d/snap/snap_2d_transforms_to_pixel = true` and `snap_2d_vertices_to_pixel = true`.
  ✅ already set. These kill the movement shimmer.

**Per-texture import (.import):**
- Filter: **Nearest** (or "Project Default" if global is Nearest).
- **Mipmaps: OFF** (mipmaps blur shrinking pixel art).
- Repeat: Disabled (Enabled only for intentionally tiling textures).
- Compress mode: **Lossless** (VRAM/lossy compression mangles sharp pixel edges).

**Per-node texture filtering.** Each CanvasItem has a `texture_filter` property; leave on "Inherit" so
it follows the project Nearest default. Only override for a deliberate effect.

**Camera (Camera2D):**
- Keep **integer zoom** (1, 2, 3, 4 — not 1.5/2.3). Fractional zoom reintroduces uneven pixels even
  with snapping.
- For smooth-yet-crisp scrolling, the cleanest approach is rendering the world to a fixed
  `SubViewport` at 480x270 and scaling that viewport up by an integer — the camera can then move
  sub-pixel inside the low-res viewport without shimmer, and the upscale stays pixel-perfect. (GDQuest
  and the Godot pixel-perfect guides cover this `SubViewportContainer` pattern.)

**Rotation.** Rotating a sprite off 90° increments breaks the pixel grid (jagged, shimmering edges).
Avoid rotating pixel sprites; for spinning effects use **pre-rendered rotation frames** (PixelLab can
generate these) or accept the look only for non-pixel FX layers (particles, shaders).

Sources: [GDQuest pixel art setup Godot 4](https://www.gdquest.com/library/pixel_art_setup_godot4/) ·
[Mina Pêcheux — pixel-perfect in Godot](https://medium.com/codex/doing-pixel-perfect-in-godot-the-right-way-77cd39f8f23d) ·
[Sprite-AI Godot sprites guide](https://www.sprite-ai.art/guides/godot-sprites) ·
[Shaggy Dev project setup](https://shaggydev.com/2021/09/21/project-setup-for-pixel-art/)

---

## 7. Game feel: shaders, lighting, particles, screenshake

All of these are **CanvasItem shaders** (Godot's 2D shader type) applied via a `ShaderMaterial` on the
sprite, plus 2D lighting and particle nodes.

### Hit-flash (white) — the single most impactful game-feel shader
Tint the whole sprite white for a few frames when damaged. Drop this on a `ShaderMaterial`, then from
GDScript set `flash_amount` to 1.0 on hit and tween it back to 0.

```glsl
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4  flash_color  : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    // keep original alpha, lerp RGB toward flash color by flash_amount
    vec3 rgb = mix(tex.rgb, flash_color.rgb, flash_amount * tex.a);
    COLOR = vec4(rgb, tex.a);
}
```

```gdscript
# on taking damage:
var mat := sprite.material as ShaderMaterial
mat.set_shader_parameter("flash_amount", 1.0)
var tw := create_tween()
tw.tween_method(
    func(v): mat.set_shader_parameter("flash_amount", v),
    1.0, 0.0, 0.12)  # flash for 120ms
```

### Other CanvasItem shaders to keep in the kit
- **Outline:** sample neighboring UVs; if a transparent texel touches an opaque one, draw the outline
  color. Useful for highlighting the hovered/targeted creature or interactable.
- **Dissolve / death:** multiply alpha by a noise texture stepped against a rising `progress` uniform
  so the sprite eats away — great for creature death or item pickup.
- **Palette swap / recolor variants:** map source colors to a swap palette to spawn color variants of
  one dino (e.g. a rare "shiny") without new art. See KoBeWi's palette-swap shader.
  https://github.com/KoBeWi/Godot-Palette-Swap-Shader ·
  https://godotshaders.com/shader/palette-swap-no-recolor-recolor/
- **Water / foliage sway:** offset UV.x by `sin(TIME + VERTEX.y)` in `vertex()` for grass/leaves/water
  motion — cheap life in the world.
- Browse: https://godotshaders.com/shader-type/canvas_item/ ·
  [official CanvasItem shader docs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)

### Day/night lighting (Cravera has TimeCycle + DayNightLight)
- **`CanvasModulate`** tints the whole 2D world — drive its `color` from `TimeCycle` to shift from warm
  daylight → blue night. This is the base ambient.
- **`PointLight2D`** for the player's torch, campfires, placed `Torch` objects — give each a soft round
  light texture; let them pop against the darkened CanvasModulate at night.
- Optionally a subtle dawn/dusk warm tint pass. Keep light textures soft but the world sprites still
  nearest-filtered (light textures can be smooth; sprites stay crisp).

### Particles (GPUParticles2D / CPUParticles2D)
- **Dust** on footsteps/landing, **blood/hit spray** on damage, **sparkle** on pickups/crafting,
  **leaves** under trees, **embers** above torches at night. Use small square pixel particles (a 2x2
  white texture) so they read as part of the pixel art, not soft blobs.

### Screenshake & hitstop
- **Screenshake:** offset the Camera2D by a small decaying random vector for ~0.1–0.2s on big hits.
  Keep it tiny (1–4 px) and snap to integers so it doesn't reintroduce shimmer.
- **Hitstop (freeze frame):** on a heavy hit, set `Engine.time_scale = 0.0` (or ~0.05) for ~40–80ms via
  a timer, then restore. Pairs with the white hit-flash to make impacts feel weighty. Use sparingly —
  only on meaningful hits (boss bites, killing blows), never on every tick.

---

## How this maps to Cravera

Prioritized decisions to standardize now:

1. **Canonical sizes (highest priority).** **16x16 tiles and world objects; 32px footprint only for
   large hero dinos**, all on the same pixel grid. 30x15-tile playfield at 480x270. One PPU everywhere;
   never scale sprites by non-integers, never rotate pixel sprites off 90°.

2. **One master palette, enforced at the gate.** Adopt a 32–48 color Lospec palette (start: Resurrect
   64 / AAP-64 / Apollo) as `cravera_palette.gpl` in the repo. **Every asset — AI, pack, or hand —
   passes through an Aseprite indexed-palette quantize before it enters the game.** This is what makes
   the hybrid sources look like one game.

3. **Perspective: 3/4 view**, locked for the player and the whole dino bestiary, drawn with shared
   rules (top-left light, thick dark outline + selout, ground-shadow ellipse, hue-shifted shading).

4. **Hybrid sprite workflow to adopt:** hero assets (player, key dinos, UI) hand-authored or
   AI-drafted then hand-finished; bulk (enemy variants, props, item icons, tiles) generated with
   **Retro Diffusion** (authentic pixels) and **PixelLab** (directional 4-dir frames + consistency to
   a reference). Fixed prompt-prefix style token, pinned model+seed, reference image, generate ~20 →
   curate 1–2 → finish in Aseprite → palette-quantize → import. Keep `walk_down/up/left/right`,
   `bite_*`, `death` SpriteFrames naming for every creature.

5. **Import settings to standardize:** filter Nearest, **mipmaps OFF**, repeat Disabled, compress
   Lossless. Add `display/window/stretch/scale_mode = "integer"` to `project.godot` (snap flags and
   Nearest default are already set ✅). Camera2D at integer zoom only; if smooth scroll is wanted, move
   to a 480x270 `SubViewport` integer-upscale.

6. **Game feel kit:** ship the **white hit-flash shader** (snippet in §7) wired into the damage path,
   plus palette-swap for rare creature variants, foliage/water sway, day/night via `CanvasModulate`
   driven by `TimeCycle` + `PointLight2D` torches, square pixel particles for dust/blood/sparkle, and
   subtle (1–4px, integer-snapped) screenshake + brief hitstop on heavy hits only.
