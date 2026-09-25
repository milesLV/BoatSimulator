extends LiftingSystem
class_name MastSystem

## Topples once every mast hole is open; hauled back up, it is only PROPPED until one is patched.

enum State {
	STANDING,
	FALLING,
	DOWN,
	RAISING,
	PROPPED,
}

const FALLEN := PI / 2.0
## A pole balanced dead upright never falls, so every fall starts from at least this lean.
const NUDGE := deg_to_rad(1.0)
## K in angle'' = K * sin(angle), solved so a fall from NUDGE takes 5.93 s (test_mast_fall).
const TOPPLE_GRAVITY := 0.7829
const BOUNCE_DURATION := 0.91
const BOUNCE_SPEED := TOPPLE_GRAVITY * BOUNCE_DURATION / 2.0
## Share of landing speed kept on the bounce; a fall from NUDGE lands at sqrt(2K cos NUDGE).
const RESTITUTION := BOUNCE_SPEED / sqrt(2.0 * TOPPLE_GRAVITY * cos(NUDGE))
## Fraction of the way upright per second.
const RAISE_RATE := 0.1
const SAIL_FOLD_DURATION := 2.0
const MAX_SAIL_LENGTH := 100.0
## For this long after it is hauled upright, R patches the mast instead of the hull.
const REPAIR_PROMPT_WINDOW := 5.0

var mast_holes: Array[MastHole] = []
var angle := 0.0
var angular_velocity := 0.0
var has_bounced := false
var time_since_raised := INF
## False on a prediction's copy, so a forecast fall is not announced.
var logs := true


func _init(new_mast_holes: Array[MastHole]) -> void:

	mast_holes = new_mast_holes
	falling_state = State.FALLING
	raising_state = State.RAISING

	for hole in mast_holes:
		hole.grade_changed.connect(_on_grade_changed)

	if is_compromised():
		_start_fall()


func is_compromised() -> bool:

	return not mast_holes.is_empty() and mast_holes.all(
		func(hole): return hole.grade >= hole.max_grade
	)


## Prediction copy: shares the holes without connecting to their signals.
func snapshot() -> MastSystem:

	var copy := MastSystem.new([])
	copy.mast_holes = mast_holes
	copy.state = state
	copy.angle = angle
	copy.angular_velocity = angular_velocity
	copy.has_bounced = has_bounced
	copy.time_since_raised = time_since_raised
	copy.logs = false

	return copy


func upright_progress() -> float:

	return 1.0 - angle / FALLEN


func sails_locked() -> bool:

	return state != State.STANDING


func physics_process(delta: float) -> void:

	time_since_raised += delta
	super(delta)


func just_raised() -> bool:

	return time_since_raised < REPAIR_PROMPT_WINDOW


func can_raise() -> bool:

	return state == State.FALLING or state == State.DOWN


func raise_time_left() -> float:

	return (1.0 - upright_progress()) / RAISE_RATE


func begin_raising() -> bool:

	if not _transition([State.FALLING, State.DOWN], State.RAISING):
		return false

	angular_velocity = 0.0

	return true


func cancel_raising() -> bool:

	return _fall_from(State.RAISING)


func knock_loose() -> bool:

	return _fall_from(State.PROPPED)


func _fall_from(required: State) -> bool:

	if state != required:
		return false

	_start_fall()

	return true


func fold_sails(sail_length: float, delta: float) -> float:

	var rate := MAX_SAIL_LENGTH / SAIL_FOLD_DURATION

	if state == State.RAISING:
		var time_left := raise_time_left()

		if time_left <= delta:
			return 0.0

		rate = maxf(rate, sail_length / time_left)

	return move_toward(sail_length, 0.0, rate * delta)


func _start_fall() -> void:

	state = State.FALLING
	angle = maxf(angle, NUDGE)
	angular_velocity = 0.0
	has_bounced = false


func _fall(delta: float) -> void:

	angular_velocity += TOPPLE_GRAVITY * sin(angle) * delta
	angle += angular_velocity * delta

	if angle < FALLEN:
		return

	angle = FALLEN

	if has_bounced:
		angular_velocity = 0.0
		state = State.DOWN
		if logs:
			ShipDebugLog.write(&"mast", "The mast is falling down.")
		return

	has_bounced = true
	angular_velocity = -RESTITUTION * angular_velocity


func _raise(delta: float) -> void:

	angle -= RAISE_RATE * FALLEN * delta

	if angle > 0.0:
		return

	angle = 0.0
	time_since_raised = 0.0
	state = State.PROPPED if is_compromised() else State.STANDING


func _on_grade_changed(_hole: ShipHolePoint, _old_grade: int, _new_grade: int) -> void:

	if not is_compromised():
		if state == State.PROPPED:
			state = State.STANDING
	elif state == State.STANDING:
		_start_fall()
