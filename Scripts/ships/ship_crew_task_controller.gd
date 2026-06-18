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
var manual_bail_modes := {}
var manual_bail_handlers := {}


func _init(
	new_crew_controller: ShipCrewController,
	new_station_controller: ShipStationController,
	new_cannon_duty_controller: ShipCannonDutyController,
	new_repair_duty_controller: ShipRepairDutyController,
	new_action_planner: ShipActionPlanner = null,
	new_anchor_system: AnchorSystem = null
) -> void:

	crew_controller = new_crew_controller
	station_controller = new_station_controller
	cannon_duty_controller = new_cannon_duty_controller
	repair_duty_controller = new_repair_duty_controller
	action_planner = new_action_planner
	anchor_system = new_anchor_system


func request_station_control(
	station_name: StringName,
	requested_input: float
) -> bool:

	var crewmate = _get_current_crewmate()

	if (
		crewmate == null
		or station_controller == null
	):
		return false

	return station_controller.request_station_control(
		crewmate,
		station_name,
		requested_input
	)


func request_anchor_drop() -> bool:

	var crewmate = _get_current_crewmate()

	if (
		crewmate == null
		or action_planner == null
	):
		return false

	return queue_manual_actions(
		crewmate,
		action_planner.build_drop_anchor(crewmate),
		"new crew action"
	)


func request_anchor_raise() -> bool:

	var crewmate = _get_current_crewmate()

	if (
		crewmate == null
		or action_planner == null
	):
		return false

	return queue_manual_actions(
		crewmate,
		action_planner.build_raise_anchor(crewmate),
		"new crew action"
	)


func request_anchor_toggle() -> bool:

	if anchor_system == null:
		return false

	if anchor_system.can_drop():
		return request_anchor_drop()

	if anchor_system.can_raise():
		return request_anchor_raise()

	return false


func request_bail_water() -> bool:

	var crewmate = _get_current_crewmate()

	if (
		crewmate == null
		or action_planner == null
	):
		return false

	return queue_manual_bail_actions(
		crewmate,
		action_planner.build_bail_water(crewmate)
	)


func request_repair_ship() -> bool:

	var crewmate = _get_current_crewmate()

	if (
		crewmate == null
		or repair_duty_controller == null
	):
		return false

	prepare_for_repair_duty(crewmate)

	return repair_duty_controller.assign_crewmate(
		crewmate
	)


func request_current_cannon_duty() -> bool:

	var crewmate = _get_current_crewmate()

	if (
		crewmate == null
		or cannon_duty_controller == null
	):
		return false

	prepare_for_cannon_duty(
		crewmate,
		"cannon duty request"
	)

	return cannon_duty_controller.request_crewmate_to_active_broadside(
		crewmate
	)


func request_cannon_duty_for(crewmate: Crewmate) -> bool:

	if (
		crewmate == null
		or cannon_duty_controller == null
	):
		return false

	prepare_for_cannon_duty(
		crewmate,
		"cannon duty assignment"
	)

	return cannon_duty_controller.assign_crewmate(
		crewmate
	)


func request_cancel_action() -> bool:

	var crewmate = _get_current_crewmate()

	if crewmate == null:
		return false

	if cancel_crewmate_action(crewmate):
		return true

	if (
		anchor_system != null
		and anchor_system.is_passive_decay_active()
	):
		return request_anchor_raise()

	return false


func prepare_for_station_control(
	crewmate: Crewmate,
	reason: String
) -> void:

	clear_manual_bail(crewmate)
	clear_repair_duty(crewmate, reason)


func prepare_for_manual_action(
	crewmate: Crewmate,
	reason: String
) -> void:

	clear_repair_duty(crewmate, reason)
	clear_manual_bail(crewmate)
	clear_cannon_duty(crewmate)
	clear_requested_station(crewmate)


func prepare_for_repair_duty(crewmate: Crewmate) -> void:
	clear_manual_bail(crewmate)
	clear_cannon_duty(crewmate)
	clear_station(crewmate)
	clear_requested_station(crewmate)


func prepare_for_cannon_duty(
	crewmate: Crewmate,
	reason: String
) -> void:

	clear_manual_bail(crewmate)
	clear_repair_duty(crewmate, reason)


