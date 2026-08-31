# Matriarch Command

**CMPU 4031 Autonomous Agents -- Artefact 2026**
**Author:** Mae Capacite (C21348423)
**Engine:** Godot 4.7.1

> A 2.5D real-time strategy game in which the player flies a living droneship,
> commands a swarm of autonomous drones, and fights a mirror AI hive for
> control of a debris field.

---

## Concept

The player flies a **Matriarch**: a grown, not built, multi-role gunship
carrying its own drone complement. Not a capital ship -- it is small enough to
manoeuvre and fight directly, but its purpose is to contest and hold ground
rather than to win an exchange alone. It carries a hatchery, and most of what
it does it does through a swarm of small autonomous drones.

Those drones are not remote-controlled. The player issues *intent* -- harvest,
follow, engage -- and the swarm decides for itself how to carry it out. Drones
claim targets, queue for a busy resource, break off when threatened, and
regroup. The swarm reads as alive because its motion is emergent rather than
scripted: there is no animation of a flock, only forces and states that
produce one.

The opponent is a **mirror hive**: the same ship, the same drones, the same
behaviours, built from the same scenes and separated only by an allegiance
flag. It is not a scripted dummy. It scores its options every frame with a
utility system and plays the same game the player does.

The setting is a spin-off of Elite Dangerous, in Thargoid space. The code
keeps a generic vocabulary throughout -- `Ship`, `Drone`, `Swarm`, `Hatchery`
-- so the systems stand on their own; the fiction lives in the documentation
and the art.

## The Loop

The economy is what makes the AI's decisions meaningful, so it comes first.

1. **Harvest.** Barnacles in the debris field hold meta-alloy. The commander
   designates one; drones fly to it, queue around it if it is occupied, draw
   alloy, and carry it back.
2. **Deposit.** Drones unload into the hatchery, which rides on the Matriarch
   itself. That single design choice makes the commander's *position* the
   economy's throughput lever -- park too far from the barnacle and income
   drops to nothing.
3. **Build.** The hatchery spends alloy on new drones.
4. **Fight.** A bigger swarm wins. Destroying the enemy Matriarch ends the
   match.

Both sides play this loop. The rival AI has to decide, continuously, whether
it is better off harvesting, patrolling, engaging or holding -- and the answer
changes as the match does.

---

## Autonomous-Agent Techniques

Mapped to the module material.

| Technique | Where it appears |
|---|---|
| Steering behaviours | `scripts/steering/` -- seek, arrive, flee, wander, offset pursue |
| Flocking | separation, alignment, cohesion on every drone |
| Force combination | WTPRS -- weighted truncated running sum with prioritisation |
| Spatial partitioning | uniform spatial hash, 27-cell neighbour scan |
| Finite state machines | two tiers: per-unit state plus a global state that runs every frame |
| Utility AI | the rival commander, following Dave Mark's Infinite Axis Utility System |
| Autonomous coordination | claim leases on shared targets, so drones queue rather than collide |

### Steering and WTPRS

Each behaviour returns a force and a weight. WTPRS accumulates them in
priority order and stops once the accumulated force reaches the agent's
maximum, so a high-priority behaviour such as separation can consume the
entire budget in a crowd and starve the lower-priority ones. This is what
stops a drone politely flocking its way into a rock.

### Two-tier state machines

`current_state._think()` runs first, then `global_state._think()`. The tiers
separate *what a unit is doing* from *what is always true of it* -- a drone in
`HarvestState` still has to notice it is being shot at. Reflexes live in the
global tier and cannot be forgotten by whichever state was written last.

### Utility AI

The rival commander does not use a state machine. Every option is scored by
several independent considerations -- swarm strength, hull integrity, alloy
held, enemy proximity -- each mapped through a response curve and then
**multiplied**. Multiplication is the point: any single consideration
returning zero vetoes the option outright, no matter how attractive the rest
look. Because multiplying many numbers below one drives every score toward
zero, scores are compensated for the number of considerations, and the current
choice gets a small momentum bonus so the commander does not oscillate between
two near-equal options.

Profiles are data (`scripts/agents/ai/commander_profiles.gd`), so a different
personality is a different table rather than different code.

