# Matriarch Command

**CMPU 4031 Autonomous Agents -- Artefact 2026**
**Author:** Mae Capacite (C21348423)
**Engine:** Godot 4.7.1

> A 1993-styled 2.5D real-time strategy game in which the player flies a living droneship, commands a swarm of autonomous drones, and fights a mirror AI hive for control of a debris field.

## Demo

[![Matriarch Command -- demo video](https://img.youtube.com/vi/9oysvpD3y6A/maxresdefault.jpg)](https://youtu.be/9oysvpD3y6A)

Recorded from the exported build, not the editor: <https://youtu.be/9oysvpD3y6A>

---

## Concept

This game takes place in Thargoid space, where two hive factions fight for control of an asteroid field, one of which is controlled by you, the player. The field contains Thargoid barnacles, which are the only source of meta-alloy. The player and the rival AI must harvest this resource to build more drones, which are then used to fight for control of the field.

The player flies a Thargoid ship variant called the Matriarch: a bio-mechanically engineered multi-role gunship that carries its own drone complement. It is primarily a territory control ship rather than a fighting ship, though it is small enough to manoeuvre and fight directly. The Matriarch carries a hatchery, and most of what it does it does through a swarm of small multi-purpose autonomous drones, built in a similar manner to Thargoid Thargons.

These autonomous drones listen to the Matriarch's commands and decide for themselves how to carry them out. The drones claim targets, queue for busy resources, break off when threatened, and regroup. The swarm produces formations and erratic behaviour that is emergent, powered by the forces and states of the individual drones.

The opponent you fight is the opposing Thargoid hive, controlled autonomously, with exactly the same capabilities and the same drones as the player.

## The Loop

The economy is what makes the AI's decisions meaningful, so it comes first.

1. **Harvest.** Barnacles in the debris field hold meta-alloy. The commander designates one; drones fly to it, queue around it if it is occupied, draw alloy, and carry it back.
2. **Deposit.** Drones unload into the hatchery, which rides on the Matriarch itself. That single design choice makes the commander's _position_ the economy's throughput lever -- park too far from the barnacle and income drops to nothing.
3. **Build.** The hatchery spends alloy on new drones.
4. **Fight.** A bigger swarm wins. Destroying the enemy Matriarch ends the match.

Both sides play this loop. The rival AI has to decide, continuously, whether it is better off harvesting, patrolling, engaging or holding -- and the answer changes as the match does.

---

## Autonomous-Agent Techniques

| Technique                              | Where it appears                                                        |
| -------------------------------------- | ----------------------------------------------------------------------- |
| Steering behaviours                    | `scripts/steering/` -- seek, arrive, flee, wander, offset pursue        |
| Flocking                               | separation, alignment, cohesion on every drone                          |
| Obstacle avoidance                     | three feelers per agent, probing ahead along the direction of travel    |
| Force combination                      | WTPRS -- weighted truncated running sum with prioritisation             |
| Spatial partitioning                   | uniform spatial hash, 27-cell neighbour scan                            |
| Finite state machines                  | two tiers: per-unit state plus a global state that runs every frame     |
| Utility AI (Additional implementation) | the rival commander, following Dave Mark's Infinite Axis Utility System |
| Autonomous coordination                | claim leases on shared targets, so drones queue rather than collide     |

### Steering and WTPRS

Each behaviour returns a force and a weight. WTPRS accumulates these forces in priority order and stops once the accumulated force reaches the agent's maximum, so a high-priority behaviour such as separation can consume the entire budget in a crowd and starve the lower-priority ones. This is what stops a drone politely flocking its way into a rock.

### Two-tier state machines

`current_state._think()` runs first, then `global_state._think()`. These two tiers separate _what a unit is doing_ from _what is always true of it_ -- a drone in `HarvestState` still has to notice it is being shot at. Reflexes live in the global tier and cannot be forgotten by whichever state was written last.

### Utility AI

The rival commander does not use a state machine. Every option is scored by several independent considerations -- swarm strength, hull integrity, alloy held, enemy proximity -- each mapped through a response curve and then **multiplied**. Multiplication is the point: any single consideration returning zero vetoes the option outright, no matter how attractive the rest look. Because multiplying many numbers below one drives every score toward zero, scores are compensated for the number of considerations, and the current choice gets a small momentum bonus so the commander does not oscillate between two near-equal options.

The rival commander's behaviour is data-driven in order to allow for different personalities. Profiles are stored in `scripts/agents/ai/commander_profiles.gd`, so a different personality is a different table rather than different code.

---

## Presentation

- **Pixel rendering.** The 3D scene renders to a 640x360 `SubViewport` and is upscaled with nearest-neighbour filtering, so the game has a deliberate low-resolution look while remaining fully 3D.
- **Elite-style HUD.** A tilted circular radar with a wrapping heading arc, a segmented speed bar wrapping the radar's edge, and an alloy readout.
- **Original meshes.** Every hull is generated by script in Blender (`blender/`) and exported to glTF. No third-party model is used. Faction colour is applied at runtime from the ship's allegiance, so both sides share one scene.
- **Synthesised audio.** Engine sounds are generated at load-time and are not sampled from any recording. The swarm roar is also synthesised, and both are additive synthesis: a stack of sine partials at fixed frequencies and amplitudes, summed into a buffer. The buffer is exactly one second long and rendered once at load, so a tone at a whole number of Hz closes cleanly at the loop seam. `ToneBank` does this; `engine_hum.gd` and `swarm_roar.gd` use it. The engine uses 17 partials, the swarm 13. At run time the loop is driven by pitch and volume: throttle for the engine, swarm size for the roar. The engine cuts out entirely below 8 per cent throttle. The partial frequencies started as FFT measurements of reference recordings, then were tuned by ear. The result does not resemble the reference and is its own sound.
- **Original music.** Three tracks written for this project, scored to the swarm rather than to the clock: the director reads what most of the swarm is actually doing and picks a theme from that, so harvesting, patrolling and fighting each sound different without any of it being triggered by hand. See [`ATTRIBUTIONS.md`](ATTRIBUTIONS.md).
- **Debug gizmos** on every agent -- velocity, steering force, perception radius, target lines, the rival commander's live utility scores, and the music director's current phase -- all toggled with a single key, so the systems can be shown or hidden without a rebuild.

### Pixel rendering

A 3D scene renders to a 640x360 `SubViewport` and is upscaled with nearest-neighbour filtering, so the game has a deliberate low-resolution look while remaining fully 3D.

### Elite-style HUD

A holographic style HUD is overlaid on the scene, with a tilted circular radar with a wrapping heading arc, a segmented speed bar wrapping the radar's edge, and an alloy readout.

### Original Music

Three tracks written for this project, scored to the swarm rather than to the clock: the director reads what most of the swarm is actually doing and picks a theme from that, so harvesting, patrolling and fighting each sound different without any of it being triggered by hand. See [`ATTRIBUTIONS.md`](ATTRIBUTIONS.md).

### Debug Gizmos

**Debug gizmos** are drawn with [Dmitriy Salnikov's debug_draw_3d](https://github.com/DmitriySalnikov/godot_debug_draw_3d), vendored into `godot/addons/`. They show points of interest, forces and velocities on every agent. `F1` toggles them, `F2` cycles which category is drawn, and `F3` moves the camera to the rival commander.

---

## Running it

```bash
cd godot
godot .
```

Requires Godot 4.7.1. The `debug_draw_3d` addon is vendored in
`godot/addons/`.

## Repository layout

| Path                       | Contents                                         |
| -------------------------- | ------------------------------------------------ |
| `godot/scripts/steering/`  | steering behaviours and WTPRS                    |
| `godot/scripts/agents/`    | ships, drones, hatchery, commander AI            |
| `godot/scripts/agents/ai/` | utility considerations and profiles              |
| `godot/scripts/states/`    | state machine and all states                     |
| `godot/scripts/swarm/`     | swarm coordination and the spatial hash          |
| `godot/scripts/audio/`     | synthesised engine sounds and the music director |
| `godot/scripts/world/`     | hulls, asteroids, barnacles, starfield           |
| `blender/`                 | scripted mesh generation                         |
| `docs/`                    | design notes, audio analysis, marking scheme     |

---

## Marking-scheme coverage

Tracked against `docs/assignment-spec.md`.

### Axis 1 -- Groovyness (visuals and sound)

- The engine and swarm are synthesised additively in code at load, not sampled.
- Three original music tracks, scored to what the swarm is doing rather than to the clock.
- Visual identity: pixel rendering, faction colours, starfield, sun, gas giant, asteroid belt, glow.
- Named identity: the Matriarch, the swarm, the Farragut wreck.
- A convincing sense of life, through emergent flocking, queueing and wandering.
- Deployed and running on a device, as Linux and Windows builds.

### Axis 2 -- Complexity (algorithms and system design)

- Complex algorithms: steering, WTPRS, flocking, a spatial hash, a two-tier FSM, and utility AI.
- Well-designed classes with clear responsibilities.
- Debug gizmos throughout, behind a single toggle: steering forces and perception radii on every agent, the rival commander's live utility scores above its hull, and the music director's phase on the 2D overlay. `F2` cycles which category is drawn, and `F3` moves the camera to the rival commander.
- Advanced Godot systems: custom shaders, a sky shader with a radiance map, global shader uniforms, sub-viewport rendering, and procedural audio.
- Runs from the exported build on Linux and Windows, and the demo video is recorded from that build rather than from the editor.

### Axis 3 -- Project management and documentation

- 135 commits on a feature branch, using Conventional Commits throughout.
- A public YouTube video, recorded from the build rather than the editor: <https://youtu.be/9oysvpD3y6A>
- A reflective "What I Learned" section, below.
- Sources and references recorded in [`ATTRIBUTIONS.md`](ATTRIBUTIONS.md).

---

## References

- Reynolds, C. W. -- _Steering Behaviors For Autonomous Characters_:
  <https://www.red3d.com/cwr/steer/>
- Reynolds, C. W. -- _Boids_: <https://www.red3d.com/cwr/boids/>
- Mark, D. -- _Infinite Axis Utility System_: <https://www.gameai.com/iaus.php>
- Module reference repositories: `skooter500/miniature-rotary-phone`,
  `skooter500/UnitySteeringBehaviours`

Full attribution for assets, music and technique is in
[`ATTRIBUTIONS.md`](ATTRIBUTIONS.md).

## What I Learned

### Fighting the engine before fighting the problem

I built the capital ship model in Blender, exported it to glTF, and imported it into Godot. It looked right in Blender but wrong in Godot: the ship was facing the wrong way. I had to figure out why, and learned that Blender's +Y axis corresponds to Godot's -Z axis.

The radar orientation, when switching it from fixed to rotating with the camera, took me a while, since the ship's facing, the camera's angle, and the disc's rotation are three different concepts of "forward", and any two can agree while the third is wrong. I fixed it by carefully describing what I saw to Claude Code, and found four separate faults that needed to be corrected. The fix was deleting five tuning flags, not adding a sixth.

### The hard part was making them act convincingly

The most difficult part was getting the autonomous agents -- the drones and the rival commander -- to behave in a way that looks alive and convincing to the player. The algorithms themselves were not the challenge; it was making them act in a believable manner. For example, distance-scaled avoidance worked well for flying past rocks but failed when drones got stuck between a barnacle and an asteroid. I had to introduce a persistence term to build pressure when a feeler stayed blocked, allowing the drone to eventually escape.

The rival commander (CommanderAI) also had its own challenges. It runs a utility system to make decisions, but it failed to perform tasks convincingly or properly. The problems I came across were that it was either too passive or too aggressive -- I had to adjust its utility AI to make it more responsive and believable. Additionally, I had to address the AI's tendency to get stuck on obstacles.

### Beyond the course material

While brainstorming the rival commander, I found three candidate approaches: a state machine, a behaviour tree, and a utility system. I decided that the utility system was the most appropriate for the complexity of the CommanderAI, as it allowed for more emergent behaviour and for decision-making based on multiple considerations. I read Dave Mark's "Infinite Axis Utility System" to understand how to implement this approach effectively.

### What I would do differently

What I would do differently, given the time to redo this project without time pressure, is to focus more on the design and planning phase before diving into implementation, and to do more hands-on experimentation and tinkering with the different aspects of the game.
