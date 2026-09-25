extends LiftingSystem
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

var drop_progress := 0.0
var is_holding_ship := false


func _init() -> void:

	falling_state = State.DROPPING
	raising_state = State.RAISING


func can_drop() -> bool:

	return state == State.RAISED


func can_raise() -> bool:

	return state == State.DROPPING or state == State.DOWN


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


func cancel_raising() -> bool:

	return _transition([State.RAISING], State.DROPPING)


func _fall(delta: float) -> void:

	drop_progress = minf(drop_progress + delta / DROP_DURATION, 1.0)

	if drop_progress >= 1.0:
		_set_state(State.DOWN)


func _raise(delta: float) -> void:

	drop_progress = maxf(drop_progress - delta / RAISE_DURATION, 0.0)

	if drop_progress <= 0.0:
		_set_state(State.RAISED)


## Bleeds a value toward zero while the anchor bites, at rate per drop duration.
static func damp(value: float, delta: float, rate: float) -> float:

	return move_toward(value, 0.0, rate / DROP_DURATION * delta)


func _set_state(new_state: int) -> void:

	if state == new_state:
		return

	state = new_state

	if state == State.DOWN:
		is_holding_ship = true
		ShipDebugLog.write(&"anchor", "Anchor has dropped all the way.")
	elif state == State.RAISED:
		is_holding_ship = false
