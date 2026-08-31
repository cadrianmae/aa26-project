# Attributions

Student: Mae Capacite, C21348423, TU856-4.

This file records the third-party music, sound assets, and code technique
this project draws on, and how each was obtained.

## Music - phase themes

Seven tracks are assigned across the game's phases, one per phase, so the
owner can audition them in the editor before the game logic that triggers
each phase is written. All seven share the same source and rendering
pipeline, described once below rather than per track.

- LAUNCH: `blue_danube.ogg` - "An der schonen blauen Donau" (The Blue
  Danube), Op. 314, by Johann Strauss II, 1866. Public domain; Strauss II
  died in 1899.
- HARVEST: `jupiter.ogg` - "Jupiter, the Bringer of Jollity", from *The
  Planets*, Op. 32, by Gustav Holst, 1914-1916. Public domain; Holst died
  in 1934.
- COMBAT: `ride_of_the_valkyries.ogg` - "Ride of the Valkyries", from *Die
  Walkure*, by Richard Wagner, 1856. Public domain; Wagner died in 1883.
- PATROL: `great_gate_of_kiev.ogg` - "The Great Gate of Kiev", from
  *Pictures at an Exhibition*, by Modest Mussorgsky, 1874. Public domain;
  Mussorgsky died in 1881.
- FLEE: `baba_yagas_hut.ogg` - "The Hut on Fowl's Legs (Baba Yaga)", from
  *Pictures at an Exhibition*, by Modest Mussorgsky, 1874. Public domain;
  Mussorgsky died in 1881.
- VICTORY: `hall_of_the_mountain_king.ogg` - "In the Hall of the Mountain
  King", from *Peer Gynt*, Op. 23, by Edvard Grieg, 1875. Public domain;
  Grieg died in 1907.
- DEFEAT: `night_on_the_bare_mountain.ogg` - "Night on Bare Mountain", by
  Modest Mussorgsky, 1867. Public domain; Mussorgsky died in 1881.

For all seven:

- The arrangements used are Frontier's: the ones heard in *Frontier: Elite
  II* (1993), copyright David Braben / Frontier Developments.
- The MIDI sequences were obtained from the Dream-Ware FE2-MIDI package,
  https://www.dream-ware.co.uk/frontier/music/ . That site states it uses
  assets and imagery from the Elite franchise with the permission of Frontier
  Developments plc, for non-commercial purposes. That permission is
  Dream-Ware's own and is not transferable to third parties. The page does
  not name who produced the MIDI sequences themselves, and states no
  redistribution terms for the MIDI files it hosts.
- Rendered to Ogg Vorbis with FluidSynth 2.5.4, using the FluidR3_GM
  soundfont (see below), at a render sample rate of 11.025 kHz.

**This set is a PLACEHOLDER.** Action item: replace all seven before
submission with public-domain or Creative Commons recordings of the same
works, for example from https://musopen.org , to avoid any copyright claim
on the assessed YouTube video arising from the Dream-Ware arrangements'
unclear redistribution terms.

## Soundfont

Fluid (R3) General MIDI soundfont, copyright (c) 2000-2002, 2008 Frank Wen.
Released under the MIT licence. Full notice, as required by the licence to
accompany derivative distribution:

```
Copyright (c) 2000-2002, 2008 Frank Wen <getfrank@gmail.com>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
```

## Not used, and deliberately so

The two original Frontier themes, "Frontier Main Theme" and "Frontier Second
Theme", composed by Dave Lowe, were deliberately excluded. Unlike the
classical arrangements used above, they have no public-domain underlying
composition, so there is no path to a clean, attributable replacement.

## Designs referenced

The setting is a spin-off of Elite Dangerous, and two of its designs are
referenced visually. Both are Frontier Developments intellectual property.
Nothing here reuses their assets: every mesh in `blender/` is original
geometry, built from scratch in a script, interpreting a silhouette from
publicly published reference images.

- **Thargoid ships and lore** -- Thargoids, Thargoid Interceptors, Thargons,
  Thargoid Barnacles and Meta-Alloys. The Matriarch and the drones are
  original designs in that visual language, not copies of specific ships.
- **Federation Farragut Battle Cruiser** -- the wreck that forms the map's
  anti-xeno hazard is a low-poly interpretation of its silhouette. 72
  triangles against the original's detailed model; the resemblance is the
  outline only.

This is a non-commercial student artefact for CMPU 4031, distributed for
assessment. No Frontier Developments asset, texture, mesh or audio file is
included in this repository.

## Sound

The Matriarch's engine and the swarm's roar are **synthesised at run time**,
not sampled. Their frequencies and levels come from FFT analysis of Elite
Dangerous reference recordings; the synthesis is original and no Frontier
audio asset is included in this repository. Method and measurements are in
[`docs/audio/analysis.md`](docs/audio/analysis.md).

## Code and technique

- Steering behaviours adapted from Bryan Duggan's
  `skooter500/miniature-rotary-phone`, `behaviors/` directory.
- The WTPRS algorithm name comes from Duggan's
  `skooter500/UnitySteeringBehaviours`.
- Reynolds, C. W., *Steering Behaviors For Autonomous Characters*,
  https://www.red3d.com/cwr/steer/
- Reynolds, C. W., *Boids*, https://www.red3d.com/cwr/boids/
- The rival commander's decision-making is a utility system, following Dave
  Mark's Infinite Axis Utility System: actions scored by independent weighted
  considerations, multiplied so any one can veto, with the count compensated
  for. https://www.gameai.com/iaus.php
- The `debug_draw_3d` addon, vendored under `godot/addons/debug_draw_3d/`.
  Copyright (c) 2024 DmitriySalnikov, released under the MIT licence (see
  `godot/addons/debug_draw_3d/LICENSE` for the full text).
