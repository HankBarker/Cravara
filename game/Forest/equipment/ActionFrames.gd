extends RefCounted
## Native authored action sheets. Tool contact uses the same clip timeline.
const DURATIONS := {"axe":.48,"pickaxe":.56,"weapon":.32,"sword":.42,"bow_draw":.40,"bow_release":.24,"fishing_cast":.60,"fishing_reel":.64,"hoe":.56,"net":.52,"bucket":.64,"pet":.60,"pickup":.44,"eat":.72,"craft":.64,"place":.36,"interact":.30,"cheer":.80,"roll":.40}
static func duration(kind: String) -> float:
	return float(DURATIONS.get(kind,.48))
static func contact_ratio(kind: String) -> float:
	return .5 if kind == "weapon" else (.55 if kind == "sword" else (.58 if kind in ["axe","pickaxe"] else .6))
## Every Keeper v2 clip (tools, actions, locomotion) in four facings. The
## rig renders the cels, so the old per-action PNG sheets are no longer read.
static func install(_source: SpriteFrames) -> SpriteFrames:
	return load("res://Forest/keeper/KeeperSkin.gd").base_frames()
