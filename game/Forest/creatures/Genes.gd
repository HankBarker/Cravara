extends RefCounted
## Pass 13: every beast is its own animal ("a purple bronto", ARK-like).
## A beast's genes (a Dictionary, saved with it):
##  - look: hue/sat/val, a shift of its hide within its kind's range; a rare
##    mutation colour (purple, white, black, gold, crimson, azure); markings:
##    the art's dark bands bolder or fainter, or speckles (genes.gdshader).
##  - temperament: calm, bold, skittish or fierce (how near it lets the keeper
##    come, how long it chases, how easily it's won).
##  - traits: up to two (hardy, swift, brute, thick-hided, tireless, gentle,
##    keen-eyed).
##  - intrinsic stats: hp, damage and speed x0.88-1.12 (a mutation adds 8-12%
##    to one), plus a few ranks of training once tamed (+5% a stat at most:
##    "upgraded, but very slightly").
## Young take after their parents (blend), with a chance of a new mutation.
## A keeper reads a beast's stats once two of the great beasts have fallen
## (Skarn, the Buried King, Old Maw): the Sky-Fang lens (`lens`).

const SHADER := preload("res://Forest/creatures/genes.gdshader")
const MUTATIONS := {
	"purple": Color(0.62, 0.38, 0.92), "white": Color(0.98, 0.96, 0.9), "black": Color(0.2, 0.2, 0.25),
	"gold": Color(1.0, 0.78, 0.32), "crimson": Color(0.92, 0.22, 0.2), "azure": Color(0.3, 0.62, 1.0),
}
const MARKINGS := ["", "bold", "faded", "speckled"]
const TEMPERS := ["calm", "bold", "skittish", "fierce"]
const TRAITS := {
	"hardy": {"name": "Hardy", "text": "+10% health"},
	"swift": {"name": "Swift", "text": "+8% pace"},
	"brute": {"name": "Brute", "text": "+10% bite"},
	"thick": {"name": "Thick-hided", "text": "takes 8% less harm"},
	"tireless": {"name": "Tireless", "text": "runs half again as long"},
	"gentle": {"name": "Gentle", "text": "won over in a fifth fewer feeds"},
	"keen": {"name": "Keen-eyed", "text": "spots trouble further off"},
}
## A rank of training: +1.7% (three at most in a stat).
const TRAIN_STEP := 0.017
const TRAIN_MAX := 3
## Base chances: a wild mutation (more of them far out), a mutation in a young one.
const WILD_MUTATION := 0.02
const FAR_MUTATION := 0.05
const BRED_MUTATION := 0.04


## Genes for a wild beast. `far`: 0 at camp, 1 at the edge of the world.
static func roll(rng: RandomNumberGenerator, far: float) -> Dictionary:
	var g := {
		"hue": rng.randf_range(-0.045, 0.045),
		"sat": rng.randf_range(0.86, 1.14),
		"val": rng.randf_range(0.93, 1.07),
		"mutation": "",
		"marking": _pick_marking(rng),
		"mark_seed": rng.randf_range(0.0, 100.0),
		"mark_tone": rng.randi_range(0, 2),
		"temper": _pick_temper(rng),
		"traits": [],
		"hp": _spread(rng), "damage": _spread(rng), "speed": _spread(rng),
		"train": {"hp": 0, "damage": 0, "speed": 0},
	}
	var n := 0
	var t := rng.randf()
	if t > 0.9: n = 2
	elif t > 0.5: n = 1
	var pool: Array = TRAITS.keys()
	for i in n:
		var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not g.traits.has(pick): g.traits.append(pick)
	if rng.randf() < lerpf(WILD_MUTATION, FAR_MUTATION, clampf(far, 0.0, 1.0)):
		_mutate(g, rng)
	return g


