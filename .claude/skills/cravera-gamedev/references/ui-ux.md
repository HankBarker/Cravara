# Cravera UI/UX & HUD Reference (Godot 4.6)

Practical reference for building Cravera's UI: inventory, crafting, HUD, drag-and-drop, and
pixel-perfect presentation at 480x270 → 1080p. All APIs are **Godot 4.6**; 3.x-only advice is
flagged with `[3.x ONLY]`.

Cravera context: render res 480x270, `canvas_items` stretch, pixel-perfect. UI built **in code**
(no .tscn-driven layout) inside `InventoryUI.gd` (a `CanvasLayer`), with `SlotUI.gd` slot widgets,
a custom `DragController` autoload, `TooltipUI.gd`, and a `CraftingManager`-driven recipe list.

---

## 1. Control & Container system for game UI

**CanvasLayer vs Control root.** Cravera puts the whole UI on a `CanvasLayer` (`InventoryUI.gd`).
That's correct: a CanvasLayer renders independently of the world `Camera2D`, so HUD stays fixed
while the camera pans. Put `Control` nodes *inside* the CanvasLayer.

**Anchors & offsets (the core of responsive UI).** Every `Control` has 4 anchors (0–1, fraction of
parent rect) + 4 offsets (pixels from the anchored edge). Use presets instead of hand-math:
```gdscript
panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)          # centered, keeps size
bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)          # stretch across top
hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)         # fill parent
hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
```
Cravera currently hard-codes positions against literal `480`/`270` (e.g. `_position_hotbar()`).
That works but breaks if the design res changes. Prefer anchors + a `MarginContainer` so the layout
is resolution-agnostic.

**Containers auto-layout their children** (you set sizing flags, not positions):
- `GridContainer` (set `columns`) — inventory/chest grids. Cravera uses this correctly.
- `HBoxContainer` / `VBoxContainer` — hotbar row, recipe list, ingredient rows.
- `MarginContainer` — uniform padding around a panel's content (use `add_theme_constant_override("margin_left", N)` etc.).
- `CenterContainer` / `AspectRatioContainer` — centering, fixed-ratio framing.
- Spacing: `add_theme_constant_override("separation", N)` (boxes), `"h_separation"`/`"v_separation"` (grid).
- Child sizing: `size_flags_horizontal = Control.SIZE_EXPAND_FILL` makes a child grab leftover space.

**Gotcha — don't mix manual `position` inside a Container.** Containers overwrite children's
`position`/`size` every layout pass. Cravera's panels are plain `Panel` (not containers), so manual
`position` on title labels works — but the moment you parent something under a `GridContainer`/`HBox`,
stop setting `.position` and use sizing flags + `custom_minimum_size` instead.

**`custom_minimum_size`** is how you give container children a fixed footprint (slots:
`Vector2(28, 28)`). The container won't shrink below it.

### mouse_filter — the #1 UI bug source

Three modes on every Control:
- `MOUSE_FILTER_STOP` (default) — consumes the event; nothing underneath receives it.
- `MOUSE_FILTER_PASS` — handles it *and* lets it continue to nodes below.
- `MOUSE_FILTER_IGNORE` — invisible to the mouse; passes straight through.

Cravera already does the two critical things right:
1. The full-screen `UIContainer` is `MOUSE_FILTER_IGNORE` — otherwise *every* world click would
   register as "over the UI" and block placement/attacks.
2. Icons, quantity labels, tooltips, decorative `ColorRect`s are all `IGNORE` so they never steal
   clicks from their parent slot.

Rules of thumb:
- Decorative/non-interactive Controls → **always `IGNORE`**. (A known Godot pain point: most
  non-interactive controls default to `STOP`, so they silently eat clicks.)
- Interactive widgets (slots, buttons) → `STOP` (slot) — Cravera's armor slots use `STOP` correctly.
- Cravera's world-placement guard reads `get_viewport().gui_get_hovered_control()` before placing —
  good defensive pattern, but it only works if non-slot UI is `IGNORE`.
- Watch out: `PASS` sometimes behaves like `STOP` for *mouse-button* events in nested Controls; if a
  click "disappears," check filters top-down. (Known long-standing engine quirk.)

