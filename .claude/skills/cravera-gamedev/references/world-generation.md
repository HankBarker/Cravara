# Procedural World & Biome Generation (Godot 4.6)

Reference for building Cravera's world: a 2D top-down pixel-art dinosaur survival/crafting
game. Native res 480x270, pixel-perfect. North stars: Core Keeper, Terraria, Stardew/Forager.
All APIs below are Godot 4.x (`TileMapLayer`, `FastNoiseLite`, `RandomNumberGenerator`). 3.x-only
advice is flagged inline.

---

## 1. FastNoiseLite

`FastNoiseLite` is a built-in `Resource` (extends `Noise`). It is the workhorse for heightmaps,
moisture maps, cave masks, and density fields. `get_noise_2d(x, y)` returns a float in roughly
`-1.0 .. 1.0` (gaussian-ish, not perfectly uniform — values cluster near 0).

### Enum values (Godot 4.x — verified against docs)

`noise_type`:
- `TYPE_SIMPLEX` (0) — default-recommended general terrain, fewer directional artifacts than Perlin.
- `TYPE_SIMPLEX_SMOOTH` (1) — engine default; smoother gradient.
- `TYPE_CELLULAR` (2) — Voronoi/Worley. Great for veins, cracks, biome cells, cave chambers.
- `TYPE_PERLIN` (3) — classic; slight axis-aligned bias.
- `TYPE_VALUE_CUBIC` (4), `TYPE_VALUE` (5) — blocky/low-cost.

`fractal_type`: `FRACTAL_NONE` (0), `FRACTAL_FBM` (1, default), `FRACTAL_RIDGED` (2, good for
mountain ridges/rivers), `FRACTAL_PING_PONG` (3).

### Key properties (with defaults)

| Property | Default | Notes |
|---|---|---|
| `seed` | 0 | Deterministic. Same seed+coords -> same value. |
| `frequency` | 0.01 | Lower = larger features. Tune per layer. |
| `fractal_octaves` | 5 | More octaves = more fine detail (and cost). |
| `fractal_lacunarity` | 2.0 | Frequency multiplier per octave. |
| `fractal_gain` | 0.5 | Amplitude falloff per octave. |
| `cellular_distance_function` | 0 | For `TYPE_CELLULAR`. |
| `cellular_jitter` | 1.0 | Cell randomness. |
| `domain_warp_enabled` | false | Warps sample coords for organic, swirly borders. |
| `domain_warp_amplitude` | 30.0 | |
| `offset` | (0,0,0) | Shift sample space (useful per-chunk). |

> Gotcha: `get_noise_2d()` and `NoiseTexture2D`/`get_image()` can differ — the image path applies
> normalization/remap. For gameplay logic always sample `get_noise_2d` directly; don't read pixels
> from a generated texture and expect identical values.

### Multi-layer sampling (heightmap + climate)

```gdscript
class_name WorldNoise
extends RefCounted

var elevation := FastNoiseLite.new()
var temperature := FastNoiseLite.new()
var humidity := FastNoiseLite.new()

func _init(world_seed: int) -> void:
    elevation.seed = world_seed
    elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX
    elevation.frequency = 0.004          # big continents
    elevation.fractal_octaves = 5

    temperature.seed = world_seed + 1    # decorrelate layers via seed offset
    temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX
    temperature.frequency = 0.0015       # very low: broad climate bands

    humidity.seed = world_seed + 2
    humidity.noise_type = FastNoiseLite.TYPE_SIMPLEX
    humidity.frequency = 0.0025

# Remap noise from [-1,1] to [0,1] for table lookups.
func _01(n: float) -> float:
    return (n + 1.0) * 0.5

func sample(x: int, y: int) -> Dictionary:
    return {
        "elevation": _01(elevation.get_noise_2d(x, y)),
        "temperature": _01(temperature.get_noise_2d(x, y)),
        "humidity": _01(humidity.get_noise_2d(x, y)),
    }
```

Use a different `seed` (not just `offset`) per climate layer so elevation and temperature aren't
correlated. For rivers/ridges use `FRACTAL_RIDGED`. For organic biome borders set
`domain_warp_enabled = true` on the elevation noise.

---

## 2. Biome assignment (Whittaker-style)

Real biome systems map two-or-three climate axes to a biome. A **Whittaker diagram** maps
temperature x precipitation (humidity) -> biome. Add elevation as a gate (water below sea level,
mountains/snow above a threshold). This matches the metadata the Cravera MCP already encodes
(`base_temperature`, `base_humidity` per terrain type).

```gdscript
# Returns a biome terrain_type string matching the JSON schema
# (grassland, desert, swamp, jungle, volcanic, tundra, cave).
func classify_biome(s: Dictionary) -> String:
    var e: float = s.elevation
    var t: float = s.temperature
    var h: float = s.humidity

    if e < 0.30:
        return "water"          # below sea level
    if e > 0.82:
        return "volcanic" if t > 0.6 else "tundra"   # high peaks: snow or lava
    # lowland Whittaker lookup
    if t > 0.66:
        return "jungle" if h > 0.5 else "desert"
    elif t > 0.33:
        return "swamp" if h > 0.66 else "grassland"
    else:
        return "tundra"
```

### Keeping it readable in pixel art

