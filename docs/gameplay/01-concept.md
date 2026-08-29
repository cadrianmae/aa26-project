# Concept and core loop

[Back to contents](index.md) | Next: [The swarm](02-the-swarm.md)

---

## The pitch

A 2.5D top-down real-time strategy game. You pilot a living bio-tech commander
ship and command a swarm of small living-metal creatures that behave like loyal
wingmen. The enemy is your mirror: the same ship, the same swarm, the same
options, driven by an AI commander.

Everything is rendered as wireframe, in the style of Elite (1984): white and
cyan lines on black, with a parallax starfield and dust streaming past as you
fly.

**The brief this answers:** create an artificial lifeform that interacts with
its surroundings and the player, with a mind of its own. The swarm is that
lifeform. It has no face and no dialogue. It reads as alive because of how it
moves: it holds together, it flinches, it scatters, and it re-forms.

---

## The core loop

> **[DIAGRAM 1 — The core loop]**
> A cycle of four nodes with arrows round: **Harvest** (units scrape asteroids)
> to **Spend** (factory grows units) to **Command** (you assign intent) to
> **Fight** (swarm engages, flinches, re-forms), arrow back to Harvest.
> Put the player ship at the centre with lines out to each node, to show every
> stage passes through the commander.
> Annotate the Harvest-to-Spend arrow with "bio-alloy" and the Spend-to-Command
> arrow with "5-15 new units".
![[01-concept Drawing 2026-08-29T15-19]]
1. **Harvest.** Units scrape caustic asteroids for alloy and convert it to
   bio-alloy. The asteroids corrode them while they work, so harvesting costs
   health continuously.
2. **Spend.** The swarm factory, a module on your ship, slowly grows new units
   in batches of five to fifteen. It can be upgraded five times.
3. **Command.** Hotkeys broadcast an intent to the whole swarm. Right-click or
   the reticle designates a target or a point.
4. **Fight.** You fly and fire your own weapon while the swarm engages,
   flinches from danger, scatters, and re-coheres around you.

---

## The tension that makes it a strategy game

Every unit harvesting is a unit not screening you.

There is one resource pool and no build menu. The only decision you ever make
is *where the creatures point*. Push the economy and you fly exposed; keep
everyone home and the enemy out-produces you and arrives with more.

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

You never select individual units. The swarm is commanded as a whole, because
your hands are already busy flying. That is a deliberate constraint: a
selection box and a flight stick compete for the same attention, and the swarm
is meant to feel like something you *direct* rather than something you
*micromanage*.

### The five intents

- **HARVEST** — go and harvest, wherever the nearest asteroid is
- **FOLLOW** — hold a defensive formation around the ship
- **ATTACK** — break off and engage the designated target
- **RECALL** — come home now
- **PATROL** — circle a designated point and watch it

Intent is a *suggestion*, not an order. See
[the state machine](03-state-machine.md).
