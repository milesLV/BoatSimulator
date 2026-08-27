class_name PlayerShip
extends Sloop

func _control(_delta: float) -> bool:

	reset_movement_input()

	if Input.is_action_just_pressed("cancelAction"):
		request(&"request_cancel_action")

		return true

	if Input.is_action_just_pressed("changeCrewmate"):
		change_crewmate()

	if Input.is_action_just_pressed("goToCannon"):
		request(&"request_current_cannon_duty")

	if Input.is_action_just_pressed("bailWater"):
		request(&"request_bail_water")

	if Input.is_action_just_pressed("repairShip"):
		request(&"request_repair_ship")

	var turn = _get_station_axis_input(&"Wheel", &"turnWheelLeft", &"turnWheelRight")
	var sail = _get_station_axis_input(
		&"SailLengthStarb", # TODO: make so can choose port or starboard size depending on whatever's closest
		&"raiseSailsUp",
		&"lowerSailsDown"
	)
	var sail_rotation = _get_station_axis_input(
		&"SailRotationStarb", # TODO: make so can choose port or starboard size depending on whatever's closest
		&"adjustSailLeft",
		&"adjustSailRight"
	)

	set_movement_input(turn, sail, sail_rotation)

	if Input.is_action_just_pressed("dropOrRaiseAnchor"):
		request(&"request_anchor_toggle")

	return true


func _get_station_axis_input(
	station_name: StringName,
	negative_action: StringName,
	positive_action: StringName
) -> float:

	var requested_input = Input.get_axis(negative_action, positive_action)

	if station_controller.get_operator_by_name(station_name) != null:
		return requested_input

	if requested_input == 0.0:
		return 0.0

	if not request(&"request_station_control", [station_name, requested_input]):
		return 0.0

	return requested_input
