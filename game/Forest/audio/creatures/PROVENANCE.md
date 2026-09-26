# Creature voices: sources and transformations

All source recordings are CC0. No ARK, Jurassic Park, or commercial-game/movie sound was used.

- Ogrebane, Monster Sound Effects 2 (17 original recorded monster vocal WAVs), CC0: https://opengameart.org/content/monster-sound-effects-2 . Download https://opengameart.org/sites/default/files/monster_sfx_pack_2.zip . License verified on author submission,2026-09-16.
- Breviceps, Chicken clucking (Freesound456803), CC0: https://freesound.org/people/Breviceps/sounds/456803/ . Publicly available HQ preview https://cdn.freesound.org/previews/456/456803_9159316-hq.mp3 used as source. License verified on author submission,2026-09-16.
- CC0 legal terms: https://creativecommons.org/publicdomain/zero/1.0/

Original source archive and recording preserved in art/forest-pass6/audio-source. tools/build_creature_audio.py is the reproducible processing recipe. manifest.json maps each of18 outputs to source, pitch and duration. Dodo uses higher clucking passages, raptor uses quieter lower avian calls, rex uses slowed low growls with short layered echoes, stego uses warm grunts, trike brighter nasal growls, longneck low resonant murmurs. All are stylized fictional creature voices.

Mono 22050 Hz Vorbis exports, low/highpass filtering, gentle attack fades, loudness normalization and peak limiting. Species ambient/attack/hurt variants have spatial attenuation, a four-voice cap, per-creature cooldown and shared 4.5-second ambient spacing. Playback uses existing SFX bus settings. Hurt playback is 6 dB quieter than attack, and raptor calls are another 5 dB quieter. Full decode verification: 18/18 via ffmpeg -v error -i FILE -f null -.
