extends Node2D
## Licensed sampled voices, positional attenuation and a shared quiet ambient budget.
static var next_ambient_msec:=0
var creature:Node2D
var emitter:AudioStreamPlayer2D
var _ambient_left:=0.0
var _cooldown:=0.0
var _rng:=RandomNumberGenerator.new()
func _ready():
	creature=get_parent();_rng.seed=creature.get_instance_id()
	emitter=AudioStreamPlayer2D.new();emitter.bus="SFX"
	emitter.max_distance=320 if creature.species=="rex" else 250
	emitter.attenuation=1.6;emitter.add_to_group("creature_voices");add_child(emitter)
	_ambient_left=_rng.randf_range(6,24)
func cue_path(cue:String)->String:
	return "res://Forest/audio/creatures/%s-%s.ogg"%[creature.species,cue]
func _process(delta:float):
	_cooldown=maxf(0,_cooldown-delta)
	_ambient_left-=delta
	if _ambient_left<=0:
		_ambient_left=_rng.randf_range(14,30)
		if not creature.is_dead and creature._attack_time<=0 and creature.net_time<=0: play_cue("ambient")
func play_cue(cue:String)->bool:
	if cue not in ["ambient","attack","hurt"] or _cooldown>0 or not is_instance_valid(creature._player): return false
	if creature.global_position.distance_to(creature._player.global_position)>emitter.max_distance: return false
	if cue=="ambient" and Time.get_ticks_msec()<next_ambient_msec: return false
	var count:=0
	for active in get_tree().get_nodes_in_group("creature_voices"):
		if active.playing: count+=1
	if count>=4: return false
	var path:=cue_path(cue)
	if not ResourceLoader.exists(path): return false
	emitter.stream=load(path)
	emitter.volume_db=-18 if cue=="ambient" else (-17 if cue=="hurt" else -11)
	if creature.species=="raptor": emitter.volume_db-=5
	if creature.species=="rex": emitter.volume_db+=2
	emitter.pitch_scale=_rng.randf_range(0.94,1.06)
	_cooldown=0.8 if cue=="hurt" else 1.4
	if cue=="ambient": next_ambient_msec=Time.get_ticks_msec()+4500
	if DisplayServer.get_name()!="headless": emitter.play()
	return true
