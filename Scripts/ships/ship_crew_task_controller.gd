class_name ShipCrewTaskController
extends RefCounted

var crew_controller: ShipCrewController
var station_controller: ShipStationController
var cannon_duty_controller: ShipCannonDutyController
var repair_duty_controller: ShipRepairDutyController
var action_planner: ShipActionPlanner
var anchor_system: AnchorSystem

var requested_station_by_crewmate := {}
var crewmate_by_requested_station := {}


func _init(
	new_crew_controller: ShipCrewController,
	new_station_controller: ShipStationController,
	new_cannon_duty_controller: ShipCannonDutyController,
	new_repair_duty_controller: ShipRepairDutyController,
	new_action_planner: ShipActionPlanner,
	new_anchor_system: AnchorSystem
) -> void:

	crew_controller = new_crew_controller
	station_controller = new_station_controller
	cannon_duty_controller = new_cannon_duty_controller
	repair_duty_controller = new_repair_duty_controller
	action_planner = new_action_planner
	anchor_system = new_anchor_system


func request_station_control(station_name: StringName, requested_input: float) -> bool:

	return station_controller.request_station_control(
		crew_controller.current_crewmate, station_name, requested_input
	)


func _request_planned(builder: StringName) -> bool:

	var crewmate := crew_controller.current_crewmate

	return queue_manual_actions(crewmate, action_planner.call(builder, crewmate), "new crew action")


func request_anchor_toggle() -> bool:

	if anchor_system.can_drop():
		return _request_planned(&"build_drop_anchor")

	if anchor_system.can_raise():
		return _request_planned(&"build_raise_anchor")

	return false


## Down or falling: go and haul it up. Propped: let it go from the sail lines, walking there
## first if need be; the next press hauls it back.
func request_mast_toggle() -> bool:

	var crewmate := crew_controller.current_crewmate
	var mast_system: MastSystem = crew_controller.ship.mast_system

	if mast_system.state == MastSystem.State.PROPPED:
		if station_controller.get_operator_by_name(&"SailLengthStarb") == crewmate:
			return mast_system.knock_loose()

		return _request_planned(&"build_knock_mast_loose")

	return _request_planned(&"build_raise_mast")


func request_bail_water() -> bool:

	var crewmate := crew_controller.current_crewmate

	if not queue_manual_actions(crewmate, action_planner.build_bail_water(crewmate), "manual bail water"):
		return false

	Crewmate.set_queue_finished_listener(crewmate, _on_manual_bail_queue_finished, true)

	return true


func request_repair_ship() -> bool:

	return repair_duty_controller.assign_crewmate(crew_controller.current_crewmate)


## Repair duty leaves the mast alone - it lets no water in - so this is the only way it gets
## patched: one trip round every mast hole that is open.
func request_repair_mast() -> bool:

	var crewmate := crew_controller.current_crewmate
	var actions: Array[ActionDefinition] = []
	var start_deck = null
	var start_position = null

	for hole in action_planner.action_points.mast_holes:
		if hole.grade > ShipHolePoint.MIN_GRADE:
			# each leg sets off from the hole before it, not from where the crewmate stands now
			actions.append_array(action_planner.build_repair_hole(crewmate, hole, start_deck, start_position))
			start_deck = hole.deck
			start_position = hole.get_position_for_actor(crewmate)

	prepare_for_repair_duty(crewmate)

	return queue_repair_actions(crewmate, actions, true)


func request_current_cannon_duty() -> bool:

	var crewmate := crew_controller.current_crewmate

	prepare_for_duty(crewmate, "cannon duty request")

	return cannon_duty_controller.request_crewmate_to_active_broadside(crewmate)


func request_cannon_duty_for(crewmate: Crewmate) -> bool:

	prepare_for_duty(crewmate, "cannon duty assignment")

	return cannon_duty_controller.assign_crewmate(crewmate)


