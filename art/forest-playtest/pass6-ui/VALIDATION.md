# Keeper appearance and inventory conveniences

Implemented in `CharacterCreator.gd`, `ForestHUD.gd`, `MainMenu.gd`, `InventoryManager.gd`, `ItemDetails.gd`, and `SlotUI.gd`.

- New Expedition opens a keeper creator before starting the forest. Gear > Appearance edits the current keeper. Skin, hair color/style, tunic and trousers use the shared appearance compositor. Direction and equipped/clothing previews retain the original animated character. Cancel discards the draft; Apply preserves equipment and inventory. Root journey save/load owns persistence.
- Sort pack merges and sorts only slots outside the current hotbar pouch, including the last three-slot pouch. Stack nearby transfers only matching types into nearby visible chests, retains overflow, protects the hotbar, and cannot reach through walls. Both actions expose clear feedback.
- Item hover shows actual damage, mining/chopping power, defense and food fullness duration; crafting hover uses the same item data. Slot tooltips wrap at native width and slots accept keyboard focus.
- Worker companions expose Work, Return, Set work home, Assign chest and their current status. Pet validates proximity and a clear path before playing the keeper animation.

`ForestUIPass6.tscn` sends viewport mouse/keyboard events and tests conservation, limits, wall obstruction, creator cancellation/application, visual preview changes, isolated root save/load, actual new-session appearance initialization, worker controls and Pet. It disables persistence to the user's settings/journey and removes only its isolated test save.

Validation: final headless run **30 checks, 0 failures**; rendered run before the final button-sizing polish **29 checks, 0 failures**; legacy UI V3 drag/equip/chest/hotbar/settings/saddle regression clean. The final added assertion confirms all creator buttons fit the native carved frame. Parent combined runner will record the final graphical rerun.

Updated menu-flow regression: **12 checks, 0 failures** headlessly. Both journal pages and every visible descendant are contained within 480x270. The first journal is 326x244 and the field-skills page 326x236 at (77,20). Reduced inter-row spacing and removed blank text lines to retain all instructions at the existing 8px font. Pairwise button bounds also confirm the creator's Turn preview and Preview clothing buttons no longer overlap.

Screenshots in this directory show the item tooltip, appearance editor, new-keeper creator and worker menu. The rendered review caught inherited default-font button minimums expanding beyond the intended creator dimensions; buttons now resolve their adventure font before their final size is assigned.

Primary reference: [Godot 4.6 Control documentation](https://docs.godotengine.org/en/4.6/classes/class_control.html), custom tooltip sizing and keyboard focus. No external UI framework or asset dependency was added for this pass.
