extends RefCounted
class_name AnchorSystem

enum State {
	RAISED,
	RIGGING,
	DROPPING,
	RAISING,
	DOWN
}

const DROP_DURATION := 3.6
const RAISE_DURATION := 8.0
const ANCHOR_DECELERATION := 300.0
const ANCHOR_ANGULAR_ACELERATION := 1.5

var state: State = State.RAISED
var drop_progress := 0.0
var is_holding_ship := false


func can_drop() -> bool:

	return state == State.RAISED


func can_raise() -> bool:

	return state == State.DROPPING or state == State.DOWN


## Moves the anchor to [param next] when it sits in one of [param allowed].
func _transition(allowed: Array, next: State) -> bool:

	if not state in allowed:
		return false

	_set_state(next)

	return true


func begin_rigging() -> bool:

	return _transition([State.RAISED], State.RIGGING)


func cancel_rigging() -> bool:

	return _transition([State.RIGGING], State.RAISED)


func start_dropping() -> void:

	if _transition([State.RIGGING, State.RAISED], State.DROPPING):
		drop_progress = 0.0


func begin_raising() -> bool:

	if state == State.DOWN:
		drop_progress = 1.0

	return _transition([State.DROPPING, State.DOWN], State.RAISING)


func raise_by_delta(delta: float) -> void:

	if state != State.RAISING:
		return

	drop_progress = clamp(drop_progress - (delta / RAISE_DURATION), 0.0, 1.0)


func cancel_raising() -> bool:

	return _transition([State.RAISING], State.DROPPING)


func finish_raising() -> void:

	if _transition([State.RAISING], State.RAISED):
		drop_progress = 0.0


func physics_process(delta: float) -> void:

	if state != State.DROPPING:
		return

	drop_progress = clamp(drop_progress + delta / DROP_DURATION, 0.0, 1.0)

	if drop_progress >= 1.0:
		_set_state(State.DOWN)


## Bleeds a value toward zero while the anchor bites, at rate per drop duration.
func damp(value: float, delta: float, rate: float) -> float:
	if not is_holding_ship:
		return value

	return move_toward(value, 0.0, (rate / DROP_DURATION) * delta)


func _set_state(new_state: State) -> void:

	if state == new_state:
		return

	state = new_state

	if state == State.DOWN:
		is_holding_ship = true
		ShipDebugLog.write(&"anchor", "Anchor has dropped all the way.")
	elif state == State.RAISED:
		is_holding_ship = false
