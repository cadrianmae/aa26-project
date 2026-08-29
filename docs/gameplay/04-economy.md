# The economy

[Back to contents](index.md) | Previous: [The state machine](03-state-machine.md) | Next: [The opposition](05-opposition.md)

**Not built yet — Phase 3.**

---

## Meta-Alloy flow

The setting is a single asteroid belt. Thargoid Barnacles are organic growths
that seed onto the asteroids themselves — the asteroid is the substrate, the
Barnacle is the harvestable growth on it, not the asteroid entire. That is
also why a Barnacle is a producer rather than a deposit: canon has Barnacles
actively extracting resources from the rock and converting them into
Meta-Alloys, so a worked Barnacle regrows slowly rather than being mined out
to nothing.

```mermaid
flowchart LR
    AST["Thargoid Barnacle<br/><small>grows on an asteroid,<br/>regrows slowly</small>"]
    HARVEST["Drone in HARVEST"]
    DEP["Drone in DEPOSIT"]
    POOL[("Meta-Alloy pool<br/><small>on the Matriarch</small>")]
    FAC["Swarm factory<br/><small>upgradeable x5</small>"]
    NEW["New Drones<br/><small>batch of 5 to 15</small>"]
    LOST["Drone destroyed"]

    AST -->|"yields Meta-Alloys,<br/>corrodes the Drone"| HARVEST
    HARVEST -->|"carrying full"| DEP
    DEP -->|"transfers Meta-Alloys"| POOL
    POOL -->|"spends"| FAC
    FAC -->|"grows"| NEW
    NEW --> HARVEST

    HARVEST -.->|"health gone"| LOST
    DEP -.->|"killed in transit"| LOST

    classDef loss fill:#5a1616,stroke:#ff6b6b,color:#fff
    classDef store fill:#1a3a4a,stroke:#4aa3c8,color:#fff
    class LOST loss
    class POOL store
```

The dashed arrows are the point. The loop is **lossy**: a Drone can die at
the Barnacle or on the way home, so Meta-Alloy-per-Drone is not guaranteed
to be positive. That is what stops "send everyone to harvest" from being
trivially correct.

1. A Drone in `HARVEST` arrives at a Barnacle and draws off the Meta-Alloys
   it has extracted from the asteroid.
2. The Barnacle corrodes the Drone the whole time it works.
3. When full, the Drone enters `DEPOSIT` and carries the Meta-Alloys back to
   the Matriarch.
4. The Matriarch adds them to the hive's single Meta-Alloy pool.
5. The factory spends from that pool to grow a batch of five to fifteen
   Drones.

---

## Why the Barnacles are caustic

Making harvesting *dangerous* rather than merely *slow* does three things:

**It makes the economy a decision.** A slow economy is just a timer. An
economy that costs you Drones means every harvesting run is a wager.

**It fires the flee reflex during peacetime.** A Drone whose health drops
while harvesting will break off and scatter. That means the swarm reads as
alive even when nothing is attacking you — which matters, because the demo
video will spend most of its length not in combat.

**It makes Meta-Alloys-per-Drone uncertain.** A Drone can die before
depositing, so the loop is lossy. That is what stops "send everyone to
harvest" being the obviously correct move.

---

## Why the factory is on the Matriarch

The factory is a module on the Matriarch, not a static base.

Thargoids are nomadic: canon describes them as existing entirely in space or
within fabricated hives, never in a settlement they leave behind. A
ship-mounted factory follows from that directly, rather than being invented to
dodge base-building scope.

You carry your own production with you. There is no base to defend, no second
thing to lose, and no build order. Killing the Matriarch ends the match, and
that is the only way to end it — see [the opposition](05-opposition.md).

The alternative, a fixed structure, would add territory pressure and a second
win condition. It was rejected as scope: one deadline, one thing to protect.

---

## Upgrades

The factory upgrades five times. Each level increases batch size, growth rate,
or both — upgrading is the Matriarch becoming a bigger hive, not just a bigger
batch size with no fictional weight behind it.

The five levels are not an arbitrary number, but they are not a name copied
from canon either. Canon establishes that Thargoid vessels come in tiers of
increasing brood capacity — the Interceptor line scales in exactly five named
steps by drone capacity: Cyclops (32), Basilisk (64), Medusa (96), Hydra
(128), then Orthrus. That is precedent for the *pattern*, not a classification
the Matriarch belongs to: a Matriarch is not an Interceptor and has no
Interceptor variants. It follows the same escalating pattern with five growth
stages of its own.

[DRAFT — Mae: the five growth stages are deliberately left unnamed here.
Naming them is your call, not a design decision to hand off — but five names,
escalating in the same spirit as the Interceptor line above, would read well
in the README.]
