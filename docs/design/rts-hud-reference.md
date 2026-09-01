# RTS / Space-Sim Design Reference
**For:** 2.5D top-down RTS, Godot 4.7, 640x360 upscaled, single-Matriarch-plus-swarm vs mirror AI
**Student:** C21348423 — CMPU-4031 Autonomous Agents artefact

---

## 1. RTS HUD Conventions

### What players need continuously vs on demand
- **Continuous (always visible):** own health/shield, resource count, minimap/radar, current selection state, unit-count summary. Players should never have to open a menu to check "am I about to die" or "can I afford this."
- **On demand (call up or contextual):** detailed unit stats, build/tech trees, full unit list, combat log. Dave Pottinger (Age of Empires/Halo Wars lead) notes RTS interfaces have changed little in 15+ years because the genre's information density is intrinsically hard to compress — the "always show enough to act, hide the rest until asked" split is the load-bearing pattern, not a shortcut ([Wayward Strategy interview](https://waywardstrategy.com/2015/05/04/lets-talk-rts-user-interface-part-1-interview-with-dave-pottinger/)).

### Minimap/radar design
- Minimap conventions: player units/base one colour, enemy another, neutral/resources a third, consistently applied everywhere (minimap, unit outlines, health bars) ([Polydin HUD guide](https://polydin.com/game-hud-design/)).
- The classic RTS minimap sits in a screen corner; Elite Dangerous instead uses a **tilted circular radar** to convey 3D positional data (see Section 2) — appropriate for a project with a Z-axis threat dimension even in a top-down 2.5D game, since drones/ships can be above/below the play plane conceptually via distance rings.

### Selection and target feedback
- Single-unit selection -> detailed panel; multi-unit selection -> compact icon+healthbar row per unit ([Medium/CodeX RTS selection devlog](https://medium.com/codex/making-a-rts-game-8-boosting-our-selection-feature-unity-c-8552bffd2f8b)).
- Control groups: Ctrl+number to assign, number to recall, double-tap number to snap camera to group ([search synthesis, RTS convention](https://www.gamedeveloper.com/game-platforms/building-rts-user-interface-in-unity-deterrence-video-devlog-8)).
- Notable failure case: Halo Wars added a "Select All" button specifically because control groups didn't work well on console input — a cautionary example of compensating for a broken core interaction with an extra button instead of fixing the interaction.

### Resource display
- Resource counters belong in one fixed, glanceable location (commonly top corner) — never require navigating a menu to check affordability.

### Unit-count and health display
- Health bars should encode state via colour + fill, and ideally a secondary cue (numeral or shape) since colour alone fails colourblind players (ties into Section 6).
- Rebuilding/destroying UI health-bar objects every selection change is a real, cited performance mistake — relevant for you at 640x360/Godot with many drones ([Medium RTS healthbars devlog](https://medium.com/codex/rts-interlude-4-improving-the-healthbars-unity-c-48ee8d663e09)).

### Common RTS HUD mistakes (from GameDeveloper.com "Dos and Don'ts")
- **Don't** scatter functionally-related info across the screen (resources top, orders right, build bottom) — this forces excessive attention-splitting. **Do** centralise related info/commands into as few zones as possible ([GameDeveloper.com](https://www.gamedeveloper.com/design/ui-strategy-game-design-dos-and-don-ts)).
- **Don't** go minimalist for its own sake — RTS players need density, not whitespace; an under-informative HUD causes confusion, not clarity, in this genre specifically.
- **Do** put idle-unit / event notifications in the HUD (e.g. "drone idle", "under attack") so the player isn't forced to scan the whole map constantly.
- **Do** provide both a keyboard and a UI-visible path to every command (helps learnability without punishing keyboard-only players).

### Applies to your project
- **Already follows:** centralised radar+status panels near the bottom (avoids scatter); alloy/resource readout in a fixed corner; number-key orders (keyboard-first, matches "comprehensive hotkeys" guidance).
- **Gaps/opportunities:**
  - No idle/event notification channel currently described (e.g. "drone destroyed", "harvest complete", "under attack from bearing X"). This is cheap and high value per the Dos/Don'ts source above.
  - No stated on-demand detail panel for swarm composition (how many drones of what type/order are active) beyond a raw count — consider one compact expandable readout, not a separate screen.

---

## 2. Elite Dangerous & Comparable Space-Sim HUDs

### Elite Dangerous panel breakdown
- **Radar (scanner):** shows the player's position relative to other ships/points of interest; contact colour encodes disposition — green friendly, blue neutral, yellow alerted, red hostile ([Elite Dangerous Wiki, HUD/Center](https://elite-dangerous.fandom.com/wiki/HUD/Center)).
- **Compass:** a small circular indicator near the scanner showing current target's direction — **solid = target ahead of you, hollow = target behind you.** This solid/hollow distinction is the key trick: it encodes a 3D relationship (in front/behind) as a 2D fill state, cheap to read at a glance ([same source](https://elite-dangerous.fandom.com/wiki/HUD/Center)).
- A second compass function points to the allocated dock/nav target and turns blue when lined up for a hyperspace jump — i.e. the compass is reused/recoloured per context rather than adding new HUD elements.
- Positioning logic: radar and compass are adjacent because they're read together — "where is it, and which way am I turning to face it" is one glance, not two.

### Everspace 2 (comparison)
- Three separate health bars for shield (blue), armour (orange), hull (red) — colour-coded by damage-mitigation layer so the player instantly knows which resource is being depleted, not just "how much HP left" ([Everspace Wiki via search synthesis](https://everspace.fandom.com/wiki/Heads-up_display_(ES2))).
- HUD elements are partly built into the cockpit model itself (diegetic framing) — not directly transferable to a top-down camera, but the layered shield/armour/hull colour convention is directly reusable for your ship-status panel.

### Rebel Galaxy / FTL (comparison, general knowledge — confirm visually if used as a citation)
- Rebel Galaxy restricts combat to a 2D plane much like your top-down XZ setup, which is why its HUD is closer to an RTS/arcade radar than Elite's full 3D sphere — a relevant precedent since your game is also plane-restricted. FTL uses no radar at all — spatial awareness is replaced entirely by discrete rooms/subsystem panels, useful only as a contrast case (not applicable to your open-space design).

### Applies to your project
- **Already follows:** tilted circular radar "Elite Dangerous style" (explicitly stated) is a direct, well-precedented borrow; wrapping heading arc plausibly serves the same "facing + target direction" role as ED's compass.
- **Gaps/opportunities:**
  - Confirm whether target indicators use a **solid/hollow ahead-behind** convention on your heading arc or radar blips — if not, this is a very cheap, high-payoff addition (a few minutes: swap a filled vs outlined draw call based on dot-product sign).
  - Adopt the **shield/armour/hull three-colour split** (blue/orange/red) for your ship/target status panels if Matriarch or drones have layered defences — gives instant "what kind of damage am I taking" read, not just a shrinking bar.
  - Consider disposition colour-coding for radar contacts (green/blue/yellow/red) consistent with target panel — check this is already true for HOLD/RALLY/PATROL/HARVEST/ENGAGE order states too, since a swarm HUD needs an equivalent "what is this drone currently doing" cue at a glance.

---

## 3. Controls: RTS + Space-Sim Conventions

### Standard RTS bindings
- Shift+Click adds to selection, Ctrl+Click removes ([search synthesis, Spring RTS engine forums](https://springrts.com/phpbb/viewtopic.php?t=30173)).
- Common order letters: A=attack, S=stop, P=patrol, F=fight, R=repair, D/G=guard/hold — your number-key order scheme (HOLD/RALLY/PATROL/HARVEST/ENGAGE) diverges from the classic single-letter convention but is defensible for a small fixed order set, and arguably easier to teach since it's a fixed menu rather than memorised letters.
- Shift+Order queues multiple orders in sequence — worth having if time allows, but not essential for a small artefact.

### Target cycling
- **Tab = cycle nearest target** is a cross-genre convention (MMOs, RTS, some FPS) — "target nearest enemy, each subsequent press moves to the next nearest, wrapping back to the first" ([search synthesis across FFXIV, general MMO convention](https://saltedxiv.com/guides/target-selection-guide-mouse-keyboard)).
- Your existing Tab-cycle-target and T-target-under-cursor match this convention exactly — no change needed, but confirm Tab cycling order is genuinely nearest-first (not just list-order), since that's the part players expect implicitly.

### Applies to your project
- **Already follows:** Tab cycle target, T target-under-cursor, Esc clear target — all match established conventions precisely; number-key order issuing is a clean adaptation of RTS command-letter conventions for a small fixed order set; WASD+mouse-aim matches twin-stick/space-sim norms.
- **Gaps/opportunities:** none critical — controls are already convention-compliant. Lowest-priority area for further research time.

---

## 4. Readability at Low Resolution (640x360)

- 640x360 and 320x180 are the two standard pixel-art base canvases because they integer-scale cleanly to 1280x720 / 1920x1080 / 3840x2160 — you're already on the "more headroom" of the two standard choices, which supports smaller text and more layered UI than 320x180 would allow ([Grokipedia, Pixel Art UI Resolutions](https://grokipedia.com/page/Pixel_Art_UI_Resolutions)).
- Minimum in-game text height guidance: **do not go below ~9px height at 1280x720**-equivalent scale for anything the player must read at a glance; headings 24-32px at that same reference scale (scale proportionally down for 640x360, i.e. roughly 4-5px minimum for body glyphs at native resolution before upscaling) ([search synthesis, game UI readability guidance](https://www.uichallenges.design/guides/game-ui-design)).
- Line height 120-150% of font size to avoid cramped stacked text (resource readouts, status panels).
- Use an 8px or 4px grid for all UI element placement/sizing — keeps edges crisp under integer upscale and avoids sub-pixel blur that ruins pixel art at low res.

### Applies to your project
- **Gaps/opportunities:**
  - Audit every HUD text element (resource readout, ship/target panels) against a hard minimum glyph height at native 640x360 — anything you can't read clearly in an actual in-engine screenshot at 1x zoom is too small; this is a 15-30 minute pass, not a redesign.
  - Confirm all HUD panels are placed/sized on an 8px (or 4px) grid relative to the 640x360 canvas so upscaling stays crisp — if any panel positions were set by eyeballing in the editor, snap them now before polish time runs out.

---

## 5. Game Feel for Swarm/Fleet Combat

- Readability under fast RTS combat depends on **strong silhouettes and distinct colour/size/animation per unit type** — without this, players can't parse who's who mid-fight ([search synthesis, RTS unit readability](https://forums.escapistmagazine.com/threads/rts-games-that-dont-rely-purely-on-apm-and-micro.253298/)).
- Two design philosophies for "communicating my units are doing something" without forcing micromanagement:
  1. **Capable default AI** — units act sensibly on their own (e.g., auto-splitting from threats, auto-engaging in ENGAGE mode) so the player trusts an order and doesn't feel compelled to babysit it.
  2. **Strong order-state feedback** — a visible, at-a-glance indicator of *which order* each drone/group is currently executing (icon over unit, colour-coded trail, or a HUD summary count per order type), so the player can verify "my PATROL order is being followed" without clicking each drone.
- Practical implication for your HOLD/RALLY/PATROL/HARVEST/ENGAGE system: the single highest-value swarm-feel addition is a compact **order-state summary** (e.g. small icon badges: "6 ENGAGE / 2 PATROL / 1 HARVEST") near the existing status panels, since you already have discrete named order states — this is exactly the kind of information a fleet HUD needs to make "my swarm is doing something" legible without opening a unit list.

### Applies to your project
- **Already follows:** discrete order system (HOLD/RALLY/PATROL/HARVEST/ENGAGE) is itself the right shape for "trust the order, don't micromanage."
- **Gaps/opportunities:**
  - No stated per-drone or per-group order-state visual indicator — add a small icon/glyph over each drone (or a colour on its blip) showing its current order, and/or a HUD tally by order type. This is the top feel-improving change available given time constraints.
  - Confirm drones have visually distinct silhouettes/colours from enemy AI drones at a glance (not just faction colour on selection) — critical at 640x360 where detail is limited.

---

## 6. Accessibility Basics

- **Never encode information in colour alone** — pair every colour cue with a shape, icon, position, or label ([Medium, accessibility overview](https://medium.com/@farisdurrani/how-to-make-video-games-more-accessible-c33416dfb33d); [Xbox Accessibility Guideline 103](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/103)).
- **Blue and orange** are safe, high-contrast choices distinguishable across red-green, tritanopia, and achromatopsia colour-vision types — worth adopting for your friendly/hostile or shield/hull distinctions instead of pure red/green ([Chris Fairfield, Colorblind Friendly Game Design](https://chrisfairfield.com/unlocking-colorblind-friendly-game-design/); [Lyssna colour-blind palette guide](https://www.lyssna.com/blog/color-blind-friendly-palette/)).
- Very light vs very dark (near-white vs near-black) is universally distinguishable — usable as a reliable secondary/tertiary cue tier.
- Test with a colourblindness simulation filter (available in most engines, or a screenshot run through a simulator) on your actual radar contacts, health bars, and order-state colours before submission — a 10-minute check, not a redesign.

### Applies to your project
- **Gaps/opportunities:**
  - Your radar's friend/foe distinction, ENGAGE-vs-other order colours, and any red=hostile/green=friendly convention are exactly the places colour-alone failures happen. Add a shape or icon differentiator (triangle vs square blips, filled vs outlined) alongside colour — cheap and directly derived from the ED solid/hollow trick in Section 2.
  - If time allows, swap red/green hostile-friendly convention toward blue/orange since it's strictly safer across colour-vision types and still reads intuitively (orange as "danger/hostile" is a common enough convention).

---

## Top 10 Prioritised Changes

| # | Change | Rationale | Effort |
|---|---|---|---|
| 1 | Add shape/icon differentiator to radar blips and order-state colours (not colour alone) | Single biggest accessibility gap; directly fixes the most common HUD accessibility failure | 30-60 min |
| 2 | Add per-drone or per-group order-state icon/badge (what is each drone currently doing) | Highest-value fix for "swarm is doing something" legibility without micromanagement | 1-2 hrs |
| 3 | Add solid/hollow (ahead/behind) convention to target indicator on heading arc, if not already present | Cheap, well-precedented (Elite Dangerous), directly improves target awareness at low res | 30-60 min |
| 4 | Audit all HUD text against a hard minimum glyph height at native 640x360 | Prevents illegible text being the thing a marker notices first | 15-30 min |
| 5 | Add idle/event notification channel (drone destroyed, harvest complete, under attack) | Closes the single most-cited "don't" gap (no passive event feedback) at low cost | 1-2 hrs |
| 6 | Adopt blue/orange (or equivalent safe pair) for friendly/hostile or shield/hull distinctions where currently red/green | Strictly safer across colour-vision types, still intuitive | 30-45 min |
| 7 | Snap all HUD panel positions/sizes to an 8px grid relative to 640x360 canvas | Keeps pixel-art upscaling crisp; avoids blur under integer scaling | 30-60 min |
| 8 | Add a compact swarm composition/order-tally readout near existing status panels (e.g. "6 ENGAGE / 2 PATROL") | On-demand detail without a separate screen; matches RTS "centralise, don't scatter" principle | 1 hr |
| 9 | Confirm Tab-cycle-target genuinely orders by nearest-first, not list order | Matches the implicit convention players already expect from Tab | 15 min (verify + fix if needed) |
| 10 | Verify drone/enemy silhouette and colour distinctness at actual 640x360 in-engine screenshot | Readability at low res is a silhouette problem more than a detail problem; catch it before submission | 15-30 min |

---

## Sources

- [Mastering Game HUD Design — Polydin](https://polydin.com/game-hud-design/)
- [RTS Game Design — GameDesignSkills](https://gamedesignskills.com/game-design/real-time-strategy/)
- [UI Strategy Game Design Dos and Don'ts — GameDeveloper.com](https://www.gamedeveloper.com/design/ui-strategy-game-design-dos-and-don-ts)
- [Let's Talk RTS User Interface, Part 1 — Wayward Strategy / Dave Pottinger interview](https://waywardstrategy.com/2015/05/04/lets-talk-rts-user-interface-part-1-interview-with-dave-pottinger/)
- [Strategy Game Battle UI — Medium/treeform](https://medium.com/@treeform/strategy-game-battle-ui-3b313ffd3769)
- [HUD/Center — Elite Dangerous Wiki](https://elite-dangerous.fandom.com/wiki/HUD/Center)
- [HUD/Odyssey — Elite Dangerous Wiki](https://elite-dangerous.fandom.com/wiki/HUD/Odyssey)
- [Elite Dangerous HUD Guide for Beginners — My Gaming Tutorials](https://mygamingtutorials.com/2025/05/11/elite-dangerous-hud-guide-for-beginners-mastering-the-cockpit-interface/)
- [Heads-up display (ES2) — Everspace Wiki](https://everspace.fandom.com/wiki/Heads-up_display_(ES2))
- [BA Keybinds — Spring RTS Engine forums](https://springrts.com/phpbb/viewtopic.php?t=30173)
- [Targeting, precision and ambiguity when using the mouse — Spring RTS Engine forums](https://springrts.com/phpbb/viewtopic.php?t=33287)
- [Target Selection Guide: Mouse & Keyboard — SaltedXIV (FFXIV)](https://saltedxiv.com/guides/target-selection-guide-mouse-keyboard)
- [Pixel Art UI Resolutions — Grokipedia](https://grokipedia.com/page/Pixel_Art_UI_Resolutions)
- [Game UI Design: The Complete Guide — UI Challenges](https://www.uichallenges.design/guides/game-ui-design)
- [RTS games that don't rely purely on APM and micro — Escapist Forums](https://forums.escapistmagazine.com/threads/rts-games-that-dont-rely-purely-on-apm-and-micro.253298/)
- [Building RTS User Interface in Unity: Deterrence, Video Devlog 8 — GameDeveloper.com](https://www.gamedeveloper.com/game-platforms/building-rts-user-interface-in-unity-deterrence-video-devlog-8)
- [Making a RTS game #8: Boosting our selection feature — Medium/CodeX](https://medium.com/codex/making-a-rts-game-8-boosting-our-selection-feature-unity-c-8552bffd2f8b)
- [RTS Interlude #4: Improving the healthbars — Medium/CodeX](https://medium.com/codex/rts-interlude-4-improving-the-healthbars-unity-c-48ee8d663e09)
- [How to make video games more accessible — Medium/Faris Durrani](https://medium.com/@farisdurrani/how-to-make-video-games-more-accessible-c33416dfb33d)
- [Xbox Accessibility Guideline 103 — Microsoft Learn](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/103)
- [Unlocking Colorblind Friendly Game Design — Chris Fairfield](https://chrisfairfield.com/unlocking-colorblind-friendly-game-design/)
- [Color Blind-Friendly Palette — Lyssna](https://www.lyssna.com/blog/color-blind-friendly-palette/)
