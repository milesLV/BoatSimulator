class_name ShipCrewTaskController
extends RefCounted

var station_controller: ShipStationController
var cannon_duty_controller: ShipCannonDutyController
var repair_duty_controller: ShipRepairDutyController


func _init(
	new_station_controller: ShipStationController,
	new_cannon_duty_controller: ShipCannonDutyController,
	new_repair_duty_controller: ShipRepairDutyController
) -> void:

	station_controller = new_station_controller
	cannon_duty_controller = new_cannon_duty_controller
	repair_duty_controller = new_repair_duty_controller


func prepare_for_station_control(
	crewmate: Crewmate,
	reason: String
) -> void:

	clear_repair_duty(crewmate, reason)


func prepare_for_manual_action(
	crewmate: Crewmate,
	reason: String
) -> void:

	clear_repair_duty(crewmate, reason)
	clear_cannon_duty(crewmate)
	clear_requested_station(crewmate)


func prepare_for_repair_duty(crewmate: Crewmate) -> void:
	clear_cannon_duty(crewmate)
	clear_station(crewmate)
	clear_requested_station(crewmate)


func prepare_for_cannon_duty(
	crewmate: Crewmate,
	reason: String
) -> void:

	clear_repair_duty(crewmate, reason)


func cancel_crewmate_action(crewmate: Crewmate) -> bool:
	if crewmate == null:
		return false

	if clear_cannon_duty(crewmate):
		return true

	clear_requested_station(crewmate)
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
	if crewmate != null:
		crewmate.requested_station = null


func cancel_plan_and_clear_station_request(
	crewmate: Crewmate,
	cancel_plan: bool
) -> void:

	if crewmate == null:
		return

	clear_requested_station(crewmate)

	if cancel_plan and crewmate.action_executor != null:
		crewmate.action_executor.cancel_plan()


func clear_station_and_actions(crewmate: Crewmate) -> void:
	if crewmate == null:
		return

	clear_requested_station(crewmate)

	if crewmate.action_executor != null:
		crewmate.action_executor.cancel_plan()

	clear_station(crewmate)
