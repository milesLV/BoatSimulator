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


func get_operator(station: StationPoint) -> Crewmate:

	return station_operators.get(station)


func get_operator_by_name(station_name: StringName) -> Crewmate:

	return get_operator(action_points.get_station(station_name))


func get_station_operated_by(crewmate: Crewmate) -> StationPoint:

	return crewmate_stations.get(crewmate)


func set_operator(station: StationPoint, crewmate: Crewmate) -> void:

	# the two maps mirror each other, so unhook both old pairings before making the new one
	crewmate_stations.erase(station_operators.get(station))
	station_operators.erase(crewmate_stations.get(crewmate))
	station_operators[station] = crewmate
	crewmate_stations[crewmate] = station

	crew_task_controller.clear_requested_station(crewmate)


func clear_operator(station: StationPoint) -> void:

	crewmate_stations.erase(station_operators.get(station))
	station_operators.erase(station)


func detach_crewmate(crewmate: Crewmate) -> bool:

	station_operators.erase(crewmate_stations.get(crewmate))

	return crewmate_stations.erase(crewmate)


func request_station_control(
	crewmate: Crewmate,
	station_name: StringName,
	requested_input: float
) -> bool:

	var station = action_points.get_station(station_name)
	var operator = get_operator(station)

	if operator != null:
		if operator == crewmate and requested_input != 0.0:
			crew_task_controller.clear_cannon_duty(crewmate)

		return operator == crewmate

	# already on the way, or someone else is
	if requested_input == 0.0 or crew_task_controller.get_station_requester(station) != null:
		return false

	var actions = action_planner.build_go_to_station(
		crewmate,
		station,
		HoldStationAction.new(station)
	)

	if actions.is_empty():
		return false

	crew_task_controller.clear_cannon_duty(crewmate)
	crew_task_controller.queue_station_request(
		crewmate, station, actions, "station control input for %s" % station_name
	)

	return false
