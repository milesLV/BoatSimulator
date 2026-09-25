class_name ShipCrewTaskController
extends RefCounted

var ship: Sloop

var crewmate_by_requested_station := {}
## crewmate -> the mast or wheel holes they are going round.
var _part_repairs := {}


func _init(new_ship: Sloop) -> void:

	ship = new_ship

	for hole in ship.action_points.mast_holes + ship.action_points.wheel_holes:
		hole.grade_changed.connect(_on_part_hole_changed)


func request_station_control(station_name: StringName, requested_input: float) -> bool:

	return ship.station_controller.request_station_control(
		ship.current_crewmate, station_name, requested_input
	)


func _request_planned(builder: StringName) -> bool:

	var crewmate := ship.current_crewmate

	return queue_manual_actions(crewmate, ship.action_planner.call(builder, crewmate), "new crew action")


func request_anchor_toggle() -> bool:

	if ship.anchor_system.can_drop():
		return _request_planned(&"build_drop_anchor")

	if ship.anchor_system.can_raise():
		return _request_planned(&"build_raise_anchor")

	return false


func request_mast_toggle() -> bool:

	var crewmate := ship.current_crewmate
	var mast_system := ship.mast_system

	if mast_system.state == MastSystem.State.PROPPED:
		if ship.station_controller.get_operator_by_name(&"SailLengthStarb") == crewmate:
			return mast_system.knock_loose()

		return _request_planned(&"build_knock_mast_loose")

	return _request_planned(&"build_raise_mast")


func request_bail_water() -> bool:

	var crewmate := ship.current_crewmate

	if not queue_manual_actions(crewmate, ship.action_planner.build_bail_water(crewmate), "manual bail water"):
		return false

	Crewmate.set_queue_finished_listener(crewmate, _on_manual_bail_queue_finished, true)

	return true


## [param decks] limits which hull holes they patch; empty is every deck.
func request_repair_ship(decks: Array = []) -> bool:

	return ship.repair_duty_controller.assign_crewmate(ship.current_crewmate, decks)


func request_repair_whole_ship() -> bool:

	if not _request_repair_part(ship.action_points.mast_holes + ship.action_points.wheel_holes):
		return request_repair_ship()

	Crewmate.set_queue_finished_listener(ship.current_crewmate, _on_parts_repaired, true)

	return true


func _on_parts_repaired(crewmate: Crewmate) -> void:

	Crewmate.set_queue_finished_listener(crewmate, _on_parts_repaired, false)
	ship.repair_duty_controller.assign_crewmate(crewmate)


## The first gunner from the selected crewmate on, else the selected one; crew_wide checks only them.
func cannon_order_recipient(crew_wide := false) -> Crewmate:

	var crew := ship.crewmates
	var start := crew.find(ship.current_crewmate)

	for i in (1 if crew_wide else crew.size()):
		var crewmate := crew[(start + i) % crew.size()]

		if ship.station_controller.get_station_operated_by(crewmate) is CannonStationPoint:
			return crewmate

	return ship.current_crewmate


func request_cannon_aim(ammo: Ammunition, target: Cannon.AimTarget, crew_wide := false) -> bool:

	var crewmate := cannon_order_recipient(crew_wide)
	var station = ship.station_controller.get_station_operated_by(crewmate)

	crewmate.ammo = ammo
	crewmate.aim_target = target

	if station is CannonStationPoint:
		station.cannon.ammo = ammo
		station.cannon.aim_target = target
		return true

	return request_current_cannon_duty()


func request_cannon_default_aim(crew_wide := false) -> bool:

	var ammo := cannon_order_recipient(crew_wide).ammo

	return request_cannon_aim(ammo, ammo.default_aim(), crew_wide)


## Repair duty skips the mast and wheel since they let no water in.
func request_repair_mast() -> bool:

	return _request_repair_part(ship.action_points.mast_holes)


func request_repair_wheel() -> bool:

	return _request_repair_part(ship.action_points.wheel_holes)


func _request_repair_part(holes: Array) -> bool:

	var crewmate := ship.current_crewmate

	prepare_for_repair_duty(crewmate)
	_part_repairs[crewmate] = holes

	return _plan_part_repair(crewmate)


func _plan_part_repair(crewmate: Crewmate) -> bool:

	var actions: Array[ActionDefinition] = []
	var start_deck = null
	var start_position = null

	for hole in _part_repairs[crewmate]:
		if hole.grade > ShipHolePoint.MIN_GRADE:
			# each leg sets off from the hole before it, not from where the crewmate stands now
			actions.append_array(ship.action_planner.build_repair_hole(crewmate, hole, start_deck, start_position))
			start_deck = hole.deck
			start_position = hole.get_position_for_actor(crewmate)

	return queue_repair_actions(crewmate, actions, true)


