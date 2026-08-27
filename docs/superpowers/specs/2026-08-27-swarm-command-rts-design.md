# Design Spec — Hybrid Bio-Tech Swarm Command (2.5D RTS)

**Module:** CMPU 4031 Autonomous Agents (Artifact)
**Author:** Mae Capacite (C21348423)
**Engine:** Godot 4.6, 3D meshes on a constrained XZ plane
**Date:** 2026-08-27
**Deadline:** 2026-09-02
**Status:** Approved. Supersedes `2026-07-13-swarm-command-design.md`.

---

## 1. What changed from the 2026-07-13 spec

The concept, the swarm model and the class philosophy carry over unchanged.
Four things are new:

| Was | Now |
|---|---|
| Free 3D space combat | **2.5D top-down RTS.** Movement locked to the XZ plane, perspective camera tilted about 60 degrees, following the player ship |
| Deploy on a cooldown | **Harvest and spend.** Units feast on caustic asteroids for alloy; a swarm factory grows batches of 5-15 and upgrades five times |
| Two intents (FOLLOW / ATTACK) | **Five intents:** FEAST, FOLLOW (defence), ATTACK, RECALL, PATROL |
| Untextured low-poly | **Wireframe rendering** in the style of the original Elite. Custom shader, per-faction colour |

The 3D-to-2.5D move is a simplification, not a rewrite. Steering collapses to
the XZ plane, formation offsets become 2D, and `look_at` stops needing an
up-vector guard for near-vertical flight.

## 2. Concept

The player pilots a living bio-tech commander ship and commands a swarm of
small living-metal creatures. The enemy is a mirror: the same ship, the same
swarm, driven by `CommanderAI`.

**Win condition:** destroy the enemy commander ship. Losing your own ends the
match.

**Core loop:**

1. **Feast** — units scrape caustic asteroids for alloy and convert it to
   bio-alloy. The asteroids corrode them while they work, so harvesting has a
   running health cost and the flee reflex fires during economy, not only
   during combat.
2. **Spend** — the swarm factory, a module on your ship, slowly grows new
   units in batches of 5-15. Upgradeable five times.
3. **Command** — hotkeys broadcast intent to the swarm. Right-click or a
   reticle designates a target.
4. **Fight** — you fly and fire your own weapon while the swarm engages,
   flinches, scatters and re-coheres around you.

**Strategic tension:** every unit feasting is a unit not screening you. One
resource pool, no build menu. The only decision is where the creatures point.

**The lifeform read** is unchanged and load-bearing for the brief: the swarm is
**emergent, not owned**. Units are the first-class autonomous agents; "a swarm"
is whichever units are currently near each other on the same side. Join, leave,
split and merge all fall out of per-unit rules. Aliveness comes from flocking,
the flee reflex, and re-cohering after losses — not from a face.

## 3. Class architecture

Nine classes plus one steering base, built once per side and instantiated twice
via an `allegiance` flag.

| Class | Extends | Responsibility | Grounding |
|---|---|---|---|
| `SteeringBehaviour` | `Node` | Base: `weight`, `enabled`, `on_draw_gizmos()`, `calculate()` | `MRP/steering_behavior.gd` |
| `SwarmUnit` | `CharacterBody3D` | The creature. WTPRS accumulation, Euler integration, banking, `allegiance`, `flock_id`, health, carried alloy | `MRP/boid.gd:141-158`, `:172-197` |
| `Swarm` | `School` | Spawns units, owns the spatial hash and neighbour caps, one per faction | `MRP/school.gd` |
| `SwarmCoordinator` | `Node` | Broadcasts intent, holds the bio-alloy pool, receives deposits. Owns no roster | new |
| `SwarmFactory` | `Node` | Grows batches of 5-15, spends alloy, holds upgrade level 1-5. Child of the ship | new |
| `Ship` | `CharacterBody3D` | Planar flight, weapon, health, hosts the factory. Same class both sides | `MRP/player_steering.gd`, `fire_at_target_global_state.gd` |
| `Asteroid` | `StaticBody3D` | Caustic alloy node. Finite yield, corrodes units feasting on it | new |
| `PlayerController` | `Node` | Input to `move()` / `fire()` / `set_intent()` / `designate()` | `MRP/player_steering.gd` |
| `CommanderAI` | `StateMachine` | Enemy brain: expand / press / retreat, same interface as `PlayerController` | `MRP/state_machine.gd` |

**Concrete behaviours**, each a child node in WTPRS priority order: `Seek`,
`Arrive`, `Flee`, `Pursue`, `OffsetPursue`, `Separation`, `Alignment`,
`Cohesion`, `Avoidance`, `Constrain`, `PlayerSteering`.

