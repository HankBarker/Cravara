extends RefCounted
## Cosmetic choices. Equipment/defense and the original source sheets are separate.
const DEFAULTS := {"skin":"warm","hair":"flax","hair_style":"short","cloth":"moss","trousers":"earth"}
const OPTIONS := {
	"skin":[{"id":"warm","label":"Warm","color":Color("c99063")},{"id":"sand","label":"Sand","color":Color("e3b987")},{"id":"umber","label":"Umber","color":Color("8c583e")},{"id":"rose","label":"Rose","color":Color("cd9b87")}],
	"hair":[{"id":"flax","label":"Flax","color":Color("d6a456")},{"id":"chestnut","label":"Chestnut","color":Color("8d5135")},{"id":"charcoal","label":"Charcoal","color":Color("41434b")},{"id":"silver","label":"Silver","color":Color("b8c5be")}],
	"hair_style":[{"id":"short","label":"Swept","color":Color("d6a456")},{"id":"cropped","label":"Cropped","color":Color("ad7b45")},{"id":"tied","label":"Tied back","color":Color("d6a456")},{"id":"braid","label":"Trail braid","color":Color("d6a456")},{"id":"curly","label":"Wild curls","color":Color("d6a456")},{"id":"ponytail","label":"High ponytail","color":Color("d6a456")}],
	"cloth":[{"id":"moss","label":"Moss","color":Color("81915a")},{"id":"ochre","label":"Ochre","color":Color("bd9248")},{"id":"river","label":"River","color":Color("558f98")},{"id":"clay","label":"Clay","color":Color("b8684f")}],
	"trousers":[{"id":"earth","label":"Earth","color":Color("796047")},{"id":"slate","label":"Slate","color":Color("57697b")},{"id":"olive","label":"Olive","color":Color("65704c")}]
}
static func normalize(values: Dictionary = {}) -> Dictionary:
	var result := DEFAULTS.duplicate()
	for field in DEFAULTS:
		for option in OPTIONS[field]:
			if str(values.get(field,"")) == option.id: result[field] = option.id
	return result
static func color_for(field: String, id: String) -> Color:
	for option in OPTIONS.get(field,[]):
		if option.id == id: return option.color
	return Color.WHITE
static func key(values: Dictionary) -> String:
	var normalized := normalize(values)
	var parts := PackedStringArray()
	for field in DEFAULTS: parts.append(str(normalized[field]))
	return ":".join(parts)
