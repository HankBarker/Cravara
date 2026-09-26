# The Cravera Dinosaur Factory: Blender as the animation backend (pass 12 experiment)

> **RETIRED (pass 13, 2026-09-25).** Hank's verdict on the Blender Scarhorn: "doesn't look that
> great". Improve the PixelLab and procedural process instead, and spend more care on each
> creature. The Scarhorn was redrawn with PixelLab v3 and animated with `gen.py` like the rest
> (`tools/dino/pick13.py`). The `-BlenderPreview` playtest, the `--blender-playtest` park and
> `Tests/BlenderCapture` were removed. `tools/blender/` stays on disk for reference only. Don't use
> it for game art without asking him.

Hank asked (2026-09-25) for Blender to be tried as the dinosaur animation factory: model, rig and
animate once, then render every clip from Cravera's fixed camera in every facing. The game stays
2D pixel art. The test animal is the **Scarhorn** (key `carno`, a Carnotaurus). Its playtest is
`tools/playtest_forest.ps1 -BlenderPreview`: one Scarhorn follows you, one stands beside a
PixelLab allosaur to compare, and a wild one hunts east of camp. **Hank decides from that
playtest whether to adopt the pipeline.** Until he does, the other species stay on PixelLab.

## Why
PixelLab animates each facing of each clip separately. Anatomy, markings and proportions drift
from frame to frame and facing to facing (the parasaur's front walk). A rigged 3D animal is the same
animal in every frame. A new clip is a few lines of keyframe code, and all 7 clips in 3 facings
(186 frames) render in **about 40 seconds**. PixelLab took hours for one species today.

## Pipeline
1. `blender --background --python tools/blender/dino_factory.py -- --species carno [--clips a,b] [--facings side,down,up] [--still]`
   (Blender 5.2 is at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`).
   - Builds the animal from lofted cross-sections (`SPECIES[key]`): spine, skull, jaw, legs,
     arms, horns and eyes. Subdivided once and baked.
   - Vertex colours come from position and normal: base, maroon back bands, belly, light rim,
     speckled scales, mouth, teeth, pupil.
   - Rigs it: root, pelvis/chest/neck/head/jaw, a 4-bone tail, IK legs. `ik.*` ankle targets walk
     the feet along the ground, so planted feet never slide. `foot.*` sets the foot angle and
     `pole.*` the knee.
   - Animates the `CLIPS` functions (idle, walk, run, bite, roar, hurt, death) as keyed actions.
   - Renders at `SCALE`=4 × the game's pixel size from an orthographic camera at `elevation`
     (26°), with the feet on the game's ground row. Facings turn the rig (side = +X, down = toward
     the camera). Output goes to `art/blender/<key>/raw/`.
2. `python tools/blender/pixelize.py carno [--colours 30] [--no-export]`
   - Each 4×4 block becomes one pixel: its commonest opaque colour (crisp, not blended), solid
     when 6 or more of its 16 sub-pixels are covered.
   - One palette for every frame (median cut), so colours never drift.
   - Lone pixels are dropped and a dark 1 px outline is drawn round the body.
   - Writes the game's strips and catalogue in the DinoArt format: `v2/<key>/<clip>_<facing>.png`
     and `v2/<key>.json` with `"source": "blender"` and the bite's hit frame. It also writes the
     resting drawings `art/<key>[_down|_up].png`.
3. Match `ForestCreature.BODY[key]` walk/run to the render's stride:
   `speed = stride × px_per_unit / (stance × cycle_seconds)`. For the carno that's walk 30, run 93.
4. `Tests/BlenderCapture.tscn` (rendered) shows it in the world. The wilds12 suite checks its clips.

## Look lessons (what made it read as Cravera)
- **Chunky, not realistic.** Real proportions (thin legs, a long lizard tail) vanish at 64 px.
  Deepen the body, enlarge the head, eyes and horns, and thicken the thighs.
- **Front views need width.** Scale body, head and stance widths about 1.3×: the side silhouette
  doesn't change, but the front reads as a creature, not a stick.
- **Hue-shifted toon bands.** The ramp's four bands (shadow, shade, lit, highlight) are tints, not
  greys: purple-brown shadows and warm orange highlights. This did more for the hand-made look
  than any geometry change.
- **A death that slumps.** Rolling the body flank-up read as a flat line from the low camera.
  Legs buckle, the belly drops, the neck and tail droop.

## Gotchas (each cost a render)
- **Loft winding.** Faces pointed inward (belly colour on the back, lighting from below). Recalc
  normals after building (bmesh `recalc_face_normals`).
- **Mix sockets.** Blender 5's Mix node has one socket per type under the same name, so
  `inputs["A"]` is the float one. Use `ShaderNodeVectorMath` MULTIPLY for colour × band.
- **IK pole angle.** It depends on the bone roll: −90° swung the knees sideways and back. `rig()`
  searches for the angle that keeps each knee at rest (about 30° here). Don't guess.
- **Root axes.** The root bone points up the world Z, so its own X is the world's X. Rotate about
  x to roll the whole animal.
- **Thighs hide in the body.** Hips must sit high and the knees low and forward, or only the
  shins show.

## A new species
1. Add a `SPECIES` entry: canvas, px/unit, colours, spine/head/jaw stations, horns, eye, leg,
   arm, bones and gait.
2. A quadruped needs its own leg set: fore legs, and IK for four feet, with a gait that phases the
   four legs. The clip functions are shared where the body plan matches.
3. Render, pixelize, set BODY speeds, capture.