## A hole opening on a part someone is still going round joins their trip.
func _on_part_hole_changed(hole: ShipHolePoint, old_grade: int, new_grade: int) -> void:

	if new_grade <= old_grade:
		return

	for crewmate in _part_repairs.keys():
		var holes: Array = _part_repairs[crewmate]
		var still_going: bool = crewmate.action_executor.plan_actions.any(func(instance): return (
			not instance.finished and instance.definition is RepairHoleAction and instance.definition.point in holes
		))

		if not still_going:
			_part_repairs.erase(crewmate)
		elif hole in holes:
			_plan_part_repair(crewmate)


func request_current_cannon_duty() -> bool:

	var crewmate := ship.current_crewmate

	prepare_for_duty(crewmate, "cannon duty request")

	return ship.cannon_duty_controller.request_crewmate_to_active_broadside(crewmate)


func request_cannon_duty_for(crewmate: Crewmate) -> bool:

	prepare_for_duty(crewmate, "cannon duty assignment")
	ship.cannon_duty_controller.assign_crewmate(crewmate)

	return true


func request_cancel_action() -> bool:

	var crewmate := ship.current_crewmate

	if clear_cannon_duty(crewmate):
		return true

	clear_requested_station(crewmate)
	clear_manual_bail(crewmate)
	ship.repair_duty_controller.clear_crewmate(crewmate, "cancel action")

	var had_actions = crewmate.action_executor.cancel_plan()

	if ship.station_controller.detach_crewmate(crewmate) or had_actions:
		return true

	if ship.anchor_system.state == AnchorSystem.State.DROPPING:
		return _request_planned(&"build_raise_anchor")

	return false


func prepare_for_repair_duty(crewmate: Crewmate) -> void:
	clear_manual_bail(crewmate)
	clear_cannon_duty(crewmate)
	ship.station_controller.detach_crewmate(crewmate)
	clear_requested_station(crewmate)


func prepare_for_duty(crewmate: Crewmate, reason: String) -> void:
	clear_manual_bail(crewmate)
	ship.repair_duty_controller.clear_crewmate(crewmate, reason)


func queue_manual_actions(crewmate: Crewmate, actions: Array, reason: String) -> bool:
	if actions.is_empty():
		return false

	ship.repair_duty_controller.clear_crewmate(crewmate, reason)
	clear_manual_bail(crewmate)
	clear_cannon_duty(crewmate)
	clear_requested_station(crewmate)

	crewmate.action_executor.replace_plan(actions)

	return true


func queue_repair_actions(crewmate: Crewmate, actions: Array, replace_current: bool) -> bool:
	if actions.is_empty():
		return false

	clear_manual_bail(crewmate)
	clear_requested_station(crewmate)

	if replace_current:
		crewmate.action_executor.replace_plan(actions)
	else:
		crewmate.action_executor.queue_actions(actions)

	return true


## An empty [param reason] means a cannon takeover, which also drops any held station.
func queue_station_request(
	crewmate: Crewmate,
	station: StationPoint,
	actions: Array,
	reason := ""
) -> bool:

	if actions.is_empty() or get_station_requester(station) not in [null, crewmate]:
		return false

	if reason.is_empty():
		clear_station_and_actions(crewmate)
	else:
		prepare_for_duty(crewmate, reason)

	clear_requested_station(crewmate)
	crewmate_by_requested_station[station] = crewmate

	crewmate.action_executor.replace_plan(actions)

	return true


func clear_cannon_duty(crewmate: Crewmate) -> bool:
	return ship.cannon_duty_controller.is_duty_crewmate(crewmate) and ship.cannon_duty_controller.clear_assignment()


func clear_requested_station(crewmate: Crewmate) -> void:
	crewmate_by_requested_station.erase(crewmate_by_requested_station.find_key(crewmate))


func get_station_requester(station: StationPoint) -> Crewmate:

	return crewmate_by_requested_station.get(station)


func clear_station_and_actions(crewmate: Crewmate) -> void:
	clear_manual_bail(crewmate)
	clear_requested_station(crewmate)
	crewmate.action_executor.cancel_plan()
	ship.station_controller.detach_crewmate(crewmate)


func clear_manual_bail(crewmate: Crewmate) -> void:
	Crewmate.set_queue_finished_listener(crewmate, _on_manual_bail_queue_finished, false)


func _on_manual_bail_queue_finished(crewmate: Crewmate) -> void:

	if crewmate.action_executor.has_actions():
		return

	# repair or cannon duty took over while the bucket was in hand
	if (
		ship.repair_duty_controller.active_crewmates.has(crewmate)
		or ship.cannon_duty_controller.is_duty_crewmate(crewmate)
	):
		clear_manual_bail(crewmate)
		return

	var next_actions = ship.action_planner.build_bail_water(crewmate)

	if next_actions.is_empty():
		clear_manual_bail(crewmate)
		return

	clear_requested_station(crewmate)
	crewmate.action_executor.queue_actions(next_actions)

