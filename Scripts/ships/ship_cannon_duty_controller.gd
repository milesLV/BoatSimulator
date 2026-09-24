class_name ShipCannonDutyController
extends RefCounted

var station_controller: ShipStationController
var action_planner: ShipActionPlanner
var cannon_director: ShipCannonDirector
var cannon_stations: Array[CannonStationPoint] = []
var crew_task_controller: ShipCrewTaskController

var duty_crewmate: Crewmate = null


func _init(
	new_action_points: ShipActionPointContainer,
	new_station_controller: ShipStationController,
	new_action_planner: ShipActionPlanner,
	new_cannon_director: ShipCannonDirector
) -> void:

	station_controller = new_station_controller
	action_planner = new_action_planner
	cannon_director = new_cannon_director
	cannon_stations = new_action_points.cannon_stations


func has_duty_crewmate() -> bool:

	return is_instance_valid(duty_crewmate)


func is_duty_crewmate(crewmate: Crewmate) -> bool:

	return duty_crewmate == crewmate


func assign_crewmate(crewmate: Crewmate) -> bool:

	if duty_crewmate != crewmate:
		clear_assignment()
		duty_crewmate = crewmate

	return true


func request_crewmate_to_active_broadside(crewmate: Crewmate) -> bool:

	if station_controller.get_station_operated_by(crewmate) is CannonStationPoint:
		return false

	var station = _get_best_station(crewmate)

	if station == null:
		ShipDebugLog.write(&"cannon", "no free cannon on the active broadside!")
		return false

	assign_crewmate(crewmate)
	_move_to_station(station)

	return true


func clear_assignment() -> bool:

	var previous_crewmate = duty_crewmate

	duty_crewmate = null

	if not is_instance_valid(previous_crewmate):
		return false

	crew_task_controller.clear_station_and_actions(previous_crewmate)

	return true


## Seconds until [param cannon] is loaded again, taken from the gunner actually reloading it.
## A gun nobody has started on yet reads as a whole reload away: when the gunner gets there
## is the route planner's business, not the gun's.
func get_reload_remaining(cannon: Cannon) -> float:

	if cannon.loaded:
		return 0.0

	var instance = duty_crewmate.action_executor.current_action if has_duty_crewmate() else null

	if instance != null and instance.definition is ReloadCannonAction and instance.definition.station.cannon == cannon:
		return instance.get_remaining_time(duty_crewmate)

	return ReloadCannonAction.RELOAD_DURATION


func update() -> void:

	if not has_duty_crewmate():
		return

	var desired_station = _get_best_station()

	if desired_station == null:
		return

	if station_controller.get_station_operated_by(duty_crewmate) == desired_station:
		_queue_cannon_cycle_if_idle(desired_station)
		return

	if crew_task_controller.get_station_requester(desired_station) == duty_crewmate:
		return

	_move_to_station(desired_station)


func _move_to_station(station: CannonStationPoint) -> void:

	var actions = action_planner.build_go_to_station(
		duty_crewmate,
		station,
		ClaimStationAction.new(station)
	)

	if actions.is_empty():
		return

	crew_task_controller.clear_station_and_actions(duty_crewmate)
	crew_task_controller.queue_station_request(duty_crewmate, station, actions)


func _queue_cannon_cycle_if_idle(station: CannonStationPoint) -> void:

	if duty_crewmate.action_executor.has_actions():
		return

	var cannon = station.cannon

	if not cannon.loaded:
		duty_crewmate.action_executor.queue_actions([ReloadCannonAction.new(station)])
		return

	if cannon.can_fire_now():
		duty_crewmate.action_executor.queue_actions([FireCannonAction.new(station)])


## The free station on the active broadside nearest the target. [param new_crewmate] is a
## fresh order, so its station must be empty and the order actually moves them; without one,
## the duty crewmate may keep the station they hold or are walking to.
func _get_best_station(new_crewmate: Crewmate = null) -> CannonStationPoint:

	var target_ship = cannon_director.get_target_ship()

	if target_ship == null:
		return null

	var allowed_crewmate = new_crewmate if new_crewmate != null else duty_crewmate
	var best_station: CannonStationPoint = null
	var best_distance := INF

	for station in cannon_stations:
		var operator = station_controller.get_operator(station)

		if (
			station.broadside != cannon_director.active_broadside
			or (operator != null and (new_crewmate != null or operator != duty_crewmate))
			or crew_task_controller.get_station_requester(station) not in [null, allowed_crewmate]
		):
			continue

		var distance = station.cannon.global_position.distance_to(target_ship.global_position)

		if distance < best_distance:
			best_distance = distance
			best_station = station

	return best_station