- **Quantize to few biomes.** 5-7 biomes total. Pixel art reads best with hard, recognizable
  palettes; don't blend 20 sub-biomes.
- **Sharp borders, not gradients.** In top-down pixel art, blend *transition tiles* (autotiling,
  Section 3) at the seam — do not interpolate colors. A 1-2 tile transition band reads as
  intentional; a wide gradient reads as mush.
- **Min biome size.** Reject biome regions smaller than N tiles (flood-fill + merge to dominant
  neighbor) so the map isn't speckled. Low climate-noise frequency (0.0015) already enforces this.
- **Majority-vote smoothing.** After classification, optionally replace each tile's biome with the
  mode of its 3x3 neighborhood once or twice to kill single-tile islands.

### Tie to Data/Biomes JSON

The MCP's `generate_biome_config` writes (exact schema):

```json
{
  "biome_name": "JungleBiome",
  "terrain_type": "jungle",
  "difficulty_level": 1,
  "metadata": { "base_temperature": "hot", "base_humidity": "humid",
                "ambient_color": "Color(0.6, 0.9, 0.5, 1.0)" },
  "creature_spawn_table": [ {"name":"Raptor","weight":10,"max_count":5,"min_level":1} ],
  "resource_nodes":       [ {"name":"Tree","scene_path":"res://...","density":10} ],
  "difficulty_parameters": { "creature_health_multiplier": 1.0, ... }
}
```

`classify_biome` returns the same `terrain_type` strings the JSON keys on. Load all
`Data/Biomes/*.json` at startup into a `Dictionary` keyed by `terrain_type`, then drive tiling,
spawn tables, and ambient light from the matched config. The string-typed `base_temperature` /
`base_humidity` ("hot"/"humid"/...) are human metadata; the *numeric* climate thresholds live in
`classify_biome`. Keep them consistent (hot -> high t band, arid -> low h band).

---

## 3. Tilemaps: TileMapLayer (NOT TileMap)

Godot 4.3+ deprecated the monolithic `TileMap` node. Use one **`TileMapLayer`** node per visual
layer (ground, cliffs, decor). 3.x and early-4.x `TileMap` + `layer` index APIs are deprecated —
do not use `tilemap.set_cell(layer, ...)`. The new per-node signatures:

```gdscript
set_cell(coords: Vector2i, source_id := -1, atlas_coords := Vector2i(-1,-1), alternative_tile := 0)
set_cells_terrain_connect(cells: Array[Vector2i], terrain_set: int, terrain: int, ignore_empty_terrains := true)
set_cells_terrain_path(path: Array[Vector2i], terrain_set: int, terrain: int, ignore_empty_terrains := true)
local_to_map(local_position: Vector2) -> Vector2i
map_to_local(map_position: Vector2i) -> Vector2   # centered position of a cell
get_cell_source_id(coords: Vector2i) -> int        # -1 if empty
```

### TileSet terrains / terrain sets / autotiling

- A **TileSet** holds one or more **terrain sets**; each terrain set holds **terrains** (e.g. one
  terrain per biome ground type). Terrains use **peering bits** — you paint, in the TileSet editor,
  which neighbors each tile expects. This is Godot's autotiling (Wang/blob).
- **Match Corners and Sides** = 47-tile blob (full 8-neighbor). **Match Sides only** = 16-tile
  (4-neighbor Wang). Use Sides-only for simple ground-vs-water borders; Corners-and-Sides for
  smooth cliff/path transitions. (3.x "Autotile" bitmask is the old equivalent — gone in 4.x.)

### Painting a TileMapLayer from a biome map (code)

Two strategies:

**A. Direct `set_cell`** — fastest, no auto-borders. Use one atlas tile per biome:

```gdscript
@onready var ground: TileMapLayer = $Ground
const SRC := 0
const BIOME_ATLAS := {
    "grassland": Vector2i(0,0), "desert": Vector2i(1,0),
    "jungle": Vector2i(2,0), "swamp": Vector2i(3,0),
    "tundra": Vector2i(4,0), "volcanic": Vector2i(5,0), "water": Vector2i(6,0),
}

func paint_region(origin: Vector2i, size: Vector2i, wn: WorldNoise) -> void:
    for ty in range(size.y):
        for tx in range(size.x):
            var c := origin + Vector2i(tx, ty)
            var biome := classify_biome(wn.sample(c.x, c.y))
            ground.set_cell(c, SRC, BIOME_ATLAS[biome])
```

**B. Terrain connect** — auto-borders between biomes. Group cells per terrain, then one call each:

```gdscript
# terrain_set 0, terrain index per biome
const BIOME_TERRAIN := {"grassland":0,"desert":1,"jungle":2,"water":3}

func paint_with_terrains(cells_by_biome: Dictionary) -> void:
    for biome in cells_by_biome:
        if BIOME_TERRAIN.has(biome):
            ground.set_cells_terrain_connect(cells_by_biome[biome], 0, BIOME_TERRAIN[biome], false)
```

`set_cells_terrain_connect` is the right tool to get clean autotiled seams between biomes — but it
is *expensive*; batch all cells of a terrain into one call, never one cell at a time.

### Multiple layers

