# Creature workers, combat cues and audio

Implemented practical active-time work for stegosaurus (wild trees), triceratops (wild berries/fiber), and dodo (one egg each active minute). Work home and chest assignment are exposed to the command UI. Cargo capacity is 12; workers return and insert one item at a time without touching existing contents. Full chests retain cargo. Walls prevent remote deposits, placed structures are excluded from gathering, and saved cargo/home/chest/egg timer resume without offline production. Carried cargo drops on death.

Followers use distinct surrounding positions and a periodically rebuilt local path around current solid props. Workers use the same routing. New walls are therefore respected without rebuilding a navigation mesh. Large distant routes retain direct/local steering; this is not a global colony simulation.

Combat now has a directional warm anticipation marker and brief ivory strike lines rather than a generic red ground circle. Harvesting uses a separate 0.48-second aimed contact/follow-through pose, with quiet positional wood or vegetation sound on the actual resource hit. It never sets a combat target or damage timer. Original dinosaur animation sheets are unchanged.

Six species each have ambient, attack and hurt samples. The CC0 source links, authors and processing recipe are documented in `game/Forest/audio/creatures/PROVENANCE.md`. Runtime playback has spatial attenuation, a four-voice cap, cooldowns and a shared ambient budget. Hurt is 6 dB below attacks; raptor is another 5 dB lower. All 18 Ogg files fully decoded with ffmpeg. Quiet bird source segments were replaced after an amplitude audit found an almost silent raptor hurt passage.

## Verification

- ForestWorkersPass6: 62 checks, 0 failures. Includes actual physics travel around a newly placed wall, harvesting a full load, walking back and depositing; capacity, save restoration, existing food conservation, wall/full-chest safety, egg active timer, all 18 sound resources, per-species cooldown/quiet hurt/distance limits, aimed gathering contact poses, material sound and animation expiry without duplicate yield or combat hits.
- ForestCreaturesTest: 73 assertions, 0 failures.
- ForestAIPass2: 19 checks, 0 failures.
- `combat-anticipation.png` and `combat-strike.png`: inspected actual rendered scene; direction/impact visible and no red ring.
- `creature-engine-audition.mp3`: actual Godot Master-bus capture, ordered dodo, raptor, stego, trike, longneck, rex attacks. Captured peak 0.111691 (~-19.0 dBFS); clean full decode. Useful for human subjective listening and final volume preference review; a successful decode and amplitude audit alone do not establish artistic sound quality.

All runtime tests use isolated no-save playtest mode. The user's journey was not changed.
