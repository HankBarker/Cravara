# Third-pass UI validation

Godot 4.6.1, 1440x810 hardware rendering on AMD Radeon RX 7700S, native UI coordinates 480x270. `ForestUIV3Test.tscn` passed in both headless and graphical modes with `UI_V3_TEST failures=0`. Existing `ForestUIV2Test.tscn` and `forest_inventory_test.gd` also passed.

The regression uses held mouse input through the viewport, including press, motion with the left-button mask, and release. It does not substitute button signals or direct inventory calls for the tested gestures.

Verified:

- Partial same-item merge retains overflow; empty-slot movement and different-item swap conserve the stacks.
- The preview appears during held drag and disappears on release, above the UI in its own CanvasLayer.
- Dragging armor moves it; clicking and releasing without movement equips exactly once.
- Releasing outside a slot cancels without losing items.
- Both player-to-chest merge and chest-to-player movement work.
- CapsLock visits inventory groups 0, 8, 16, 24, 32, then wraps. The last group exposes slots 32–34 only. Numeric 3 selects absolute slot 34; unavailable numeric 8 cannot select an unrelated slot. No stack is physically rotated.
- Settings preview a shadow toggle and Cancel restores it. A hash check confirms the user's settings.cfg remains unchanged.
- A real companion-menu button equips a Stegosaurus saddle; Ride mounts it and dismount restores the rider.

Screenshots were visually inspected: satchel typography, last partial pouch, settings alignment and saddle command layout. `01-satchel.png`, `02-last-pouch.png`, `03-settings.png`, `04-saddle-commands.png` are engine renderer output.

The drag fix addresses two distinct defects: Godot keeps mouse capture on the pressed source slot, so release cannot be delegated to the destination's gui_input; and a root-node preview follows the world camera unless it is put on a separate CanvasLayer. Press coordinates are explicitly transformed from the originating GUI event, so a click cannot be mistaken for a drag due to stale mouse state.

Typography now uses IM Fell English headings and Alegreya Sans body text, distributed under the SIL Open Font License. Both unmodified font files and licenses are bundled under `game/Forest/fonts`.

Sources: https://github.com/google/fonts/tree/main/ofl/imfellenglish and https://github.com/google/fonts/tree/main/ofl/alegreyasans
