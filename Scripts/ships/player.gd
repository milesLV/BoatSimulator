extends Sloop

func _physics_process(delta):
	turn_input = 0.0
	sail_input = 0.0
	sail_rotation_input = 0.0

	# Changing crewmates
	if Input.is_action_just_pressed("changeCrewmate"):
		_change_crewmate()
	
	# Turning wheel
	if Input.is_action_pressed("turnWheelLeft"):
		turn_input -= 1.0
	if Input.is_action_pressed("turnWheelRight"):
		turn_input += 1.0

	# Adjusting sail length
	if Input.is_action_pressed("lowerSailsDown"):
		sail_input += 1.0
	if Input.is_action_pressed("raiseSailsUp"):
		sail_input -= 1.0
	
	# Adjusting sail rotation
	if Input.is_action_pressed("adjustSailLeft"):
		sail_rotation_input -= 1.0
	if Input.is_action_pressed("adjustSailRight"):
		sail_rotation_input += 1.0

	_process_movement(delta)
	update_active_cannon()
	
	if Input.is_action_just_pressed("dropOrRaiseAnchor"): # testing

		var actions = (
			ActionBuilder.build_go_to_wheel(
				current_crewmate
			)
		)

		current_crewmate.action_executor.queue_actions(
			actions
		)
