# CombatMath.gd - shared combat math so every damage path agrees.
# class_name makes these callable anywhere as CombatMath.mitigate(...).
class_name CombatMath
extends RefCounted

# Percentage-based armor mitigation. Replaces the old flat `damage - defense`,
# which walls out as armor climbs (a 14-damage hit vs 22 defense chipped to 1).
# With this curve every point of defense has smooth diminishing returns and
# high-tier armor stays meaningful without ever making a hit do nothing:
#     defense   0 -> 100% taken
#     defense  50 ->  67% taken
#     defense 100 ->  50% taken
#     defense 200 ->  33% taken
# A connecting hit always deals at least 1.
static func mitigate(raw: int, defense: int) -> int:
	if raw <= 0:
		return 0
	var d: float = float(maxi(defense, 0))
	var dealt: float = float(raw) * 100.0 / (100.0 + d)
	return maxi(1, int(round(dealt)))
