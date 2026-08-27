# Design Spec — Hybrid Bio-Tech Swarm Command

**Module:** CMPU 4031 Autonomous Agents (Artifact, 40% of module)
**Author:** Mae Capacite (C21348423)
**Engine:** Godot 4.6, 3D
**Date:** 2026-07-13
**Status:** Approved concept + architecture; implementation open to refinement.

---

## 1. Concept

A 3D space combat sandbox. The player pilots a hybrid **bio-tech ship** and
commands a **swarm** of small living-metal creatures that behave like loyal
wingmen. The enemy is a **symmetric AI commander** — its own ship, its own
swarm, the same capabilities — making the match a mirror duel.

The swarm must read as *alive*: it holds formation, hunts, flinches from
fire, scatters, and re-coheres through emergent motion rather than a face.
This satisfies the brief's "autonomous, anthropomorphic lifeform" framing.

**Key mental model (locked):** the swarm is **emergent, not owned**. Units
are the first-class autonomous agents. "A swarm" is simply whichever units
are currently near each other and on the same side. Join, leave, split, and
merge all fall out of per-unit rules; nothing central holds a fixed roster.

## 2. Player Experience

- **Fly and fight your own ship** — manoeuvre in 3D, fire your own weapon.
- **Deploy the swarm** on a cooldown. Units are a limited, precious resource.
- **Two swarm intents:**
  - `FOLLOW` — hold a defensive formation around the ship, intercept threats.
  - `ATTACK` — when the player designates an enemy in range, the swarm breaks
    off and engages while the player keeps manoeuvring.
- **Manage the swarm as a resource** — each unit has its own health and dies
  individually. Lost units replenish only after a cooldown, forcing a balance
  between offence and defence.

## 3. The Enemy

A symmetric `CommanderAI`: own ship, own swarm, same intents and behaviours.
Built from the same classes as the player side via an allegiance flag (build
once, instantiate twice). Runs a simple high-level decision loop — advance /
engage / retreat — so it is a genuine autonomous agent, not a scripted dummy.

## 4. Win Condition

Destroy the enemy commander ship. Losing your own ship ends the match.

---

## 5. Class Architecture

Six core classes plus one steering base. Built once, instantiated per
faction (player / AI). Follows SOLID — each class has a single reason to
change.

| Class | Node type | Responsibility | Design note |
|---|---|---|---|
| `SteeringBehaviour` | `RefCounted` base | Return one `Vector3` force (seek/arrive/pursue/flee/separation/alignment/cohesion). | Open-closed: add behaviours without touching units. |
| `Munition` | `CharacterBody3D` | The autonomous agent. Holds `allegiance` + `flock_id` + health; runs per-unit FSM; queries neighbours; sums steering; launches/joins, detonates/leaves. | First-class, not owned. |
| `FlockGrid` | `Node` / script | Spatial partition: "units near X on side S". Cheap neighbour queries; enables emergent membership. | W11 flocking optimisation. |
| `SwarmCoordinator` | `Node` | Per faction: deploy/replenish cooldown, launch new units, broadcast intent (`mode_changed`, `target_designated`, `recall`) via signals. Owns no roster. | Conductor, not container. |
| `Ship` | `CharacterBody3D` | Commander vessel: movement, weapon, health. | Same class both sides. |
| `PlayerController` | `Node` | Reads input, drives player `Ship` + `SwarmCoordinator`. | Input isolated from ship logic. |
| `CommanderAI` | `Node` | Enemy brain: high-level FSM (advance/engage/retreat) driving enemy `Ship` + `SwarmCoordinator`. | Mirrors `PlayerController`'s interface. |

### Emergent membership

Each `Munition` carries `allegiance` + `flock_id` and asks `FlockGrid` "who is
near me on my side?" each frame. Membership is an emergent query result, not
a list:

- **Split** — some units adopt a new `flock_id`.
- **Merge** — units adopt a shared `flock_id`.
- **Join** — a launched unit seeks a flock and matches its `flock_id` in range.
- **Leave** — death/detonation removes the node; neighbours re-query and
  re-cohere next frame.

### Strategy pattern (human vs AI)

`PlayerController` and `CommanderAI` present the same interface onto
`Ship` + `SwarmCoordinator` (`move()`, `fire()`, `set_intent()`,
`designate()`). The ship does not know which is driving it. This makes the
enemy AI testable by pointing it at the player's own ship.

---

## 6. Two-Tier FSM

**Tier 1 — Swarm intent** (broadcast by `SwarmCoordinator`; units listen):
`FOLLOW` / `ATTACK` / `RECALL`. Biases which Tier-2 state a unit prefers; a
unit may override intent for survival.

**Tier 2 — Per-unit FSM.** Each state is a recipe of composed
`SteeringBehaviour` forces — no new movement code per state, only re-weighting.