## A young one's genes from its parents (either may be empty: a wild egg).
## `inherit`: the chance each stat comes from the better parent; `mutation`: x
## the base chance of a new mutation (Breeding perks).
static func blend(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator, inherit := 0.55, mutation := 1.0) -> Dictionary:
	if a.is_empty() and b.is_empty(): return roll(rng, 0.0)
	if a.is_empty(): a = b
	if b.is_empty(): b = a
	var g: Dictionary = roll(rng, 0.0)
	for k in ["hue", "sat", "val"]:
		g[k] = lerpf(float(a.get(k, 0.0)), float(b.get(k, 0.0)), rng.randf()) + rng.randf_range(-0.01, 0.01)
	# The better parent's gift, more often than not.
	for stat in ["hp", "damage", "speed"]:
		var best := maxf(float(a.get(stat, 1.0)), float(b.get(stat, 1.0)))
		var worst := minf(float(a.get(stat, 1.0)), float(b.get(stat, 1.0)))
		g[stat] = best if rng.randf() < inherit else worst
	g.marking = a.get("marking", "") if rng.randf() < 0.5 else b.get("marking", "")
	g.temper = a.get("temper", "calm") if rng.randf() < 0.5 else b.get("temper", "calm")
	g.traits = []
	for parent in [a, b]:
		for t in parent.get("traits", []):
			if rng.randf() < 0.5 and not g.traits.has(t) and g.traits.size() < 2: g.traits.append(t)
	# A parent's mutation colour may carry; a new one may arise.
	var carried := ""
	for parent in [a, b]:
		if str(parent.get("mutation", "")) != "" and rng.randf() < 0.45: carried = str(parent.mutation)
	g.mutation = carried
	if rng.randf() < BRED_MUTATION * mutation:
		_mutate(g, rng)
	g.train = {"hp": 0, "damage": 0, "speed": 0}
	return g


static func _spread(rng: RandomNumberGenerator) -> float:
	# Two dice: most beasts near the middle, a few at the ends.
	return snappedf(1.0 + (rng.randf() + rng.randf() - 1.0) * 0.12, 0.001)


