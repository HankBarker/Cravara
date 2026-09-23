# Fourth-pass interface, foley and collectibles

Godot 4.6.1. `ForestUIV4Test.tscn` passed with zero failures in headless and AMD Radeon RX 7700S OpenGL-rendered modes. Native UI coordinates remain 480x270; rendered captures used the user's fullscreen setting at 1920x1080. Test inputs are actual viewport mouse and keyboard events.

Verified:

- All three stitched-hide/crystal shortcut charms accept clicks.
- Settings hides only these buttons; hotbar stays visible and Tab/K/P still open their menus.
- Tab/K/P cannot open menus during the respawn countdown.
- All four satchel/gear cues resolve to recorded leather/cloth sample files. Durations are 0.44–0.73 seconds. FFmpeg fully decoded all four with no errors.
- Torch, timber, stone and saddle drops fit a 12px maximum dimension, with unchanged native collision coordinates while their sprites bob.
- A full inventory leaves the entire stack in the world. Freeing a slot while still overlapping picks up exactly the original three torches without requiring a new body-enter event.
- The user's settings file hash is identical before and after the test. Save writes are disabled by the test and --no-save-playtest.

The new interface ornament is original authored Godot geometry. Audio comes from the official Kenney RPG Audio pack, CC0, with natural material-handling recordings layered and faded for the four interactions. No synthesized open/close tones or metallic equip overlay remain for those events. Full source and editing provenance is bundled at `game/Forest/audio/leather/PROVENANCE.md`.

Screenshots: `01-shortcut-charms.png`, `02-settings.png`, `03-clean-hud.png`, `04-miniature-drops.png`. These are engine renderer outputs, visually inspected for clipping, label fit and item scale.

## Session interaction regression

`ForestInteractionPass4.tscn` passed **25 checks with zero failures** in both headless and OpenGL-rendered mode after the terrain cache optimization. This independent fixture leaves session/player runtime scripts unchanged. It feeds physical key and mouse events through `Input.parse_input_event`, with OS pointer alignment in graphical mode, and checks the actual held-input state.

- Quick E mounts and dismounts; held E opens the mounted companion's commands without dismounting or changing orders.
- Held Q targets a nearby companion and opens group orders when away. Wild creatures do not expose companion menus.
- Workbench interaction works without precise cursor targeting.
- A mounted mouse press causes one directional strike; holding it does not repeat damage. F consumes one berry and heals once despite key-repeat; immediate repeat feeding observes cooldown.
- Movement and feeding are blocked behind a modal, including after the feeding cooldown expires. Holding the mouse while closing a modal leaks into neither a mount strike nor a survivor tool swing.
- Respawn blocks Tab/K/P/E/Q and pending interaction state.
- Actual selected-item right-click routing places roofing over a wall and flooring beneath a door, consuming one item each.
- The settings file SHA-256 remains unchanged; persistent game saving is disabled.

Evidence: `../interaction-pass4-log.txt`, `../interaction-pass4-render-log.txt`, and `05-mounted-command-input.png`. The command panel capture was inspected for readable labels and clipping at the native 480x270 layout.
