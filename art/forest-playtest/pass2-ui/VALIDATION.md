# Forest interface pass 2

Verified 2026-09-15 with Godot 4.6.1 on AMD Radeon RX 7700S, GL compatibility, 1440x810 (480x270 native coordinates). Screenshots are renderer outputs, not mockups.

Run `res://Tests/ForestUIV2Test.tscn -- --no-save-playtest`. The same suite passed in headless and hardware-rendered modes with `UI_V2_TEST failures=0`.

The test dispatches keyboard and mouse events through the viewport, not direct button signal calls:

- Tab opens the satchel and recipes; K switches to equipment; P opens companions; Escape closes UI.
- Clicking the Light slot then a Torch candidate equips one torch.
- Clicking each armor and trinket slot then the matching candidate equips all six slots without losing the torch.
- The live character portrait displays the equipped armor and held light.
- Individual Stay, group Passive, and individual Neutral have their intended scope.
- A dead companion's command cannot accidentally broadcast to the other companion.
- Physical E held for 0.42 seconds opens targeted orders without cycling; quick E retains the tap action.
- Physical Q held for 0.42 seconds opens group orders; holding E near untamed wildlife does not expose companion orders.
- A nearby corpse does not intercept held E intended for the next closest living companion.
- Player controls are locked while orders are open, including a real held D movement attempt.
- Physical Escape/J open pause/journal, and those overlays and the title guide fit the native screen.

The original `forest_menu_flow.gd` regression also passes with zero failures. The extra guide controls had expanded that panel to 268 pixels high at y=8; reducing body line spacing while retaining font size and every instruction restores its 300x218 layout.

Manual image review covered status bars, inventory grid and footer, crafting rows, equipment and portrait, roster, and command panel. This found and corrected inventory footer/frame overlap, undimmed HUD behind modal panels, and awkward equipment-stat wrapping.

The extended review caught pause/journal frame corners overlapping headings. The root integration now places ornament behind the panel, outside its content margins, with Cinzel headings. Refreshed `09-pause.png` and `10-journal.png` verify this correction.

## Assets

`game/UI/CrystalFrame.gd` and `CrystalMeter.gd` contain original authored UI geometry: carved slate, bronze corners, fern details, crystal inlays and segmented gem meters. No game art from the reference games was copied.

Headings use Cinzel, copyright 2020 The Cinzel Project Authors, SIL Open Font License 1.1. Font and full license are bundled in `game/Forest/fonts/Cinzel.ttf` and `Cinzel-OFL.txt`.

Source: https://github.com/google/fonts/tree/main/ofl/cinzel

Body text uses Godot's bundled default font. Creature imagery in the roster and the player portrait reuse the project's existing sprite resources.
