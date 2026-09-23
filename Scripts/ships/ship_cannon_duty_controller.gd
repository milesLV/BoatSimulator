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
		cannon_stations = action_points.cannon_stations


func has_duty_crewmate() -> bool:

	return duty_crewmate != null and is_instance_valid(duty_crewmate)


func is_duty_crewmate(crewmate: Crewmate) -> bool:

	return has_duty_crewmate() and duty_crewmate == crewmate


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

	if station_controller.get_station_operated_by(crewmate) is CannonStationPoint:
		return false

	var active_broadside = cannon_director.active_broadside
	var station = _get_best_cannon_station_for_broadside(
		active_broadside,
		crewmate,
		true
	) if active_broadside != -1 else null

	if station == null:
		ShipDebugLog.write(&"cannon", "no free cannon on the active broadside!")
		return false

	assign_crewmate(crewmate)
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


## Seconds until [param cannon] is loaded again, taken from the gunner actually reloading it.
## A gun nobody has started on yet reads as a whole reload away: when the gunner gets there
## is the route planner's business, not the gun's.
func get_reload_remaining(cannon: Cannon) -> float:

	if cannon.loaded:
		return 0.0

	var instance = (
		duty_crewmate.action_executor.current_action
		if has_duty_crewmate() and duty_crewmate.action_executor != null
		else null
	)

	if (
		instance == null
		or not (instance.definition is ReloadCannonAction)
		or instance.definition.station.get_cannon(ship) != cannon
	):
		return ReloadCannonAction.RELOAD_DURATION

	return instance.get_remaining_time(duty_crewmate)


func update() -> void:

	if not has_duty_crewmate():
		return

	var active_broadside = cannon_director.active_broadside

	if active_broadside == -1:
		return

	var desired_station = _get_best_cannon_station_for_broadside(active_broadside, null, false)

	if desired_station == null:
		return

	var current_station = station_controller.get_station_operated_by(duty_crewmate)

	if current_station == desired_station:
		_queue_cannon_cycle_if_idle(desired_station)
		return

	if crew_task_controller.get_requested_station(duty_crewmate) == desired_station:
		return

	_move_to_station(desired_station)


func _move_to_station(station: CannonStationPoint) -> void:

	if station == null or duty_crewmate == null or duty_crewmate.action_executor == null:
		return

	var actions = action_planner.build_go_to_station(
		duty_crewmate,
		station,
		ClaimStationAction.new(station)
	)

	if actions.is_empty():
		return

	_clear_crewmate_state(duty_crewmate)
	crew_task_controller.queue_station_request(duty_crewmate, station, actions)


func _queue_cannon_cycle_if_idle(station: CannonStationPoint) -> void:

	if station == null or duty_crewmate == null or duty_crewmate.action_executor == null:
		return

	if duty_crewmate.action_executor.has_actions():
		return

	var cannon = station.get_cannon(ship)

	if cannon == null:
		return

	if not cannon.loaded:
		duty_crewmate.action_executor.queue_actions([ReloadCannonAction.new(station)])
		return

	if cannon.can_fire_now():
		duty_crewmate.action_executor.queue_actions([FireCannonAction.new(station)])


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

		if not _station_free_for(station, requesting_crewmate, require_unoccupied):
			continue

		var cannon = station.get_cannon(ship)

		if cannon == null:
			continue

		var distance = cannon.global_position.distance_to(target_ship.global_position)

		if distance < best_distance:
			best_distance = distance
			best_station = station

	return best_station


## Free for [param crewmate]. [param require_empty] also rejects a station the
## crewmate is already operating, so a fresh order actually moves them.
func _station_free_for(
	station: CannonStationPoint,
	crewmate: Crewmate,
	require_empty: bool
) -> bool:

	var operator = station_controller.get_operator(station)

	if operator != null and (require_empty or operator != duty_crewmate):
		return false

	var requester = crew_task_controller.get_station_requester(station)
	var allowed_requester = crewmate if require_empty else duty_crewmate

	return requester == null or requester == allowed_requester


func _clear_crewmate_state(crewmate: Crewmate) -> void:

	if crewmate == null:
		return

	crew_task_controller.clear_station_and_actions(crewmate)
