class_name PlayerShip
extends Sloop

const REPAIR_OPTIONS: Array[String] = [
	"Repair mast", "Repair whole hull", "Bail water",
	"Repair mid deck", "Repair lower deck", "Repair whole ship",
]
const AIM_OPTIONS: Array[String] = ["Fire at hull", "Fire at mast", "Fire at cannon", "Fire at wheel", "Fire at crew"]


func _ready() -> void:

	super()
	# the GUI is a sibling that may not be ready yet
	_bind_radial_menu.call_deferred()


func _bind_radial_menu() -> void:

	var menu: RadialMenu = get_tree().get_first_node_in_group(&"radial_menu")

	if menu == null:
		return

	menu.bind(&"repairShip", REPAIR_OPTIONS, _on_repair_option, func(crew_wide):
		# just after the mast is hauled up, R goes to patch it so it stays up
		_order(crew_wide, &"request_repair_mast" if mast_system.just_raised() else &"request_repair_ship")
	)
	menu.bind(&"goToCannon", AIM_OPTIONS,
		func(i, crew_wide): _order(crew_wide, &"request_cannon_aim", [i, crew_wide]),
		func(crew_wide): _order(crew_wide, &"request_cannon_aim", [Cannon.AimTarget.HULL, crew_wide])
	)


func _on_repair_option(index: int, crew_wide: bool) -> void:

	match index:
		0: _order(crew_wide, &"request_repair_mast")
		1: _order(crew_wide, &"request_repair_ship")
		2: _order(crew_wide, &"request_bail_water")
		3: _order(crew_wide, &"request_repair_ship", [[DeckGraph.DECKS.MID]])
		4: _order(crew_wide, &"request_repair_ship", [[DeckGraph.DECKS.LOWER]])
		5: _order(crew_wide, &"request_repair_whole_ship")


## Gives the order to the selected crewmate, or with [param crew_wide] to each crewmate in turn
## as though they were the one selected.
func _order(crew_wide: bool, method: StringName, args := []) -> void:

	var selected = crew_controller.current_crewmate

	for crewmate in (get_crewmates() if crew_wide else [selected]):
		crew_controller.current_crewmate = crewmate
		request(method, args)

	crew_controller.current_crewmate = selected

func _control() -> bool:

	set_movement_input(0.0, 0.0, 0.0)

	if Input.is_action_just_pressed("cancelAction"):
		request(&"request_cancel_action")

		return true

	if Input.is_action_just_pressed("changeCrewmate"):
		change_crewmate()

	if Input.is_action_just_pressed("bailWater"):
		request(&"request_bail_water")

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
