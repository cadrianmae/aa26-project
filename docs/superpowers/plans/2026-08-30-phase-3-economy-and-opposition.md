# Phase 3 and 4: Economy and Opposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn a swarm that can be commanded into a game that can be won or lost: drones harvest Meta-Alloys from Barnacles and deposit them, the hive spends alloys to grow, a rival hive does the same under AI control, and the two swarms can destroy each other.

**Architecture:** The economy is a loop between three nodes that never reference each other directly. A `Barnacle` holds a finite alloy reserve and answers "how much can be taken". `HarvestState` and `DepositState` move a drone between a Barnacle and its hive, carrying a payload. A `Hive` owns the alloy pool and the factory that spends it. The opposition reuses every one of these: `CommanderAI` drives an enemy `Swarm` through the same `Swarm.order()` API the player's hotkeys use, so the rival hive is not a special case — it is a second player with a script instead of a keyboard.

**Tech Stack:** Godot 4.7 (project targets 4.6 features), GDScript, `debug_draw_3d` for gizmos.

**Spec:** `docs/superpowers/specs/2026-08-27-swarm-command-rts-design.md`

## Global Constraints

- **Engine:** Godot 4.6 feature level under 4.7.1. Binary is `godot`; `godot-dev run` runs the project.
- **Parse check:** `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`. Empty output means every script parses. NEVER use `--check-only --script`: it does not load the global class cache and reports misleading "Could not find type" errors.
- **Parse checks are not enough.** Every task ends with a runtime probe: instantiate `main.tscn`, step physics frames, print observed state. Three bugs this project has shipped (unwired `leader` paths, `PlayerSwarm` ordered after `Units`, `SwarmCoordinator` resolving in `_ready`) all parsed and loaded cleanly while doing nothing.
- **Never resolve another node by group in `_ready()`.** Godot readies siblings in scene order, so the node you want may not have joined its group yet. Resolve on first use instead. This has bitten the project three times; treat it as the house rule.
- **File and folder names:** `snake_case`. **Node names in scenes:** `PascalCase`.
- **GDScript member order:** doc comment FIRST at the very top of the file above `class_name`, then `class_name`, `extends`, signals, enums, constants, `@export`, vars, `@onready`, then methods.
- **Type annotations:** explicit `var x: Vector3 = ...` preferred over `:=`.
- **Indentation:** tabs. **Line length:** under 100 characters. **Quotes:** double.
- **Forward axis is +Z**, following Duggan. `Vector3.FORWARD` is -Z and is wrong here.
- **Movement plane:** XZ. Y is held constant; zero the Y component of every steering force.
- **Code vocabulary is generic:** `Ship`, `Drone`, `Swarm`, `Hive`, `Barnacle`. Thargoid names live in `docs/` only.
- **Attribution:** every file adapted from Duggan carries a comment naming the source file and line range.
- **Language:** British and Irish English. No emoji, no non-ASCII symbols anywhere in code or docs.
- **Commit messages are ONE LINE**, Conventional Commits `type(scope): message` or `type: message`. No body, no trailers, no `Co-Authored-By`. Never pass a second `-m`.
- **Mae authors** `HarvestState._think()` (Task 3) and `CommanderAI.decide()` (Task 6). Both arrive as `TODO(human)` and must NOT be implemented.
- **Scene edits:** add nodes as normal children. NEVER as overrides into instanced sub-scenes — the editor silently prunes those in this project.

## Time budget

| Day | Availability | Target |
|---|---|---|
| Sunday 30 Aug | Partial | Tasks 1 to 3 |
| Monday 31 Aug | **Full — the only one** | Tasks 4 to 7 |
| Tuesday 1 Sep | Partial, **protected** | Build, README, video. No new features. |
| Wednesday 2 Sep | Mostly unavailable | Submission only |

If Monday runs short, **cut Task 7 first, then Task 5**. Tasks 1 to 4 plus 6 are a complete, defensible artefact: an economy, a growing swarm, and an opponent. Weapons without an economy is not.

---

## File Structure

