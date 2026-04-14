extends "res://Scripts/ships/sloop.gd"

func _physics_process(delta):
	turn_input = 0.0
	sail_input = 0.0

	if Input.is_action_pressed("turnWheelLeft"):
		turn_input -= 1.0
	if Input.is_action_pressed("turnWheelRight"):
		turn_input += 1.0

	if Input.is_action_pressed("lowerSailsDown"):
		sail_input += 1.0
	if Input.is_action_pressed("raiseSailsUp"):
		sail_input -= 1.0

	_process_movement(delta)