- `$Ground` (biome floor, TileMapLayer)
- `$Cliffs` (elevation edges/walls — Core Keeper-style mineable walls; own collision)
- `$Decor` (scattered grass/flowers, painted from a high-freq density noise; usually no collision)

Order layers in the scene tree (and via `z_index` / `y_sort_enabled` for top-down depth). Resource
*objects* (trees, rocks, chests) stay as instanced scenes (current `ResourceSpawner` approach), not
tiles — keep them in a `Node2D` container with `y_sort_enabled` for correct overlap.

---

## 4. World structure: finite vs chunked vs infinite

How the north-star games actually do it:

- **Stardew Valley** — fully **hand-authored static maps**. ConcernedApe abandoned procedural mines
  as "too ambitious." Not procedural at all.
- **Terraria** — one **large finite 2D tile world**, fully generated up-front from a seed (biomes,
  ores, caverns, chests) then saved. World stays in memory/save; not streamed in chunks.
- **Core Keeper** — **chunk grid, generated/streamed on demand** as players mine outward from the
  Core. Deterministic from seed; Voronoi for chasms, convolution for biome borders; per-chunk
  structure rolls from weighted scene lists. This is the closest model to Cravera's wall-mining
  fantasy.

| Model | Pros | Cons | Fits Cravera? |
|---|---|---|---|
| **Fixed finite** (current) | Simple, fully knowable, easy save (just object list), no streaming bugs | Bounded exploration; whole world in memory; big maps stutter on gen | Good for a v1 / demo island |
| **Chunked streaming** | "Endless" feel, constant memory, scales | Seams, save complexity (dirty-chunk tracking), per-chunk determinism needed | Best long-term fit (Core Keeper model) |
| **True infinite** | Never hits a wall | Float precision drift far from origin; hard to balance/curate | Overkill; avoid |

**Recommendation for Cravera:** keep the current **fixed finite map for v1** (it already works and
the rect is small), but architect generation *as if chunked* — generate by tile coords through a
seeded noise field, so moving to streaming later is a loop change, not a rewrite. Adopt **chunked
streaming** when the map needs to exceed comfortable in-memory size.

### Chunk load/unload sketch

```gdscript
const CHUNK := 32                    # tiles per chunk side
var loaded: Dictionary = {}          # Vector2i chunk_coord -> Node

func _process(_dt: float) -> void:
    var pc := world_to_chunk(player.global_position)
    var wanted := {}
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            wanted[pc + Vector2i(dx, dy)] = true
    for c in wanted:
        if not loaded.has(c):
            loaded[c] = generate_chunk(c)     # paint tiles + spawn objects
    for c in loaded.keys():
        if not wanted.has(c):
            save_dirty(c)                     # persist player edits
            loaded[c].queue_free()
            loaded.erase(c)
```

Only **dirty** chunks (player mined/built/picked-up) need saving; pristine chunks regenerate
identically from the seed (Section 6).

---

## 5. Object/resource distribution (upgrade the rejection sampler)

Current `ResourceSpawner` does **uniform random + min-distance rejection** (`randf_range` then
reject if within `min_distance`). It works but: (a) not deterministic (`randf_range` uses global
RNG), (b) O(n^2) distance checks against a growing list, (c) clumpy/uneven because uniform random
isn't blue-noise.

### Poisson-disk (Bridson) — even spacing, blue noise

Bridson's algorithm gives evenly-spaced-but-random points (no two closer than `radius`) in O(n)
using a background grid. Ideal for trees/rocks scattered naturally.

```gdscript
# Deterministic Bridson Poisson-disk sampling in a rect.
static func poisson_disk(size: Vector2, radius: float, rng: RandomNumberGenerator,
                         k := 30) -> Array[Vector2]:
    var cell := radius / sqrt(2.0)
    var gw := int(ceil(size.x / cell))
    var gh := int(ceil(size.y / cell))
    var grid := {}                      # Vector2i -> Vector2 (point)
    var points: Array[Vector2] = []
    var active: Array[Vector2] = []

    var first := Vector2(rng.randf() * size.x, rng.randf() * size.y)
    _insert(first, grid, cell); points.append(first); active.append(first)

    while not active.is_empty():
        var i := rng.randi() % active.size()
        var p := active[i]
        var found := false
        for _n in range(k):
            var ang := rng.randf() * TAU
            var rad := radius * (1.0 + rng.randf())     # ring r..2r
            var cand := p + Vector2(cos(ang), sin(ang)) * rad
            if cand.x < 0 or cand.y < 0 or cand.x >= size.x or cand.y >= size.y:
                continue
            if _far_enough(cand, grid, cell, radius):
                _insert(cand, grid, cell); points.append(cand); active.append(cand)
                found = true
                break
        if not found:
            active.remove_at(i)
    return points

static func _insert(p: Vector2, grid: Dictionary, cell: float) -> void:
    grid[Vector2i(int(p.x / cell), int(p.y / cell))] = p

static func _far_enough(p: Vector2, grid: Dictionary, cell: float, radius: float) -> bool:
    var gx := int(p.x / cell); var gy := int(p.y / cell)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            var q = grid.get(Vector2i(gx + dx, gy + dy))
            if q != null and p.distance_to(q) < radius:
                return false
    return true
```