## Drops whatever the current crewmate is doing; with nothing to drop, a dropping anchor is
## hauled back up instead.
func request_cancel_action() -> bool:

	var crewmate := crew_controller.current_crewmate

	if clear_cannon_duty(crewmate):
		return true

	clear_requested_station(crewmate)
	clear_manual_bail(crewmate)
	repair_duty_controller.clear_crewmate(crewmate, "cancel action")

	var had_actions = crewmate.action_executor.cancel_plan()

	if station_controller.detach_crewmate(crewmate) or had_actions:
		return true

	if anchor_system.state == AnchorSystem.State.DROPPING:
		return _request_planned(&"build_raise_anchor")

	return false


func prepare_for_repair_duty(crewmate: Crewmate) -> void:
	clear_manual_bail(crewmate)
	clear_cannon_duty(crewmate)
	station_controller.detach_crewmate(crewmate)
	clear_requested_station(crewmate)


## Clears whatever duty a crewmate is on so a station or cannon order can take over.
func prepare_for_duty(crewmate: Crewmate, reason: String) -> void:
	clear_manual_bail(crewmate)
	repair_duty_controller.clear_crewmate(crewmate, reason)


func queue_manual_actions(crewmate: Crewmate, actions: Array, reason: String) -> bool:
	if actions.is_empty():
		return false

	repair_duty_controller.clear_crewmate(crewmate, reason)
	clear_manual_bail(crewmate)
	clear_cannon_duty(crewmate)
	clear_requested_station(crewmate)

	crewmate.action_executor.cancel_plan()
	crewmate.action_executor.queue_actions(actions)

	return true


func queue_repair_actions(crewmate: Crewmate, actions: Array, replace_current: bool) -> bool:
	if actions.is_empty():
		return false

	clear_manual_bail(crewmate)
	clear_requested_station(crewmate)

	if replace_current:
		crewmate.action_executor.cancel_plan()

	crewmate.action_executor.queue_actions(actions)

	return true


## Sends a crewmate to a station. [param reason] empty means a cannon takeover,
## which drops whatever station the crewmate is already holding.
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
		crewmate.action_executor.cancel_plan()

	clear_requested_station(crewmate)
	requested_station_by_crewmate[crewmate] = station
	crewmate_by_requested_station[station] = crewmate

	crewmate.action_executor.queue_actions(actions)

	return true


func clear_cannon_duty(crewmate: Crewmate) -> bool:
	if not cannon_duty_controller.is_duty_crewmate(crewmate):
		return false

	return cannon_duty_controller.clear_assignment()


func clear_requested_station(crewmate: Crewmate) -> void:
	crewmate_by_requested_station.erase(requested_station_by_crewmate.get(crewmate))
	requested_station_by_crewmate.erase(crewmate)


func get_station_requester(station: StationPoint) -> Crewmate:

	return crewmate_by_requested_station.get(station)


func clear_station_and_actions(crewmate: Crewmate) -> void:
	clear_manual_bail(crewmate)
	clear_requested_station(crewmate)
	crewmate.action_executor.cancel_plan()
	station_controller.detach_crewmate(crewmate)


func clear_manual_bail(crewmate: Crewmate) -> void:
	Crewmate.set_queue_finished_listener(crewmate, _on_manual_bail_queue_finished, false)


func _on_manual_bail_queue_finished(crewmate: Crewmate) -> void:

	if crewmate.action_executor.has_actions():
		return

	# repair or cannon duty took over while the bucket was in hand
	if (
		repair_duty_controller.is_repair_duty_crewmate(crewmate)
		or cannon_duty_controller.is_duty_crewmate(crewmate)
	):
		clear_manual_bail(crewmate)
		return

	var next_actions = action_planner.build_bail_water(crewmate)

	if next_actions.is_empty():
		clear_manual_bail(crewmate)
		return

	clear_requested_station(crewmate)
	crewmate.action_executor.queue_actions(next_actions)