| Path | Responsibility |
|---|---|
| `scripts/world/barnacle.gd` | A finite alloy reserve at a fixed point. Knows nothing about drones. |
| `scripts/agents/hive.gd` | Owns one side's alloy pool and its factory. One per allegiance. |
| `scripts/states/unit/harvest_state.gd` | Existing stub. Drive a drone to a Barnacle and fill its payload. |
| `scripts/states/unit/deposit_state.gd` | Existing stub. Return a full drone to its hive and empty it. |
| `scripts/agents/commander_ai.gd` | Issues orders to an enemy `Swarm` through `Swarm.order()`. |
| `scripts/combat/weapon.gd` | Fires projectiles on a cooldown at a target. |
| `scripts/combat/projectile.gd` | Travels, hits, applies damage, frees itself. |
| `scripts/states/unit/engage_state.gd` | Existing stub. Pursue and fire on the nearest enemy. |
| `scenes/world/barnacle.tscn` | Barnacle with a `Hull` using `HullShape.ROCK`. |
| `scenes/combat/projectile.tscn` | Projectile with its collision shape. |

---

### Task 1: Barnacle and the alloy pool

The economy's two endpoints, with nothing moving between them yet. Split from harvesting so the reserve and the pool can be tested without a drone in the picture.

**Files:**
- Create: `godot/scripts/world/barnacle.gd`
- Create: `godot/scripts/agents/hive.gd`
- Create: `godot/scenes/world/barnacle.tscn`
- Modify: `godot/scenes/main.tscn` (three Barnacles, one Hive)

**Interfaces:**
- Produces: `Barnacle.extract(amount: float) -> float` returning what was actually taken (may be less than asked, or 0.0 when exhausted); `Barnacle.reserve: float`; `Barnacle.depleted` signal; `Barnacle.nearest_to(tree: SceneTree, point: Vector3) -> Barnacle` static, mirroring `Threat.nearest_to`.
- Produces: `Hive.deposit(amount: float) -> void`; `Hive.alloys: float`; `Hive.alloys_changed(total: float)` signal; `Hive.for_allegiance(tree: SceneTree, allegiance: int) -> Hive` static.

- [ ] **Step 1: Write `barnacle.gd`**

Model on `scripts/world/threat.gd` — same shape of static lookup, same group-per-allegiance convention (Barnacles are neutral, so one group, `"barnacles"`).

```gdscript
class_name Barnacle
extends Node3D

signal depleted(barnacle: Barnacle)

const GROUP: String = "barnacles"

@export var reserve: float = 100.0
@export var harvest_radius: float = 6.0

func extract(amount: float) -> float:
	var taken: float = minf(amount, reserve)
	reserve -= taken
	if reserve <= 0.0:
		depleted.emit(self)
	return taken
```

- [ ] **Step 2: Write `hive.gd`** with `deposit()`, the `alloys_changed` signal, and the static lookup. Group name `"hive_" + str(allegiance)`.

- [ ] **Step 3: Build `barnacle.tscn`** — `Node3D` with the script, a child `Hull` (`hull_shape = 2` for ROCK, `hull_colour` a dull green), and a `StaticBody3D` + `CollisionShape3D` so it is solid.

- [ ] **Step 4: Place three Barnacles and one Hive in `main.tscn`.** Spread the Barnacles 40 to 80 units from the origin so a rally order is needed to reach them.

- [ ] **Step 5: Runtime probe.** Load `main.tscn`, step 5 frames, then assert: `Barnacle.nearest_to()` finds the closest of the three; `extract(30.0)` returns `30.0` and leaves `reserve == 70.0`; `extract(999.0)` returns `70.0`, leaves `0.0`, and emits `depleted` exactly once; `Hive.for_allegiance(tree, 0)` resolves; `deposit(50.0)` moves `alloys` to `50.0`.

- [ ] **Step 6: Commit** — `feat(world): add barnacles and a hive alloy pool`

---

### Task 2: Drone payload and the deposit half

Deposit before harvest, so a drone can be tested carrying a payload it was simply handed. This avoids needing harvesting to work before deposit can be seen at all.

**Files:**
- Modify: `godot/scripts/agents/drone.gd` (payload fields)
- Modify: `godot/scripts/states/unit/deposit_state.gd`
- Modify: `godot/scenes/units/drone.tscn` (a second `ArriveBehaviour` named `ArriveHive`)

**Interfaces:**
- Consumes: `Hive.deposit()`, `Hive.for_allegiance()` from Task 1.
- Produces: `Drone.payload: float`, `Drone.payload_capacity: float`, `Drone.is_full() -> bool`.

- [ ] **Step 1: Add payload fields to `drone.gd`** under a new `@export_group("Harvesting")`: `payload_capacity: float = 10.0`, and a plain `var payload: float = 0.0`.

- [ ] **Step 2: Write `DepositState`.** `_enter()` points `ArriveHive` at the hive found via `Hive.for_allegiance()` and calls `use_only(["ArriveHive", "Separation", "Alignment"])`. `_think()` checks distance to the hive; within `deposit_radius`, calls `hive.deposit(payload)`, zeroes `payload`, and transitions to `"Harvest"`.

