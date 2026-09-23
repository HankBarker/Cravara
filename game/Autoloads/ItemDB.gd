# ItemDB.gd - single source of truth for item definitions.
#
# Items are authored as data: one `.tres` per item under res://Items/Data/.
# Adding a new item = drop a new `.tres` there (and, if craftable, one recipe
# entry). No more editing a giant create_item_by_id() match in four places.
#
# CraftingManager.create_item_by_id() and SaveManager now route through here.
extends Node

const DATA_DIR := "res://Items/Data/"
const _ArmorIconFactory = preload("res://Items/ArmorIconFactory.gd")
const _ChestItem = preload("res://Items/ChestItem.gd")

# id -> prototype Item. Prototypes are never handed out directly; make() returns
# a duplicate so per-instance state can never bleed across stacks.
var _items: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_items.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("ItemDB: data directory not found: " + DATA_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and (fname.ends_with(".tres") or fname.ends_with(".res")):
			_register_file(DATA_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	print("📦 ItemDB loaded %d items: %s" % [_items.size(), ", ".join(_items.keys())])

func _register_file(path: String) -> void:
	var res = load(path)
	if res is Item:
		if res.id == "":
			push_warning("ItemDB: item with empty id at " + path)
			return
		_resolve_icon(res)
		_trim_icon_canvas(res)
		_items[res.id] = res
	else:
		push_warning("ItemDB: %s is not an Item resource" % path)

# Fill in a procedural pixel icon when the data file has no baked texture.
func _resolve_icon(item: Item) -> void:
	var wardrobe_icon := "res://Forest/equipment/art/wardrobe/icons/" + item.id + ".png"
	if ResourceLoader.exists(wardrobe_icon):
		item.icon = load(wardrobe_icon)
		return
	var latest_icon := "res://Forest/art/v6/item-" + item.id + ".png"
	if ResourceLoader.exists(latest_icon):
		item.icon=load(latest_icon)
		return
	var current_icon := "res://Forest/art/v5/item-" + item.id + ".png"
	if ResourceLoader.exists(current_icon):
		item.icon = load(current_icon)
		return
	# V2 original raster artwork shares the world's quartz, bark and bone palette.
	# Resolve by stable item ID so old saves receive the same upgraded presentation.
	var forest_icon := "res://Forest/art/v2/item-" + item.id + ".png"
	if ResourceLoader.exists(forest_icon):
		item.icon = load(forest_icon)
		return
	if item.icon != null:
		return
	match item.icon_generator:
		"armor_head": item.icon = _ArmorIconFactory.make("head")
		"armor_chest": item.icon = _ArmorIconFactory.make("chest")
		"armor_legs": item.icon = _ArmorIconFactory.make("legs")
		"chest": item.icon = _ChestItem._make_icon()
		"forest": item.icon = preload("res://Items/ForestItemIcons.gd").make(item.id)
		_: pass

# --- Public API ---

func has(id: String) -> bool:
	return _items.has(id)

func make(id: String) -> Item:
	var proto = _items.get(id)
	if proto == null:
		return null
	return proto.duplicate()

func get_prototype(id: String) -> Item:
	return _items.get(id)

func all_ids() -> Array:
	return _items.keys()


# Existing pack icons carry a large transparent canvas. Crop only the display region
# so a tool reads at the same visual scale as the native 16px forest materials.
func _trim_icon_canvas(item: Item) -> void:
	if item.icon == null: return
	var image := item.icon.get_image()
	if image == null: return
	var used := image.get_used_rect()
	if used.size.x == 0 or used.size.y == 0: return
	if used.size.x >= image.get_width() - 2 and used.size.y >= image.get_height() - 2: return
	var atlas := AtlasTexture.new()
	atlas.atlas = item.icon
	atlas.region = used.grow(1).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	item.icon = atlas
