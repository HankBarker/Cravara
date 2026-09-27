# Biome music (passes 16 and 17)

Each land plays its own music (`ForestPlaytest.BIOME_MUSIC`), crossfading over
1.8 s as the keeper walks between lands (`AudioManager.play_music`). Pass 17
gave each land a playlist: one tune plays out, then the next starts
(`AudioManager.music_finished` → `ForestPlaytest.biome_music(true)`). A land
with a single tune loops it. A tune picks up where it left off when the keeper
comes back. The boss fights share `BOSS_MUSIC` (`ForestPlaytest.fight_music`).

All tracks are Hank's own Cravara music. The pass 16 tracks came from
`assets_raw/Music/`, and the pass 17 tracks from his `Cravera Folder/Music`.
Pass 17 dropped the two placeholders made from older tracks (`bonelands.mp3`
and `boss.mp3`, a slowed and a sped-up copy). Hank's new tracks took their
places.

To add a tune, drop the file here and add it to its land's `BIOME_MUSIC` list.
The second number is the tune's level against the others, in dB. It comes from
a loudness measurement, so every track plays at about the same loudness.

| Land | File | Source (Hank's) | Level (dB) |
|---|---|---|---|
| The plains (forest) | `../forest-plains.mp3` | Travel Music (Plains) | 0.0 |
| | `sparse-wandering-melody.mp3` | Sparse Wandering Melody | +1.4 |
| The Mirefen Bog | `prehistoric-bog.mp3` | Prehistoric Bog | +1.4 |
| | `jungle-deep.mp3` | Jungle Deep | +1.7 |
| | `prehistoric-bog-2.mp3` | Prehistoric Bog (1) | +0.8 |
| | `bog.mp3` | Travel Music (Jungle) | -1.8 |
| The Sunscar Dunes | `des-enigme.mp3` | Des enigme | +1.9 |
| | `../cravara-ost.mp3` | Cravara OST (also the intro's) | +0.8 |
| The Pale Lands | `volcanic-drones.mp3` | Volcanic Drones | +1.4 |
| | `prehistoric-unease.mp3` | Prehistoric Unease | +2.6 |
| The Bonelands | `prehistoric-stalking.mp3` | Prehistoric Stalking | -1.5 |
| | `untitled.mp3` | Untitled | +1.2 |
| Underground (caves) | `../boss-echoes.mp3` | Travel Music (Cave) | -0.6 |
| | `prehistoric-stalking-2.mp3` | Prehistoric Stalking (1) | -0.8 |
| Boss fights | `the-final-rumble.mp3` | The Final Rumble | 0.0 |

The new files are unchanged copies, only renamed to the project's
lower-case-with-dashes style.
