@abstract
extends RefCounted
class_name LiftingSystem

## Gear hauled up by hand that comes down on its own: the anchor and the mast.

## One of the subclass's State values; each enum starts at its resting state, 0.
var state := 0
var falling_state: int
var raising_state: int


@abstract func can_raise() -> bool

@abstract func begin_raising() -> bool

@abstract func cancel_raising() -> bool

@abstract func _fall(delta: float) -> void

@abstract func _raise(delta: float) -> void


## Runs here rather than in the crewmate's action, so a prediction's copy moves too.
func physics_process(delta: float) -> void:

	if state == raising_state:
		_raise(delta)
	elif state == falling_state:
		_fall(delta)


func _transition(allowed: Array, next: int) -> bool:

	if not state in allowed:
		return false

	_set_state(next)

	return true


func _set_state(new_state: int) -> void:

	state = new_state
