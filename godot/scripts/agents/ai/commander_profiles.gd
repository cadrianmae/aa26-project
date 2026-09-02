## The commanders' personalities, as data.
##
## Each profile maps an intent to the considerations that make it attractive.
##
## The inputs a consideration can name, all normalised to 0..1 by
## [method CommanderAI.gather_inputs]:
##
##   health            1.0 at full, 0.0 destroyed
##   swarm_fraction    drones alive, against max_drones
##   war_readiness     drones alive, against minimum_war_swarm (1.0 = ready)
##   alloy_fraction    alloys banked, against the cost of one drone
##   has_barnacle      1.0 when a rock with alloys is in range, else 0.0
##   barnacle_distance 0.0 on top of it, 1.0 at the edge of harvest_range
##   has_enemy         1.0 when an enemy commander is known, else 0.0
##   enemy_distance    0.0 alongside it, 1.0 at the edge of harvest_range
##   firepower_ratio   0.5 evenly matched, above 0.5 this commander is ahead,
##                     counting only what is inside scouting_range. Raised
##                     while the hive is provoked, so retaliation clears the
##                     gates that keep it patient when unharmed.
##
## Curves: LINEAR, INVERSE, QUADRATIC, INVERSE_QUADRATIC, THRESHOLD.
class_name CommanderProfiles
extends RefCounted

## The curve names, mirrored from [enum Consideration.Response].
##
## Local constants: GDScript cannot resolve another class's enum from here.
const LINEAR: int = 0
const INVERSE: int = 1
const QUADRATIC: int = 2
const INVERSE_QUADRATIC: int = 3
const THRESHOLD: int = 4


## Shorthand, so a table reads as data rather than as constructor calls.
##
## `curve` defaults to the literal 0 (= LINEAR): default arguments cannot
## reach another class's enum at parse time.
static func need(
	input: StringName,
	curve: int = 0,
	from: float = 0.0,
	to: float = 1.0,
	gate: float = 0.5,
	minimum: float = 0.0
) -> Consideration:
	return Consideration.make(input, curve, from, to, gate, minimum)


## The default opponent: harvest, then seek, then destroy.
static func escalating() -> UtilityProfile:
	var profile: UtilityProfile = UtilityProfile.named("escalating")
	profile.considerations = {

		# HARVEST -- the opening move, and the fallback whenever the swarm is
		# too thin to do anything else.
		Swarm.Intent.HARVEST: [
			# No rock, no harvesting. A veto rather than a preference.
			need(&"has_barnacle", THRESHOLD),
			# Falls away as the swarm fills out. Floored at 0.35 so a ready
			# commander still replaces what a fight costs it.
			need(&"war_readiness", INVERSE, 0.0, 1.0, 0.5, 0.35),
			# Nearer rocks preferred, but a floor so a distant rock is still
			# better than idling. Without the floor, distance alone could veto
			# the whole economy.
			need(
				&"barnacle_distance", INVERSE_QUADRATIC,
				0.0, 1.0, 0.5, 0.25
			),
		],

		# PATROL -- the middle of the arc: strong enough to be out, nothing
		# worth committing to yet.
		Swarm.Intent.PATROL: [
			# Needs real numbers behind it. Below 0.45 readiness this is zero
			# and HARVEST wins uncontested.
			need(&"war_readiness", LINEAR, 0.45, 1.0),
			# More attractive when there is no rock to work. With a floor, so
			# a commander with a rock still patrols occasionally rather than
			# mining until attacked.
			need(
				&"has_barnacle", INVERSE,
				0.0, 1.0, 0.5, 0.3
			),
			# Not while badly hurt.
			need(&"health", LINEAR, 0.3, 1.0),
		],

		# ENGAGE -- the end of the arc. Deliberately demanding: an AI that
		# attacks the moment it can is an AI that dies early.
		Swarm.Intent.ENGAGE: [
			need(&"has_enemy", THRESHOLD),
			# QUADRATIC and gated at 0.45: below that much of a swarm this is
			# ZERO, not merely small, so a thin swarm cannot attack at all.
			# Matched to PATROL's own start, so there is no band of readiness
			# where the hive is too strong to harvest and too weak to fight.
			need(&"war_readiness", QUADRATIC, 0.45, 1.0),
			# Prefers to pick the fight in good health, but will not refuse
			# one outright -- hence the floor.
			need(&"health", LINEAR, 0.25, 1.0, 0.5, 0.3),
			# Closer enemies are more attractive, again with a floor: distance
			# discourages, it does not forbid.
			need(
				&"enemy_distance", INVERSE,
				0.0, 1.0, 0.5, 0.35
			),
			# Starts BELOW an even match, deliberately. Both hives field the
			# same ship and the same drones, so a mirror start sits at exactly
			# 0.5; a gate opening at 0.5 would forbid the rival from ever
			# attacking until the player broke the symmetry first.
			#
			# Still zero once genuinely behind, and no floor, so being outgunned
			# vetoes the attack -- unless provoked, which raises the input
			# before it arrives here. See CommanderAI.is_provoked.
			need(&"firepower_ratio", LINEAR, 0.42, 0.8),
		],

		# RALLY -- withdraw to the rally point. Where an outgunned hive goes
		# instead of attacking.
		Swarm.Intent.RALLY: [
			# Only against a force it can actually see.
			need(&"has_enemy", THRESHOLD),
			# The mirror of ENGAGE's test: rises as the odds worsen, zero once
			# the hive is even with its enemy.
			need(&"firepower_ratio", INVERSE, 0.2, 0.5),
			# A hurt commander runs. Floored, so this raises the urgency of a
			# withdrawal without being required for one.
			need(&"health", INVERSE_QUADRATIC, 0.0, 1.0, 0.5, 0.4),
		],

		# HOLD -- the last resort when everything else is vetoed. HOLD keeps the
		# commander where it stands, so it must lose to RALLY, which retreats.
		Swarm.Intent.HOLD: [
			# Collapses once an enemy is in sight: standing still is only ever
			# right when there is nothing to react to. Keyed on health alone
			# this rose as the hive got hurt, so a dying commander held its
			# ground instead of running.
			need(&"has_enemy", INVERSE, 0.0, 1.0, 0.5, 0.2),
			need(&"health", INVERSE, 0.0, 1.0, 0.5, 0.15),
		],
	}
	return profile