This replaces the entire `while spawned_count < total` loop — and it's deterministic given a seeded
`RandomNumberGenerator`.

### Density maps from noise (vary radius / accept probability)

Multiply by a low-freq density noise so groves and clearings emerge instead of uniform coverage:

```gdscript
func keep_point(p: Vector2, density: FastNoiseLite, rng: RandomNumberGenerator) -> bool:
    var d := (density.get_noise_2d(p.x, p.y) + 1.0) * 0.5   # 0..1 density
    return rng.randf() < d                                   # thin out low-density areas
```

### Clustering: ore veins & tree groves

For veins/groves, use **`TYPE_CELLULAR`** noise thresholded high (only cell centers pass), or scatter
a few "seed" points then add a small random cluster around each. Core Keeper uses Voronoi for chasms
the same way.

### Biome-gated weighted spawn tables (matches existing schema)

Honor `resource_nodes[].density` and `creature_spawn_table[].weight` / `max_count`:

```gdscript
func pick_weighted(table: Array, rng: RandomNumberGenerator) -> Dictionary:
    var total := 0
    for e in table: total += e.weight
    var r := rng.randi_range(1, total)
    for e in table:
        r -= e.weight
        if r <= 0: return e
    return table.back()

func spawn_resources_for(biome: String, points: Array[Vector2],
                         cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var table: Array = cfg[biome].resource_nodes
    for p in points:
        if classify_biome(world_noise.sample(int(p.x), int(p.y))) != biome:
            continue                                 # biome gate
        var node = pick_weighted_by_density(table, rng)
        # respect density: higher density -> higher accept chance
        if rng.randf() < float(node.density) / 20.0:
            spawn(node.scene_path, p)
```

### Avoiding water / edges

Gate on the **same noise field** used for tiles, not a hardcoded box. The current code's
`if pos.x > 2300 and pos.y > 2300` water check is a magic-number hack — replace with
`if sample(p).elevation < 0.30: reject`. Edge buffer can stay, or derive from chunk bounds.

---

## 6. Determinism & seeds

Determinism = same world seed reproduces the same world (so unmodified chunks regenerate for free,
and seeds are shareable like Terraria/Core Keeper).

- **One `world_seed: int`** stored in the save. Feed it to every `FastNoiseLite.seed`
  (with per-layer offsets) and to `RandomNumberGenerator`.
- **Use `RandomNumberGenerator`, never global `randf()`/`randi()`** for world gen. The global RNG is
  shared and not reproducible. The current `ResourceSpawner` uses `randf_range`/`pick_random` —
  swap to a seeded `RandomNumberGenerator`.
- **Per-chunk RNG:** derive a stable sub-seed from world seed + chunk coords so each chunk is
  independent of generation order:

```gdscript
func rng_for_chunk(world_seed: int, c: Vector2i) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(Vector3i(world_seed, c.x, c.y))   # stable, order-independent
    return rng
```

- **Save = seed + diffs.** Persist `world_seed` plus only player modifications (mined walls, placed
  buildings, depleted nodes) per chunk. Regenerate everything else. This is far smaller than saving
  every tile, and matches Core Keeper. The current `get_resource_positions()`/`load_resource_positions()`
  pattern (saving the full position list) becomes unnecessary once gen is deterministic.

---

## 7. Decoration & ambiance

- **Scatter/decor layer.** A separate high-frequency density noise drives `$Decor` tiles or tiny
  scene scatters (grass tufts, pebbles, bones). Keep them non-colliding and `y_sort`-ed.
- **Depth in top-down.** Use `y_sort_enabled` on object containers so things lower on screen draw in
  front. For background depth, a subtle `Parallax2D` (Godot 4.x replacement for `ParallaxBackground`)
  layer for far terrain/fog. Don't parallax the gameplay plane — it breaks tile alignment.
- **Biome transitions.** Let autotiled terrains (Section 3) handle the visual seam; additionally
  scatter "edge" decor (e.g. dead grass between grassland and desert) in a 2-3 tile band detected by
  "neighbor biome differs."
- **Ambient color per biome.** The JSON `metadata.ambient_color` already exists — drive a
  `CanvasModulate` or per-biome light tint from the biome under the player, lerping on biome change.
  Combine with the existing `TimeCycle` day/night autoload (multiply biome tint x time-of-day tint).
- **Paths & rivers.** Rivers: threshold a `FRACTAL_RIDGED` noise band near 0, carve to water tile,
  follow downhill (elevation gradient). Paths: `set_cells_terrain_path` along a route (e.g. between
  points of interest) for a clean autotiled trail.

---

## 8. The forest as it ships (2026-09)

The forest is a finite, seeded 112x112-cell map (now the western half of a 224x112 world: see the Bonelands below) (`Forest/ForestWorld.gd`, `EXTENT = 56`, 16px cells,
seed 726151). `_generate()` draws terrain from one FastNoiseLite plus a seeded RNG (river, lake,
paths, moss, outcrops, a jittered 4-cell grid of trees/rocks/bushes/ferns, the authored camp), and
saves are **diffs against the seed** (`mined`, `placed`, `water_edits`, `floors`, `roofs`, `doors`,
`chests`, `damage`, `caches`). `restore()` regenerates, then replays the diffs.

