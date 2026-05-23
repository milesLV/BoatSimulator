extends ActionDefinition
class_name ClaimStationAction

var station: StationPoint


func _init(
	new_station: StationPoint
) -> void:

	station = new_station
	action_point = station
	action_id = (
		"claim_%s"
		% _get_station_name()
	)
	action_location = _get_station_name()
	base_duration = 0.0
	progress_policy = ProgressPolicy.ONE_SHOT


func on_start(actor, _instance) -> void:

	if (
		station == null
		or actor == null
		or actor.ship == null
		or actor.ship.station_controller == null
	):
		return

	var current_station = actor.ship.station_controller.get_station_operated_by(
		actor
	)

	if (
		current_station != null
		and current_station != station
	):
		actor.ship.station_controller.clear_operator(
			current_station
		)

	actor.ship.station_controller.set_operator(
		station,
		actor
	)
	actor.requested_station = null


func _get_station_name() -> String:

	if station == null:
		return ""

	return String(
		station.name
	)
