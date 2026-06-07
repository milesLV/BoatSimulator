class_name ShipCrewCommandController
extends RefCounted

var crew_controller: ShipCrewController
var action_planner: ShipActionPlanner
var station_controller: ShipStationController
var cannon_duty_controller: ShipCannonDutyController
var repair_duty_controller: ShipRepairDutyController
var anchor_system: AnchorSystem
var crew_task_controller: ShipCrewTaskController


func _init(
	new_crew_controller: ShipCrewController,
	new_action_planner: ShipActionPlanner,
	new_station_controller: ShipStationController,
	new_cannon_duty_controller: ShipCannonDutyController,
	new_repair_duty_controller: ShipRepairDutyController,
	new_anchor_system: AnchorSystem,
	new_crew_task_controller: ShipCrewTaskController
) -> void:

	crew_controller = new_crew_controller
	action_planner = new_action_planner
	station_controller = new_station_controller
	cannon_duty_controller = new_cannon_duty_controller
	repair_duty_controller = new_repair_duty_controller
	anchor_system = new_anchor_system
	crew_task_controller = new_crew_task_controller


func request_station_control(
	station_name: StringName,
	requested_input: float
) -> bool:

	if station_controller == null:
		return false

	var crewmate = _get_current_crewmate()

	if crewmate == null:
		return false

	if requested_input == 0.0:
		return station_controller.request_station_control(
			crewmate,
			station_name,
			requested_input
		)

	if crew_task_controller != null:
		crew_task_controller.prepare_for_station_control(
			crewmate,
			"station control input for %s"
			% station_name
		)

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

	var actions = action_planner.build_drop_anchor(crewmate)

	return _queue_crewmate_actions(
		crewmate,
		actions
	)


func request_anchor_raise() -> bool:

	var crewmate = _get_current_crewmate()

	if (
		crewmate == null
		or action_planner == null
	):
		return false

	var actions = action_planner.build_raise_anchor(crewmate)

	return _queue_crewmate_actions(
		crewmate,
		actions
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

	var actions = action_planner.build_bail_water(crewmate)

	return _queue_crewmate_actions(
		crewmate,
		actions
	)


func request_repair_ship() -> bool:

	var crewmate = _get_current_crewmate()

	if (
		crewmate == null
		or repair_duty_controller == null
	):
		return false

	if crew_task_controller != null:
		crew_task_controller.prepare_for_repair_duty(crewmate)
	else:
		_clear_cannon_duty_for_crewmate(crewmate)

		if station_controller != null:
			station_controller.detach_crewmate(crewmate)

		crewmate.requested_station = null

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

	if crew_task_controller != null:
		crew_task_controller.prepare_for_cannon_duty(
			crewmate,
			"cannon duty request"
		)
	else:
		_clear_repair_duty_for_crewmate(
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

	if crew_task_controller != null:
		crew_task_controller.prepare_for_cannon_duty(
			crewmate,
			"cannon duty assignment"
		)
	else:
		_clear_repair_duty_for_crewmate(
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

	if crew_task_controller != null:
		if crew_task_controller.cancel_crewmate_action(
			crewmate
		):
			return true
	else:
		if (
			cannon_duty_controller != null
			and cannon_duty_controller.is_duty_crewmate(crewmate)
		):
			var cleared_duty = cannon_duty_controller.clear_assignment()

			if cleared_duty:
				return true

		crewmate.requested_station = null
		_clear_repair_duty_for_crewmate(
			crewmate,
			"cancel action"
		)

		if (
			crewmate.action_executor != null
			and crewmate.action_executor.has_actions()
		):
			crewmate.action_executor.cancel_plan()

			if station_controller != null:
				station_controller.detach_crewmate(crewmate)

			return true

		if station_controller != null:
			var detached = station_controller.detach_crewmate(crewmate)

			if detached:
				return true

	return _request_passive_decay_cancel()


func _queue_crewmate_actions(
	crewmate: Crewmate,
	actions: Array
) -> bool:

	if (
		crewmate == null
		or actions.is_empty()
	):
		return false

	if crew_task_controller != null:
		return crew_task_controller.queue_manual_actions(
			crewmate,
			actions,
			"new crew action"
		)

	_clear_repair_duty_for_crewmate(
		crewmate,
		"new crew action"
	)
	_clear_cannon_duty_for_crewmate(crewmate)

	crewmate.requested_station = null
	crewmate.action_executor.cancel_plan()
	crewmate.action_executor.queue_actions(actions)

	return true


func _request_passive_decay_cancel() -> bool:

	if (
		anchor_system != null
		and anchor_system.is_passive_decay_active()
	):
		return request_anchor_raise()

	return false


func _clear_cannon_duty_for_crewmate(crewmate: Crewmate) -> void:

	if (
		crewmate == null
		or cannon_duty_controller == null
		or not cannon_duty_controller.is_duty_crewmate(crewmate)
	):
		return

	cannon_duty_controller.clear_assignment()


func _clear_repair_duty_for_crewmate(
	crewmate: Crewmate,
	reason := "crew command"
) -> void:

	if repair_duty_controller == null:
		return

	repair_duty_controller.clear_crewmate(
		crewmate,
		reason
	)


func _get_current_crewmate() -> Crewmate:

	if crew_controller == null:
		return null

	return crew_controller.get_current_crewmate()
