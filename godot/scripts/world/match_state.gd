## Decides when the match is over and who won.
class_name MatchState
extends Node

## Emitted once, when the match resolves.
signal finished(winner_allegiance: int)

## Which side the player commands.
@export var player_allegiance: int = 0

## Drive the music to VICTORY or DEFEAT when the match ends.
@export var set_music_phase: bool = true

## Whether the match has already resolved. Guards against the signal firing
## twice if both commanders die in the same frame.
var finished_already: bool = false

## The winning side once resolved, or -1.
var winner: int = -1

var _watched: Array[Ship] = []


func _ready() -> void:
	# Deferred: the ships join their groups in their own _ready, and Godot
	# readies siblings in scene order, so this may run first.
	call_deferred("_watch_commanders")


func _watch_commanders() -> void:
	for side in [0, 1]:
		for node in get_tree().get_nodes_in_group("commander_" + str(side)):
			var ship: Ship = node as Ship
			if ship == null or _watched.has(ship):
				continue
			_watched.append(ship)
			ship.destroyed.connect(_on_commander_destroyed)


func _on_commander_destroyed(ship: Ship) -> void:
	if finished_already:
		return
	finished_already = true
	winner = 1 - ship.allegiance
	finished.emit(winner)

	if not set_music_phase:
		return
	var director: MusicDirector = get_tree().get_root().find_child(
		"MusicDirector", true, false
	) as MusicDirector
	if director == null:
		return
	director.play_phase(
		MusicDirector.Phase.VICTORY if winner == player_allegiance
		else MusicDirector.Phase.DEFEAT
	)


## Whether the player won. Only meaningful once [member finished_already].
func player_won() -> bool:
	return winner == player_allegiance