### Strategy pattern, human against AI

`PlayerController` and `CommanderAI` present an identical interface onto
`Ship` + `SwarmCoordinator`. The ship never knows which is driving it, so the
enemy AI is testable by pointing it at the player's own ship and the mirror
match costs nothing extra to build.

### Separation of concerns

`SwarmFactory` is split from `SwarmCoordinator` deliberately. Production rate
and upgrades change for economy-balance reasons; intent broadcasting changes
for command reasons. Separate reasons to change, separate classes — the S in
SOLID applied rather than recited.

## 4. Two-tier FSM

Duggan's `StateMachine` already provides both tiers: `current_state._think()`
runs, then `global_state._think()`, every frame
(`MRP/state_machine.gd:39-42`). Swarm intent rides as the **global state**;
the unit's own situation drives the **current state**. A unit may override
intent for survival, and that override is the aliveness beat.

**Tier 1, swarm intent** (broadcast by `SwarmCoordinator`, units listen):
`FEAST` / `FOLLOW` / `ATTACK` / `RECALL` / `PATROL`.

**Tier 2, per-unit state.** Each state is a recipe of composed steering
forces — no new movement code per state, only re-weighting.

| State | Entered when | Steering recipe | Exits to |
|---|---|---|---|
| `LAUNCH` | freshly grown by the factory | `seek` toward the ship | `FOLLOW` on arrival |
| `FOLLOW` | intent FOLLOW, safe | `separation + alignment + cohesion` + `offset_pursue` at a formation slot | `FEAST` / `ENGAGE` / `PATROL` / `FLEE` |
| `FEAST` | intent FEAST, asteroid in range | `arrive` at the asteroid, then drain alloy while taking corrosion damage | `DEPOSIT` when full, `FLEE` on low health |
| `DEPOSIT` | carrying alloy | `arrive` at the ship, transfer to the pool | `FEAST` / `FOLLOW` |
| `ENGAGE` | intent ATTACK, target designated | `pursue` (lead the target) + `separation` | `DETONATE` / `FLEE` |
| `PATROL` | intent PATROL, point designated | `follow_path` around the point + flocking triple | `ENGAGE` / `FLEE` |
| `FLEE` | threat or fire in danger radius; reflex, overrides intent | `flee` from the threat + `separation` | back to the intent's state when safe |
| `DETONATE` | within strike distance | none — trigger blast, remove the unit | terminal |

`FLEE` is a reflex edge from any state. `DETONATE` and death remove the unit;
neighbours re-query the grid and re-cohere the next frame.

**Course mapping:** W2 seek/arrive, W3 path following and player steering,
W5 SOLID and WTPRS, W6 pursue and offset pursue, W7-10 wander/avoidance/FSM,
W11 flocking and the spatial hash.

## 5. Project structure

Follows the official Godot conventions: snake_case for every file and folder,
PascalCase for node names, third-party in a top-level `addons/`.

```
aa26-project/
├── docs/
└── godot/
    ├── project.godot
    ├── addons/debug_draw_3d/
    ├── scripts/
    │   ├── agents/          swarm_unit.gd, ship.gd
    │   ├── steering/        steering_behaviour.gd + one file per behaviour
    │   ├── states/
    │   │   ├── unit/        launch, follow, feast, deposit, engage, patrol, flee
    │   │   └── commander/   expand, press, retreat
    │   ├── swarm/           swarm.gd, swarm_coordinator.gd, swarm_factory.gd
    │   ├── control/         player_controller.gd, commander_ai.gd, follow_camera.gd
    │   ├── world/           asteroid.gd, arena_bounds.gd
    │   └── ui/              hud.gd, alloy_readout.gd
    ├── scenes/
    │   ├── units/ ships/ world/
    │   └── main.tscn
    ├── shaders/             wireframe.gdshader
    └── assets/audio/
```

Grouping scripts by role rather than assets-beside-scenes is a deliberate
departure from the Godot doc's default. That default optimises for asset-heavy
projects; this one is code-heavy with almost no imported art, because wireframe
rendering means the meshes are CSG primitives plus a shader.

## 6. Visual design — wireframe

Rendering is in the style of the original Elite: unlit wireframe hulls with
additive glow, per-faction colour (player cyan, enemy amber), on a dark field.

This is not only an aesthetic choice. It earns the grade-1 "custom shaders"
criterion directly, it costs a fraction of what modelling would, and it solves
a genuine 2.5D readability problem — solid shaded units at a tilted camera
angle merge into an indistinct clump, whereas wireframes stay legible when
fifty of them overlap.

## 7. Build strategy

