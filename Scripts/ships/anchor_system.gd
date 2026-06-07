extends RefCounted
class_name AnchorSystem

signal state_changed(state)

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

var ship
var state: State = State.RAISED
var drop_elapsed := 0.0
var drop_progress := 0.0
var is_holding_ship := false


func _init(new_ship) -> void:

	ship = new_ship

func can_drop() -> bool:

	return state == State.RAISED


func can_raise() -> bool:

	return (
		state == State.DROPPING
		or state == State.DOWN
	)


func is_passive_decay_active() -> bool:

	return state == State.DROPPING


func begin_rigging() -> bool:

	if not can_drop():
		return false

	_set_state(State.RIGGING)

	return true


func cancel_rigging() -> bool:

	if state != State.RIGGING:
		return false

	_set_state(State.RAISED)

	return true


func start_dropping() -> bool:

	if (
		state != State.RIGGING
		and state != State.RAISED
	):
		return false

	drop_elapsed = 0.0
	drop_progress = 0.0

	_set_state(State.DROPPING)

	return true


func begin_raising() -> bool:

	if not can_raise():
		return false

	if state == State.DOWN:
		drop_progress = 1.0

	_sync_drop_elapsed_to_progress()

	_set_state(State.RAISING)

	return true


func raise_by_delta(delta: float) -> void:

	if state != State.RAISING:
		return

	drop_progress = clamp(
		drop_progress - (delta / RAISE_DURATION),
		0.0,
		1.0
	)

	_sync_drop_elapsed_to_progress()


func cancel_raising() -> bool:

	if state != State.RAISING:
		return false

	_sync_drop_elapsed_to_progress()

	_set_state(State.DROPPING)

	return true


func finish_raising() -> bool:

	if state != State.RAISING:
		return false

	drop_elapsed = 0.0
	drop_progress = 0.0

	_set_state(State.RAISED)

	return true


func get_raise_remaining_duration() -> float:

	return drop_progress * RAISE_DURATION


func physics_process(delta: float) -> void:

	if state != State.DROPPING:
		return

	drop_elapsed += delta
	drop_progress = clamp(
		drop_elapsed / DROP_DURATION,
		0.0,
		1.0
	)

	if drop_progress >= 1.0:
		_set_state(State.DOWN)


func affects_ship_movement() -> bool:

	return is_holding_ship


func locks_steering() -> bool:

	return is_holding_ship


func apply_velocity(
	current_velocity: float,
	delta: float
) -> float:

	if not affects_ship_movement():
		return current_velocity

	return move_toward(
		current_velocity,
		0.0,
		_get_drop_deceleration() * delta
	)


func apply_angular_velocity(
	current_angular_velocity: float,
	delta: float
) -> float:

	if not locks_steering():
		return current_angular_velocity

	return move_toward(
		current_angular_velocity,
		0.0,
		_get_drop_angular_deceleration() * delta
	)


func _get_drop_deceleration() -> float:

	return ANCHOR_DECELERATION / DROP_DURATION


func _get_drop_angular_deceleration() -> float:

	return ANCHOR_ANGULAR_ACELERATION / DROP_DURATION


func _sync_drop_elapsed_to_progress() -> void:

	drop_elapsed = drop_progress * DROP_DURATION


func _set_state(new_state: State) -> void:

	if state == new_state:
		return

	state = new_state

	if state == State.DOWN:
		is_holding_ship = true
	elif state == State.RAISED:
		is_holding_ship = false

	state_changed.emit(state)

	if state == State.DOWN:
		ShipDebugLog.anchor("Anchor has dropped all the way.")
