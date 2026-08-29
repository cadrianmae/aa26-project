# Concept and core loop

[Back to contents](index.md) | Next: [The swarm](02-the-swarm.md)

---

## The pitch

A 2.5D top-down real-time strategy game set in the Elite Dangerous universe,
among the Thargoids. You pilot a Thargoid Interceptor and command a swarm of
Thargons — small combat-and-harvest drones — that behave like loyal wingmen.
The enemy is your mirror: another Interceptor, another swarm of Thargons, the
same options, driven by an AI commander.

This is not humans against aliens. Both sides are Thargoid: two rival hives
contesting the same territory. Canon already has Thargoids fighting over the
Barnacle sites they seeded themselves one to two million years ago, so two
hives contesting a shared belt of seeded asteroids is almost canon rather than
an invented premise.

Rendering follows Frontier / Elite II (1993): flat-shaded solid polygons, per-
faction colour, with a parallax starfield and dust streaming past as you fly.
The baseline Cyclops Interceptor presents grey/cyan in canon, which is why the
player's hulls are cyan; the rival hive is amber. The original wireframe
renderer, in the style of Elite (1984), is retained behind a `render_style`
toggle on the `Hull` class rather than discarded.

**The brief this answers:** create an artificial lifeform that interacts with
its surroundings and the player, with a mind of its own. The swarm of Thargons
is that lifeform. It has no face and no dialogue. It reads as alive because of
how it moves: it holds together, it flinches, it scatters, and it re-forms.

---

## The core loop

> **[DIAGRAM 1 — The core loop]**
> A cycle of four nodes with arrows round: **Harvest** (Thargons work Barnacles)
> to **Spend** (factory grows Thargons) to **Command** (you assign intent) to
> **Fight** (swarm engages, flinches, re-forms), arrow back to Harvest.
> Put the player's Interceptor at the centre with lines out to each node, to
> show every stage passes through the commander.
> Annotate the Harvest-to-Spend arrow with "Meta-Alloys" and the Spend-to-
> Command arrow with "5-15 new Thargons".
![[01-concept Drawing 2026-08-29T15-19]]
1. **Harvest.** Thargons work Thargoid Barnacles growing on asteroids,
   drawing off the Meta-Alloys the Barnacle itself extracts and converts from
   the rock. The Barnacle corrodes them while they work, so harvesting costs
   health continuously.
2. **Spend.** The swarm factory, a module on your Interceptor, slowly grows
   new Thargons in batches of five to fifteen. It can be upgraded five times.
3. **Command.** Hotkeys broadcast an intent to the whole swarm. Right-click or
   the reticle designates a target or a point.
4. **Fight.** You fly and fire your own weapon while the swarm engages,
   flinches from danger, scatters, and re-coheres around you.

The factory lives on the Interceptor rather than as a static base because
Thargoids are nomadic: canon describes them as existing entirely in space or
within fabricated hives, never in a fixed settlement. A ship-mounted factory
is the in-fiction default, not a design shortcut.

**A deliberate deviation from canon:** in Elite Dangerous, Thargons are pure
combat drones, controlled by the parent ship's hive mind and inert without it.
This project's Thargons harvest as well as fight. That is a conscious change
made for gameplay reasons — one resource-gathering, dual-purpose unit rather
than two unit types — not an oversight.

---

## The tension that makes it a strategy game

Every Thargon harvesting is a Thargon not screening you.

There is one resource pool and no build menu. The only decision you ever make
is *where the creatures point*. Push the economy and you fly exposed; keep
everyone home and the rival hive out-produces you and arrives with more.

[DRAFT — Mae: is this the tension you actually want? The alternative is to make
units cheap and the pressure temporal rather than positional. Worth deciding
before Phase 3 builds the economy around it.]

---

## What the player does

| Verb | Input | Notes |
|---|---|---|
| Fly | W / S thrust, A / D turn | Movement is locked to the XZ plane |
| Fire | Space | Not implemented yet — Phase 4 |
| Set swarm intent | Number keys | Not implemented yet — Phase 3 |
| Designate | Right-click or reticle | Not implemented yet — Phase 3 |

You never select individual Thargons. The swarm is commanded as a whole,
because your hands are already busy flying. That is a deliberate constraint: a
selection box and a flight stick compete for the same attention, and the swarm
is meant to feel like something you *direct* rather than something you
*micromanage*.

### The five intents

- **HARVEST** — go and work the nearest Barnacle
- **FOLLOW** — hold a defensive formation around the Interceptor
- **ATTACK** — break off and engage the designated target
- **RECALL** — come home now
- **PATROL** — circle a designated point and watch it

Intent is a *suggestion*, not an order. See
[the state machine](03-state-machine.md).