**The ground picture** (`Forest/ground/`, a look only; `terrain` stays the gameplay truth):
- `ForestGround.gd` writes one texel per cell (`r` kind: 0 grass, 1 dirt, 2 water, 3 moss, 4 sand,
  5 tilled soil, 6 flagstones; `g` water depth; `b` flags river/wet) and bakes two SubViewports
  once per edit: `ground_bake.gdshader` (organic region edges from bilinear cell weights + per-kind
  noise wobble, grass lips and shadows over paths, earth banks above water, dithered moss seams,
  furrowed soil, running-bond flagstones, detail stamps from `art/stamps.png`) and
  `water_field.gdshader` (shore distance + depth) that the live `water.gdshader` animates (depth
  bands, caustics, drifting glints, foam, stepped at 10fps). After any terrain/water/soil edit call
  `surface.rebuild()`; `ForestWorld` does for its own edits.
- Visual-only layers on the world: `ground_style` (cell -> `"sand"` along noisy stretches of shore,
  `"stone"` flagstones in an oval under paved ruins) and `tilled` (Gardening's `_sync_soil` ->
  `set_soil`).
- `ForestFlora.gd`: one MultiMesh of swaying tufts/blossoms (`flora.gdshader`, ~8k instances,
  scattered by hash so it needs no saving), hidden on water, floors, tilled beds and any prop's
  cell; the keeper and nearby creatures bend it. Props sway via `sway.gdshader` (`ForestProp.SWAY`).
- Art: `tools/world/make_ground_art.py` cuts stamps and flora from the craftpix packs in
  `assets_raw`. Shader gotcha: a `const` may not shadow a built-in (`LIGHT`), hence `W_*` names.