func cancel_crewmate_action(crewmate: Crewmate) -> bool:
	if crewmate == null:
		return false

	if clear_cannon_duty(crewmate):
		return true

	clear_requested_station(crewmate)
	clear_manual_bail(crewmate)
	clear_repair_duty(crewmate, "cancel action")

	if (
		crewmate.action_executor != null
		and crewmate.action_executor.has_actions()
	):
		crewmate.action_executor.cancel_plan()
		clear_station(crewmate)
		return true

	return clear_station(crewmate)


func queue_manual_actions(
	crewmate: Crewmate,
	actions: Array,
	reason: String
) -> bool:

	if crewmate == null or actions.is_empty():
		return false

	prepare_for_manual_action(crewmate, reason)

	if crewmate.action_executor == null:
		return false

	crewmate.action_executor.cancel_plan()
	crewmate.action_executor.queue_actions(actions)

	return true


func queue_manual_bail_actions(
	crewmate: Crewmate,
	actions: Array,
	drain_to_zero := false
) -> bool:

	if not queue_manual_actions(
		crewmate,
		actions,
		"manual bail water"
	):
		return false

	manual_bail_modes[crewmate] = drain_to_zero
	_connect_manual_bail_listener(crewmate)

	return true


func queue_repair_actions(
	crewmate: Crewmate,
	actions: Array,
	replace_current: bool
) -> bool:

	if crewmate == null or actions.is_empty():
		return false

	clear_manual_bail(crewmate)
	clear_requested_station(crewmate)

	if crewmate.action_executor == null:
		return false

	if replace_current:
		crewmate.action_executor.cancel_plan()

	crewmate.action_executor.queue_actions(actions)

	return true


func queue_station_request(
	crewmate: Crewmate,
	station: StationPoint,
	actions: Array,
	reason: String
) -> bool:

	if (
		crewmate == null
		or station == null
		or actions.is_empty()
		or crewmate.action_executor == null
	):
		return false

	if is_station_requested_by_other(
		station,
		crewmate
	):
		return false

	prepare_for_station_control(
		crewmate,
		reason
	)

	crewmate.action_executor.cancel_plan()

	if not set_requested_station(
		crewmate,
		station
	):
		return false

	crewmate.action_executor.queue_actions(actions)

	return true


func queue_cannon_station_actions(
	crewmate: Crewmate,
	station: StationPoint,
	actions: Array
) -> bool:

	if (
		crewmate == null
		or station == null
		or actions.is_empty()
		or crewmate.action_executor == null
	):
		return false

	if is_station_requested_by_other(
		station,
		crewmate
	):
		return false

	clear_station_and_actions(crewmate)

	if not set_requested_station(
		crewmate,
		station
	):
		return false

	crewmate.action_executor.queue_actions(actions)

	return true


func queue_cannon_action(
	crewmate: Crewmate,
	action: ActionDefinition
) -> bool:

	if (
		crewmate == null
		or action == null
		or crewmate.action_executor == null
	):
		return false

	crewmate.action_executor.queue_action(action)

	return true


func clear_repair_duty(
	crewmate: Crewmate,
	reason: String
) -> bool:

	if repair_duty_controller == null:
		return false

	return repair_duty_controller.clear_crewmate(crewmate, reason)


func clear_cannon_duty(crewmate: Crewmate) -> bool:
	if (
		crewmate == null
		or cannon_duty_controller == null
		or not cannon_duty_controller.is_duty_crewmate(crewmate)
	):
		return false

	return cannon_duty_controller.clear_assignment()


func clear_station(crewmate: Crewmate) -> bool:
	if station_controller == null:
		return false

	return station_controller.detach_crewmate(crewmate)


func clear_requested_station(crewmate: Crewmate) -> void:
	if crewmate == null:
		return

	var station = requested_station_by_crewmate.get(crewmate)

	if station != null:
		crewmate_by_requested_station.erase(station)

	requested_station_by_crewmate.erase(crewmate)
	crewmate.requested_station = null


