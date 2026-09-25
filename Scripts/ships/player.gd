class_name PlayerShip
extends Sloop

const REPAIR_OPTIONS: Array[String] = [
	"Repair mast", "Repair whole hull", "Bail water",
	"Repair mid deck", "Repair lower deck", "Repair whole ship",
]
const AIM_LABELS := {
	Cannon.AimTarget.HULL: "Fire at hull", Cannon.AimTarget.MAST: "Fire at mast",
	Cannon.AimTarget.CANNON: "Fire at cannon", Cannon.AimTarget.WHEEL: "Fire at wheel",
	Cannon.AimTarget.CREW: "Fire at crew",
}
const CYCLE_HINT := "Press Tab to cycle through ammunition"

## The ammunition whose aims the open C ring shows.
var _ring_ammo := Ammunition.CANNONBALL


func _ready() -> void:

	super()
	# the GUI is a sibling that may not be ready yet
	_bind_radial_menu.call_deferred()


func _bind_radial_menu() -> void:

	var menu: RadialMenu = get_tree().get_first_node_in_group(&"radial_menu")

	if menu == null:
		return

	menu.bind(&"repairShip", func(_crew_wide, _cycle): return REPAIR_OPTIONS, _on_repair_option, func(crew_wide):
		# just after the mast is hauled up, R goes to patch it so it stays up
		_order(crew_wide, &"request_repair_mast" if mast_system.just_raised() else &"request_repair_ship")
	)
	menu.bind(&"goToCannon",
		func(crew_wide, cycle): return _cannon_ring(menu, crew_wide, cycle),
		func(i, crew_wide): _order_ammo(crew_wide, _ring_ammo, _ring_ammo.aim_options[i]),
		func(crew_wide): _order(crew_wide, &"request_cannon_default_aim", [crew_wide])
	)

	# 1, 2, ...: a tap loads that ammunition at its usual aim, a hold offers its other aims
	for ammo in Ammunition.ALL:
		menu.bind(ammo.key_action,
			func(_crew_wide, _cycle): return _aim_labels(ammo),
			func(i, crew_wide): _order_ammo(crew_wide, ammo, ammo.aim_options[i]),
			func(crew_wide): _order_ammo(crew_wide, ammo, ammo.default_aim())
		)


## The C ring shows the aims of whatever the order's recipient has loaded. An order for the
## whole crew with no gunner selected has no one ammunition to go by, so it starts on the first
## and Tab pages through the rest.
func _cannon_ring(menu: RadialMenu, crew_wide: bool, cycle: int) -> Array:

	var recipient := crew_task_controller.cannon_order_recipient(crew_wide)
	var pages = crew_wide and station_controller.get_station_operated_by(recipient) is not CannonStationPoint

	_ring_ammo = Ammunition.ALL[cycle % Ammunition.ALL.size()] if pages else recipient.ammo
	menu.hint = CYCLE_HINT if pages else ""

	return _aim_labels(_ring_ammo)


func _aim_labels(ammo: Ammunition) -> Array:

	return ammo.aim_options.map(func(target): return AIM_LABELS[target])


func _order_ammo(crew_wide: bool, ammo: Ammunition, target: Cannon.AimTarget) -> void:

	_order(crew_wide, &"request_cannon_aim", [ammo, target, crew_wide])


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
