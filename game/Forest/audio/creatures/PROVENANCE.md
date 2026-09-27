# Creature voices: sources and transformations

All source recordings are CC0. No ARK, Jurassic Park, or commercial-game/movie sound was used.

- Ogrebane, Monster Sound Effects 2 (17 original recorded monster vocal WAVs), CC0: https://opengameart.org/content/monster-sound-effects-2 . Download https://opengameart.org/sites/default/files/monster_sfx_pack_2.zip . License verified on author submission,2026-09-16.
- Breviceps, Chicken clucking (Freesound456803), CC0: https://freesound.org/people/Breviceps/sounds/456803/ . Publicly available HQ preview https://cdn.freesound.org/previews/456/456803_9159316-hq.mp3 used as source. License verified on author submission,2026-09-16.
- CC0 legal terms: https://creativecommons.org/publicdomain/zero/1.0/

Original source archive and recording preserved in art/forest-pass6/audio-source. tools/build_creature_audio.py is the reproducible processing recipe. manifest.json maps each of18 outputs to source, pitch and duration. Dodo uses higher clucking passages, raptor uses quieter lower avian calls, rex uses slowed low growls with short layered echoes, stego uses warm grunts, trike brighter nasal growls, longneck low resonant murmurs. All are stylized fictional creature voices.

Mono 22050 Hz Vorbis exports, low/highpass filtering, gentle attack fades, loudness normalization and peak limiting. Species ambient/attack/hurt variants have spatial attenuation, a four-voice cap, per-creature cooldown and shared 4.5-second ambient spacing. Playback uses existing SFX bus settings. Hurt playback is 6 dB quieter than attack, and raptor calls are another 5 dB quieter. Full decode verification: 18/18 via ffmpeg -v error -i FILE -f null -.

## ElevenLabs voices (pass 16)

Generated with ElevenLabs sound effects (text to sound effects) through the ElevenLabs MCP connector on 2026-09-26, for the game's owner and on the owner's own ElevenLabs account. No third-party recordings are involved. Every request used the prompts, durations and cue lists in `tools/audio/elevenlabs_sfx.py`: text = the `VOICES` prompt + `STYLE`, `duration_seconds` = the table's seconds, one generation per take (none were retried).

Licence note: the account was on ElevenLabs' free tier when these were made (the Music API refused it as a free account). ElevenLabs' pricing page lists the commercial licence from the Starter plan up, so confirm the licence terms before a commercial release.

What was made: 75 clips in `v2/`, named `<species>-<cue>-<n>.mp3`, the naming `elevenlabs_sfx.py` and CreatureAudio use.
- New voices for carno, yuty, dimetrodon, anky, proto, compy, utah, deino, sucho and spino: ambient x2, roar x1, attack x2, hurt x1, death x1. Cues a species has no `VOICES` entry for were skipped (anky and proto have no attack, compy has no roar).
- A death cry (`death-1`) for raptor, rex, allo, trike, stego, longneck, parasaur, dodo, lystro and ossuar. These keep the older CC0 voices above for their other cues.

Processing, per clip, with ffmpeg 8.1.2 (the ElevenLabs originals were 44.1 kHz stereo MP3s):
1. Downmix to mono.
2. Trim leading and trailing silence below -50 dBFS (`silenceremove`, peak detection, run on the clip and on its reverse).
3. 10 ms linear fade-in and 60 ms linear fade-out.
4. Loudness: two-pass `loudnorm`. Pass 1 measures (I=-16, TP=-1.5, LRA=50). Pass 2 feeds the measured values back with `linear=true`, so each clip gets one fixed gain toward -16 LUFS integrated, measured on the mono signal. Pass 2 runs with TP=0 only so that loudnorm stays in linear mode. The -1.5 dBTP ceiling is enforced on the encoded MP3 instead: its true peak is measured with `ebur128`, and the gain is lowered if needed. The gain is also re-aimed if MP3 encoding moved the loudness. Where the ceiling binds (16 clips with sharp bites or clicks), the clip is left quieter than -16 LUFS rather than limited or compressed.
5. Resample to 44.1 kHz (soxr). Encode as 128 kbps CBR mono MP3 with libmp3lame, with metadata stripped.
6. Verification: `ffmpeg -v error -i FILE -f null -` prints nothing for all 75 files. Durations come from ffprobe. Every file's true peak is at or below -1.5 dBTP.

