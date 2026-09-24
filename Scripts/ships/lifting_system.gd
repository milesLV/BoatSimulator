@abstract
extends RefCounted
class_name LiftingSystem

## Gear a crewmate hauls up by hand, one press and they keep at it until it is up, and that
## comes down on its own: the anchor and the mast. Each has its own states and its own way of
## moving; this runs whichever motion the current state calls for.

## One of the subclass's State values. Both enums start at their resting state, 0.
var state := 0
## The subclass's states for coming down on its own and being hauled up.
var falling_state: int
var raising_state: int


## Whether a haul can start now.
@abstract func can_raise() -> bool

## A crewmate takes hold and starts hauling.
@abstract func begin_raising() -> bool

## The hauler let go before it was up.
@abstract func cancel_raising() -> bool

## One tick of coming down on its own.
@abstract func _fall(delta: float) -> void

## One tick of being hauled up; the crewmate's action only holds them to it.
@abstract func _raise(delta: float) -> void


## The motion runs here rather than in the crewmate's action, so a prediction's copy moves too.
func physics_process(delta: float) -> void:

	if state == raising_state:
		_raise(delta)
	elif state == falling_state:
		_fall(delta)


## Moves to [param next] when in one of [param allowed].
func _transition(allowed: Array, next: int) -> bool:

	if not state in allowed:
		return false

	_set_state(next)

	return true


## Override for side effects of entering a state.
func _set_state(new_state: int) -> void:

	state = new_state
