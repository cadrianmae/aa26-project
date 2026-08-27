# Hybrid Bio-Tech Swarm Command

**CMPU 4031 Autonomous Agents — Artifact 2026**
**Author:** Mae Capacite (C21348423)
**Engine:** Godot 4.6 (3D)

> Working title. A 3D space combat sandbox where a living bio-tech ship
> commands a swarm of semi-autonomous creatures as wingmen against a
> symmetric AI opponent.

---

## Concept

A hybrid bio-tech vessel fights in open 3D space. It does not fight alone:
the player deploys a **swarm** of small living-metal creatures that behave
like loyal wingmen — flocking, hunting, fleeing, and regrouping with a mind
of their own. The enemy is an AI commander with the **same** capabilities,
making the match a mirror duel of two swarm-commanding ships.

The swarm is meant to read as *alive*, not mechanical: it holds formation,
reacts with fear to enemy fire, scatters, and re-coheres — an
anthropomorphic lifeform expressed through emergent motion rather than a
face.

## Player Experience

- **Fly and fight your own ship** — manoeuvre in 3D and fire your own weapon.
- **Deploy the swarm** on a cooldown. Units are a limited, precious resource.
- **Two swarm modes:**
  - `FOLLOW` — the swarm holds a defensive formation around your ship and
    intercepts incoming threats.
  - `ATTACK` — when you designate an enemy within range, the swarm breaks
    off, pursues, and engages it while you keep manoeuvring.
- **Manage the swarm as a resource** — each unit has its own health and can
  be destroyed individually. Lost units replenish only after a cooldown, so
  the player must balance offence against defence.

## The Enemy

A symmetric **AI commander**: its own ship, its own swarm, the same two
modes and the same steering behaviours. Built from the same classes as the
player's side via a faction/allegiance flag (build once, instantiate twice).
It runs a simple high-level decision loop — advance, engage, retreat — so it
behaves as a genuine autonomous agent rather than a scripted dummy.

## Win Condition

Destroy the enemy commander ship. Losing your own ship ends the match.

---

## Autonomous-Agent Techniques

Mapped to CMPU 4031 course material:

| Technique | Where it appears |
|---|---|
| Steering behaviours (seek, arrive, pursue, flee) | Every swarm unit |
| Flocking (separation, alignment, cohesion) | `FOLLOW` formation + regroup |
| Obstacle avoidance | Swarm navigation around battlefield hazards |
| Finite State Machines (two tiers) | Swarm mode (`FOLLOW`/`ATTACK`) + per-unit (`SEEK`/`PURSUE`/`FLEE`/`DETONATE`) |
| Autonomous decision-making | Enemy AI commander (advance/engage/retreat) |
| Signals / event coordination | Commander-to-swarm "communication" |

## Planned System Design

Indicative classes (subject to refinement during implementation):

- `SteeringBehaviour` — base for reusable steering forces
- `Munition` (swarm unit) — steering + health + per-unit FSM
- `Swarm` — deploy/replenish, mode switching, formation, target designation
- `Ship` — player/enemy vessel, movement + weapon
- `CommanderAI` — enemy high-level decision loop
- `Target` / hazard nodes — obstacles and designatable enemies

---

## Grade-1 Coverage Checklist

Tracked against the marking scheme (`docs/assignment-spec.md`). `[OK]` =
covered by the core concept; `[TODO]` = additive work to secure the band.

### Axis 1 — Groovyness (visuals & sound)

- `[TODO]` **Sound design** — engine hum, swarm deploy pulse, lock-on chirp,
  unit death, enemy fire. Purposeful, not decorative.
- `[TODO]` **Visual VFX** — bio-tech glow (custom shader), exhaust trails
  (particles), death-burst particles, subtle post-processing.
- `[TODO]` **Name + identity** — name the swarm species and both commander
  ships; give the lifeform a personality the brief can point to.
- `[OK]` Convincing sense of life — emergent flock/flee/regroup motion.
- `[TODO]` Deployed and running on a device (PC build).

### Axis 2 — Complexity (algorithms & system design)

- `[OK]` Complex algorithms — steering, flocking, two-tier FSM, autonomous
  enemy AI, obstacle avoidance.
- `[OK]` 5-6 well-designed classes following SOLID.
- `[TODO]` **Debug gizmos on all nodes** — velocity, steering force,
  detection radius, target lines via `DebugDraw3D`.
- `[TODO]` Advanced Godot systems — shaders, particles, animation.
- `[TODO]` Deployed and demoed on a device (PC build).

### Axis 3 — Project management & documentation

- `[TODO]` **30-40 commits on feature branches**, meaningful messages.
- `[TODO]` **Public YouTube video from the BUILD** (not editor),
  demonstrating all features and explaining the project.
- `[TODO]` All README sections completed, including reflective
  "What I Learned".
- `[OK]` Source/reference material in repo (`docs/assignment-spec.md`,
  Reynolds links).

---

## Status

Early development. Proof of concept: a single unit performs Reynolds seek
toward a static target. See `docs/superpowers/specs/` for the design spec
(in progress) and `docs/assignment-spec.md` for the marking scheme.

## References

- Reynolds, C. W. — Steering Behaviors For Autonomous Characters:
  <https://www.red3d.com/cwr/steer/>
- Reynolds, C. W. — Boids (flocking):
  <https://www.red3d.com/cwr/boids/>
- Module reference repositories (steering + procedural animation):
  `skooter500/miniature-rotary-phone`

## What I Learned

_To be written as the project progresses (reflective section, per the
marking scheme)._
