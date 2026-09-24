class_name PlayerShip
extends Sloop

func _control() -> bool:

	set_movement_input(0.0, 0.0, 0.0)

	if Input.is_action_just_pressed("cancelAction"):
		request(&"request_cancel_action")

		return true

	if Input.is_action_just_pressed("changeCrewmate"):
		change_crewmate()

	if Input.is_action_just_pressed("goToCannon"):
		request(&"request_current_cannon_duty")

	if Input.is_action_just_pressed("bailWater"):
		request(&"request_bail_water")

	# just after the mast is hauled up, R goes to patch it so it stays up
	if Input.is_action_just_pressed("repairShip"):
		request(&"request_repair_mast" if mast_system.just_raised() else &"request_repair_ship")

	if Input.is_action_just_pressed("repairMast"):
		request(&"request_repair_mast")

	var turn = _get_station_axis_input(&"Wheel", &"turnWheelLeft", &"turnWheelRight")
	var sail_length := 0.0

	# a mast off its feet takes S as an order to raise it, like X for the anchor
	if mast_system.sails_locked():
		if Input.is_action_just_pressed("lowerSailsDown"):
			request(&"request_mast_toggle")
	else:
		sail_length = _get_station_axis_input(
			&"SailLengthStarb", # TODO: make so can choose port or starboard size depending on whatever's closest
			&"raiseSailsUp",
			&"lowerSailsDown"
		)
	var sail_rotation = _get_station_axis_input(
		&"SailRotationStarb", # TODO: make so can choose port or starboard size depending on whatever's closest
		&"adjustSailLeft",
		&"adjustSailRight"
	)

	set_movement_input(turn, sail_length, sail_rotation)

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

	if requested_input == 0.0 or not request(&"request_station_control", [station_name, requested_input]):
		return 0.0

	return requested_input
