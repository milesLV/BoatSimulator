extends Sloop

func _physics_process(delta):
	turn_input = 0.0
	sail_input = 0.0
	sail_rotation_input = 0.0

	# Changing crewmates
	if Input.is_action_just_pressed("changeCrewmate"):
		_change_crewmate()
	
	# Turning wheel
	var wheel_request := 0.0

	if Input.is_action_pressed("turnWheelLeft"):
		wheel_request -= 1.0

	if Input.is_action_pressed("turnWheelRight"):
		wheel_request += 1.0


	var wheel_ready = (
		request_station_control(
			&"Wheel",
			wheel_request
		)
	)

	# Held input persists.
	if wheel_ready:
		turn_input = wheel_request

	# Adjusting sail length
	var sail_request := 0.0

	if Input.is_action_pressed("lowerSailsDown"):
		sail_request += 1.0

	if Input.is_action_pressed("raiseSailsUp"):
		sail_request -= 1.0


	var sail_ready = (
		request_station_control(
			&"SailLengthStarb", # TODO: make so can choose port or starboard size depending on whatever's closest
			sail_request
		)
	)


	if sail_ready:
		sail_input = sail_request
	
	# Adjusting sail rotation
	var rotation_request := 0.0

	if Input.is_action_pressed("adjustSailLeft"):
		rotation_request -= 1.0

	if Input.is_action_pressed("adjustSailRight"):
		rotation_request += 1.0


	var rotation_ready = (
		request_station_control(
			&"SailRotationStarb", # TODO: make so can choose port or starboard size depending on whatever's closest
			rotation_request
		)
	)


	if rotation_ready:
		sail_rotation_input = rotation_request

	_process_movement(delta)
	update_active_cannon()
	
	#if Input.is_action_just_pressed("dropOrRaiseAnchor"): # testing