- [ ] **Step 3: Add the `ArriveHive` node** to `drone.tscn`, `enabled = false`, placed directly after `Arrive` so it inherits the same priority band.

- [ ] **Step 4: Runtime probe.** Load `main.tscn`, hand a drone `payload = 10.0`, force it into `Deposit` via `machine.change_state()`, step 200 frames, and assert: the drone's distance to the hive shrinks monotonically over the first 100 frames; `payload` reaches `0.0`; `Hive.alloys` reaches `10.0`; the drone's state is now `Harvest`.

- [ ] **Step 5: Commit** — `feat(states): carry and deposit a payload at the hive`

---

### Task 3: Harvest — MAE AUTHORS THE THINK

**Files:**
- Modify: `godot/scripts/states/unit/harvest_state.gd`
- Modify: `godot/scenes/units/drone.tscn` (an `ArriveBarnacle` behaviour)

**Interfaces:**
- Consumes: `Barnacle.nearest_to()`, `Barnacle.extract()`, `Drone.payload`, `Drone.is_full()`.
- Produces: nothing new. Closes the loop with `DepositState`.

- [ ] **Step 1: Write the scaffolding.** `_enter()` finds `Barnacle.nearest_to(get_tree(), unit.global_position)`, stores it, points `ArriveBarnacle` at it, and calls `use_only(["ArriveBarnacle", "Separation", "Alignment"])`. Add `@export var harvest_rate: float = 8.0` (alloys per second).

- [ ] **Step 2: Leave `_think()` as `TODO(human)`.** Mae writes it. She will need: `unit.global_position.distance_to(barnacle.global_position)`, `barnacle.harvest_radius`, `barnacle.extract(harvest_rate * get_process_delta_time())`, `unit.payload`, `unit.is_full()`, and `machine.change_state(machine.state_named("Deposit"))`. The decisions that are hers: what to do when the Barnacle is exhausted mid-harvest, and whether a drone re-targets to another Barnacle or returns to the hive with a part load.

- [ ] **Step 3: Add `ArriveBarnacle`** to `drone.tscn`, `enabled = false`.

- [ ] **Step 4: STOP.** Do not implement `_think()`. Report the task as awaiting Mae.

- [ ] **Step 5 (after Mae writes it): Runtime probe.** Order `HARVEST`, step 600 frames, assert: `Hive.alloys` is strictly greater than zero; at least one Barnacle's `reserve` has fallen; drones are observed in both `Harvest` and `Deposit` across the run.

- [ ] **Step 6: Commit** — `feat(states): harvest alloys from barnacles`

---

### Task 4: The factory

Spends the pool. Without it the economy has an inflow and no purpose.

**Files:**
- Modify: `godot/scripts/agents/hive.gd`
- Modify: `godot/scenes/main.tscn`

**Interfaces:**
- Consumes: `Hive.alloys`, `Swarm.register()`.
- Produces: `Hive.drone_cost: float`, `Hive.spawn_drone() -> Drone`, `Hive.drone_spawned(drone: Drone)` signal.

- [ ] **Step 1: Add spawning to `hive.gd`.** `@export var drone_scene: PackedScene`, `@export var drone_cost: float = 25.0`, `@export var max_drones: int = 40`. A `_process` that spawns while `alloys >= drone_cost` and the swarm is under `max_drones`, deducting the cost each time.

- [ ] **Step 2: Spawn position.** Place new drones at the hive with a small random offset on XZ, and set `allegiance` and `swarm` before `add_child()` so the drone's own `_ready()` registers correctly.

- [ ] **Step 3: Runtime probe.** Set `alloys = 100.0` directly, step 20 frames, assert the swarm grew by exactly `floor(100 / 25) = 4` drones, that `alloys` is `0.0`, and that every new drone appears in `swarm.units` and has non-empty `neighbours` within 30 frames.

- [ ] **Step 4: Commit** — `feat(hive): spend alloys to grow the swarm`

---

### Task 5: Weapons

**Files:**
- Create: `godot/scripts/combat/weapon.gd`, `godot/scripts/combat/projectile.gd`
- Create: `godot/scenes/combat/projectile.tscn`
- Modify: `godot/scripts/states/unit/engage_state.gd`
- Modify: `godot/scenes/units/drone.tscn`, `godot/scenes/ships/commander_ship.tscn`

