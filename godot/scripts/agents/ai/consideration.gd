## One input, mapped through a curve, giving a score from 0.0 to 1.0.
##
## The atom of a utility system. An action's score is the product of its
## considerations, so each one answers a single question -- "how attractive is
## this given my swarm size?" -- and knows nothing about the action it serves
## or the others alongside it.
##
## Multiplied rather than averaged, following Dave Mark's Infinite Axis
## Utility System. Multiplication means any single consideration can VETO an
## action by scoring zero, which is what lets "there is no enemy" rule out
## attacking without a special case. An average would let a strong swarm
## outvote the absence of anything to fight.
##
## Reference: Mark, D., "Building a Better Centaur: AI at Massive Scale" and
## the Infinite Axis Utility System, presented at GDC. See ATTRIBUTIONS.md.
class_name Consideration
extends RefCounted

## How an input is mapped to a score.
##
## Named Response, not Curve: Curve is a built-in Godot class, and an enum of
## that name shadows it. The symptom is misleading -- every other script that
## referenced this file failed with "Could not resolve external class member",
## pointing at the reference rather than at the shadowing declaration.
##
## Response is also the term the utility-AI literature uses for exactly this:
## the response curve mapping an input to a score.
enum Response {
	## Straight through: 0 stays 0, 1 stays 1.
	LINEAR,
	## Flipped: scarcity becomes attractive. "The less health I have, the
	## more I want to retreat."
	INVERSE,
	## Rises slowly then sharply. Something that only matters once it is
	## nearly satisfied -- a swarm at 40% strength is not nearly half as
	## ready to fight as one at 80%.
	QUADRATIC,
	## Falls sharply then slowly. Urgent early, indifferent later.
	INVERSE_QUADRATIC,
	## 0 below the threshold, 1 above it. A hard gate, for facts rather than
	## degrees: is there an enemy at all.
	THRESHOLD,
}

## Which value from the AI's input set this reads.
var input: StringName

## How that value maps to a score. One of [enum Curve].
##
## Typed int rather than Curve because GDScript cannot resolve an external
## class's enum in a parameter annotation -- another script writing
## `Consideration.Curve` as a type fails to parse with "Could not resolve
## external class member". The values are the enum's, the annotation is just
## its underlying type.
var curve: int

## Where the input is treated as 0.0. Values below clamp to it.
var from: float

## Where the input is treated as 1.0. Values above clamp to it.
var to: float

## Only used by THRESHOLD: the point at which the score flips to 1.
var threshold: float

## Never lets the score reach zero, so this consideration cannot veto on its
## own. Use when a factor should discourage an action without forbidding it.
var floor_value: float


## Build one, as a static factory rather than a parameterised _init.
##
## GDScript cannot resolve another class's custom constructor from a static
## function -- CommanderProfiles calling Consideration.new(args) fails to
## parse with "Could not resolve external class member _init". A static
## factory is reached the same way any other static method is, and works.
static func make(
	input_name: StringName,
	curve_type: int = 0,
	range_from: float = 0.0,
	range_to: float = 1.0,
	gate: float = 0.5,
	minimum: float = 0.0
) -> Consideration:
	var made: Consideration = Consideration.new()
	made.input = input_name
	made.curve = curve_type
	made.from = range_from
	made.to = range_to
	made.threshold = gate
	made.floor_value = minimum
	return made


## Score this consideration against a set of named inputs.
##
## A missing input scores 0.0 rather than erroring: a profile that names an
## input the AI does not supply should make its action unattractive, not crash
## the game mid-match.
func score(inputs: Dictionary) -> float:
	if not inputs.has(input):
		return 0.0

	var raw: float = float(inputs[input])
	if curve == Response.THRESHOLD:
		return maxf(1.0 if raw >= threshold else 0.0, floor_value)

	# Normalise into 0..1 across the consideration's own range, so a curve is
	# written once and reused against inputs of any scale.
	var span: float = to - from
	var t: float = 0.0 if is_zero_approx(span) else clampf((raw - from) / span, 0.0, 1.0)

	var value: float = t
	match curve:
		Response.INVERSE:
			value = 1.0 - t
		Response.QUADRATIC:
			value = t * t
		Response.INVERSE_QUADRATIC:
			value = (1.0 - t) * (1.0 - t)
		_:
			value = t

	return maxf(value, floor_value)