static func _pick_marking(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if r < 0.4: return ""
	if r < 0.65: return "bold"
	if r < 0.85: return "faded"
	return "speckled"


static func _pick_temper(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if r < 0.3: return "calm"
	if r < 0.6: return "bold"
	if r < 0.8: return "skittish"
	return "fierce"


## A mutation: a new colour and a gift to one stat.
static func _mutate(g: Dictionary, rng: RandomNumberGenerator) -> void:
	var colours: Array = MUTATIONS.keys()
	g.mutation = colours[rng.randi_range(0, colours.size() - 1)]
	var stat: String = ["hp", "damage", "speed"][rng.randi_range(0, 2)]
	g[stat] = snappedf(float(g.get(stat, 1.0)) * rng.randf_range(1.08, 1.12), 0.001)


## Genes as saved (JSON turns every number into a float): the ranks back to
## whole numbers, the traits to strings.
static func clean(g: Dictionary) -> Dictionary:
	if g.is_empty(): return {}
	var out := g.duplicate(true)
	var train: Dictionary = out.get("train", {}) if out.get("train", {}) is Dictionary else {}
	out.train = {"hp": int(train.get("hp", 0)), "damage": int(train.get("damage", 0)), "speed": int(train.get("speed", 0))}
	out.mark_tone = int(out.get("mark_tone", 0))
	var traits: Array = []
	for t in out.get("traits", []): traits.append(str(t))
	out.traits = traits
	out.mutation = str(out.get("mutation", ""))
	out.marking = str(out.get("marking", ""))
	out.temper = str(out.get("temper", "calm"))
	return out


## A short fingerprint of an animal (for matching one after a save).
static func fingerprint(g: Dictionary) -> String:
	return "%s|%s|%s|%.3f|%.3f|%.3f" % [str(g.get("temper", "")), str(g.get("mutation", "")), str(g.get("marking", "")), float(g.get("hp", 1.0)), float(g.get("damage", 1.0)), float(g.get("speed", 1.0))]


# ------------------------------------------------------------------ effects
## A stat's multiplier: intrinsic, traits and training.
static func stat_mult(g: Dictionary, stat: String) -> float:
	if g.is_empty(): return 1.0
	var m := float(g.get(stat, 1.0))
	var traits: Array = g.get("traits", [])
	match stat:
		"hp": if traits.has("hardy"): m *= 1.1
		"damage": if traits.has("brute"): m *= 1.1
		"speed": if traits.has("swift"): m *= 1.08
	m *= 1.0 + TRAIN_STEP * float(g.get("train", {}).get(stat, 0))
	return m


## How the temperament (and a keen eye) shifts a behaviour.
##  notice: how far off it notices the keeper; comfort: how near a herbivore
##  lets them come; tire: how long it chases; feeds: how many feeds it takes.
static func temper(g: Dictionary, what: String) -> float:
	if g.is_empty(): return 1.0
	var t := str(g.get("temper", "calm"))
	var traits: Array = g.get("traits", [])
	var m := 1.0
	match what:
		"notice":
			m = {"calm": 0.85, "bold": 1.0, "skittish": 1.1, "fierce": 1.2}.get(t, 1.0)
			if traits.has("keen"): m *= 1.15
		"comfort":
			m = {"calm": 0.8, "bold": 0.9, "skittish": 1.3, "fierce": 1.15}.get(t, 1.0)
		"tire":
			m = {"calm": 0.9, "bold": 1.0, "skittish": 0.8, "fierce": 1.3}.get(t, 1.0)
			if traits.has("tireless"): m *= 1.5
		"feeds":
			m = {"calm": 0.85, "bold": 1.0, "skittish": 1.1, "fierce": 1.25}.get(t, 1.0)
			if traits.has("gentle"): m *= 0.8
		"harm":
			if traits.has("thick"): m = 0.92
	return m


# ------------------------------------------------------------------ the look
static func material(g: Dictionary, frame_size: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	apply(m, g, frame_size)
	return m


static func apply(m: ShaderMaterial, g: Dictionary, frame_size: Vector2) -> void:
	m.set_shader_parameter("hue", float(g.get("hue", 0.0)))
	m.set_shader_parameter("sat", float(g.get("sat", 1.0)))
	m.set_shader_parameter("val", float(g.get("val", 1.0)))
	var mut := str(g.get("mutation", ""))
	if MUTATIONS.has(mut):
		var c: Color = MUTATIONS[mut]
		m.set_shader_parameter("mutation", Vector4(c.r, c.g, c.b, 0.92 if mut in ["white", "black"] else 0.86))
	else:
		m.set_shader_parameter("mutation", Vector4(0, 0, 0, 0))
	m.set_shader_parameter("marking", MARKINGS.find(str(g.get("marking", ""))))
	var tones := [Color(0.1, 0.08, 0.08), Color(0.3, 0.16, 0.08), Color(0.9, 0.86, 0.74)]
	var tone: Color = tones[clampi(int(g.get("mark_tone", 0)), 0, 2)]
	m.set_shader_parameter("mark_color", Vector4(tone.r, tone.g, tone.b, 1.0))
	m.set_shader_parameter("mark_seed", float(g.get("mark_seed", 0.0)))
	m.set_shader_parameter("frame_size", frame_size)


# ------------------------------------------------------------------ reading them
## The Sky-Fang lens: stats readable once two of the great beasts have fallen.
static func lens(tree: SceneTree) -> bool:
	var session = tree.get_first_node_in_group("forest_session") if tree else null
	if session == null: return false
	var m: Dictionary = session.get("_milestones") if session.get("_milestones") != null else {}
	var fallen := 0
	for boss in ["alpha", "ossuar", "maw"]:
		if bool(m.get(boss, false)): fallen += 1
	return fallen >= 2


## What anyone can see: its temperament, its traits, a mutation's colour.
static func looks(g: Dictionary) -> String:
	if g.is_empty(): return ""
	var parts: Array = [str(g.get("temper", "calm")).capitalize()]
	var mut := str(g.get("mutation", ""))
	if mut != "": parts.push_front(mut.capitalize())
	for t in g.get("traits", []):
		parts.append(str(TRAITS.get(t, {}).get("name", t)))
	return " · ".join(parts)


## With the lens: health, bite and pace against its kind's average.
static func stat_line(g: Dictionary) -> String:
	if g.is_empty(): return ""
	return "Health %d%% · Bite %d%% · Pace %d%%" % [int(round(stat_mult(g, "hp") * 100.0)), int(round(stat_mult(g, "damage") * 100.0)), int(round(stat_mult(g, "speed") * 100.0))]


## Ranks of training left in a stat, and the total (a beast trains a little, never a lot).
static func can_train(g: Dictionary, stat: String) -> bool:
	return int(g.get("train", {}).get(stat, 0)) < TRAIN_MAX
