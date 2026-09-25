class_name ShipStationController
extends RefCounted

var ship: Sloop
var station_operators := {}


func _init(new_ship: Sloop) -> void:

	ship = new_ship


func get_operator(station: StationPoint) -> Crewmate:

	return station_operators.get(station)


func get_operator_by_name(station_name: StringName) -> Crewmate:

	return get_operator(ship.action_points.get_station(station_name))


func get_station_operated_by(crewmate: Crewmate) -> StationPoint:

	return station_operators.find_key(crewmate)


func set_operator(station: StationPoint, crewmate: Crewmate) -> void:

	station_operators.erase(station_operators.find_key(crewmate))
	station_operators[station] = crewmate

	ship.crew_task_controller.clear_requested_station(crewmate)


func detach_crewmate(crewmate: Crewmate) -> bool:

	return station_operators.erase(station_operators.find_key(crewmate))


func request_station_control(
	crewmate: Crewmate,
	station_name: StringName,
	requested_input: float
) -> bool:

	var station = ship.action_points.get_station(station_name)
	var operator = get_operator(station)

	if operator != null:
		if operator == crewmate and requested_input != 0.0:
			ship.crew_task_controller.clear_cannon_duty(crewmate)

		return operator == crewmate

	if requested_input == 0.0 or ship.crew_task_controller.get_station_requester(station) != null:
		return false

	var actions = ship.action_planner.build_at(crewmate, station, [HoldStationAction.new(station)])

	if actions.is_empty():
		return false

	ship.crew_task_controller.clear_cannon_duty(crewmate)
	ship.crew_task_controller.queue_station_request(
		crewmate, station, actions, "station control input for %s" % station_name
	)

	return false
