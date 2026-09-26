# Cravera Character Studio

Start from the Cravera root:

```powershell
python tools/character_studio.py serve --port 18765
```

Open http://127.0.0.1:18765. Port 8765 is reserved on this machine; use 18765.
Dependencies: Python with Pillow. The studio stays local to this computer.

## What is implemented

- Character projects, concept display beside original Rex references, terrain backdrops.
- Design approval, revision notes, and a local work request queue.
- Frame playback, scrubbing, contact sheet, preview FPS, individual animation approval.
- Integrity gates: approval hashes cover image bytes and clip timing, looping and pivot.
- Technical checks: transparent background, hard alpha, canvas agreement, size, padding,
  duplicate frames. These checks do not judge anatomy or animation quality.
- A complete approved 13-clip set exports to a new `game/Sprites/CharacterStudio/` folder
  as a Godot SpriteFrames resource. Export never replaces an existing gameplay scene.

## Generation workflow for Codex

The page is a review/work queue, not an autonomous generation API. ChatGPT image generation
is available to the active Codex task and does not automatically run when a browser button
is clicked. User tells Codex to process the saved queue. No API key is embedded in the page.

1. Inspect the actual reference sprites. Generate a design with the built-in image tool.
2. Register it using `add-concept`. Show it to the user. Wait for their approval.
3. Process pending requests from `art/character-studio/<id>/character.json`.
4. Prepare a native-resolution approved sprite in Aseprite. Keep the original large concept.
   Inspect at 1x and integer zoom against terrain. Do not silently squash a large concept into
   a 32px canvas and call it finished. Establish one canvas and foot/pelvis pivot for the clip.
5. Generate six right-facing walk poses from the SAME approved reference: contact A, down A,
   passing A, contact B, down B, passing B. Use separately saved outputs. Constrain skull,
   torso length, markings, lighting, scale and camera; feet alternate support, not all limbs.
   Keep forearms as forearms and tail as tail. The old lion rig is not the canonical raptor.
6. Clean in Aseprite using the native MCP or batch Lua; export individual transparent PNGs.
   Never center/crop each frame independently; use one canvas and fixed anchor.
7. Register frames in playback order, e.g.:

```powershell
python tools/character_studio.py add-clip raptor-v2 walk_right frame00.png frame01.png frame02.png frame03.png frame04.png frame05.png --fps 8
```

8. Show the loop and every frame in the workbench. Check feet sliding, anatomy changes,
   flicker, tail drift, first/last frame continuity and visibility at actual game size.
9. After walk approval, complete the other directions and actions. 15–20 images is not a
   guaranteed complete set: four-direction walk/bite/idle plus death usually needs more.
10. `python tools/character_studio.py export raptor-v2` writes a NEW resource only after all
    required approvals. Run Godot import and load tests, then integrate the approved resource
    into the actual creature scene and playtest separately. Verify attack hit timing and death
    duration against raptor.gd; resource loading alone is not a gameplay test.

Required clips: idle/walk/bite × down/up/left/right, plus directionless death. Clip FPS changes
in the browser are playback preview only; saved timing is supplied during registration.
Refresh the page after Codex registers new art.

## Connections

`python tools/character_studio_probe.py` handshakes with the project-configured Godot and
Aseprite MCP servers without exposing credentials. Godot has 12 tools; Aseprite has 116.
The PixelLab Aseprite extension prints `handle-pose.lua` dialog errors during batch startup;
the tested core file operations still complete. PixelLab MCP was verified separately with
`get_balance`: 16 generations remained on 2026-09-08, none spent on this studio iteration.

The first ChatGPT output painted a checkerboard rather than real transparency. The revised
concept instead used a magenta key, extracted by `prepare-concept.lua` inside Aseprite. PNG
background layers must first be converted with `LayerFromBackground` or alpha is lost on save.
Inspect edges after extraction. This is a concept, not a validated game-size animation frame.

Tests: `python -m unittest discover -s tools -p test_character_studio.py -v`.
They exercise approval integrity, rejected frames, path scope, missing-clip protection, and
load an exported synthetic 13-animation resource in a disposable real Godot project.

## First actual walk test

The user approved the revised lean blue raptor in chat. Six separate ChatGPT frame outputs
are preserved under `raptor-v2/walk-source`. Two follow-up pose corrections were attempted;
the improved down-B frame was selected. `walk-prepared` contains transparent full-resolution
PNGs, native 96x64 PNGs, a contact sheet, animated GIF and editable `walk-right.aseprite`.
The PNGs use one 16:1 nearest sampling transform and the same origin for every pose.
No per-frame automatic cropping or recentering is applied.

Preparation command (output directory must exist):

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe' --batch `
  --script-param 'source=C:/Cravera/art/character-studio/raptor-v2/walk-source' `
  --script-param 'out=C:/Cravera/art/character-studio/raptor-v2/walk-prepared' `
  --script-param 'count=6' --script C:/Cravera/tools/character_studio_prepare.lua
```

The 96x64 native trial retains the approved colors instead of silently mapping teal into
the existing earth/green palette. Final game footprint and palette harmonization still need
review. Contact A/B and the loop seam merit further cleanup: generation sometimes repeats
the same near/far leg arrangement. Technical validation passing is not visual approval.

The actual six-frame resource is also loaded by `raptor-v2/godot-preview/check.gd` in an
isolated Godot project. No files in the playable Raptor scene were replaced by this task.
