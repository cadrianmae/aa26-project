# Attributions

Student: Mae Capacite, C21348423, TU856-4.

This file records the third-party music, sound assets, and code technique
this project draws on, and how each was obtained.

## Music - launch theme

- Work: "An der schonen blauen Donau" (The Blue Danube), Op. 314, by Johann
  Strauss II, 1866. The composition itself is in the public domain, as
  Strauss II died in 1899.
- The arrangement used is the one heard in *Frontier: Elite II* (1993),
  copyright David Braben / Frontier Developments.
- The MIDI sequence was obtained from the Dream-Ware FE2-MIDI package,
  https://www.dream-ware.co.uk/frontier/music/ . That site states it uses
  assets and imagery from the Elite franchise with the permission of Frontier
  Developments plc, for non-commercial purposes. That permission is
  Dream-Ware's own and is not transferable to third parties. The page does
  not name who produced the MIDI sequence itself, and states no redistribution
  terms for the MIDI files it hosts.
- Rendered to Ogg Vorbis with FluidSynth 2.5.4, using the FluidR3_GM
  soundfont (see below).

**This asset is a PLACEHOLDER.** Action item: replace it before submission
with a public-domain or Creative Commons recording of the Blue Danube, for
example from https://musopen.org , to avoid any copyright claim on the
assessed YouTube video arising from the Dream-Ware arrangement's unclear
redistribution terms.

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

## Code and technique

- Steering behaviours adapted from Bryan Duggan's
  `skooter500/miniature-rotary-phone`, `behaviors/` directory.
- The WTPRS algorithm name comes from Duggan's
  `skooter500/UnitySteeringBehaviours`.
- Reynolds, C. W., *Steering Behaviors For Autonomous Characters*,
  https://www.red3d.com/cwr/steer/
- Reynolds, C. W., *Boids*, https://www.red3d.com/cwr/boids/
- The `debug_draw_3d` addon, vendored under `godot/addons/debug_draw_3d/`.
  Copyright (c) 2024 DmitriySalnikov, released under the MIT licence (see
  `godot/addons/debug_draw_3d/LICENSE` for the full text).
