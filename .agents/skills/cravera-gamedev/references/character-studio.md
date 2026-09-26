# Character wardrobe workflow (2026-09-21)

The latest user explicitly requested PixelLab MCP/API for an autonomous character-editor
and modular-armor upgrade. This supersedes the earlier image-first approval gates below
for this pass. Read live `get_balance`; the old 40-generation trial note is stale.
The verified account began this pass with 2,000 subscription generations. Multi-image
`edit_image` batches cost 20 generations each in this run; always recheck current pricing.

Runtime: `EquipmentSkin.gd` bakes `WardrobeArt.gd` head/chest/legs/hair PNG layers into
each original cel. Item-ID cache keys are essential in both regular and mounted skins.
Head art uses `head_origin`, exact `head_rows` and `head_facing` (idle glances); feet map
to actual foot-column bottoms. Hair recoloring must stay inside the head silhouette,
especially on upward-facing raised-hand actions. Helmet scalp underlay prevents original
hair leaking through generated art. Keep the selected face and skin pixels visible.

Art sources and generation ledger: `art/character-pass7/PROVENANCE.md`; reproducible
integer registration/palette extraction: `tools/wardrobe_pass7_import.py`; layered Aseprite
sources: `game/Forest/equipment/art/wardrobe/wardrobe_{direction}.aseprite`.
64px edit requests enlarged the leather body; a 32px cropped input fixed proportions.
Never assume prompt-based pose preservation: inspect every direction at native scale.

Wardrobe previews in `CharacterCreator.gd` never grant gear or save preview pieces.
Only normalized appearance persists. Real new armor is crafted/equipped through existing
ItemDB/inventory systems. Tests: WardrobePass7, WardrobeEditorPass7, WardrobeSavePass7,
WardrobeWorldPass7 and the expanded CharacterPass6 attachment suite. Tests always use
`--no-save-playtest`; current-save snapshot is separate from old legacy fixtures.

# Historical Codex character workflow (2026-09-08)

Current user preference supersedes the older PixelLab-first recipes: use built-in ChatGPT
image generation for design and individual poses, Aseprite for cleanup and assembly, and
PixelLab only if needed. Inspect actual Rex assets as style references. User approves design
before animation; animation approval is separate from concept approval.

Local review app: `python tools/character_studio.py serve` → http://127.0.0.1:18765.
Implementation/workflow guide: `tools/character_studio_web/README.md`.
Project data: `art/character-studio/<id>/character.json`. Read the request queue before acting.
The app does not autonomously call ChatGPT. Execute generation in the active Codex task.

The new raptor-v2 concept is lean, slate-blue/teal, ivory underneath with rust markings.
The user explicitly approved this revised design and requested a six-frame walk test.
The complete current 21-clip raptor was approved for gameplay integration on 2026-09-14. The rebuilt front/rear run uses 16 frames at 24 FPS; approved side runs retain 16 frames at 25 FPS.
Do not infer future animation approval from concept approval. The current Raptor.tscn uses the approved CharacterStudio export; earlier artwork is preserved on disk.

Godot/Aseprite MCP servers are configured in `.codex/config.toml`; when unavailable as session
tools, `tools/character_studio_probe.py` can connect directly using the Python MCP client.
Verified 12 Godot tools and 116 Aseprite tools; the Aseprite PixelLab extension emits startup
dialog warnings but core batch operations work. Do not print credentials from configuration.

Image generation can return a painted checkerboard without alpha. Inspect PNG alpha, not the
visual checker pattern. Magenta backgrounds plus Aseprite key extraction worked. Convert a
background layer to a normal layer before saving alpha. Use `character_studio_prepare.lua`
for fixed-canvas six-frame preparation; no per-frame recentering. This version is specific to
1536x1024 source frames and makes a 96x64 trial sprite (16:1 nearest sampling).

Keep the bipedal anatomy. A lion template or remapping arms into a tail is not a dependable
raptor rig. Independent generated poses may confuse near/far legs even with strong prompts.
Inspect complete playback, foot placement and wraparound before calling the walk finished.
Resource parsing tests do not certify visual quality or combat timing.


