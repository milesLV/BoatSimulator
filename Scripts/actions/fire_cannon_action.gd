extends ActionDefinition
class_name FireCannonAction

var station: CannonStationPoint


func _init(new_station: CannonStationPoint) -> void:

	station = new_station
	action_point = station
	action_id = (
		"fire_%s"
		% _get_station_name()
	)
	action_location = _get_station_name()
	base_duration = 0.0
	progress_policy = ProgressPolicy.ONE_SHOT


func on_start(actor, _instance) -> void:

	var cannon = _get_cannon(actor)

	if cannon == null:
		return

	cannon.fire()


func _get_cannon(actor) -> Cannon:

	if station == null:
		return null

	var cannon = station.get_cannon_for_operator(actor)

	if cannon == null or not cannon.can_fire_now():
		return null

	return cannon


func _get_station_name() -> String:

	if station == null:
		return ""

	return String(
		station.name
	)
