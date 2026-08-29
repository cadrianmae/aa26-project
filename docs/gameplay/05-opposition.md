# The opposition

[Back to contents](index.md) | Previous: [The economy](04-economy.md) | Next: [References](06-references.md)

**Not built yet — Phase 4.**

---

## A symmetric commander

The rival hive is a `CommanderAI`: its own Interceptor, its own swarm of
Thargons, the same five intents, the same behaviours. Built from the same
classes as the player's side, with an allegiance flag deciding which is which
— built once, instantiated twice.

It runs a high-level decision loop of its own: **expand**, **press**,
**retreat**.

---

## Why symmetric, and why rigid

The player controller and the rival hive's AI present an identical interface
onto Interceptor and swarm: move, fire, set intent, designate. The ship does
not know which is at the helm.

Three things follow from that:

**The rival hive is testable.** Point `CommanderAI` at the player's own
Interceptor and it flies it. Any bug in the AI shows up immediately, in a ship
you already know the feel of.

**The match is a genuine mirror.** The opponent is not a scripted dummy with
different rules and hidden advantages. It has exactly your options, which makes
losing informative rather than unfair.

**It costs almost nothing.** A symmetric opponent is one new class, not a
parallel implementation of everything.

The three-state loop — expand, press, retreat — is also a deliberate piece of
characterisation rather than a shortcut. Thargoids are described in canon as
territorial, hyper-aggressive, and "extremely slow to adapt". A rival hive
that cycles through a small, rigid set of postures rather than adapting
cleverly to the player is not a simplified opponent standing in for a smarter
one — it is what the species is written to be. The rigidity is the fiction,
not a compromise on it.

---

## Winning and losing

Destroy the rival hive's Interceptor. Losing your own ends the match.

Nothing else is a win condition. Thargons are ammunition, not territory. There
is no base to raze, no points to accumulate, and no timer.

That single condition is what keeps the economy honest: every Thargon you grow
exists to protect one Interceptor or threaten another, and any strategy that
forgets that loses to one that does not.

### Hearts are narrative, not mechanical

Thargoid vessels are described in canon as having "Hearts" — organic analogues
to subsystems — and as regenerating external damage. This project does not
model that. Both Interceptors use a single health pool with uniform damage:
there is no per-Heart subsystem, no heart-destruction phase, and no
regeneration. Where "Hearts" comes up in this project's fiction, it is the
in-universe explanation of *why* a ship has a weak point at all, not a
description of code that exists. Keeping that distinction explicit is
consistent with the honesty this document tries to keep about what is built
versus what is only lore.

[DRAFT — Mae: worth deciding whether the rival hive's Interceptor flees at low
health. It would make the endgame a chase rather than a slugging match, and it
would demonstrate the same "self-interest over orders" idea at the commander
level that the swarm demonstrates at the unit level — and it would tie neatly
into the overdeveloped-survival-instinct framing already used for the flee
reflex. Cheap to add if `CommanderAI` already has a retreat state.]
