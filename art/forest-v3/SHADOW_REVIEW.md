# Lighting review

Reviewed the actual ForestPlaytest scene at dawn, noon, dusk and night; placed a torch beside a timber wall and moved an equipped lantern to each side of the barrier. Settings-off capture confirms illumination remains while shadows disable.

Three corrections in `ForestLighting.gd`:

1. Fire/torch/shrine footprints no longer occlude their own emitters, preventing erroneous triangular darkness radiating from the light itself. Their sun projections remain.
2. Artificial light energy adapts to daylight, retaining18% at noon and full intensity at night. Torch flicker retains a separately stored original base so the adjustment does not compound; carried lights follow the same daylight rule.
3. Sun projections use cached alpha contours from the actual tree and prop artwork. Finite foliage and roof silhouettes replace extruded collision rectangles; point-light occlusion continues to use grounded physical footprints. Tiny projected source flecks with degenerate geometry are filtered using triangulation validity before rendering.

These are stylized2D projections, not a3D height map or full sprite-normal lighting system. Shadows rotate/shorten with the sun, while nearby lights use Godot's native occlusion and move with the carried source.

Evidence:

- `shadows-dawn.png`, `shadows-noon.png`, `shadows-dusk.png`, `shadows-night-torch.png`.
- `shadows-lantern-left.png`, `shadows-lantern-right.png`, `shadows-shadows-disabled.png`.
- `shadow-review.log`: zero assertion failures and no engine errors after final correction.
- `root-shadow-regression.log`: root pass3,53 assertions, zero failures; no engine errors.
- Reproducible scene/capture/assertion driver: `shadow_review.gd`, run through Godot with `--no-save-playtest`.

Technical references reviewed: [Godot BitMap alpha contours](https://docs.godotengine.org/en/stable/classes/class_bitmap.html) and [LightOccluder2D](https://docs.godotengine.org/en/stable/classes/class_lightoccluder2d.html).
