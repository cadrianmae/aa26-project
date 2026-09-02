## Every string the player reads, in one place.
##
## Gathered here so the game's language can be reviewed, edited or translated
## without reading the code that draws it. Debug overlay labels are NOT here:
## they are developer-facing, never translated, and belong beside the values
## they annotate.
##
## To translate: replace these values, or swap the constants for [code]tr()[/code]
## calls against a Godot translation CSV.
class_name Strings
extends RefCounted

## End-of-match announcement.
const VICTORY: String = "VICTORY"
const DEFEAT: String = "DEFEAT"
const VICTORY_SUBTITLE: String = "the belt is yours"
const DEFEAT_SUBTITLE: String = "the Matriarch is lost"

## Headings on the HUD panels.
const OWN_SHIP: String = "MATRIARCH"
const ALLOY: String = "ALLOY"
const SWARM: String = "SWARM"

## Shown by the swarm panel when the hive has no drones left.
const SWARM_EMPTY: String = "no drones"

## What the target panel calls each kind of contact.
const TARGET_SHIP: String = "HOSTILE MATRIARCH"
const TARGET_SWARM: String = "HOSTILE SWARM"
const TARGET_BARNACLE: String = "BARNACLE"

## Compass points around the radar, from north, clockwise.
const NORTH: String = "N"
const NORTH_EAST: String = "NE"
const EAST: String = "E"
const SOUTH_EAST: String = "SE"
const SOUTH: String = "S"
const SOUTH_WEST: String = "SW"
const WEST: String = "W"
const NORTH_WEST: String = "NW"