**Interfaces:**
- Consumes: `Drone.take_damage()` (already built, currently unreachable), `Ship.health`.
- Produces: `Weapon.fire_at(target: Node3D) -> void`, `Weapon.cooldown: float`, `Weapon.damage: float`, `Weapon.range: float`.

- [ ] **Step 1: `projectile.gd`** — travels along +Z at `speed`, frees itself after `lifetime` seconds, and on body entry calls `take_damage(damage)` if the body has that method and a differing `allegiance`.

- [ ] **Step 2: `weapon.gd`** — a `Node` child of an agent, holding cooldown state and instancing projectiles.

- [ ] **Step 3: `EngageState`** — pursue the nearest enemy `Drone` or `Ship` and call `fire_at()` when inside `range`. Steer with the existing `SeekBehaviour`, retargeted in `_enter()`; there is no `PursueBehaviour` in this project, only `OffsetPursueBehaviour`, which holds a formation slot and is the wrong shape for chasing. Add an `Engage` node of type `SeekBehaviour` to `drone.tscn` rather than reusing `OffsetPursue`, whose target is the commander.

- [ ] **Step 4: Runtime probe.** Place two drones of opposing allegiance 15 units apart, force both into `Engage`, step 400 frames, and assert: at least one projectile existed at some point; at least one drone's `health` fell; a drone reaching zero health emitted `died` and left `swarm.units`.

- [ ] **Step 5: Commit** — `feat(combat): add weapons, projectiles and damage`

---

### Task 6: CommanderAI — MAE AUTHORS THE DECISION

**Files:**
- Create: `godot/scripts/agents/commander_ai.gd`
- Modify: `godot/scenes/main.tscn` (an enemy Ship, Swarm, Hive and drones at allegiance 1)

**Interfaces:**
- Consumes: `Swarm.order()`, `Hive.alloys`, `Barnacle.nearest_to()`.
- Produces: `CommanderAI.decide() -> Swarm.Intent`.

- [ ] **Step 1: Write the scaffolding.** A `Node` that samples on an interval (mirror `MusicDirector.sample_interval`, do not sample per frame), resolves its `Swarm` and `Hive` on first use, and calls `decide()` then `swarm.order()`.

- [ ] **Step 2: Leave `decide()` as `TODO(human)`.** Mae writes it. She will need: `swarm.units.size()`, `hive.alloys`, `Barnacle.nearest_to()`, the enemy `Ship`'s position and health, and `Swarm.Intent`. The decisions that are hers: when a hive stops harvesting and starts fighting, whether it retreats when losing, and whether it reacts to the player's swarm size or ignores it.

- [ ] **Step 3: STOP.** Do not implement `decide()`. Report the task as awaiting Mae.

- [ ] **Step 4 (after Mae writes it): Runtime probe.** Step 1200 frames and assert the enemy swarm's intent took at least two distinct values, that its `Hive.alloys` rose at some point, and that its drone count changed.

- [ ] **Step 5: Commit** — `feat(ai): add a rival hive commander`

---

### Task 7: Win and lose — CUT THIS FIRST IF TIME RUNS OUT

**Files:**
- Create: `godot/scripts/world/match_state.gd`
- Modify: `godot/scenes/main.tscn`

- [ ] **Step 1:** A node watching both Ships' `destroyed` signals; the survivor wins.
- [ ] **Step 2:** Drive `MusicDirector.play_phase()` to `VICTORY` or `DEFEAT`. Both themes already exist and are currently unreachable.
- [ ] **Step 3: Runtime probe.** Set the enemy ship's health to zero, step 10 frames, assert the phase became `VICTORY`.
- [ ] **Step 4: Commit** — `feat(world): decide the match when a commander dies`

---

## Tuesday, protected — no new features

- [ ] Export Linux and Windows from `godot/build/`; confirm the Linux binary runs (`embed_pck` is now true, so the executable is self-contained apart from `libdd3d`)
- [ ] Rewrite `README.md` — currently 135 lines describing the pre-pivot concept. Source material is `docs/gameplay/`
- [ ] Replace placeholder music with Musopen recordings before anything is uploaded
- [ ] Record the demo video: flocking, the flee reflex, orders 1 to 4, harvesting, the factory, the rival hive
- [ ] Update `docs/gameplay/index.md` build-status table

## Deferred

`docs/stretch-list.md` holds these; none are needed for a complete artefact: sound effects, factory upgrade tiers, enemy swarm parity beyond a single rival, player-triggered split and merge, obstacle avoidance, procedural animation.
