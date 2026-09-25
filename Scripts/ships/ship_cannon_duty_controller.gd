class_name ShipCannonDutyController
extends RefCounted

var ship: Sloop

var duty_crewmate: Crewmate = null


func _init(new_ship: Sloop) -> void:

	ship = new_ship


func has_duty_crewmate() -> bool:

	return is_instance_valid(duty_crewmate)


func is_duty_crewmate(crewmate: Crewmate) -> bool:

	return duty_crewmate == crewmate


func assign_crewmate(crewmate: Crewmate) -> void:

	if duty_crewmate != crewmate:
		clear_assignment()
		duty_crewmate = crewmate


func request_crewmate_to_active_broadside(crewmate: Crewmate) -> bool:

	if ship.station_controller.get_station_operated_by(crewmate) is CannonStationPoint:
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

	ship.crew_task_controller.clear_station_and_actions(previous_crewmate)

	return true


## A gun nobody has started on yet reads as a whole reload away.
func get_reload_remaining(cannon: Cannon) -> float:

	if cannon.loaded:
		return 0.0

	var instance = duty_crewmate.action_executor.current_action if has_duty_crewmate() else null

	if instance != null and instance.definition is ReloadCannonAction and instance.definition.point.cannon == cannon:
		return instance.get_remaining_time(duty_crewmate)

	return ReloadCannonAction.RELOAD_DURATION


func update() -> void:

	if not has_duty_crewmate():
		return

	var desired_station = _get_best_station()

	if desired_station == null:
		return

	if ship.station_controller.get_station_operated_by(duty_crewmate) == desired_station:
		_queue_cannon_cycle_if_idle(desired_station)
		return

	if ship.crew_task_controller.get_station_requester(desired_station) == duty_crewmate:
		return

	_move_to_station(desired_station)


func _move_to_station(station: CannonStationPoint) -> void:

	var actions = ship.action_planner.build_at(duty_crewmate, station, [ClaimStationAction.new(station)])

	if actions.is_empty():
		return

	ship.crew_task_controller.queue_station_request(duty_crewmate, station, actions)


func _queue_cannon_cycle_if_idle(station: CannonStationPoint) -> void:

	if duty_crewmate.action_executor.has_actions():
		return

	var cannon = station.cannon

	if not cannon.loaded:
		duty_crewmate.action_executor.queue_actions([ReloadCannonAction.new(station)])
		return

	if cannon.can_fire_now():
		duty_crewmate.action_executor.queue_actions([FireCannonAction.new(station)])


## A fresh order needs an empty station; otherwise the duty crewmate may keep the one they hold.
func _get_best_station(new_crewmate: Crewmate = null) -> CannonStationPoint:

	var target_ship = ship.cannon_director.get_target_ship()

	if target_ship == null:
		return null

	var allowed_crewmate = new_crewmate if new_crewmate != null else duty_crewmate
	var best_station: CannonStationPoint = null
	var best_distance := INF

	for station in ship.action_points.cannon_stations:
		var operator = ship.station_controller.get_operator(station)

		if (
			station.broadside != ship.cannon_director.active_broadside
			or (operator != null and (new_crewmate != null or operator != duty_crewmate))
			or ship.crew_task_controller.get_station_requester(station) not in [null, allowed_crewmate]
		):
			continue

		var distance = station.cannon.global_position.distance_to(target_ship.global_position)

		if distance < best_distance:
			best_distance = distance
			best_station = station

	return best_station
