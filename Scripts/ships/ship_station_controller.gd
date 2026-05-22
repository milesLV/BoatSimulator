class_name ShipStationController
extends RefCounted

var action_points: ShipActionPointContainer
var action_planner: ShipActionPlanner
var station_operators := {}


func _init(
	new_action_points: ShipActionPointContainer,
	new_action_planner: ShipActionPlanner
) -> void:

	action_points = new_action_points
	action_planner = new_action_planner


func get_station(
	station_name: StringName
) -> StationPoint:

	return action_points.get_station(
		station_name
	)


func has_operator(
	station: StationPoint
) -> bool:

	return (
		station != null
		and station_operators.has(station)
	)


func get_operator(
	station: StationPoint
) -> Crewmate:

	if station == null:
		return null

	return station_operators.get(station)


func get_operator_by_name(
	station_name: StringName
) -> Crewmate:

	return get_operator(
		get_station(
			station_name
		)
	)


func get_station_operated_by(
	crewmate: Crewmate
) -> StationPoint:

	if crewmate == null:
		return null

	for station in station_operators.keys():

		if station_operators[station] == crewmate:
			return station

	return null


func set_operator(
	station: StationPoint,
	crewmate: Crewmate
) -> void:

	if station == null:
		return

	station_operators[station] = crewmate


func clear_operator(
	station: StationPoint
) -> void:

	if station == null:
		return

	station_operators.erase(station)


func cancel_station_request(
	crewmate: Crewmate
) -> void:

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

	var station = get_station(
		station_name
	)

	if station == null:
		return false

	var operator = get_operator(
		station
	)

	if operator != null:
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

	cancel_station_request(
		crewmate
	)

	crewmate.requested_station = station
	crewmate.action_executor.queue_actions(
		actions
	)

	return false
