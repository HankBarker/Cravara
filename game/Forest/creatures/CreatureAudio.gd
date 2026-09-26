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
	# The big hunters carry: a rex is heard well before it's seen.
	emitter.max_distance={"rex":420,"alpha":400,"allo":330,"ossuar":460,"parasaur":330,"carno":400,"yuty":440,"spino":460,"sucho":330,"utah":330}.get(creature.species,250)
	emitter.attenuation=1.6;emitter.add_to_group("creature_voices");add_child(emitter)
	_ambient_left=_rng.randf_range(6,24)
## Pass 12's beasts borrow a kin's voice, pitched to suit: the Scarhorn a
## deeper allosaur, the Ashmane a rex dropped low, the dimetrodon a hissing
## allosaur, the ankylosaur a trike's bellow, the protoceratops a lystro's
## squawk, the compy a raptor's chirp pitched up.
const VOICE:={"carno":["allo",0.84],"yuty":["rex",0.78],"dimetrodon":["allo",1.22],"anky":["trike",0.76],"proto":["lystro",0.88],"compy":["raptor",1.6],
	# Pass 13: the Sandblade a deep raptor's shriek, the deinonychus a raptor's
	# call, the Suchomimus a hissing allosaur, the spinosaur a rex pitched up.
	"utah":["raptor",0.74],"deino":["raptor",0.9],"sucho":["allo",1.12],"spino":["rex",0.9]}
## Pass 15: each species' own voice (tools/audio/elevenlabs_sfx.py), several
## takes of each cue so a herd never repeats itself; the old borrowed voices
## where there's none yet.
static var _takes:={}
func own_takes(cue:String)->Array:
	var key:="%s-%s"%[creature.species,cue]
	if not _takes.has(key):
		var found:=[]
		for n in range(1,5):
			var path:="res://Forest/audio/creatures/v2/%s-%d.mp3"%[key,n]
			if ResourceLoader.exists(path): found.append(path)
		_takes[key]=found
	return _takes[key]
func cue_path(cue:String)->String:
	var own:=own_takes(cue)
	if not own.is_empty(): return own[_rng.randi()%own.size()]
	var who:String=VOICE[creature.species][0] if VOICE.has(creature.species) else creature.species
	return "res://Forest/audio/creatures/%s-%s.ogg"%[who,cue]
func _process(delta:float):
	_cooldown=maxf(0,_cooldown-delta)
	_ambient_left-=delta
	if _ambient_left<=0:
		# Raptors call to each other often; the rest now and then.
		_ambient_left=_rng.randf_range(7,16) if creature.species=="raptor" else _rng.randf_range(14,30)
		if not creature.is_dead and creature._attack_time<=0 and creature.net_time<=0: play_cue("ambient")
func play_cue(cue:String)->bool:
	# A death cry always sounds (pass 15).
	if cue=="death" and own_takes("death").is_empty(): return false
	if cue not in ["ambient","attack","hurt","roar","death"] or (_cooldown>0 and cue!="death") or not is_instance_valid(creature._player): return false
	if creature.global_position.distance_to(creature._player.global_position)>emitter.max_distance: return false
	if cue=="ambient" and Time.get_ticks_msec()<next_ambient_msec: return false
	var count:=0
	for active in get_tree().get_nodes_in_group("creature_voices"):
		if active.playing: count+=1
	if count>=4 and cue!="death": return false
	var path:=cue_path(cue)
	# A species without its own roar roars with its attack call.
	if cue=="roar" and not ResourceLoader.exists(path): path=cue_path("attack")
	if not ResourceLoader.exists(path): return false
	emitter.stream=load(path)
	emitter.volume_db=-18 if cue=="ambient" else (-17 if cue=="hurt" else (-8 if cue=="roar" else (-10 if cue=="death" else -11)))
	if creature.species=="raptor": emitter.volume_db-=1
	if creature.species in ["rex","alpha"]: emitter.volume_db+=2
	# A species' own voice is its own pitch; a borrowed one is pitched to suit.
	var borrowed:bool=VOICE.has(creature.species) and own_takes(cue).is_empty()
	emitter.pitch_scale=_rng.randf_range(0.94,1.06)*(float(VOICE[creature.species][1]) if borrowed else 1.0)
	# A baby sounds smaller.
	if creature.get("baby")==true: emitter.pitch_scale*=1.35
	_cooldown=0.8 if cue=="hurt" else (2.2 if cue=="roar" else 1.4)
	if cue=="ambient": next_ambient_msec=Time.get_ticks_msec()+4500
	if DisplayServer.get_name()!="headless": emitter.play()
	return true
