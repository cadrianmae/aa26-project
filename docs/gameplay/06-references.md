# References

[Back to contents](index.md) | Previous: [The opposition](05-opposition.md)

---

## Steering behaviours

- Reynolds, C. W. — *Steering Behaviors For Autonomous Characters*:
  <https://www.red3d.com/cwr/steer/>
- Reynolds, C. W. — *Boids*: <https://www.red3d.com/cwr/boids/>
- Reynolds, C. W. — *Flocks, Herds, and Schools: A Distributed Behavioral
  Model*, SIGGRAPH 1987

## Module material

- Duggan, B. — `skooter500/miniature-rotary-phone`, `behaviors/` directory.
  The canonical implementation of every behaviour used here: seek, arrive,
  flee, pursue, offset pursue, the flocking triple, the spatial hash, and the
  finite state machine.
- Duggan, B. — `skooter500/UnitySteeringBehaviours`. Source of the WTPRS name,
  from the `CalculationMethods` enum: `WeightedTruncatedSum`,
  `WeightedTruncatedRunningSumWithPrioritisation`, `PrioritisedDithering`.
- Assignment brief and marking scheme:
  [`../assignment-spec.md`](../assignment-spec.md)

## Visual reference

- *Elite* (Acornsoft, 1984) — wireframe rendering, and the source of the
  visual language this artefact borrows.

## Audio

The music is placeholder. Full licensing detail, including the caveat that the
current arrangements are not cleared for redistribution and must be replaced
before submission, is in [`../../ATTRIBUTIONS.md`](../../ATTRIBUTIONS.md).

## Engine and tooling

- Godot 4.7, GDScript
- `debug_draw_3d` — gizmo drawing, vendored under `godot/addons/`
- FluidSynth and the Fluid (R3) soundfont — used to render the placeholder
  audio. See `ATTRIBUTIONS.md` for the MIT notice.

## Project documents

- [Design spec](../superpowers/specs/2026-08-27-swarm-command-rts-design.md) —
  class architecture, the two-tier FSM, build strategy
- [Phase 2 plan](../superpowers/plans/2026-08-29-phase-2-flocking-and-fsm.md) —
  flocking, state machine, flee reflex
