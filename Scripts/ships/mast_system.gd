extends RefCounted
class_name MastSystem

## Once every mast hole is open the mast topples like a pole hinged at the deck, bounces once,
## and lies there. A crewmate on the sail-length station catches it with "lower sails" and
## hauls it back upright, like the anchor: one press and they keep at it. Until a mast hole is
## patched it only stays up propped, and the next press or a ball through the rigging brings
## it down again.

enum State {
	STANDING,
	FALLING,
	DOWN,
	RAISING,
	PROPPED,
}

## Angle from upright, in radians, at which the mast lies on the deck.
const FALLEN := PI / 2.0
## A pole balanced dead upright never falls, so every fall starts from at least this lean.
const NUDGE := deg_to_rad(1.0)
## The pole's angular gravity, K in angle'' = K * sin(angle). Solved numerically so a fall from
## NUDGE to the deck takes 5.93 s; test_mast_fall pins it.
const TOPPLE_GRAVITY := 0.7829
## A full fall from NUDGE bounces for this long, impact to apex to touchdown, peaking ~5% up.
const BOUNCE_DURATION := 0.91
const BOUNCE_SPEED := TOPPLE_GRAVITY * BOUNCE_DURATION / 2.0
## Energy says a fall from rest at a0 lands at sqrt(2K cos a0), so a full fall lands at
## sqrt(2K cos NUDGE); the bounce keeps this fraction of whatever speed it lands with.
## From 45 degrees that is 84% of the full bounce speed: ~0.77 s long, apex ~3.7% up.
const RESTITUTION := BOUNCE_SPEED / sqrt(2.0 * TOPPLE_GRAVITY * cos(NUDGE))
## Hauling it upright is linear: this much of the way per second.
const RAISE_RATE := 0.1
const SAIL_FOLD_DURATION := 2.0
const MAX_SAIL_LENGTH := 100.0
## For this long after it is hauled upright, R patches the mast instead of the hull.
const REPAIR_PROMPT_WINDOW := 5.0

var mast_holes: Array[MastHole] = []
var state := State.STANDING
var angle := 0.0
var angular_velocity := 0.0
var has_bounced := false
var time_since_raised := INF
## False on a prediction's copy, so a forecast fall is not announced.
var logs := true


func _init(new_mast_holes: Array[MastHole]) -> void:

	mast_holes = new_mast_holes

	for hole in mast_holes:
		hole.grade_changed.connect(_on_grade_changed)

	if is_compromised():
		_start_fall()


## Every mast hole open as far as it goes. A hole being repaired still counts until it is done.
func is_compromised() -> bool:

	return not mast_holes.is_empty() and mast_holes.all(
		func(hole): return hole.grade >= hole.max_grade
	)


## A copy to run forward in a prediction. It reads the same holes but does not listen to them.
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


## 1 upright, 0 on the deck.
func upright_progress() -> float:

	return 1.0 - angle / FALLEN


## Anything but a sound, standing mast: the sails furl and "lower sails" works the mast instead.
func sails_locked() -> bool:

	return state != State.STANDING


## Raising runs here rather than in the crewmate's action, so a prediction's copy raises too.
func physics_process(delta: float) -> void:

	time_since_raised += delta

	if state == State.RAISING:
		_raise(delta)
	elif state == State.FALLING:
		_fall(delta)


func just_raised() -> bool:

	return time_since_raised < REPAIR_PROMPT_WINDOW


func can_raise() -> bool:

	return state == State.FALLING or state == State.DOWN


## Seconds of hauling left to get it upright.
func raise_time_left() -> float:

	return (1.0 - upright_progress()) / RAISE_RATE


## A catch throws away whatever the fall or the bounce was doing.
func begin_raising() -> void:

	if can_raise():
		state = State.RAISING
		angular_velocity = 0.0


## The hauler let go: it falls again, from rest.
func cancel_raising() -> void:

	if state == State.RAISING:
		_start_fall()


## A ball through the rigging of a propped mast. The holes are already as open as they go.
func knock_loose() -> bool:

	if state != State.PROPPED:
		return false

	_start_fall()

	return true


## Furls the sails toward nothing: over SAIL_FOLD_DURATION on its own, faster if the mast is
## being raised and would otherwise get there first.
func fold_sails(sail_length: float, delta: float) -> float:

	var rate := MAX_SAIL_LENGTH / SAIL_FOLD_DURATION

	if state == State.RAISING:
		var time_left := raise_time_left()

		# the next frame finishes the raise, so be furled by then
		if time_left <= delta:
			return 0.0

		rate = maxf(rate, sail_length / time_left)

	return move_toward(sail_length, 0.0, rate * delta)


static func bounce_speed(impact_speed: float) -> float:

	return RESTITUTION * impact_speed


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
	angular_velocity = -bounce_speed(angular_velocity)


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

		return

	if state == State.STANDING:
		_start_fall()
