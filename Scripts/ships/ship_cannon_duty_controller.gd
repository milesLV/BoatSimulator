class_name ShipCannonDutyController
extends RefCounted

var ship: Node2D
var action_points: ShipActionPointContainer
var station_controller: ShipStationController
var action_planner: ShipActionPlanner
var cannon_director: ShipCannonDirector
var cannon_stations: Array[CannonStationPoint] = []
var crew_task_controller: ShipCrewTaskController

var duty_crewmate: Crewmate = null


func _init(
	new_ship: Node2D,
	new_action_points: ShipActionPointContainer,
	new_station_controller: ShipStationController,
	new_action_planner: ShipActionPlanner,
	new_cannon_director: ShipCannonDirector
) -> void:

	ship = new_ship
	action_points = new_action_points
	station_controller = new_station_controller
	action_planner = new_action_planner
	cannon_director = new_cannon_director

	if action_points != null:
		cannon_stations = action_points.get_cannon_stations()


func set_task_controller(new_crew_task_controller: ShipCrewTaskController) -> void:

	crew_task_controller = new_crew_task_controller


func has_duty_crewmate() -> bool:

	return (
		duty_crewmate != null
		and is_instance_valid(duty_crewmate)
	)


func is_duty_crewmate(crewmate: Crewmate) -> bool:

	return (
		has_duty_crewmate()
		and duty_crewmate == crewmate
	)


func assign_crewmate(crewmate: Crewmate) -> bool:

	if crewmate == null:
		return false

	if duty_crewmate == crewmate:
		return true

	clear_assignment()
	duty_crewmate = crewmate

	return true


func request_crewmate_to_active_broadside(crewmate: Crewmate) -> bool:

	if crewmate == null:
		return false

	if _get_current_cannon_station(
		crewmate
	) != null:
		return false

	var active_broadside = cannon_director.get_active_broadside()

	if active_broadside == -1:
		ShipDebugLog.cannon("no cannons on the active broadside!")
		return false

	var station = _get_best_unoccupied_station_for_broadside(
		active_broadside,
		crewmate
	)

	if station == null:
		ShipDebugLog.cannon("no cannons on the active broadside!")
		return false

	if duty_crewmate != crewmate:
		clear_assignment()
		duty_crewmate = crewmate

	_move_to_station(station)

	return true


func clear_assignment() -> bool:

	if not has_duty_crewmate():
		duty_crewmate = null
		return false

	var previous_crewmate = duty_crewmate

	duty_crewmate = null

	_clear_crewmate_state(previous_crewmate)

	return true


func update() -> void:

	if not has_duty_crewmate():
		return

	var active_broadside = cannon_director.get_active_broadside()

	if active_broadside == -1:
		return

	var desired_station = _get_best_station_for_broadside(active_broadside)

	if desired_station == null:
		return

	var current_station = station_controller.get_station_operated_by(duty_crewmate)

	if current_station == desired_station:
		_queue_cannon_cycle_if_idle(desired_station)
		return

	if _get_requested_station(duty_crewmate) == desired_station:
		return

	_move_to_station(desired_station)


func _move_to_station(station: CannonStationPoint) -> void:

	if (
		station == null
		or duty_crewmate == null
		or duty_crewmate.action_executor == null
	):
		return

	var actions = action_planner.build_cannon_station_actions(
		duty_crewmate,
		station
	)

	if actions.is_empty():
		return

	_clear_crewmate_state(duty_crewmate)
	crew_task_controller.queue_cannon_station_actions(
		duty_crewmate,
		station,
		actions
	)


func _queue_cannon_cycle_if_idle(station: CannonStationPoint) -> void:

	if (
		station == null
		or duty_crewmate == null
		or duty_crewmate.action_executor == null
	):
		return

	if duty_crewmate.action_executor.has_actions():
		return

	var cannon = station.get_cannon(ship)

	if cannon == null:
		return

	if not cannon.is_loaded():
		_queue_cannon_action(ReloadCannonAction.new(station))
		return

	if cannon.can_fire_now():
		_queue_cannon_action(FireCannonAction.new(station))


func _get_best_station_for_broadside(broadside: int) -> CannonStationPoint:

	return _get_best_cannon_station_for_broadside(
		broadside,
		null,
		false
	)


func _get_best_unoccupied_station_for_broadside(
	broadside: int,
	requesting_crewmate: Crewmate
) -> CannonStationPoint:

	return _get_best_cannon_station_for_broadside(
		broadside,
		requesting_crewmate,
		true
	)


func _get_best_cannon_station_for_broadside(
	broadside: int,
	requesting_crewmate: Crewmate,
	require_unoccupied: bool
) -> CannonStationPoint:

	var target_ship = cannon_director.get_target_ship()

	if target_ship == null:
		return null

	var best_station: CannonStationPoint = null
	var best_distance := INF

	for station in cannon_stations:

		if station.broadside != broadside:
			continue

		if (
			require_unoccupied
			and not _station_unoccupied(
				station,
				requesting_crewmate
			)
		):
			continue

		if (
			not require_unoccupied
			and not _station_available_for(station)
		):
			continue

		var cannon = station.get_cannon(ship)

		if cannon == null:
			continue

		var distance = cannon.global_position.distance_to(target_ship.global_position)

		if distance < best_distance:
			best_distance = distance
			best_station = station

	return best_station


func _get_current_cannon_station(crewmate: Crewmate) -> CannonStationPoint:

	var station = station_controller.get_station_operated_by(crewmate)

	if station is CannonStationPoint:
		return station

	return null


func _station_available_for(station: CannonStationPoint) -> bool:

	var operator = station_controller.get_operator(station)

	if (
		operator != null
		and operator != duty_crewmate
	):
		return false

	var requesting_crewmate = _get_station_requester(station)

	if (
		requesting_crewmate != null
		and requesting_crewmate != duty_crewmate
	):
		return false

	return true


func _station_unoccupied(
	station: CannonStationPoint,
	requesting_crewmate: Crewmate
) -> bool:

	if station_controller.has_operator(
		station
	):
		return false

	var station_requester = _get_station_requester(station)

	if (
		station_requester != null
		and station_requester != requesting_crewmate
	):
		return false

	return true


func _queue_cannon_action(action: ActionDefinition) -> void:

	if duty_crewmate == null:
		return

	crew_task_controller.queue_cannon_action(
		duty_crewmate,
		action
	)


func _get_requested_station(crewmate: Crewmate) -> StationPoint:

	if crewmate != null:
		return crew_task_controller.get_requested_station(crewmate)

	return null


func _get_station_requester(station: StationPoint) -> Crewmate:

	return crew_task_controller.get_station_requester(station)


func _clear_crewmate_state(crewmate: Crewmate) -> void:

	if crewmate == null:
		return

	crew_task_controller.clear_station_and_actions(crewmate)