Sources: [mouse filter forum thread](https://forum.godotengine.org/t/mouse-filters-set-to-pass-control-still-blocking-mouse-input/16812),
[Solve Mouse Events in Godot 4](https://www.theslidefactory.com/post/help-my-mouse-events-dont-work-in-godot-4),
[godot-proposals#788](https://github.com/godotengine/godot-proposals/issues/788).

---

## 2. Inventory UI patterns

**Slot grid construction** (matches Cravera's `_create_slot` + `create_inventory_slots`):
```gdscript
var grid := GridContainer.new()
grid.columns = 9
grid.add_theme_constant_override("h_separation", 2)
grid.add_theme_constant_override("v_separation", 2)
for i in range(start_index, end_index):
    var slot := _create_slot(i, 28)   # Panel + SlotUI script + icon + qty label
    grid.add_child(slot)
```

**Slot anatomy** (Cravera's is solid): a `Panel` (StyleBoxFlat border = rarity), a child
`TextureRect` icon (`IGNORE`, inset 2px), and a `Label` quantity (bottom-right, with a 1px-offset
shadow `Label` behind it for readability — a good low-res trick since drop-shadows don't exist on
plain Labels).

**Rarity tint/frame.** Cravera recolors the slot border per rarity via a duplicated StyleBoxFlat.
Keep it but make it **colorblind-safe**: pair color with a corner pip or frame thickness (e.g.
legendary = 2px border + animated shimmer) so it reads without hue. Don't rely on hue alone.

**Equipment slots** (armor head/chest/legs): Cravera builds these as standalone `Panel`s with a
faint letter tag ("H"/"C"/"L") and `gui_input` → equip/unequip. Good. To extend: add a ghost
silhouette icon when empty (TextureRect with `modulate.a = 0.25`) so players know what goes there.

**Container/chest UI.** Cravera's `SlotUI.source` field is the key abstraction: a slot reads/writes
`source.inventory` and emits `source.inventory_changed` instead of the global `InventoryManager`.
This lets one `SlotUI` script serve player inventory, hotbar, and chest. Keep this — it's the right
design. Chest opens via `open_chest()`, rebuilds slots, connects `inventory_changed`.

**Quick-move (shift-click).** Implemented: `SlotUI._on_gui_input` checks `event.shift_pressed` →
`parent_ui.transfer_slot(self)` which shoves the stack player↔chest. Extend to also target the
crafting/armor context and to merge into existing partial stacks first.

**Right-click actions.** Cravera uses right-click to consume food (`_try_consume`). Survival-game
convention is right-click = "use/split half"; consider a context split (right-click a stack →
pick up half) for stackable mats, since you already have `max_stack` on `Item`.

**Stack-merge vs swap.** Today drop = swap (`cross_swap`). The expected behavior: if source and
target hold the **same item id**, *merge* up to `max_stack` and leave the remainder; only swap when
items differ. This is the single biggest inventory-feel gap — see §3.

---

## 3. Drag-and-drop: built-in vs Cravera's DragController

**Godot's built-in system** (3 virtuals on `Control`):
```gdscript
func _get_drag_data(_pos):
    var preview := TextureRect.new()
    preview.texture = item.icon
    preview.custom_minimum_size = Vector2(28, 28)
    set_drag_preview(preview)            # follows cursor automatically
    return {"from_slot": slot_index, "source": source}

func _can_drop_data(_pos, data): return data is Dictionary and data.has("from_slot")
func _drop_data(_pos, data):     _resolve_move(data, slot_index)   # swap or merge
```
Pros: automatic preview, automatic drop targeting, drop-cancel handling, works with focus/touch.
Cons: less control over preview pixel snapping; data is opaque; preview is a separate Control you
re-skin each drag.

**Cravera's custom `DragController` autoload.** Manual: `start_drag()` spawns a `TextureRect` on the
root at `z_index = 1000`, `_process()` tracks the mouse, `SlotUI` mouse-up resolves the swap,
`_unhandled_input` cancels on release outside a slot. Trade-offs:

| | Built-in | Cravera DragController |
|---|---|---|
| Preview | `set_drag_preview` auto | manual TextureRect (full pixel control) |
| Drop targeting | engine finds target | SlotUI mouse-up compares `dragged_slot` |
| Cancel/outside | `Variant()` not accepted | `_unhandled_input` on release |
| Touch/controller | supported | mouse-only |
| Cross-container | manual data | already handled (`source` field) |

**Recommendation: keep the custom controller** — it's already wired through `source`/`cross_swap`,
gives exact pixel-perfect preview placement (critical at 480x270), and avoids the built-in system's
quirks with CanvasLayer coordinates. But fix these edge cases:

1. **Stack-merge on drop** (see §2) — currently always swaps; add same-id merge into `cross_swap`.
2. **Drop outside UI = drop item into world.** `DragController._unhandled_input` currently just
   `end_drag()` (item snaps back). Survival convention: releasing over the game world should spawn
   the item as a world pickup. Detect "no hovered slot" via `gui_get_hovered_control()`, then call
   your world-drop spawner.
3. **Pixel-snap the preview.** `floor()` the preview position each frame so the dragged icon never
   lands on a half-pixel and blurs: `dragged_icon.position = (mouse - Vector2(14,14)).floor()`.
4. **Split-drag** (right-button drag = half stack) is a common survival nicety; hook it in
   `start_drag` by passing a `quantity` override.

Sources: [Drag and Drop in Godot 4.x (DEV)](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13),
[Control.get_drag_data API](https://cyoann.github.io/GodotSharpAPI/html/6cc954a6-04db-fb70-7aad-3d09f2506675.htm).

---

## 4. Crafting menu UX

Cravera's `populate_crafting_panel()` builds a `VBoxContainer` of recipe rows inside a
`ScrollContainer`, filtered by `selected_category` (All/Tools/Building/Materials/Armor), each row
greyed when `CraftingManager.can_craft()` is false. Strong foundation. Per-row it shows result icon,
name, `have/need` ingredient counts (green/red), and a Craft button. Good — this mirrors Terraria's
"can-craft" list and Core Keeper's station panels.

**Greying uncraftable recipes** (the pattern, already in Cravera):
```gdscript
var craftable := CraftingManager.can_craft(recipe.ingredients)
result_icon.modulate = Color.WHITE if craftable else Color(0.5, 0.5, 0.5, 0.7)
name_label.add_theme_color_override("font_color",
    Color(0.9, 0.88, 0.95) if craftable else Color(0.5, 0.5, 0.5))
craft_btn.disabled = not craftable          # also give it a "disabled" StyleBox
```

**Upgrades worth adding:**
- **"Show only craftable" toggle** — a CheckButton that filters `get_recipes_by_category()` to
  recipes passing `can_craft`. (Terraria does exactly this; it's the most-requested QoL.)
- **Search box** — a `LineEdit` filtering by `recipe.name`; invaluable once recipe count grows.
- **Sort craftable-first** — within a category, sort `can_craft` rows to the top so reachable
  recipes don't hide below greyed ones.
- **Craft feedback** — on success play `craft_success` (already wired) + a brief Tween pop on the
  result icon and a `FloaterLabel` "+1 Torch" near the cursor.
- **Workbench-gating** — Cravera has a Workbench item but recipes are flat (`personal_recipes`). Add
  a `station` key to recipes (`"station": "workbench"`) and filter by nearby station, like Core
  Keeper. "Personal" recipes (no station) always show; station recipes appear only when in range.
- **Craft-all / hold-to-repeat** — hold the Craft button to batch-craft while ingredients last.
- **Rebuild cost** — `populate_crafting_panel()` re-instantiates every row on each inventory change.
  Fine now; if recipe count grows, cache rows and only update `modulate`/labels.

---

## 5. HUD design

**Bars: custom `ColorRect` (Cravera) vs `TextureProgressBar`.** Cravera builds health/hunger/stamina
as border `Panel` + bg `ColorRect` + fill `ColorRect`, tweening `fill.size.x`. This works and gives
total control, but means manual layout per bar.

- `TextureProgressBar` is the idiomatic choice: assign under/progress/over textures, set `value`,
  done. **Caveat for 4.6:** `TextureProgressBar` does **not** support the Theme system — it uses
  Texture2Ds only, so you can't reskin it via a shared Theme. If you want one themed style across
  bars, plain `ProgressBar` (with a `StyleBoxFlat` fill) is themeable; `TextureProgressBar` is not.
- **Recommendation:** for pixel-art bars with custom frames, Cravera's ColorRect approach is fine
  and arguably cleaner than fighting `TextureProgressBar`'s non-themeable skinning. Factor the
  border+bg+fill+label into one reusable `StatBar` scene/class to kill the duplication between
  `_build_health_bar()` and `_build_stat_bar()`.

**Damage/heal flash & low-stat warnings.** Cravera already color-shifts health (green→yellow→red)
and tweens hunger to red below 20%. Add:
- A red full-screen vignette flash on damage (a `ColorRect` overlay, alpha tweened 0.3→0 over 0.2s).
- A pulsing fill (`Tween.set_loops()`) when a stat is critically low.
- Heal = brief green tint on the fill.

**Hotbar selection highlight.** `_update_hotbar_selection()` recolors the selected slot's border
gold + thicker + glow, and brightens its number. Solid. Add a subtle scale-pop Tween on selection
change for juice.

**Item-pickup toasts.** `FloaterLabel.spawn()` already floats text up and fades — perfect for
"+3 Wood" on pickup and "Needs axe" hints. Wire it to `InventoryManager.item_picked_up` (currently
`_on_item_picked_up` is empty) to show pickup toasts near the player.

**Minimap.** At 480x270 a minimap eats scarce screen space; if added, keep it tiny (≤48px),
top-right, toggleable, and render it on the same CanvasLayer with nearest filtering.

Sources: [TextureProgressBar theme limitation (godot-proposals#7265)](https://github.com/godotengine/godot-proposals/issues/7265),
[Health Bar with TextureProgressBar](https://app.studyraid.com/en/read/32761/1441903/creating-a-health-bar-with-textureprogressbar).

---

## 6. Pixel-perfect UI at 480x270

Cravera's `project.godot` is already configured correctly:
- `display/window/stretch/mode="canvas_items"` — scales UI with the window, keeps shapes crisp.
- `viewport_width=480 / viewport_height=270`, window override 1920x1080 (exact 4x integer scale —
  ideal, no shimmer).
- `rendering/textures/canvas_textures/default_texture_filter=0` (Nearest) — hard pixel edges.
- `snap_2d_vertices_to_pixel` / `snap_2d_transforms_to_pixel=true` — good.

**Design the UI at native 480x270.** Every size/offset you type is a *native* pixel and gets ×4 on
screen. So a `font_size = 7` renders at ~28px on a 1080p display. Build and preview at 480x270.

**Fonts — the blurry-text trap.** With `canvas_items`, fonts stay crisp **only at the design res or
exact integer multiples**; non-integer window sizes (e.g. 1366x768) blur text. Mitigations:
- Ship at integer-scaled windows (1920x1080 = 4x, 960x540 = 2x). Offer these as the only fullscreen
  options, or letterbox.
- Use a **bitmap/pixel font** (e.g. a `.ttf` pixel font imported with **hinting off** and
  **antialiasing off**, or a true `BitmapFont`/`FontFile` with `subpixel_positioning = Disabled`).
  Set `multichannel_signed_distance_field = false`. This keeps glyphs on the pixel grid.
- Keep font sizes to values that map to clean multiples (Cravera uses 5/6/7/8 — fine).

**NinePatchRect for window/button frames.** Today Cravera draws panels with `StyleBoxFlat` (solid
fill + 1px border + rounded corners). For pixel-art window chrome, a `NinePatchRect` with a tiny
source texture gives authentic decorated borders that don't stretch:
```gdscript
var win := NinePatchRect.new()
win.texture = load("res://UI/panel_9slice.png")     # e.g. 16x16 with a 4px border
win.patch_margin_left = 4; win.patch_margin_top = 4
win.patch_margin_right = 4; win.patch_margin_bottom = 4
win.texture.set_meta("filter", false)   # ensure Nearest on the imported texture
```
Set the texture's import **Filter = Nearest** (or rely on the project default 0). `StyleBoxTexture`
is the Theme-resource equivalent (use it inside a Theme so every Panel shares the frame).

**The Theme resource system.** Cravera builds every StyleBox imperatively in GDScript — readable but
duplicative and hard to keep consistent. A single `Theme` resource centralizes StyleBoxes, fonts,
font sizes, and colors:
```gdscript
var theme := Theme.new()
theme.set_font_size("font_size", "Label", 7)
theme.set_color("font_color", "Label", Color(0.9, 0.88, 0.95))
theme.set_stylebox("panel", "Panel", panel_stylebox)     # one window look everywhere
theme.set_stylebox("normal", "Button", button_normal)
$UIContainer.theme = theme    # inherited by all descendants
```
Recolor/restyle the whole game by editing one resource. Strongly recommended as Cravera's UI grows.

Sources: [GDQuest pixel art setup Godot 4](https://www.gdquest.com/library/pixel_art_setup_godot4/),
[Multiple resolutions (Godot docs)](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html),
[canvas_items font blur issue #86563](https://github.com/godotengine/godot/issues/86563).

---

## 7. Game feel & accessibility

**Open/close tweens.** Inventory currently toggles `visible` instantly. Add a quick scale+fade:
```gdscript
func toggle_inventory():
    var opening := not inventory_panel.visible
    if opening:
        inventory_panel.visible = true
        inventory_panel.scale = Vector2(0.9, 0.9); inventory_panel.modulate.a = 0.0
        var t := create_tween().set_parallel()
        t.tween_property(inventory_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        t.tween_property(inventory_panel, "modulate:a", 1.0, 0.10)
    # else: tween out, then set visible=false in a finished callback
```
Remember to set `pivot_offset` to the panel center so it scales from the middle.

**Button hover/press SFX.** Cravera has `AudioManager.play_sfx("ui_click")`. Wire `mouse_entered` →
soft hover blip and `pressed` → click on Buttons and slots (debounce hover so dragging across a grid
isn't a machine-gun). Route through the Theme/a helper so every button gets it for free.

**Juicy slots.** On successful drop/equip: a 1.1→1.0 scale pop Tween on the slot icon; on
shift-transfer, a quick fly-to animation of a ghost icon toward the chest.

**Keyboard & controller navigation.** Godot's focus system drives this:
- Set `focus_mode = Control.FOCUS_ALL` on slots/buttons you want navigable (Cravera sets
  `FOCUS_NONE` on craft/category buttons — fine for mouse, but blocks controller).
- `GridContainer` auto-injects focus neighbor handling for its children, so arrow-key/D-pad grid
  navigation mostly "just works" once children are focusable. For custom flow set
  `focus_neighbor_left/right/top/bottom` (or `focus_next`/`focus_previous`).
- Call `grab_focus()` on the first slot when the inventory opens so a controller has a starting point.
- Bind A/Cross to "activate slot", X/Square to "split", etc., via input actions.

**Accessibility:**
- **Colorblind-safe rarity** — pair hue with shape (corner pip, frame thickness, icon glow), never
  hue alone (see §2).
- **Scalable UI** — because everything is in native pixels, expose a UI-scale multiplier by scaling
  the root Control / swapping integer window scales. A single Theme makes a "large UI" variant easy.
- **Remappable keys** — Cravera uses Maaack's Menus Template, which ships an input-remap screen and
  settings persistence; route gameplay actions (`toggle_inventory`, `interact`, `hotbar_1..8`)
  through remappable input actions so they appear there. Avoid hard-coded `KEY_*` checks.

Sources: [Keyboard/Controller Navigation & Focus (Godot docs)](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html),
[GridContainer class ref](https://docs.godotengine.org/en/stable/classes/class_gridcontainer.html).

---

## How this maps to Cravera

Prioritized upgrades, highest-impact first:

1. **Stack-merge + world-drop in `DragController`/`cross_swap`** (highest gameplay impact). Today
   drop always *swaps*; make same-`item.id` drops *merge* into `max_stack` with remainder, and make
   release over the world spawn a pickup instead of snapping back. Pixel-snap the drag preview
   (`.floor()`). **Keep the custom DragController** — it's already cross-container aware and gives the
   pixel control you need at 480x270.

2. **Introduce one `Theme` + a pixel font standard.** Replace the ~dozen hand-built StyleBoxFlats in
   `InventoryUI.gd`/`SlotUI.gd`/`TooltipUI.gd` with a single `Theme` resource on `$UIContainer`
   (Panel/Button/Label styles, font, sizes). Standardize on a **pixel `.ttf` imported with
   antialiasing OFF, hinting OFF, MSDF OFF**, and keep font sizes 5–8 native px. This fixes
   consistency and the blurry-text risk, and makes recoloring/large-UI trivial.
   **Font standard:** body 6px, slot qty 7px, titles 8px, micro-labels 5px; restrict windowed modes
   to integer scales (960x540, 1440x810, 1920x1080) to keep text crisp.

3. **Crafting QoL: "show craftable only" toggle + search + workbench-gating.** Add a CheckButton and
   `LineEdit` above the recipe `VBoxContainer`, sort `can_craft` rows first, and add a `station` key
   to `CraftingManager.personal_recipes` so the existing Workbench actually gates advanced recipes
   (Core Keeper-style). Low effort on top of the existing `populate_crafting_panel()`.

Secondary: factor health/hunger/stamina into one reusable `StatBar` (kills the
`_build_health_bar`/`_build_stat_bar` duplication); wire `FloaterLabel` pickup toasts to the unused
`_on_item_picked_up`; add open/close Tweens and hover/press SFX via the Theme; make slots/buttons
`FOCUS_ALL` + `grab_focus()` on open for controller support; add colorblind-safe rarity shapes;
add empty-armor-slot ghost icons. Migrate hard-coded `480`/`270` positioning to anchors +
`MarginContainer` so a future res change doesn't break layout.
