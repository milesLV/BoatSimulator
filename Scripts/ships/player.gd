class_name PlayerShip
extends Sloop

## [label, crew task request, its args], in ring order.
const REPAIR_ORDERS := [
	["Repair mast", &"request_repair_mast", []],
	["Repair wheel", &"request_repair_wheel", []],
	["Repair whole hull", &"request_repair_ship", []],
	["Bail water", &"request_bail_water", []],
	["Repair mid deck", &"request_repair_ship", [[DeckGraph.DECKS.MID]]],
	["Repair lower deck", &"request_repair_ship", [[DeckGraph.DECKS.LOWER]]],
	["Repair whole ship", &"request_repair_whole_ship", []],
]
const AIM_LABELS := {
	Cannon.AimTarget.HULL: "Fire at hull", Cannon.AimTarget.MAST: "Fire at mast",
	Cannon.AimTarget.CANNON: "Fire at cannon", Cannon.AimTarget.WHEEL: "Fire at wheel",
	Cannon.AimTarget.CREW: "Fire at crew",
}
const CYCLE_HINT := "Press Tab to cycle through ammunition"

var _ring_ammo := Ammunition.CANNONBALL


func _ready() -> void:

	super()
	# the GUI is a sibling that may not be ready yet
	_bind_radial_menu.call_deferred()


func _bind_radial_menu() -> void:

	var menu: RadialMenu = get_tree().get_first_node_in_group(&"radial_menu")

	if menu == null:
		return

	menu.bind(&"repairShip",
		func(_crew_wide, _cycle): return REPAIR_ORDERS.map(func(order): return order[0]),
		func(i, crew_wide): _order(crew_wide, REPAIR_ORDERS[i][1], REPAIR_ORDERS[i][2]),
		func(crew_wide):
		# just after the mast is hauled up, R patches it so it stays up
		_order(crew_wide, &"request_repair_mast" if mast_system.just_raised() else &"request_repair_ship")
	)
	menu.bind(&"goToCannon",
		func(crew_wide, cycle): return _cannon_ring(menu, crew_wide, cycle),
		func(i, crew_wide): _order_ammo(crew_wide, _ring_ammo, _ring_ammo.aim_options[i]),
		func(crew_wide): _order(crew_wide, &"request_cannon_default_aim", [crew_wide])
	)

	for ammo in Ammunition.ALL:
		menu.bind(ammo.key_action,
			func(_crew_wide, _cycle): return _aim_labels(ammo),
			func(i, crew_wide): _order_ammo(crew_wide, ammo, ammo.aim_options[i]),
			func(crew_wide): _order_ammo(crew_wide, ammo, ammo.default_aim())
		)


## A crew-wide order with no gunner selected has no ammunition to go by, so Tab pages through all.
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


func _order(crew_wide: bool, method: StringName, args := []) -> void:

	var selected = current_crewmate

	for crewmate in (crewmates if crew_wide else [selected]):
		current_crewmate = crewmate
		request(method, args)

	current_crewmate = selected

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

	if mast_system.sails_locked():
		if Input.is_action_just_pressed("lowerSailsDown"):
			request(&"request_mast_toggle")
	else:
		sail_length = _get_station_axis_input(
			&"SailLengthStarb", # TODO: use whichever side's station is closest
			&"raiseSailsUp",
			&"lowerSailsDown"
		)
	var sail_rotation = _get_station_axis_input(
		&"SailRotationStarb",
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
	var manned = station_controller.get_operator_by_name(station_name) != null

	return requested_input if manned or request(&"request_station_control", [station_name, requested_input]) else 0.0