func set_requested_station(
	crewmate: Crewmate,
	station: StationPoint
) -> bool:

	if (
		crewmate == null
		or station == null
	):
		return false

	var requesting_crewmate = crewmate_by_requested_station.get(station)

	if (
		requesting_crewmate != null
		and requesting_crewmate != crewmate
	):
		return false

	clear_requested_station(crewmate)

	requested_station_by_crewmate[crewmate] = station
	crewmate_by_requested_station[station] = crewmate
	crewmate.requested_station = station

	return true


func get_requested_station(crewmate: Crewmate) -> StationPoint:

	if crewmate == null:
		return null

	return requested_station_by_crewmate.get(crewmate)


func get_station_requester(station: StationPoint) -> Crewmate:

	if station == null:
		return null

	return crewmate_by_requested_station.get(station)


func is_station_requested_by_other(
	station: StationPoint,
	crewmate: Crewmate
) -> bool:

	var requesting_crewmate = get_station_requester(station)

	return (
		requesting_crewmate != null
		and requesting_crewmate != crewmate
	)


func cancel_plan_and_clear_station_request(
	crewmate: Crewmate,
	cancel_plan: bool
) -> void:

	if crewmate == null:
		return

	clear_manual_bail(crewmate)
	clear_requested_station(crewmate)

	if cancel_plan and crewmate.action_executor != null:
		crewmate.action_executor.cancel_plan()


func clear_station_and_actions(crewmate: Crewmate) -> void:
	if crewmate == null:
		return

	clear_manual_bail(crewmate)
	clear_requested_station(crewmate)

	if crewmate.action_executor != null:
		crewmate.action_executor.cancel_plan()

	clear_station(crewmate)


func clear_manual_bail(crewmate: Crewmate) -> void:

	if crewmate == null:
		return

	manual_bail_modes.erase(crewmate)
	_disconnect_manual_bail_listener(crewmate)


func _connect_manual_bail_listener(crewmate: Crewmate) -> void:

	if (
		crewmate == null
		or crewmate.action_executor == null
	):
		return

	var handler: Callable

	if manual_bail_handlers.has(crewmate):
		handler = manual_bail_handlers[crewmate]
	else:
		handler = Callable(
			self,
			"_on_manual_bail_queue_finished"
		).bind(crewmate)
		manual_bail_handlers[crewmate] = handler

	if not crewmate.action_executor.queue_finished.is_connected(handler):
		crewmate.action_executor.queue_finished.connect(handler)


func _disconnect_manual_bail_listener(crewmate: Crewmate) -> void:

	if (
		crewmate == null
		or crewmate.action_executor == null
		or not manual_bail_handlers.has(crewmate)
	):
		return

	var handler: Callable = manual_bail_handlers[crewmate]

	if crewmate.action_executor.queue_finished.is_connected(handler):
		crewmate.action_executor.queue_finished.disconnect(handler)

	manual_bail_handlers.erase(crewmate)


func _on_manual_bail_queue_finished(crewmate: Crewmate) -> void:

	if (
		crewmate == null
		or action_planner == null
		or not manual_bail_modes.has(crewmate)
	):
		return

	if (
		crewmate.action_executor != null
		and crewmate.action_executor.has_actions()
	):
		return

	if _crewmate_has_incompatible_duty(crewmate):
		clear_manual_bail(crewmate)
		return

	var drain_to_zero: bool = manual_bail_modes.get(
		crewmate,
		false
	)
	var next_actions = action_planner.build_bail_water(
		crewmate,
		drain_to_zero
	)

	if next_actions.is_empty():
		clear_manual_bail(crewmate)
		return

	clear_requested_station(crewmate)
	crewmate.action_executor.queue_actions(next_actions)


func _crewmate_has_incompatible_duty(crewmate: Crewmate) -> bool:

	return (
		(
			repair_duty_controller != null
			and repair_duty_controller.is_repair_duty_crewmate(crewmate)
		)
		or (
			cannon_duty_controller != null
			and cannon_duty_controller.is_duty_crewmate(crewmate)
		)
	)


func _get_current_crewmate() -> Crewmate:

	if crew_controller == null:
		return null

	return crew_controller.get_current_crewmate()
