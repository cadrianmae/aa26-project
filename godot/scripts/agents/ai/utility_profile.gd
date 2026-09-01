## A commander's personality, as data.
##
## Maps each [enum Swarm.Intent] to the considerations that make it
## attractive. Swapping profiles swaps the AI: an aggressive commander and a
## turtling one differ only in these tables, with no code path between them.
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
## Hysteresis: a challenger must be meaningfully better, not marginally.
var momentum: float = 0.12


## Build one, as a static factory rather than a parameterised _init.
##
## Same GDScript limitation as [method Consideration.make].
static func named(name: String) -> UtilityProfile:
	var made: UtilityProfile = UtilityProfile.new()
	made.profile_name = name
	return made


## Score one intent: the product of its considerations.
##
## Compensated for consideration count (Mark's fix): multiplying sub-1.0
## values otherwise penalises an action for having more considerations.
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
		# Momentum only on a still-viable option: adding it unconditionally would
		# floor a vetoed current intent at momentum and it could never be dropped.
		if intent == current and value > 0.0:
			value += momentum
		if value > best_score:
			best_score = value
			best = intent

	return best


## Every intent's score, for debugging and for the write-up.
func explain(inputs: Dictionary, current: int) -> Dictionary:
	var scores: Dictionary = {}
	for intent in considerations:
		var value: float = score(intent, inputs)
		# Same rule as best_intent, and it must stay the same rule: this is
		# what the log prints, so any difference between them would make the
		# debug output describe a decision the commander did not make.
		if intent == current and value > 0.0:
			value += momentum
		scores[intent] = value
	return scores
