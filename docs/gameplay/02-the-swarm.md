# The swarm

[Back to contents](index.md) | Previous: [Concept and core loop](01-concept.md) | Next: [The state machine](03-state-machine.md)

---

## Emergent, not owned

This is the central design commitment, and everything else follows from it.

There is no roster. No object holds a list called "the swarm". A swarm is
simply *whichever Drones are currently near each other and on the same
side*.

Each Thargoid Drone (`Drone` in code) asks a spatial index, every frame, "who
is near me, on my side?" and steers according to what it finds. From that one
question, four behaviours fall out for free:

- **Join** — a newly grown Drone flies toward the group and starts seeing
  neighbours
- **Leave** — a Drone dies; its neighbours re-query next frame and re-cohere
- **Split** — a group pulled in two directions separates naturally
- **Merge** — two groups drifting together start seeing each other

None of those are coded as features. They are consequences.

> **[DIAGRAM 2 — Emergent membership]**
> Four small panels in a row, each showing the same handful of unit dots:
> Join (one dot flying in from the edge toward a cluster), Leave (a dot
> greyed out, its neighbours' links re-drawn to each other), Split (one
> cluster pulling into two), Merge (two clusters converging into one).
> Draw the neighbour links as thin lines between dots so the reader can see
> the links redraw. Emphasise that nothing external changes — only which
> dots are near which.
![[02-the-swarm Drawing 2026-08-29T15-19]]

**Why it matters for the brief:** a lifeform that is a list of members is a
spreadsheet. A lifeform whose group structure is a *result* of individual
behaviour is a flock. The assignment asks for something that reads as alive,
and this is the structural reason it does.

---

## Finding neighbours cheaply

The naive way to answer "who is near me" is for every Drone to check every
other Drone. That is O(n squared): at 100 units it is 9,900 distance checks
per frame, at 1,000 units it is 999,000.

Instead the swarm keeps a **uniform spatial hash**. The world is divided into
cubic cells, every Drone is binned into a cell once per frame, and a Drone
asking for neighbours only tests the units in its own cell and the 26 around
it — 27 cells in total.

Binning is O(n) and there is no tree to rebuild, which is the right trade for a
few hundred agents that all move every frame.

Three defects in the reference implementation are corrected here, and each
correction is documented at its site in the code:

1. **Cell size smaller than the perception radius.** The 27-cell scan only
   guarantees a reach of one cell width, so a cell smaller than the neighbour
   distance silently misses genuine neighbours.
2. **Neighbour cap truncating by scan order.** Capping the neighbour count by
   stopping early keeps whichever units the iteration reached first, not the
   nearest ones. Fixed by collecting all candidates, sorting by distance, then
   truncating.
3. **Alignment latching its last force.** A Drone that loses all its
   neighbours kept applying its previous alignment force forever. Fixed by
   contributing nothing when there are no neighbours.

---

## How a Drone decides where to go

Each Drone runs several steering behaviours at once and combines them into
one force. The combination is **WTPRS**: Weighted Truncated Running Sum with
Prioritisation.

> **[DIAGRAM 3 — WTPRS force accumulation]**
> A vertical list of behaviour boxes in priority order (Flee, Separation,
> Alignment, Cohesion, Offset Pursue), each with a weight label and a small
> arrow showing its force. To the right, a running accumulator arrow growing
> as each is added. Draw a horizontal line labelled `max_force` and show the
> accumulator hitting it partway down the list, with everything below the cut
> greyed out and labelled "never evaluated this tick".
> The greyed-out part is the whole point of the diagram.
![[02-the-swarm Drawing 2026-08-29T15-17]]

1. **Weighted** — each behaviour's force is multiplied by its own weight
2. **Running sum** — forces accumulate, and the total is tested after *every
   single addition*
3. **Truncated** — when the total exceeds the unit's force budget it is
   clamped
4. **With prioritisation** — and the loop *breaks*, so behaviours later in the
   list contribute nothing at all that tick

The consequence worth understanding: **priority is scene-tree order.** There is
no priority property anywhere. Reordering the behaviour nodes on a unit changes
what it does. `Flee` sits first, which is why the reflex wins.

[DRAFT — Mae: this is the section a marker is most likely to probe, since it is
the algorithm the module teaches and the one you implemented yourself. Worth
writing the last paragraph in your own words.]

---

## The behaviours themselves

| Behaviour | What it wants | Note |
|---|---|---|
| Separation | Get away from close neighbours | Inverse-distance falloff, so near neighbours dominate. Magnitude kept. |
| Alignment | Match neighbours' average heading | Averages headings, not velocities, so it is speed-independent |
| Cohesion | Move toward the neighbours' centre | Normalised to unit length, so distance sets direction only |
| Offset pursue | Hold a slot relative to the Matriarch | Slot is captured from where the Drone starts, not authored |
| Flee | Get away from a threat | Range-gated, so a distant threat costs nothing |

Separation keeps its magnitude and cohesion discards its own. That asymmetry is
deliberate: it is what stops the flock collapsing into a point.
