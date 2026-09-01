## The colours the game is drawn in.
##
## Take an alpha variant with the two-argument constructor rather than retyping
## the channels: [code]Color(Palette.PLAYER, 0.75)[/code].
class_name Palette
extends RefCounted

## The player's hive: hulls, radar contacts, HUD panels and gauges.
const PLAYER: Color = Color(0.435, 0.812, 0.353)

## The rival hive, everywhere the player's green would otherwise appear.
const RIVAL: Color = Color(0.851, 0.643, 0.255)

## Barnacles and the Meta-Alloy they hold.
const BARNACLE: Color = Color(0.62, 0.82, 0.23)

## Asteroids, and anything belonging to neither side.
const ROCK: Color = Color(0.42, 0.39, 0.34)

## Engine exhaust, at the hot end of the thruster ramp.
const THRUST: Color = Color(0.65, 0.12, 0.03)

## Backing behind the HUD's translucent panels.
const PANEL_BACKING: Color = Color(0.02, 0.04, 0.03)