| File | Seconds | Integrated LUFS | True peak dBTP |
|---|---|---|---|
| v2/carno-ambient-1.mp3 | 0.960 | -17.7 | -1.86 |
| v2/carno-ambient-2.mp3 | 1.347 | -16.0 | -2.67 |
| v2/carno-roar-1.mp3 | 2.096 | -16.0 | -4.63 |
| v2/carno-attack-1.mp3 | 1.036 | -19.4 | -1.53 |
| v2/carno-attack-2.mp3 | 1.020 | -18.2 | -1.60 |
| v2/carno-hurt-1.mp3 | 1.000 | -15.9 | -4.19 |
| v2/carno-death-1.mp3 | 2.560 | -16.0 | -5.82 |
| v2/yuty-ambient-1.mp3 | 1.819 | -16.0 | -6.14 |
| v2/yuty-ambient-2.mp3 | 1.441 | -16.0 | -6.27 |
| v2/yuty-roar-1.mp3 | 2.760 | -16.0 | -5.00 |
| v2/yuty-attack-1.mp3 | 1.073 | -23.6 | -1.65 |
| v2/yuty-attack-2.mp3 | 1.200 | -23.6 | -1.61 |
| v2/yuty-hurt-1.mp3 | 1.280 | -16.0 | -3.90 |
| v2/yuty-death-1.mp3 | 3.200 | -16.0 | -5.18 |
| v2/dimetrodon-ambient-1.mp3 | 1.725 | -18.3 | -1.64 |
| v2/dimetrodon-ambient-2.mp3 | 1.852 | -18.6 | -1.68 |
| v2/dimetrodon-roar-1.mp3 | 1.173 | -16.0 | -5.87 |
| v2/dimetrodon-attack-1.mp3 | 1.000 | -15.9 | -4.37 |
| v2/dimetrodon-attack-2.mp3 | 0.760 | -16.0 | -4.39 |
| v2/dimetrodon-hurt-1.mp3 | 0.880 | -16.0 | -3.92 |
| v2/dimetrodon-death-1.mp3 | 1.510 | -15.9 | -4.54 |
| v2/anky-ambient-1.mp3 | 1.324 | -18.2 | -1.62 |
| v2/anky-ambient-2.mp3 | 1.154 | -20.6 | -1.64 |
| v2/anky-roar-1.mp3 | 1.760 | -16.0 | -7.05 |
| v2/anky-hurt-1.mp3 | 1.000 | -16.0 | -4.28 |
| v2/anky-death-1.mp3 | 2.400 | -16.0 | -6.94 |
| v2/proto-ambient-1.mp3 | 1.360 | -16.0 | -3.77 |
| v2/proto-ambient-2.mp3 | 0.527 | -16.0 | -5.30 |
| v2/proto-roar-1.mp3 | 0.845 | -16.0 | -5.48 |
| v2/proto-hurt-1.mp3 | 0.680 | -16.0 | -8.38 |
| v2/proto-death-1.mp3 | 1.200 | -16.0 | -6.99 |
| v2/compy-ambient-1.mp3 | 1.200 | -16.0 | -5.24 |
| v2/compy-ambient-2.mp3 | 1.185 | -16.0 | -2.70 |
| v2/compy-attack-1.mp3 | 0.680 | -15.9 | -5.95 |
| v2/compy-attack-2.mp3 | 0.680 | -16.0 | -4.85 |
| v2/compy-hurt-1.mp3 | 0.480 | -16.0 | -5.42 |
| v2/compy-death-1.mp3 | 0.626 | -16.0 | -4.08 |
| v2/utah-ambient-1.mp3 | 1.317 | -18.7 | -1.65 |
| v2/utah-ambient-2.mp3 | 1.600 | -16.0 | -4.50 |
| v2/utah-roar-1.mp3 | 1.600 | -16.0 | -9.24 |
| v2/utah-attack-1.mp3 | 1.000 | -16.0 | -6.00 |
| v2/utah-attack-2.mp3 | 1.000 | -16.1 | -5.42 |
| v2/utah-hurt-1.mp3 | 0.880 | -16.0 | -8.61 |
| v2/utah-death-1.mp3 | 1.760 | -16.0 | -6.80 |
| v2/deino-ambient-1.mp3 | 1.474 | -26.5 | -1.52 |
| v2/deino-ambient-2.mp3 | 0.561 | -18.1 | -1.70 |
| v2/deino-roar-1.mp3 | 1.183 | -16.0 | -8.85 |
| v2/deino-attack-1.mp3 | 0.880 | -16.0 | -5.78 |
| v2/deino-attack-2.mp3 | 0.880 | -16.0 | -6.59 |
| v2/deino-hurt-1.mp3 | 0.800 | -16.0 | -3.32 |
| v2/deino-death-1.mp3 | 1.600 | -16.0 | -6.05 |
| v2/sucho-ambient-1.mp3 | 2.200 | -16.0 | -2.15 |
| v2/sucho-ambient-2.mp3 | 1.432 | -16.0 | -4.75 |
| v2/sucho-roar-1.mp3 | 1.799 | -16.0 | -4.67 |
| v2/sucho-attack-1.mp3 | 0.833 | -17.0 | -1.68 |
| v2/sucho-attack-2.mp3 | 0.724 | -16.0 | -2.40 |
| v2/sucho-hurt-1.mp3 | 1.000 | -16.0 | -5.22 |
| v2/sucho-death-1.mp3 | 2.028 | -16.0 | -5.18 |
| v2/spino-ambient-1.mp3 | 2.559 | -16.0 | -5.37 |
| v2/spino-ambient-2.mp3 | 2.375 | -16.0 | -4.19 |
| v2/spino-roar-1.mp3 | 2.999 | -16.0 | -8.80 |
| v2/spino-attack-1.mp3 | 1.280 | -17.1 | -1.54 |
| v2/spino-attack-2.mp3 | 1.280 | -16.2 | -1.65 |
| v2/spino-hurt-1.mp3 | 0.840 | -16.0 | -7.27 |
| v2/spino-death-1.mp3 | 3.100 | -16.0 | -6.07 |
| v2/raptor-death-1.mp3 | 1.504 | -17.9 | -1.57 |
| v2/rex-death-1.mp3 | 3.480 | -16.0 | -3.65 |
| v2/allo-death-1.mp3 | 2.560 | -16.3 | -1.66 |
| v2/trike-death-1.mp3 | 2.095 | -16.1 | -1.68 |
| v2/stego-death-1.mp3 | 2.290 | -16.0 | -4.37 |
| v2/longneck-death-1.mp3 | 3.480 | -16.0 | -6.30 |
| v2/parasaur-death-1.mp3 | 2.014 | -16.0 | -5.66 |
| v2/dodo-death-1.mp3 | 1.000 | -16.0 | -6.75 |
| v2/lystro-death-1.mp3 | 1.000 | -18.5 | -1.70 |
| v2/ossuar-death-1.mp3 | 3.480 | -16.0 | -4.00 |
