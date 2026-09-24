extends RefCounted
## Suite teardown for rendered runs: silence every sound and give the audio
## thread time to release it before the suite quits.
##
## The AudioServer frees a stopped playback on a later mix. The regression
## runner (tools/verify_forest.ps1) uses the Dummy audio driver, which mixes
## only every ~90 ms, so music or a click still registered when the tree
## quits is reported as "ERROR: N resources still in use at exit" and fails
## the suite even though every check passed.
##   await preload("res://Tests/quiet_exit.gd").settle(get_tree())

const PLAYER_TYPES := ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]


static func settle(tree: SceneTree) -> void:
	for attempt in 5:
		var manager := tree.root.get_node_or_null("AudioManager")
		if manager and manager.has_method("stop_music"):
			manager.stop_music()
		var busy := false
		for type in PLAYER_TYPES:
			for player in tree.root.find_children("*", type, true, false):
				busy = busy or player.playing
				player.stop()
		# A stopped playback fades out on one mix and is released on the next.
		await tree.create_timer(0.3, true, false, true).timeout
		if not busy:
			return
