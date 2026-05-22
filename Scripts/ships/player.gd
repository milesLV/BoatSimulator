class_name PlayerShip
extends Sloop

func _physics_process(delta):
	turn_input = 0.0
	sail_input = 0.0
	sail_rotation_input = 0.0

	# Changing crewmates
	if Input.is_action_just_pressed("changeCrewmate"):
		_change_crewmate()

	var wheel_request = _get_wheel_request()
	var sail_request = _get_sail_length_request()
	var rotation_request = _get_sail_rotation_request()

	if not _apply_active_station_input(
		wheel_request,
		sail_request,
		rotation_request
	):
		_apply_station_input(
			&"Wheel",
			wheel_request
		)
		_apply_station_input(
			&"SailLengthStarb", # TODO: make so can choose port or starboard size depending on whatever's closest
			sail_request
		)
		_apply_station_input(
			&"SailRotationStarb", # TODO: make so can choose port or starboard size depending on whatever's closest
			rotation_request
		)

	if Input.is_action_just_pressed("dropOrRaiseAnchor"):
		request_anchor_toggle()

	_process_movement(delta)
	update_active_cannon()


func _get_wheel_request() -> float:

	var request := 0.0

	if Input.is_action_pressed("turnWheelLeft"):
		request -= 1.0

	if Input.is_action_pressed("turnWheelRight"):
		request += 1.0

	return request


func _get_sail_length_request() -> float:

	var request := 0.0

	if Input.is_action_pressed("lowerSailsDown"):
		request += 1.0

	if Input.is_action_pressed("raiseSailsUp"):
		request -= 1.0

	return request


func _get_sail_rotation_request() -> float:

	var request := 0.0

	if Input.is_action_pressed("adjustSailLeft"):
		request -= 1.0

	if Input.is_action_pressed("adjustSailRight"):
		request += 1.0

	return request


func _apply_active_station_input(
	wheel_request: float,
	sail_request: float,
	rotation_request: float
) -> bool:

	var station = station_controller.get_station_operated_by(
		current_crewmate
	)

	if station == null:
		return false

	match StringName(station.name):
		&"Wheel":
			if wheel_request != 0.0:
				return _apply_station_input(
					&"Wheel",
					wheel_request
				)

		&"SailLengthStarb":
			if sail_request != 0.0:
				return _apply_station_input(
					&"SailLengthStarb",
					sail_request
				)

		&"SailRotationStarb":
			if rotation_request != 0.0:
				return _apply_station_input(
					&"SailRotationStarb",
					rotation_request
				)

	return false


func _apply_station_input(
	station_name: StringName,
	requested_input: float
) -> bool:

	var ready = request_station_control(
		station_name,
		requested_input
	)

	if not ready:
		return false

	match station_name:
		&"Wheel":
			turn_input = requested_input

		&"SailLengthStarb":
			sail_input = requested_input

		&"SailRotationStarb":
			sail_rotation_input = requested_input

	return requested_input != 0.0
