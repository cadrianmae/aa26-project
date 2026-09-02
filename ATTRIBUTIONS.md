# Attributions

Student: Mae Capacite, C21348423, TU856-4.

This file records the third-party music, sound assets, and code technique this project draws on, and how each was obtained.

## Music

Three original tracks, composed for this project:

| Track                      | Used for                |
| -------------------------- | ----------------------- |
| `mainmaenu.ogg`            | LAUNCH, VICTORY, DEFEAT |
| `maegameresource.ogg`      | HARVEST, PATROL         |
| `musicforaspacebattle.ogg` | COMBAT, FLEE            |

Composed by **My Girlfriend**, and used with her permission. Not sourced from any library, sample pack or existing recording; written for this artefact. Supplied as 11.025 kHz stereo WAV and converted here to Ogg Vorbis for the engine.

Three tracks cover seven phases, paired by mood rather than stretched one per phase: the calm bookends share a theme, the economy shares a theme, and the two fight phases share a theme.

## Music that was removed before submission

An earlier build used seven public-domain classical works rendered from MIDI sequences obtained from the Dream-Ware FE2-MIDI package. The underlying compositions are public domain, but the _arrangements_ were Frontier's, from _Frontier: Elite II_ (1993), and the package stated no redistribution terms for the MIDI files themselves.

Those seven tracks were replaced rather than risk an unclear claim on an assessed public video. This is recorded rather than quietly deleted because the reasoning is the point: the compositions being out of copyright did not make somebody else's arrangement of them free to redistribute.

## Not used, and deliberately so

The two original Frontier themes, "Frontier Main Theme" and "Frontier Second Theme", composed by Dave Lowe, were never used. They have no public-domain underlying composition, so there was no path to a clean, attributable version of them.

## Designs referenced

The setting is a spin-off of Elite Dangerous, and two of its designs are referenced visually. Both are Frontier Developments intellectual property. Nothing here reuses their assets: every mesh in `blender/` is original geometry, built from scratch in a script, interpreting a silhouette from publicly published reference images.

- **Thargoid ships and lore** -- Thargoids, Thargoid Interceptors, Thargons, Thargoid Barnacles and Meta-Alloys. The Matriarch and the drones are original designs in that visual language, not copies of specific ships.
- **Federation Farragut Battle Cruiser** -- the wreck that forms the map's obstacle is a low-poly interpretation of its silhouette. 72 triangles against the original's detailed model; the resemblance is the outline only.

This is a non-commercial student artefact for CMPU 4031, distributed for
assessment. No Frontier Developments asset, texture, mesh or audio file is
included in this repository.

## Code and technique

- Steering behaviours adapted from Bryan Duggan's `skooter500/miniature-rotary-phone`, `behaviors/` directory.
- The WTPRS algorithm name comes from Duggan's `skooter500/UnitySteeringBehaviours`.
- Reynolds, C. W., _Steering Behaviors For Autonomous Characters_, https://www.red3d.com/cwr/steer/
- Reynolds, C. W., _Boids_, https://www.red3d.com/cwr/boids/
- The rival commander's decision-making is a utility system, following Dave Mark's Infinite Axis Utility System: actions scored by independent weighted considerations, multiplied so any one can veto, with the count compensated for. https://www.gameai.com/iaus.php
- The `debug_draw_3d` addon, vendored under `godot/addons/debug_draw_3d/`. Copyright (c) 2024 DmitriySalnikov, released under the MIT licence (see `godot/addons/debug_draw_3d/LICENSE` for the full text).
