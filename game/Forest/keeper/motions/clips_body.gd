extends RefCounted
## Whole-body reactions and states: hurt, death, dodge roll, cheer, riding.
## Field reference: res://Forest/keeper/KeeperMotion.gd

static func clips() -> Dictionary:
	return {
		# Four quick frames sized to the 0.3 s Hurt state, read as a hit from the
		# front: 0 the body is knocked back and the arms fly up, eyes shut; 1 the
		# flinch (head ducks, arms pull in); 2-3 recover to the carry pose. The
		# held item is thrown back behind the body so it never covers the face.
		"hurt": {"frames": 4, "duration": 0.32, "hold": "held", "views": {
			"side": [
				{"f": 0, "b": [-2, 0], "hip": [-1, 0], "hd": [-1, 0], "hm": [1, -4], "ho": [3, -4], "fm": [1, -1], "fo": [0, 0], "ta": -150, "tl": "back", "blink": true},
				{"f": 1, "b": [-2, 1], "hip": [-1, 1], "hd": [-1, 1], "hm": [0, -2], "ho": [1, -2], "fm": [1, 0], "ta": -140, "blink": true},
				{"f": 2, "b": [-1, 0], "hip": [0, 0], "hd": [0, 0], "hm": [0, -1], "ho": [0, -1], "fm": [0, 0], "ta": -130, "blink": false},
				{"f": 3, "b": [0, 0], "hm": [0, 0], "ho": [0, 0], "ta": -125},
			],
			"down": [
				{"f": 0, "b": [0, -2], "hip": [0, -1], "hd": [0, 0], "hm": [2, -4], "ho": [-2, -4], "fm": [0, 0], "fo": [0, 0], "ta": -55, "tl": "back", "blink": true, "hv": "side", "hf": true},
				{"f": 1, "b": [0, 1], "hip": [0, 1], "hd": [0, 1], "hm": [1, -1], "ho": [-1, -1], "ta": -65, "blink": true},
				{"f": 2, "b": [0, 0], "hip": [0, 0], "hd": [0, 0], "hm": [0, -1], "ho": [0, -1], "ta": -70, "blink": false, "hv": "down", "hf": false},
				{"f": 3, "hm": [0, 0], "ho": [0, 0]},
			],
			"up": [
				{"f": 0, "b": [0, 1], "hip": [0, 1], "hd": [0, 1], "hm": [2, -4], "ho": [-2, -4], "fm": [0, 0], "fo": [0, 0], "ta": -60, "tl": "back"},
				{"f": 1, "b": [0, 2], "hip": [0, 1], "hm": [1, -2], "ho": [-1, -2], "ta": -65},
				{"f": 2, "b": [0, 1], "hip": [0, 0], "hd": [0, 0], "hm": [0, -1], "ho": [0, -1], "ta": -70},
				{"f": 3, "b": [0, 0], "hm": [0, 0], "ho": [0, 0]},
			],
		}},
		# Stagger, knees buckle, drop, hit the ground (a lossless quarter turn),
		# a small bounce, settle, lie still with the eyes closed. Frame times
		# (durations) give a hang before the fall and a long final hold.
		"death": {"frames": 8, "duration": 1.0, "durations": [1.0, 1.0, 1.0, 1.2, 0.8, 1.0, 1.5, 3.0], "views": {
			"side": [
				{"f": 0, "b": [-1, 0], "hip": [0, 0], "hd": [-1, 0], "hm": [1, -4], "ho": [2, -4], "fm": [0, 0], "fo": [0, 0], "blink": true},
				{"f": 1, "b": [-2, 1], "hip": [-1, 0], "hd": [-1, 1], "hm": [0, -2], "ho": [1, -3], "fm": [1, 0], "blink": false},
				{"f": 2, "b": [-2, 2], "hip": [-1, 1], "hm": [0, 0], "ho": [0, -1], "km": -1, "ko": -1},
				{"f": 3, "b": [-4, 3], "hip": [-2, 2], "hd": [-1, 1], "hm": [0, -3], "ho": [1, -4], "blink": true},
				{"f": 4, "b": [0, 0], "hip": [0, 0], "hd": [0, 0], "hm": [2, 1], "ho": [-1, 1], "fm": [1, 0], "fo": [0, 0], "km": 0, "ko": 0, "rot": -90, "pivot": [32, 40], "blink": true},
				{"f": 5, "b": [1, 0], "hip": [1, 0], "hm": [3, 0], "ho": [0, 0], "fm": [2, 0], "fo": [1, 0]},
				{"f": 6, "b": [0, 0], "hip": [0, 0], "hm": [2, 2], "ho": [-1, 2], "fm": [1, 0], "fo": [0, 0]},
				{"f": 7, "hm": [2, 2], "ho": [-1, 2]},
			],
			"down": [
				{"f": 0, "b": [0, -1], "hip": [0, 0], "hd": [0, 0], "hm": [2, -4], "ho": [-2, -4], "fm": [0, 0], "fo": [0, 0], "blink": true},
				{"f": 1, "b": [-1, 1], "hip": [0, 0], "hd": [-1, 0], "hm": [1, -2], "ho": [-1, -2], "blink": false},
				{"f": 2, "b": [-2, 2], "hip": [-1, 1], "hd": [-1, 1], "hm": [0, 0], "ho": [0, 0]},
				{"f": 3, "b": [-4, 3], "hip": [-2, 2], "hd": [0, 1], "hm": [1, -3], "ho": [-1, -4], "blink": true},
				{"f": 4, "b": [0, 0], "hip": [0, 0], "hd": [0, 0], "hm": [2, 1], "ho": [-2, 1], "rot": -90, "pivot": [32, 40], "blink": true},
				{"f": 5, "b": [1, 0], "hip": [1, 0], "hm": [3, 0], "ho": [-1, 0], "fm": [1, 0], "fo": [1, 0]},
				{"f": 6, "b": [0, 0], "hip": [0, 0], "hm": [3, 2], "ho": [-3, 2], "fm": [0, 0], "fo": [0, 0]},
				{"f": 7, "hm": [3, 2], "ho": [-3, 2]},
			],
			"up": [
				{"f": 0, "b": [0, 1], "hip": [0, 0], "hd": [0, 1], "hm": [2, -4], "ho": [-2, -4], "fm": [0, 0], "fo": [0, 0]},
				{"f": 1, "b": [1, 1], "hip": [0, 0], "hd": [1, 1], "hm": [1, -2], "ho": [-1, -2]},
				{"f": 2, "b": [2, 2], "hip": [1, 1], "hd": [1, 1], "hm": [0, 0], "ho": [0, 0]},
				{"f": 3, "b": [4, 3], "hip": [2, 2], "hd": [0, 1], "hm": [1, -4], "ho": [-1, -3]},
				{"f": 4, "b": [0, 0], "hip": [0, 0], "hd": [0, 0], "hm": [2, 1], "ho": [-2, 1], "rot": 90, "pivot": [32, 40]},
				{"f": 5, "b": [-1, 0], "hip": [-1, 0], "hm": [1, 0], "ho": [-3, 0], "fm": [-1, 0], "fo": [-1, 0]},
				{"f": 6, "b": [0, 0], "hip": [0, 0], "hm": [3, 2], "ho": [-3, 2], "fm": [0, 0], "fo": [0, 0]},
				{"f": 7, "hm": [3, 2], "ho": [-3, 2]},
			],
		}},
		# Dodge roll: crouch, dive into a tuck, three quarter-turns, land in a
		# crouch and spring up. The player moves the body; the clip only has to
		# read as a quick tumble. The tuck keeps the boots out in front so the
		# legs stay readable through the spin.
		"roll": {"frames": 8, "duration": 0.40, "views": {
			"side": [
				{"f": 0, "b": [1, 2], "hip": [0, 1], "hd": [0, 0], "hm": [2, -1], "ho": [2, -1], "fm": [0, 0], "fo": [0, 0], "km": -1, "ko": -1},
				{"f": 1, "b": [1, 4], "hip": [0, 3], "hd": [1, 1], "hm": [3, 0], "ho": [3, 0], "fm": [2, -1], "fo": [3, -1], "rot": 90, "pivot": [32, 32]},
				{"f": 2, "rot": 180},
				{"f": 3, "rot": 270},
				{"f": 4, "b": [1, 3], "hip": [0, 2], "hd": [0, 1], "hm": [3, 1], "ho": [2, 1], "fm": [1, 0], "fo": [1, 0], "rot": 0},
				{"f": 5, "b": [1, 1], "hip": [0, 1], "hd": [0, 0], "hm": [2, -1], "ho": [1, -1], "fm": [0, 0], "fo": [0, 0]},
				{"f": 6, "b": [0, -1], "hip": [0, 0], "hm": [1, -2], "ho": [0, -1], "km": 0, "ko": 0},
				{"f": 7, "b": [0, 0], "hm": [0, 0], "ho": [0, 0]},
			],
			"down": [
				{"f": 0, "b": [0, 2], "hip": [0, 1], "hd": [0, 0], "hm": [-2, 0], "ho": [2, 0], "fm": [0, 0], "fo": [0, 0]},
				{"f": 1, "b": [0, 4], "hip": [0, 3], "hd": [0, 1], "hm": [-3, 2], "ho": [3, 2], "fm": [1, -1], "fo": [-1, -1], "rot": 90, "pivot": [32, 32]},
				{"f": 2, "rot": 180},
				{"f": 3, "rot": 270},
				{"f": 4, "b": [0, 3], "hip": [0, 2], "hd": [0, 1], "hm": [-3, 1], "ho": [3, 1], "fm": [1, 0], "fo": [-1, 0], "rot": 0},
				{"f": 5, "b": [0, 1], "hip": [0, 1], "hd": [0, 0], "hm": [-1, 0], "ho": [1, 0], "fm": [0, 0], "fo": [0, 0]},
				{"f": 6, "b": [0, -1], "hip": [0, 0], "hm": [0, -1], "ho": [0, -1]},
				{"f": 7, "b": [0, 0], "hm": [0, 0], "ho": [0, 0]},
			],
			"up": [
				{"f": 0, "b": [0, 2], "hip": [0, 1], "hd": [0, 0], "hm": [-2, -1], "ho": [2, -1], "fm": [0, 0], "fo": [0, 0]},
				{"f": 1, "b": [0, 4], "hip": [0, 3], "hd": [0, 1], "hm": [-3, 0], "ho": [3, 0], "fm": [1, -1], "fo": [-1, -1], "rot": 90, "pivot": [32, 32]},
				{"f": 2, "rot": 180},
				{"f": 3, "rot": 270},
				{"f": 4, "b": [0, 3], "hip": [0, 2], "hd": [0, 1], "hm": [-3, 0], "ho": [3, 0], "fm": [1, 0], "fo": [-1, 0], "rot": 0},
				{"f": 5, "b": [0, 1], "hip": [0, 1], "hd": [0, 0], "hm": [-1, 0], "ho": [1, 0], "fm": [0, 0], "fo": [0, 0]},
				{"f": 6, "b": [0, -1], "hip": [0, 0], "hm": [0, -1], "ho": [0, -1]},
				{"f": 7, "b": [0, 0], "hm": [0, 0], "ho": [0, 0]},
			],
		}},
		# A happy hop with both arms up (taming success, milestones): dip, spring,
		# a beaming apex, squash on landing, arms float down.
		"cheer": {"frames": 8, "duration": 0.80, "views": {
			"down": [
				{"f": 0, "b": [0, 1], "hip": [0, 1], "hd": [0, 0], "hm": [0, 0], "ho": [0, 0], "fm": [0, 0], "fo": [0, 0]},
				{"f": 1, "b": [0, 2], "hip": [0, 2], "hd": [0, 1], "hm": [0, 1], "ho": [0, 1]},
				{"f": 2, "b": [0, -3], "hip": [0, -3], "hd": [0, 0], "fm": [0, -3], "fo": [0, -3], "hm": [4, -9], "ho": [-4, -9]},
				{"f": 3, "b": [0, -4], "hip": [0, -4], "fm": [0, -4], "fo": [0, -4], "blink": true},
				{"f": 4, "b": [0, -2], "hip": [0, -2], "fm": [0, -2], "fo": [0, -2], "blink": false},
				{"f": 5, "b": [0, 1], "hip": [0, 1], "hd": [0, 1], "fm": [0, 0], "fo": [0, 0], "hm": [4, -7], "ho": [-4, -7]},
				{"f": 6, "b": [0, 0], "hip": [0, 0], "hd": [0, 0], "hm": [2, -4], "ho": [-2, -4]},
				{"f": 7, "hm": [0, 0], "ho": [0, 0]},
			],
			"side": [
				{"f": 0, "b": [0, 1], "hip": [0, 1], "hd": [0, 0], "hm": [0, 0], "ho": [0, 0], "fm": [0, 0], "fo": [0, 0]},
				{"f": 1, "b": [0, 2], "hip": [0, 2], "hd": [0, 1], "hm": [-1, 1], "ho": [-1, 1], "km": -1, "ko": -1},
				{"f": 2, "b": [0, -3], "hip": [0, -3], "hd": [0, 0], "fm": [0, -3], "fo": [0, -3], "hm": [0, -10], "ho": [1, -10], "km": 0, "ko": 0},
				{"f": 3, "b": [0, -4], "hip": [0, -4], "fm": [1, -4], "fo": [-1, -4], "blink": true},
				{"f": 4, "b": [0, -2], "hip": [0, -2], "fm": [0, -2], "fo": [0, -2], "blink": false},
				{"f": 5, "b": [0, 1], "hip": [0, 1], "hd": [0, 1], "fm": [0, 0], "fo": [0, 0], "hm": [0, -8], "ho": [1, -8], "km": -1, "ko": -1},
				{"f": 6, "b": [0, 0], "hip": [0, 0], "hd": [0, 0], "hm": [1, -4], "ho": [1, -4], "km": 0, "ko": 0},
				{"f": 7, "hm": [0, 0], "ho": [0, 0]},
			],
			"up": [
				{"f": 0, "b": [0, 1], "hip": [0, 1], "hd": [0, 0], "hm": [0, 0], "ho": [0, 0], "fm": [0, 0], "fo": [0, 0]},
				{"f": 1, "b": [0, 2], "hip": [0, 2], "hd": [0, 1], "hm": [0, 1], "ho": [0, 1]},
				{"f": 2, "b": [0, -3], "hip": [0, -3], "hd": [0, 0], "fm": [0, -3], "fo": [0, -3], "hm": [2, -10], "ho": [-2, -10]},
				{"f": 3, "b": [0, -4], "hip": [0, -4], "fm": [0, -4], "fo": [0, -4]},
				{"f": 4, "b": [0, -2], "hip": [0, -2], "fm": [0, -2], "fo": [0, -2], "blink": false},
				{"f": 5, "b": [0, 1], "hip": [0, 1], "hd": [0, 1], "fm": [0, 0], "fo": [0, 0], "hm": [2, -8], "ho": [-2, -8]},
				{"f": 6, "b": [0, 0], "hip": [0, 0], "hd": [0, 0], "hm": [1, -4], "ho": [-1, -4]},
				{"f": 7, "hm": [0, 0], "ho": [0, 0]},
			],
		}},
		# Seated astride a mount. Hip lands on cel (32,39), the saddle contract
		# used by MountedAppearance; hands hold the reins.
		"ride": {"frames": 1, "duration": 1.0, "loop": true, "views": {
			"side": [
				{"f": 0, "b": [0, 1], "hip": [0, 1], "hm": [3, -2], "ho": [3, -2], "fm": [2, 0], "fo": [2, 0], "km": 1, "ko": 1},
			],
			"down": [
				{"f": 0, "b": [0, 1], "hip": [0, 1], "hm": [-3, -1], "ho": [3, -1], "fm": [3, -1], "fo": [-3, -1], "km": -1, "ko": 1},
			],
			"up": [
				{"f": 0, "b": [0, 1], "hip": [0, 1], "hm": [-2, -2], "ho": [2, -2], "fm": [3, -1], "fo": [-3, -1], "km": 1, "ko": -1},
			],
		}},
		# Legacy name used by the old Attack state's fallback.
		"swing": {"frames": 8, "duration": 0.32, "hold": "held", "alias": "weapon", "views": {}},
	}
