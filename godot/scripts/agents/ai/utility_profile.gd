## A commander's personality, as data.
##
## Maps each [enum Swarm.Intent] to the considerations that make it
## attractive. Swapping profiles swaps the AI: an aggressive commander and a
## turtling one differ only in these tables, with no code path between them.
##
## This is what makes the system worth its extra lines over an if-else ladder.
## A ladder encodes priority in the ORDER of its branches, so changing the
## AI's character means restructuring it. A utility profile encodes priority
## in WEIGHTS, so a different opponent is a different table.
##
## Reference: Mark, D., Infinite Axis Utility System. See ATTRIBUTIONS.md.
class_name UtilityProfile
extends RefCounted

## Name, for logs and for the write-up.
var profile_name: String = "unnamed"

## Intent to its considerations. An intent absent from here is never chosen.
var considerations: Dictionary = {}

## Extra score given to whatever the commander is already doing.
##
## Momentum, and it is the reason a utility system does not need a hysteresis
## hack. Two intents scoring 0.51 and 0.49 would otherwise swap every time the
## inputs wobbled, and the swarm would spend its life changing its mind. A
## small bonus means a challenger has to be meaningfully better, not
## marginally better, to take over.
var momentum: float = 0.12


## Build one, as a static factory rather than a parameterised _init.
##
## Same reason as [method Consideration.make]: GDScript cannot resolve another
## class's custom constructor from a static function, so CommanderProfiles
## calling UtilityProfile.new("name") fails to parse.
static func named(name: String) -> UtilityProfile:
	var made: UtilityProfile = UtilityProfile.new()
	made.profile_name = name
	return made


## Score one intent: the product of its considerations.
##
## A product, not an average. Any consideration scoring zero vetoes the whole
## action, which is how "there is no enemy" rules out attacking without a
## special case anywhere.
##
## Compensated for the number of considerations. Multiplying values under 1.0
## drives a score down the more considerations it has, so an action with four
## would always lose to one with two however well it scored. The exponent
## corrects for that -- Mark's fix, and without it a profile silently punishes
## its own detail.
func score(intent: int, inputs: Dictionary) -> float:
	if not considerations.has(intent):
		return 0.0
	var list: Array = considerations[intent]
	if list.is_empty():
		return 0.0

	var total: float = 1.0
	for consideration in list:
		var value: float = consideration.score(inputs)
		if value <= 0.0:
			return 0.0
		total *= value

	var compensation: float = 1.0 - 1.0 / float(list.size())
	var adjustment: float = (1.0 - total) * compensation
	return total + adjustment * total


## The best intent for these inputs, with the current one given momentum.
##
## Returns the fallback when nothing scores above zero, which happens when
## every action has been vetoed -- no enemy, no reachable rock, nothing to do.
func best_intent(
	inputs: Dictionary, current: int, fallback: int = Swarm.Intent.HOLD
) -> int:
	var best: int = fallback
	var best_score: float = 0.0

	for intent in considerations:
		var value: float = score(intent, inputs)
		if intent == current:
			value += momentum
		if value > best_score:
			best_score = value
			best = intent

	return best


## Every intent's score, for debugging and for the write-up.
##
## A utility system's decisions are opaque from outside -- it picks a winner
## and says nothing about why. This is how a demo shows the reasoning.
func explain(inputs: Dictionary, current: int) -> Dictionary:
	var scores: Dictionary = {}
	for intent in considerations:
		var value: float = score(intent, inputs)
		if intent == current:
			value += momentum
		scores[intent] = value
	return scores