---

## Presentation

- **Pixel rendering.** The 3D scene renders to a 640x360 `SubViewport` and is
  upscaled with nearest-neighbour filtering, so the game has a deliberate
  low-resolution look while remaining fully 3D.
- **Elite-style HUD.** A tilted circular radar with a wrapping heading arc, a
  segmented speed bar wrapping the radar's edge, and an alloy readout.
- **Original meshes.** Every hull is generated by script in Blender
  (`blender/`) and exported to glTF. No third-party model is used. Faction
  colour is applied at runtime from the ship's allegiance, so both sides share
  one scene.
- **Synthesised audio.** The engine and swarm sounds are not samples. Their
  partials were measured by FFT from reference recordings and are rendered to
  seamless looping streams at load. See
  [`docs/audio/analysis.md`](docs/audio/analysis.md) for the method, the
  measurements, and two corrections worth reading.
- **Debug gizmos** on every agent -- velocity, steering force, perception
  radius, target lines -- toggled with a single key so the forces can be shown
  or hidden without a rebuild.

---

## Running it

```bash
cd godot
godot .
```

Requires Godot 4.7.1. The `debug_draw_3d` addon is vendored in
`godot/addons/`.

## Repository layout

| Path | Contents |
|---|---|
| `godot/scripts/steering/` | steering behaviours and WTPRS |
| `godot/scripts/agents/` | ships, drones, hatchery, commander AI |
| `godot/scripts/agents/ai/` | utility considerations and profiles |
| `godot/scripts/states/` | state machine and all states |
| `godot/scripts/swarm/` | swarm coordination and the spatial hash |
| `godot/scripts/audio/` | synthesised engine sounds |
| `godot/scripts/world/` | hulls, asteroids, barnacles, starfield |
| `blender/` | scripted mesh generation |
| `docs/` | design notes, audio analysis, marking scheme |

---

## Marking-scheme coverage

Tracked against `docs/assignment-spec.md`.

### Axis 1 -- Groovyness (visuals and sound)

- `[OK]` Sound design -- synthesised engine and swarm, derived from measured
  spectra rather than sampled.
- `[OK]` Visual identity -- pixel rendering, faction colours, starfield, sun,
  gas giant, asteroid belt, glow.
- `[OK]` Named identity -- the Matriarch, the swarm, the Farragut wreck.
- `[OK]` Convincing sense of life -- emergent flocking, queueing, wandering.
- `[OK]` Deployed and running on a device -- Linux and Windows builds, both
  verified from the exported binary rather than the editor.

### Axis 2 -- Complexity (algorithms and system design)

- `[OK]` Complex algorithms -- steering, WTPRS, flocking, spatial hash,
  two-tier FSM, utility AI.
- `[OK]` Well-designed classes with clear responsibilities.
- `[OK]` Debug gizmos on all agents, with a toggle.
- `[OK]` Advanced Godot systems -- custom shaders, sky shader with radiance
  map, global shader uniforms, sub-viewport rendering, procedural audio.
- `[OK]` Runs from the exported build on Linux and Windows; the demo video is
  recorded from that build, not the editor.

### Axis 3 -- Project management and documentation

- `[OK]` 92 commits on a feature branch, Conventional Commits throughout.
- `[TODO]` Public YouTube video recorded from the build, not the editor.
- `[TODO]` Reflective "What I Learned" section below.
- `[OK]` Sources and references recorded in
  [`ATTRIBUTIONS.md`](ATTRIBUTIONS.md).

---

## References

- Reynolds, C. W. -- *Steering Behaviors For Autonomous Characters*:
  <https://www.red3d.com/cwr/steer/>
- Reynolds, C. W. -- *Boids*: <https://www.red3d.com/cwr/boids/>
- Mark, D. -- *Infinite Axis Utility System*: <https://www.gameai.com/iaus.php>
- Module reference repositories: `skooter500/miniature-rotary-phone`,
  `skooter500/UnitySteeringBehaviours`

Full attribution for assets, music and technique is in
[`ATTRIBUTIONS.md`](ATTRIBUTIONS.md).

## What I Learned

<!-- TODO(human) -->