**Points of interest** (`ForestWorld.SITES`, placed by `_place_points_of_interest()` at the end of
`_generate()`): seven sites (Star Temple, Old Watchtower, Hall of the First Builders, Moot Circle,
Grove Shrine, Wolf Idol, Fallen Stones), each a main ruin/idol (`ForestProp.LANDMARKS`, solid at the
base, never dismantled), companion pieces (`_find_beside`: framing offsets, then rings out to 9
cells), an ancient `cache` (opens once with E; loot `world/Loot.gd`, always 2-5 `ancient_coin`),
relic mounds and meadow `roots` (dig with the garden hoe: `is_dig_spot`/`dig_at`, remembered in
`mined`). Carvings: `lore_at[cell]` -> `world/Lore.gd` id; E opens the session's `show_lore`, the
journal lists them (milestones `lore_<id>`; `cache` and `valuable` when coins turn up, the
merchant's cue). Rules that keep old saves safe, enforced by `Tests/world_poi_suite.gd`:
- Placement is deterministic and draws no RNG before the seeded props (hashes and noise only).
- No POI prop sits on a cell that held a seeded prop, so no saved `mined`/`damage` can hit one;
  only brush in a ruin's footprint is cleared. Sites keep >= 18 cells from spawn, >= 8 from the
  shrine/tribe camp, >= 14 from each other, and every find stays <= `EXTENT - 5` from the centre.
- The suite loads both recorded old journeys (`art/forest-pass4`, `art/forest-pass6`) and, read
  only, the player's own pre-POI save, and checks none of their edits lands on a POI.
- New items: `tools/world/make_items.py` (Raven icons) writes `ancient_coin`, `sky_idol`,
  `fossil_bone`, `wild_tuber`, `baked_tuber` (.tres; campfire recipe in `CraftingManager`). POI art:
  `tools/world/make_poi_art.py` -> `Forest/art/poi/`.

**The Bonelands (pass 10): the world doubled east.** `BOUNDS = Rect2i(-56,-56,224,112)`,
`BONELANDS = Rect2i(56,-56,112,112)`; ask `world.bounds()`, `region_of(c)` ("forest"/"bonelands")
and `on_edge(c)` (the outer wall ring: never mined or built on, "The wilds go on beyond here, one
day.") instead of `EXTENT`. `_generate_bonelands()` runs **after everything else, from its own RNG
and noise** (`world_seed ^ 0x5B0E`; even its props' art variants, which `_spawn_prop` draws from
`rng`, come from a swapped-in stream, `^ 0x5B0F`, so the forest's generator ends where it always
did and the Bonelands don't shift when the forest's ruins change: world_poi_suite's pre-POI world
caught that), so the forest's original square stays cell for cell what old saves expect: `Tests/legacy_world_signature.gd` hashes it for three seeds against
`Tests/fixtures/legacy_world_signature.json` (the bonelands suite checks it every run). It takes
down the forest's east wall (x = 55), lays a dry wash (terrain 1) winding east, waterholes
(terrain 2) where the noise is low, outcrops of wall and crystal (`ore` 28%) where it's high, sand
`ground_style` fading in over the first 10 columns (green stays round the water), then scatters on a
5-cell grid: trees, bushes and ferns on the green; boulders, `bone_pile` (decor) and `relic` mounds
on the sand; cattails by the water. Stone there is **sandstone**: `ForestProp.sandstone` (set in
`_spawn_prop` for wall/ore/rock inside `BONELANDS`) swaps in `art/bonelands/sand_*.png`, recoloured
from the mossy originals by `tools/world/make_bonelands_art.py` (exact colour map; crystal blues
kept so a vein still reads as a vein). Everything sized to the world uses the bounds: the ground
bake (`ForestGround.origin/cells`, shaders take `ivec2 canvas_px/world_offset`, the terrain include
`ivec2 map_size/map_origin`), the map overlay, the creature leash (`_outside_world`). Hand-authored
for now; once there are three or four regions they can be generated outward (Hank's plan). Suite:
`Tests/BonelandsSuite.tscn` (legacy signature, determinism, bounds, open seam and walkable reach,
edge ring, sandstone, wash/waterholes/fade, scatter, wildlife, an old journey gaining the new
wildlife once). Look: `Tests/BonelandsLookCapture.tscn` -> `art/world-v2/bonelands-*.png`.

**The wilds (pass 11): three new regions round the old map.** `BOUNDS = Rect2i(-168,-140,336,276)`
(92,736 cells, ~3.7x pass 10). `GLASSMERE = Rect2i(-168,-56,112,112)` (west),
`PALE_HILLS = Rect2i(-168,-140,336,84)` (the whole north), `DUNES = Rect2i(-168,56,336,80)` (the whole
south); `OLD_BOUNDS = Rect2i(-56,-56,224,112)` is the pass-10 map, and the Bonelands keep their east
rim via `_old_edge`. `region_of(c)` answers forest/bonelands/glassmere/pale_hills/dunes;
`Forest/world/Regions.gd` holds names, a one-line blurb (the first-visit banner) and map colours.
`Forest/world/WildsGen.gd` runs **after** the forest and the Bonelands with its own RNG swapped into
`w.rng` (`world_seed ^ 0x7711`), so both old squares stay cell for cell (the legacy signature now
covers the forest interior `Rect2i(-54,-54,108,109)` and the Bonelands interior
`Rect2i(56,-54,111,109)`, POIs filtered to each area; fixture in `Tests/fixtures/`).
- **Glassmere:** an ellipse lake round `lake_centre (-116,-2)` with four islands; a BFS from the
  shore gives each water cell its depth, and depth >= 3 is `w.deep` (a StaticBody2D on layer 32:
  walkers' masks include 32; the keeper drops it while boating and takes layer 64, the shore, so a
  boat can't sail onto land). The piranha bay (`w.piranha`, `w.piranha_bay`) is the shallows of the
  south-east shore. Beaches, the Fishers' Shrine (lore `glass_isle`), lily pads, reeds, clam beds.
- **Pale Hills:** a winding road (`road_y(x)`), ponds, chalk outcrops (`ForestProp.chalk` swaps
  `art/pass11/chalk_*` like sandstone), 12 `pale_crystal` (power 2), pines and birches, the Last
  Keeper's Camp (E: lore `keeper_journal`) and the Pale Waystone (lore `pale_road`).
- **Dunes:** oases, sandstone, sand fading in over 9 rows, cacti (fruit), dead trees, bone heaps,
  relics, mesas, the Ossuary (`w.ossuary`, the second boss's ring) and the Kingstone to its west
  (lore `buried_king`, which unlocks the Grave Horn recipe).
- `_open_seams()` takes the old rim's walls/ore off rows y=-56,-55,55 and columns x=-56,-55.
- Nests (`Forest/world/Nesting.gd`) are placed after all of it from `world_seed ^ 0x4E57`.
- Pass 13 ore veins and far crystal (`Forest/world/Minerals.gd`) come last, from `world_seed ^ 0x0E5E`
  for the cells and `^ 0x0E5F` swapped into `world.rng` for the art variants.
- **Every post-pass that calls `_spawn_prop` must swap its own RNG into `world.rng`** (and put the
  forest's back): `_spawn_prop` draws `variant` from `world.rng`. Minerals first used a private RNG
  for its cells only, so its 380 props' variants shifted with whatever the ruins drew before them
  (`Tests/WorldPOISuite.tscn`, which regenerates the world without ruins, caught it).

**Rendering a world this size** (pass 11; 11,000 props and ~180 beasts at ~11 ms):
- `ForestGround` bakes the ground in 32-cell chunks near the view (`BAKES_PER_FRAME 2`,
  `MARGIN 320` px ahead, dropped past `KEEP 900`); `rebuild_cells(cells)` re-bakes the chunks an
  edit touches.
- `ForestFlora` is a Node2D of per-chunk MultiMesh patches (`refresh_cells`).
- `ForestWorld._cull_props()` hides props in 16-cell squares outside the view plus `CULL_MARGIN 420`
  (every 0.25 s): the renderer walks every *visible* CanvasItem each frame, so hiding far props is
  what keeps the frame cheap.
- Lighting and the workbench scan look at a window of cells round the keeper only.
- Creatures: see dinosaurs.md "Performance (pass 11)".

**Review tools.** `res://Tests/WorldLookCapture.tscn` (rendered) shoots the camp, trail, ford, river,
lake, shore, moss, tribe camp, every POI and every carved companion piece to
`art/world-v2/look-*.png`, then benchmarks a busy meadow **with vsync off** (otherwise it only
measures the monitor's refresh: this machine has 59Hz and 165Hz displays).

---

## How this maps to Cravera

Prioritized, concrete upgrades.

**P0 — Make generation deterministic & noise-driven (highest leverage).**
1. Add a `WorldNoise` helper (Section 1) seeded from a single stored `world_seed`. Replace
   `ResourceSpawner`'s `randf_range`/`pick_random` with a seeded `RandomNumberGenerator`. This alone
   makes worlds reproducible and shareable.
2. Replace the magic-number water check (`pos.x > 2300 and pos.y > 2300`) with an elevation-noise
   gate (`sample(p).elevation < 0.30`). Replace `is_position_valid`'s O(n^2) min-distance loop with
   the **Poisson-disk sampler** (Section 5) — even, blue-noise scatter in one deterministic pass.

**P1 — Wire the biome JSON pipeline into actual generation.**
3. Load all `Data/Biomes/*.json` (the MCP `generate_biome_config` schema) into a `Dictionary` keyed
   by `terrain_type`. Implement `classify_biome` (Section 2) using elevation+temperature+humidity.
   Drive (a) ground `TileMapLayer` painting, (b) per-biome weighted spawn using the existing
   `resource_nodes.density` and `creature_spawn_table.weight/max_count` fields, (c) ambient tint from
   `metadata.ambient_color` combined with `TimeCycle`.
4. Build a proper `TileMapLayer` ground layer with a TileSet **terrain set** (Section 3) and paint it
   from the biome map via `set_cells_terrain_connect` for clean autotiled biome borders. Add `$Cliffs`
   and `$Decor` layers. Keep resource objects as instanced scenes under a `y_sort`-ed `Node2D`.

**P2 — Recommended world model & scaling.**
5. Keep the **fixed finite map for v1** but generate it through tile-coord noise sampling (chunk-ready
   architecture), and save **seed + diffs** instead of the full position list. When the map needs to
   grow beyond comfortable memory, switch to **chunked streaming** (Section 4, Core Keeper model) —
   per-chunk RNG from `hash(world_seed, cx, cy)`, load 3x3 around the player, save only dirty chunks.
   Cellular/Voronoi noise for ore veins and chasms; ridged noise for rivers.

### Sources
- [FastNoiseLite — Godot docs](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)
- [Noise — Godot docs](https://docs.godotengine.org/en/stable/classes/class_noise.html)
- [TileMapLayer — Godot docs](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)
- [Setting up auto-tile with the Terrains feature](https://uhiyama-lab.com/en/notes/godot/terrains-autotile-setup/)
- [Godot forum: set_cells_terrain_connect usage](https://forum.godotengine.org/t/how-do-i-use-set-cells-terrain-connect/92925)
- [Bridson "Fast Poisson Disk Sampling in Arbitrary Dimensions" — GDScript impl (udit)](https://github.com/udit/poisson-disc-sampling)
- [Heightmap-based procedural world map — GDQuest](https://www.gdquest.com/tutorial/godot/pcg/world-map/)
- [Procedural generation patterns in Godot 4 — Ziva](https://ziva.sh/blogs/godot-procedural-generation)
- [Core Keeper world generation — Core Keeper Wiki](https://corekeeper.atma.gg/en/World)
- [Terraria world generation — tModLoader / Terraria Wiki](https://hackmd.io/@tModLoader/HJUiVKXzu)
- [Stardew Valley uses hand-authored maps — GamesRadar](https://www.gamesradar.com/games/simulation/stardew-valley-creator-wanted-the-mines-to-be-like-terraria-but-it-was-way-too-ambitious-in-the-end-should-have-been-an-entire-game-on-its-own/)

## Pass 12: the bog, the barren dunes, the ashen Pale Lands, villages (Hank's direction)
See `vision.md` for why.

- **Glassmere → the Mirefen Bog** (region id still `glassmere`). `WildsGen._glassmere()` keeps a
  dark central mere (`e < 0.86`: deep water, so the boat and Old Maw keep working).
  - A marsh ring (`e < 1.4`) holds black pools (pool noise < −0.24) and mud flats
    (`ground_style "mud"`, drawn as dirt). Mud replaces the beaches.
  - Props: reeds and cattails at the water's edge, dead and bog trees, ferns and toadstools, lily
    pads on 30% of still water, clams by the mere's isles. No palms.
  - Shaders take a `bog_area` uniform (fading in over the easternmost 12 columns): the water goes
    peaty green-brown (`water.gdshader`) and the ground dark olive with black mud
    (`ground_bake.gdshader`).
- **The Sunscar Dunes, barren.**
  - `ground_style "hardpan"` (bare dirt) flats break through the sand deeper in (badlands noise
    > 0.34).
  - The props lean to rock, dead trees, bone piles and mesas; the oases' green edges are sparse.
  - The flora on sand is mostly bare: a few sprigs and dry scrub (`ForestFlora._scatter`).
- **The Pale Hills → the Pale Lands.** They are pale with ash from the mountain beyond (Embercrack
  Ridge, to come).
  - Ground: the `pale_area` blend in the ground shader is ash-grey with dark cinder specks.
  - Grass: the flora shader greys it dead (`pale_area` there too).
  - Trees and brush: `ForestProp.ashen` draws them with `fx/ashen.gdshader`, grey and dusted pale
    on top, and still (no sway).
  - The edge text points north to the smouldering mountain.
- **Region air** (`fx/RegionAir.gd`, presets `ash` and `mire`, one node each on the session):
  - **Grade.** A screen grade on CanvasLayer 5 under the HUD (`fx/region_grade.gdshader`):
    desaturate toward the air's tint, a haze thickening up the screen and darkening with night, and
    in the Pale Lands the mountain's orange glow on the northern edge after dark. It strengthens
    with depth into the region.
  - **Particles:** ash and embers, or soft mist puffs (a radial gradient texture; untextured
    particles draw squares), plus fireflies at night.
  - **The ash hush:** `Ambience.hush` fades the insects out and pitches the wind down, the music is
    ducked, and the mountain rumbles now and then.
  - **First visit** (milestone `pale_dread`): a synthesised toll (`tools/audio/make_pale_audio.py`),
    a pitched-down roar, and a warning about the ash.
- **The keeper's ash** (`ForestPlayer.ash`) fills over 70 s in the Pale Lands, reduced by
  `ash_guard`:
  - Sail-skin Veil 0.6, Sunward wraps 0.5, Ashmane Mantle or a tamed Ashmane 1.0.
  - It clears under a roof or by a tent (`world.sheltered_at`) and outside the region.
  - Full: CHOKING (−2 hp every 1.25 s) and slower. The HUD row reads "ASH n%".
- **Villages:** `WildsGen._villages()` lays the Sunward oasis and the Ashen war camp from their
  own RNG, lists them in `world.villages` and marks them on the map (teal and red).

## Pass 15: ring worlds, micro places, caves (Hank: "like Core Keeper... randomized in placement")

- **Two layouts** (`world/Layout.gd`), picked per journey and saved (`world.layout_kind`,
  `world_seed`):
  - **legacy**: the fixed boxes every journey before pass 15 was made in (seed 726151). Never
    change what it generates: old saves' edits are stored against it. `Tests/legacy_world_signature.gd`
    hashes the forest and Bonelands squares against `Tests/fixtures/legacy_world_signature.json`;
    `world_poi_suite` checks the match. A new prop kind placed by a post-pass (nests, veins, seams,
    wild crops, cave mouths...) must go in the signature's `ADDED` list.
  - **rings**: every new journey (the menu sets a random seed; tests use `--rings SEED`). 420x420
    cells: the plains inside `PLAINS` 76 (the edge wanders per angle via a LUT), the bog and the
    dunes facing each other out to `MIDDLE` 150, the Pale Lands and Bonelands beyond; lands turned
    by the seed, borders bent by warp noise. A per-cell land grid and a from_inner cache are built
    once (~180 ms); `land_index(c)` and `from_inner(c)` are array reads.
- `world/RingsGen.gd` lays each land (plains -> mirefen -> dunes -> pale -> bonelands -> rim ->
  villages -> red meadow, haven, oases -> ruins). Every step swaps in its own RNG, so a land's
  content doesn't shift when another land changes.
- **Micro places** (`world.micro` cell -> index into `MICRO`, `micro_at` name -> centre): the red
  meadow, Stillwater haven (a village; hunters won't enter: `ForestCreature.in_haven`), oases.
- **The land map texture** (`ForestGround._land_map`, one texel a cell over `render_bounds()`):
  r = land index (5 = caves), g = cells in from the land's inner edge, b = micro index. The ground
  bake, water and flora shaders read it (`land_of`, `micro_of` helpers) for the bog murk, ash,
  crimson grass and the cave floor. Built from a PackedByteArray in one pass.
- **Caves** (`world/Caves.gd`): two per land (`PLAN`), kinds hollow / warren / grotto / explorer /
  lair. Insides are carved into a strip of cells east of `bounds()` (`render_bounds()` includes it;
  `region_of` returns "caves" there; `deep_rock` is never breakable). Each cave carves with its own
  RNG (`world_seed ^ hash(id)`) before its mouth is placed; a mouth needs open ground in its land (a
  ring world may clear scrub round it, a legacy world never clears seeded props). E at the mouth /
  the shaft travels (`ForestPlaytest.cave_travel`). `world/CaveLife.gd` peoples them once a journey
  (skip caves with no mouth).
- **Big hunters are spread** in a new ring world (`ForestPlaytest._spread_hunters`: rex, carno, allo,
  yuty, spino at least 480 px apart, each moved within its own land). The wildlife tables still place
  by the old world's compass arcs, which put three allosaurs, the carno and a rex on one another's
  ground in the dunes: endless rival fights, each run at full rate far off (~1 ms a frame).
- **Frame cost** (PerfProbe, same hour): a ring world averaged ~1.3x the old world's frame time
  (~17-19 ms against ~12-15 ms), worst at the villages (21-24 ms). Not one hotspot: denser content
  (27k props against 15k, 64k nodes against 37k) and more beasts near the villages. Next: profile in
  the editor.
- **Boot cost** (ring world, `--gen-timing`): generation ~2.9 s (the Pale Lands and Bonelands spawn
  ~15k of the ~23k props; each prop node costs ~100 us), ground 0.5 s, flora 1.1 s. `Forest/Boot.gd`
  pumps window events between steps so Windows doesn't flag "Not Responding"; input is held off
  with `get_tree().root.gui_disable_input` until the boot frame ends.