| State | Entered when | Steering recipe | Exits to |
|---|---|---|---|
| `LAUNCH` | freshly fired from ship | `seek` toward flock / ship | `FOLLOW` on arrival |
| `FOLLOW` | intent=`FOLLOW`, safe | `separation + alignment + cohesion` + `arrive` at formation offset | `ENGAGE` / `FLEE` |
| `ENGAGE` | intent=`ATTACK` + target in range | `pursue` (lead target) + `separation` | `DETONATE` / `FLEE` |
| `FLEE` | threat/enemy fire in danger radius (reflex, overrides intent) | `flee` from threat + `separation` (disperse) | `FOLLOW`/`ENGAGE` when safe |
| `DETONATE` | within strike distance or on contact | none — trigger blast, then remove | `DEAD` (terminal) |

```
        launch          arrive
 [LAUNCH] ---------> [FOLLOW] <---------------+
                        |  ^  intent=ATTACK   | safe
              intent=   |  |  +target         |
              ATTACK    v  |                  |
                     [ENGAGE] ----------> [FLEE]  <-- threat in radius
                        |   in strike dist   (reflex: any state -> FLEE)
                        v
                    [DETONATE] --> DEAD (unit leaves; neighbours re-cohere)
```

`FLEE` is a reflex edge from any state — the core "aliveness" beat.
`DETONATE` removes the unit from its flock; neighbours re-cohere.

Course-week mapping: W2 seek/arrive, W5 SOLID/refactoring, W6 pursue/flee,
W11 flocking.

---

## 7. Build Strategy — Vertical Slice (Strategy A)

Get an ugly end-to-end loop first, then widen, then polish. Each phase is a
feature branch; commits cluster toward the 30-40 grade-1 target. If the
deadline bites mid-project, a working gradeable artifact still exists.

| Phase | Branch | Definition of done |
|---|---|---|
| 0 — POC (current) | `feat/poc-seek` | One unit Reynolds-seeks a static target and stops. |
| 1 — Vertical slice | `feat/vertical-slice` | Player `Ship` moves; 3 units `FOLLOW` in formation; designate 1 dummy enemy; units `ENGAGE` -> `DETONATE`; a unit can die. Ugly cubes, one faction. End-to-end loop playable. |
| 2 — Widen swarm | `feat/flocking`, `feat/launch-replenish`, `feat/flee-reflex` | Real flocking via `FlockGrid`; `LAUNCH`/join; `FLEE` reflex; per-unit health + deploy/replenish cooldown. |
| 3 — Enemy AI + PvP | `feat/commander-ai` | `CommanderAI` (advance/engage/retreat) drives a symmetric enemy ship + swarm. Win = kill enemy commander. |
| 4 — Groovy | `feat/vfx`, `feat/sound`, `feat/gizmos`, `feat/identity` | Bio-tech glow shader, particle trails/blasts, sound set, `DebugDraw3D` gizmos on all nodes, species/ship names. PC build + YouTube-from-build. |

Steering-force gizmos are drawn from Phase 1 as a debugging aid and
formalised as grade evidence in Phase 4 (no extra work).

---

## 8. Grade-1 Coverage Checklist

Tracked against `docs/assignment-spec.md`. `[OK]` = covered by core concept;
`[TODO]` = additive work to secure the band.

### Axis 1 — Groovyness
- `[TODO]` Sound design — engine hum, deploy pulse, lock-on chirp, unit death, enemy fire.
- `[TODO]` Visual VFX — bio-tech glow shader, exhaust trails, death-burst particles, post-processing.
- `[TODO]` Name + identity — swarm species and both commander ships.
- `[OK]` Convincing sense of life — emergent flock/flee/regroup motion.
- `[TODO]` Deployed on device (PC build).

### Axis 2 — Complexity
- `[OK]` Complex algorithms — steering, flocking, two-tier FSM, enemy AI, obstacle avoidance.
- `[OK]` 5-6 well-designed SOLID classes.
- `[TODO]` Debug gizmos on all nodes (`DebugDraw3D`).
- `[TODO]` Advanced Godot systems — shaders, particles, animation.
- `[TODO]` Deployed on device (PC build).

### Axis 3 — Project management & documentation
- `[TODO]` 30-40 commits on feature branches, meaningful messages.
- `[TODO]` Public YouTube video from the BUILD, demonstrating all features.
- `[TODO]` All README sections completed, including reflective "What I Learned".
- `[OK]` Source/reference material in repo.

---

## 9. Open Unknowns

Deliberately left flexible; the class boundaries above absorb changes here.

- Exact obstacle-avoidance approach (ray-cast whiskers vs steering force).
- Formation shape and slot assignment in `FOLLOW`.
- Target-designation mechanism (reticle lock vs nearest-in-cone).
- Player ship control scheme (6-DoF vs constrained flight).
- Whether split/merge is player-triggered or purely emergent.

---

## 10. References

- Reynolds, C. W. — Steering Behaviors For Autonomous Characters:
  <https://www.red3d.com/cwr/steer/>
- Reynolds, C. W. — Boids: <https://www.red3d.com/cwr/boids/>
- Module reference repositories (steering + procedural animation):
  `skooter500/miniature-rotary-phone`
- Marking scheme: `docs/assignment-spec.md`
