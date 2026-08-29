# The opposition

[Back to contents](index.md) | Previous: [The economy](04-economy.md) | Next: [References](06-references.md)

**Not built yet — Phase 4.**

---

## A symmetric commander

The enemy is a `CommanderAI`: its own ship, its own swarm, the same five
intents, the same behaviours. Built from the same classes as the player's side,
with an allegiance flag deciding which is which — built once, instantiated
twice.

It runs a high-level decision loop of its own: **expand**, **press**,
**retreat**.

---

## Why symmetric

The player controller and the enemy AI present an identical interface onto ship
and swarm: move, fire, set intent, designate. The ship does not know which is
at the helm.

Three things follow from that:

**The enemy is testable.** Point `CommanderAI` at the player's own ship and it
flies it. Any bug in the AI shows up immediately, in a ship you already know
the feel of.

**The match is a genuine mirror.** The opponent is not a scripted dummy with
different rules and hidden advantages. It has exactly your options, which makes
losing informative rather than unfair.

**It costs almost nothing.** A symmetric opponent is one new class, not a
parallel implementation of everything.

---

## Winning and losing

Destroy the enemy commander ship. Losing your own ends the match.

Nothing else is a win condition. Units are ammunition, not territory. There is
no base to raze, no points to accumulate, and no timer.

That single condition is what keeps the economy honest: every unit you grow
exists to protect one ship or threaten another, and any strategy that forgets
that loses to one that does not.

[DRAFT — Mae: worth deciding whether the enemy commander flees at low health.
It would make the endgame a chase rather than a slugging match, and it would
demonstrate the same "self-interest over orders" idea at the commander level
that the swarm demonstrates at the unit level. Cheap to add if `CommanderAI`
already has a retreat state.]
