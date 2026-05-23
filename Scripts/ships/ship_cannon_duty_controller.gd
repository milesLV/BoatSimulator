class_name ShipCannonDutyController
extends RefCounted

var ship: Node2D
var action_points: ShipActionPointContainer
var station_controller: ShipStationController
var action_planner: ShipActionPlanner
var cannon_director: ShipCannonDirector
var cannon_stations: Array[CannonStationPoint] = []

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


func has_duty_crewmate() -> bool:

	return (
		duty_crewmate != null
		and is_instance_valid(
			duty_crewmate
		)
	)


func is_duty_crewmate(
	crewmate: Crewmate
) -> bool:

	return (
		has_duty_crewmate()
		and duty_crewmate == crewmate
	)


func assign_crewmate(
	crewmate: Crewmate
) -> bool:

	if crewmate == null:
		return false

	if duty_crewmate == crewmate:
		return true

	clear_assignment()
	duty_crewmate = crewmate

	return true


func clear_assignment() -> bool:

	if not has_duty_crewmate():
		duty_crewmate = null
		return false

	var previous_crewmate = duty_crewmate

	duty_crewmate = null

	_clear_crewmate_state(
		previous_crewmate
	)

	return true


func update() -> void:

	if not has_duty_crewmate():
		return

	var active_broadside = cannon_director.get_active_broadside()

	if active_broadside == -1:
		return

	var desired_station = _get_best_station_for_broadside(
		active_broadside
	)

	if desired_station == null:
		return

	var current_station = station_controller.get_station_operated_by(
		duty_crewmate
	)

	if current_station == desired_station:
		_queue_cannon_cycle_if_idle(
			desired_station
		)
		return

	if duty_crewmate.requested_station == desired_station:
		return

	_move_to_station(
		desired_station
	)


func _move_to_station(
	station: CannonStationPoint
) -> void:

	if (
		station == null
		or duty_crewmate == null
		or duty_crewmate.action_executor == null
	):
		return

	_clear_crewmate_state(
		duty_crewmate
	)

	var actions = action_planner.build_cannon_station_actions(
		duty_crewmate,
		station
	)

	if actions.is_empty():
		return

	duty_crewmate.requested_station = station
	duty_crewmate.action_executor.queue_actions(
		actions
	)


func _queue_cannon_cycle_if_idle(
	station: CannonStationPoint
) -> void:

	if (
		station == null
		or duty_crewmate == null
		or duty_crewmate.action_executor == null
	):
		return

	if duty_crewmate.action_executor.has_actions():
		return

	var cannon = station.get_cannon(
		ship
	)

	if cannon == null:
		return

	if not cannon.is_loaded():
		duty_crewmate.action_executor.queue_action(
			ReloadCannonAction.new(
				station
			)
		)
		return

	if cannon.can_fire_now():
		duty_crewmate.action_executor.queue_action(
			FireCannonAction.new(
				station
			)
		)


func _get_best_station_for_broadside(
	broadside: int
) -> CannonStationPoint:

	var target_ship = cannon_director.get_target_ship()

	if target_ship == null:
		return null

	var best_station: CannonStationPoint = null
	var best_distance := INF

	for station in cannon_stations:

		if station.broadside != broadside:
			continue

		var cannon = station.get_cannon(
			ship
		)

		if cannon == null:
			continue

		var distance = cannon.global_position.distance_to(
			target_ship.global_position
		)

		if distance < best_distance:
			best_distance = distance
			best_station = station

	return best_station


func _clear_crewmate_state(
	crewmate: Crewmate
) -> void:

	if crewmate == null:
		return

	crewmate.requested_station = null

	if crewmate.action_executor != null:
		crewmate.action_executor.cancel_plan()

	if station_controller != null:
		station_controller.detach_crewmate(
			crewmate
		)
