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
