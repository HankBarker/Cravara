extends RefCounted
## What the Keeper is standing on (for footstep dust and foley), read from the
## forest's terrain codes: 0 meadow grass, 1 dirt path, 2 water, 3 dark grass,
## plus timber floors and tilled garden soil laid over them.

## Dust palettes: "puff" is the pale cloud, "bits" the flecks thrown up.
const DUST := {
	"grass": {"puff": Color("e4edbd"), "alpha": 0.74, "bits": [Color("9ccc6c"), Color("c3d67a"), Color("5e7a33")], "blades": true},
	"moss": {"puff": Color("cfdeb2"), "alpha": 0.68, "bits": [Color("74a878"), Color("8fb055"), Color("3f6b4e")], "blades": true},
	"dirt": {"puff": Color("eedfb2"), "alpha": 0.82, "bits": [Color("8a6f3e"), Color("c7a85c"), Color("6e5a34")]},
	"soil": {"puff": Color("d2bb8e"), "alpha": 0.78, "bits": [Color("5e4a32"), Color("8a6f47")]},
	"wood": {"puff": Color("f4e9ca"), "alpha": 0.72, "bits": [Color("b8915c")]},
}
const FOLEY := {"grass": "step_grass", "moss": "step_moss", "dirt": "step_dirt", "soil": "step_dirt", "wood": "step_wood", "water": "step_water"}


static func at(world: Node, session: Node, pos: Vector2) -> String:
	if not is_instance_valid(world):
		return "grass"
	var c: Vector2i = world.to_cell(pos)
	if world.water.has(c):
		return "water"
	if world.floors.has(c):
		return "wood"
	if is_instance_valid(session):
		var garden = session.get("gardening")
		if is_instance_valid(garden) and garden.plots.has(c):
			return "soil"
	match int(world.terrain.get(c, 0)):
		1:
			return "dirt"
		2:
			return "water"
		3:
			return "moss"
	return "grass"


static func dust(surface: String) -> Dictionary:
	return DUST.get(surface, DUST.grass)


static func foley(surface: String) -> String:
	return FOLEY.get(surface, "step_grass")
