class_name PlayerShip
extends Sloop

func is_crewmate_selected(crewmate: Crewmate) -> bool:

	return super.is_crewmate_selected(
		crewmate
	)

func _physics_process(delta):
	reset_movement_input()
	_process_health(delta)

	if is_sunk():
		return

	if Input.is_action_just_pressed("cancelAction"):
		request_cancel_action()
		_process_movement(delta)
		update_cannon_systems()
		return

	# Changing crewmates
	if Input.is_action_just_pressed("changeCrewmate"):
		change_crewmate()

	if Input.is_action_just_pressed("goToCannon"):
		request_current_cannon_duty()

	if Input.is_action_just_pressed("bailWater"):
		request_bail_water()

	if Input.is_action_just_pressed("repairShip"):
		request_repair_ship()

	var turn = _get_station_axis_input(
		&"Wheel",
		&"turnWheelLeft",
		&"turnWheelRight"
	)
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

	set_movement_input(
		turn,
		sail,
		sail_rotation
	)

	if Input.is_action_just_pressed("dropOrRaiseAnchor"):
		request_anchor_toggle()

	_process_movement(delta)
	update_cannon_systems()


func _get_axis_request(
	negative_action: StringName,
	positive_action: StringName
) -> float:

	var request := 0.0

	if Input.is_action_pressed(
		negative_action
	):
		request -= 1.0

	if Input.is_action_pressed(
		positive_action
	):
		request += 1.0

	return request


func _get_station_axis_input(
	station_name: StringName,
	negative_action: StringName,
	positive_action: StringName
) -> float:

	var requested_input = _get_axis_request(
		negative_action,
		positive_action
	)

	if not _can_apply_station_input(
		station_name,
		requested_input
	):
		return 0.0

	return requested_input


func _can_apply_station_input(
	station_name: StringName,
	requested_input: float
) -> bool:

	if _station_has_operator(
		station_name
	):
		return true

	if requested_input == 0.0:
		return false

	return request_station_control(
		station_name,
		requested_input
	)


func _station_has_operator(station_name: StringName) -> bool:

	return (
		station_controller.get_operator_by_name(station_name)
		!= null
	)
