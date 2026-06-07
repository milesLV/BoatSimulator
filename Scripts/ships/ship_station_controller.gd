class_name ShipStationController
extends RefCounted

var action_points: ShipActionPointContainer
var action_planner: ShipActionPlanner
var station_operators := {}
var crewmate_stations := {}
var crew_task_controller: ShipCrewTaskController


func _init(
	new_action_points: ShipActionPointContainer,
	new_action_planner: ShipActionPlanner
) -> void:

	action_points = new_action_points
	action_planner = new_action_planner


func set_task_controller(new_crew_task_controller: ShipCrewTaskController) -> void:

	crew_task_controller = new_crew_task_controller


func get_station(station_name: StringName) -> StationPoint:

	return action_points.get_station(
		station_name
	)


func has_operator(station: StationPoint) -> bool:

	return (
		station != null
		and station_operators.has(station)
	)


func get_operator(station: StationPoint) -> Crewmate:

	if station == null:
		return null

	return station_operators.get(station)


func get_operator_by_name(station_name: StringName) -> Crewmate:

	return get_operator(
		get_station(station_name)
	)


func get_station_operated_by(crewmate: Crewmate) -> StationPoint:

	if crewmate == null:
		return null

	return crewmate_stations.get(
		crewmate
	)


func set_operator(
	station: StationPoint,
	crewmate: Crewmate
) -> void:

	if (
		station == null
		or crewmate == null
	):
		return

	var current_operator = station_operators.get(station)

	if (
		current_operator != null
		and current_operator != crewmate
	):
		crewmate_stations.erase(current_operator)

	var previous_station = crewmate_stations.get(crewmate)

	if (
		previous_station != null
		and previous_station != station
	):
		station_operators.erase(previous_station)

	station_operators[station] = crewmate
	crewmate_stations[crewmate] = station


func clear_operator(station: StationPoint) -> void:

	if station == null:
		return

	var crewmate = station_operators.get(station)

	if (
		crewmate != null
		and crewmate_stations.get(
			crewmate
		) == station
	):
		crewmate_stations.erase(crewmate)

	station_operators.erase(station)


func detach_crewmate(crewmate: Crewmate) -> bool:

	var station = get_station_operated_by(crewmate)

	if station == null:
		return false

	clear_operator(station)

	return true


func cancel_station_request(crewmate: Crewmate) -> void:

	if crewmate == null:
		return

	crewmate.requested_station = null

	if crewmate.action_executor != null:
		crewmate.action_executor.cancel_plan()


func request_station_control(
	crewmate: Crewmate,
	station_name: StringName,
	requested_input: float
) -> bool:

	if crewmate == null:
		return false

	if (
		crewmate.ship != null
		and crewmate.ship.has_method("is_sunk")
		and crewmate.ship.is_sunk()
	):
		return false

	var station = get_station(station_name)

	if station == null:
		return false

	var operator = get_operator(station)

	if operator != null:
		if operator == crewmate:
			_clear_cannon_duty_for_station_control(
				crewmate,
				requested_input
			)

		return operator == crewmate

	if requested_input == 0.0:
		return false

	if crewmate.requested_station == station:
		return false

	var actions = action_planner.build_station_control(
		crewmate,
		station
	)

	if actions.is_empty():
		return false

	if crew_task_controller != null:
		crew_task_controller.prepare_for_station_control(
			crewmate,
			"station control input for %s"
			% station_name
		)

	_clear_cannon_duty_for_station_control(
		crewmate,
		requested_input
	)

	cancel_station_request(crewmate)

	crewmate.requested_station = station
	crewmate.action_executor.queue_actions(actions)

	return false


func _clear_cannon_duty_for_station_control(
	crewmate: Crewmate,
	requested_input: float
) -> void:

	if requested_input == 0.0:
		return

	if (
		crewmate == null
		or crewmate.ship == null
	):
		return

	if crew_task_controller != null:
		crew_task_controller.clear_cannon_duty(crewmate)
		return

	if (
		crewmate.ship.cannon_duty_controller == null
		or not crewmate.ship.cannon_duty_controller.is_duty_crewmate(crewmate)
	):
		return

	crewmate.ship.cannon_duty_controller.clear_assignment()
