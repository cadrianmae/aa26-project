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
			# QUADRATIC and gated at 0.6: below that much of a swarm this is
			# ZERO, not merely small, so a thin swarm cannot attack at all.
			need(&"war_readiness", QUADRATIC, 0.6, 1.0),
			# Prefers to pick the fight in good health, but will not refuse
			# one outright -- hence the floor.
			need(&"health", LINEAR, 0.25, 1.0, 0.5, 0.3),
			# Closer enemies are more attractive, again with a floor: distance
			# discourages, it does not forbid.
			need(
				&"enemy_distance", INVERSE,
				0.0, 1.0, 0.5, 0.35
			),
		],

		# HOLD -- retreat, and the last resort when everything else is vetoed.
		Swarm.Intent.HOLD: [
			# INVERSE_QUADRATIC: nearly nothing at full health, then rising
			# sharply once the commander is genuinely in trouble.
			need(&"health", INVERSE_QUADRATIC),
		],
	}
	return profile