Available days: **Thu 27 Aug, Sat 29, Mon 31, Tue 1 Sep.** Wednesday 2 Sep is
the deadline and the lab test, so it is not a build day. Each phase must be
independently demoable, because whichever one the deadline lands on is what
gets marked.

| Phase | Branch | Done when | Day |
|---|---|---|---|
| 0+1 — Barebones build | `feat/vertical-slice` | Folder tree, addons, input map, wireframe shader, tilted follow camera. Ship flies on XZ. `SwarmUnit` with WTPRS and integration. Five units hold formation via offset pursue. Runs and is playable | Thu 27 |
| 2 — Swarm proper | `feat/flocking`, `feat/unit-fsm` | Spatial hash, flocking triple, per-unit FSM, FLEE reflex, unit health and death | Sat 29 |
| 3 — Economy | `feat/feast-economy`, `feat/factory` | Caustic asteroids, FEAST and DEPOSIT, alloy pool, factory batches and upgrades | Mon 31 |
| 4 — Enemy and Groovy | `feat/commander-ai`, `feat/vfx`, `feat/readme` | Mirror `CommanderAI`, win and lose conditions, then trails, sound, PC build, README, YouTube video | Tue 1 |

**Tuesday afternoon is reserved for the build, README and video.** Those carry
a full third of the marks and cannot be salvaged after the deadline. If
Tuesday morning overruns, `CommanderAI` is cut, not the video.

**Commit target:** 30-40 commits across six feature branches, 5-7 each.

## 8. Verification

There is no unit-test framework. This is a real-time simulation whose
correctness is visual, so the verification mechanism is **gizmos**: every
behaviour draws its own force through `on_draw_gizmos()`, and
`DebugDraw2D.set_text` names which behaviour tripped the WTPRS truncation.

Gizmos go in from Phase 1 rather than being retrofitted, because they are
simultaneously the debugging tool and the grade-1 "gizmos on all nodes"
criterion.

## 9. Defects in the reference code to fix and write up

Three real bugs in Duggan's implementation. Fixing them, and explaining the
fixes in the README, is concrete evidence of the self-directed learning the
Complexity band asks for.

1. **The spatial hash misses genuine neighbours.** The 27-cell scan guarantees
   a reach of only `cell_size` in any one direction, but the defaults are
   `cell_size = 10` against `neighbor_distance = 20`
   (`MRP/school.gd:9,14`). Neighbours at 16-20 units are silently dropped.
   Fix: `cell_size >= neighbor_distance`.
2. **`max_neighbors` truncates by scan order, not distance.**
   `count_neighbors_partitioned()` returns as soon as the cap is hit
   (`MRP/boid.gd:65-66`), so the units kept are the first encountered rather
   than the nearest.
3. **`alignment.gd` latches.** `force` is a member written only inside the
   `neighbors.size() > 0` guard (`MRP/alignment.gd:17-20`), so a unit with no
   neighbours keeps its last alignment force indefinitely.

A fourth, in `MRP/state_machine.gd`: `change_state()` reparents the new state
onto the boid, but `_ready()` does not do the same for `initial_state`, so the
first state lives at a different place in the tree from every state after it.

## 10. Conventions

- **+Z is forward** throughout, following Duggan
  (`look_at(origin - velocity, up)`). A formation slot behind the leader
  therefore needs a **negative** Z offset.
- **Separation falloff is inverse `1/d`**, not inverse-square
  (`MRP/separation.gd:21`).
- **Alignment averages headings** (`basis.z`), not velocities
  (`MRP/alignment.gd:17`). Speed-independent, and only correct because +Z is
  forward.
- **Priority is scene-tree child order**, since WTPRS breaks out of the loop
  once the force budget is spent. Reordering child nodes changes behaviour.
- British and Irish English throughout. Student number C21348423 in the README.

## 11. Open unknowns

Deliberately flexible; the class boundaries absorb changes here.

- Formation shape and slot assignment in `FOLLOW`.
- Target designation: reticle lock against nearest-in-cone.
- Whether split and merge are player-triggered or purely emergent.
- Whether obstacle avoidance keeps five 3D feelers or reduces to three
  in-plane ones for the 2.5D case.

## 12. References

- Reynolds, C. W. — Steering Behaviors For Autonomous Characters:
  <https://www.red3d.com/cwr/steer/>
- Reynolds, C. W. — Boids: <https://www.red3d.com/cwr/boids/>
- Duggan, B. — `skooter500/miniature-rotary-phone`, `behaviors/`
- Duggan, B. — `skooter500/UnitySteeringBehaviours`, source of the WTPRS name
- Godot project organisation and GDScript style guide: see
  `CLAUDE_SOURCES.md`
- Marking scheme: `docs/assignment-spec.md`
