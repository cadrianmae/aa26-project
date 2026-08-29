# Thargoid Swarm Command — Gameplay

**Module:** CMPU 4031 Autonomous Agents
**Author:** Mae Capacite (C21348423)
**Status:** Draft. Sections marked [DRAFT] are a first pass for Mae to edit.

This describes what the game IS and how it PLAYS. The architecture that
implements it lives in
[`../superpowers/specs/2026-08-27-swarm-command-rts-design.md`](../superpowers/specs/2026-08-27-swarm-command-rts-design.md).

Where something is not built yet, it says so. Nothing here claims a feature
that does not exist.

---

## Contents

1. [Concept and core loop](01-concept.md) — the pitch, the four-stage loop, what the player does
2. [The swarm](02-the-swarm.md) — emergent membership, steering, WTPRS
3. [The state machine](03-state-machine.md) — two tiers, and the flee reflex
4. [The economy](04-economy.md) — Thargoid Barnacles, Meta-Alloys, the factory
5. [The opposition](05-opposition.md) — the rival hive, winning and losing
6. [References](06-references.md) — sources and attribution

---

## Build status

Honest status with Phase 2 complete: the swarm flocks, holds formation,
scatters from a threat and re-forms when it passes.

| System | Status |
|---|---|
| Flat-shaded rendering, custom shader (wireframe retained as a toggle) | Built |
| Parallax starfield, three layers | Built |
| World-space dust particles | Built |
| Ship flight on the XZ plane | Built |
| Tilted follow camera | Built |
| WTPRS force accumulation | Built |
| Offset-pursue formation | Built |
| Debug gizmos on every behaviour | Built |
| Phase-based music director | Built, placeholder tracks |
| Spatial hash, nearest-first neighbour queries | Built |
| Flocking: separation, alignment, cohesion | Built |
| Two-tier state machine, nine unit states | Built |
| Flee reflex, reachable from every state | Built |
| Thargon health and death | Built, nothing triggers it yet |
| Barnacles, harvesting, Meta-Alloys | Phase 3 |
| Swarm intent broadcasting and hotkeys | Phase 3 |
| Swarm factory, Interceptor tiers | Phase 3 |
| Rival hive commander AI | Phase 4 |
| Weapons, combat | Phase 4 |

Six of the nine unit states are honest stubs that hold formation: `Launch`,
`Harvest`, `Deposit`, `Engage`, `Patrol` and `Detonate`. Each is a placeholder
whose real behaviour arrives in the phase named above. `Follow` and `Flee` are
implemented, which is what the flocking and the reflex need.

`Thargon health and death` is built and wired — `take_damage()` deregisters
from the swarm, emits, and frees — but nothing calls it yet. Barnacle
harvesting and combat are what will.

---

## Diagram checklist

Two tools, chosen per diagram.

**Mermaid** for anything that is really structured data — states, flows,
dependencies. It renders natively in both Obsidian and GitHub, needs no export
step, and lives in the document as diffable text, so it can never drift out of
date with the prose around it.

**Excalidraw** for anything that needs visual judgement — spatial illustration,
emphasis, before-and-after panels. Keep the editable source in
`docs/diagrams/` and export SVG into `docs/images/`.

| Diagram | Tool | Where | Done |
|---|---|---|---|
| Unit state machine | Mermaid | [The state machine](03-state-machine.md) | [x] |
| Meta-Alloy flow | Mermaid | [The economy](04-economy.md) | [ ] |
| Core loop | Either | [Concept and core loop](01-concept.md) | [ ] |
| Emergent membership | Excalidraw | [The swarm](02-the-swarm.md) | [ ] |
| WTPRS accumulation | Excalidraw | [The swarm](02-the-swarm.md) | [ ] |

The bottom two want Excalidraw specifically. Emergent membership is four
before-and-after panels, and WTPRS needs the behaviours below the force cut
visibly greyed out — both are arguments made by *emphasis*, which a
graph-layout tool will not make for you.

For Excalidraw exports, embed with `![Core loop](../images/core-loop.svg)`
rather than a `![[wikilink]]`: GitHub does not render wikilinks, and a marker
reading the repo on GitHub would see literal brackets.

Export SVG rather than PNG: it stays sharp in the README, in any submitted
PDF, and at any zoom in the demo video.