## Revision 3 lessons (2026-09-11)

Character metadata and versioned review folders are the current source of truth. The Studio now contains 21 clips. `refinement-r3` revises front/rear running, rear walking, and the four claw lunges. Directional movement uses 20 frames at 25fps; side cycles remain unchanged.

Do not sort unrelated generated poses by foot depth and assume a smooth gait: this can switch body shape and tail silhouette every frame. `character_studio_stable_gait.lua` uses consistent artwork and controlled full-leg motion for the problem directions. This remains a visual candidate, not a universally applicable rig.

Generated sheets may have wrong row/column counts, gradient backgrounds, and poses crossing cell boundaries. Inspect them before extraction. `character_studio_sheet.lua` labels connected sprite artwork and extracts with transparent margins at unchanged pixel scale. `character_studio_assemble.lua` handles native assembly and mirroring. Inspect anatomy and playback independently of technical audits. Prior user feedback values 1x review at 20-25 FPS and both-claw forward lunges instead of single-arm swipes.

## Game integration (2026-09-14)

Raptor.tscn points to the versioned 21-clip, 292-frame SpriteFrames export. raptor.gd selects idle/walk/run by movement speed, locks bite/claw-lunge through completion, checks physical player contact during active frames once per attack, and waits for the complete death clip before cleanup. No global speed scaling changes the approved frame rates. Empty navigation maps fall back to direct steering.

Launch tools/playtest_raptor.ps1 for the interactive isolated test scene. R respawns, T provokes chase, F follows, B bites, L lunges, K kills, WASD moves the real player. SaveManager disables persistence in that scene and with --no-save-playtest. Automated verification: launch res://Tests/RaptorPlaytest.tscn with -- --no-save-playtest --verify-raptor. It checks direction selection, rates, all attack clips/windows, real bite/lunge damage, interruption, chase/follow and death completion. Rendered suite evidence is art/character-studio/raptor-v2/integration-test.log and in-game-playtest.png. Godot reports shutdown resource-leak warnings also seen in playground smoke testing; runtime integration assertions pass.

## Direction scale correction (2026-09-14)

The gameplay scene now uses CharacterStudio/raptor-v2-grounded/frames.tres. Approved Studio sources remain untouched. Vertical clips are baked at two-thirds scale (idle_down at0.6), side art remains native scale; all292frames use112x80canvas with one fixed ground offset per clip, preserving authored foot motion. Aseprite recipe: tools/character_studio_game_scale.lua with art/character-studio/raptor-v2/game-scale-jobs.lua. Never scale each frame by its own bounds. Direction turns preserve normalized stride progress; facing uses20percent axis hysteresis. The interactive test C key previews the entire raptor at80percent; this is optional and not the main-game default. Comparison captures: direction-scale-before.png and direction-scale-after.png.

## Keeper customization and actions (2026-09-16)

Forest keeper uses Appearance.normalize({skin,hair,hair_style,cloth,trousers}), ActionFrames.install(source), and EquipmentSkin.build(source,armor,light,appearance). The 52 action clips have fixed64x64 canvases and per-frame head/body/hand/offhand anchors. Tool overlays read hand_position rather than estimating a separate arm. Character creator previews only idle clips; full skin caches cap12 and mounted composites24 to bound customization memory. Mounted actions replace the seated upper body with the current dressed action frame, while retaining seated legs and the independent player hurtbox. Play_action may refuse during combat: controllers must honor that return, and damage must cancel active bow/fishing ownership. Bow holds the last draw cel until release/cancel. Preserve original sheets and use layered Aseprite outputs for new pose sources.

Rendered playback and native bounds matter alongside resource tests. Current31-suite runner includes real-input bow/garden actions, character maker, mounted shooting and read-only legacy-save compatibility. Validation and preview paths: art/forest-pass6/VALIDATION.md and art/forest-playtest/v6/CHARACTER_QA.md.
