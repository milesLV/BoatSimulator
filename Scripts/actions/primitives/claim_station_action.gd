extends ActionDefinition
class_name ClaimStationAction

var station: StationPoint


func _init(new_station: StationPoint) -> void:

	station = new_station
	action_id = "claim_%s" % (String(station.name) if station != null else "")
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

	var current_station = actor.ship.station_controller.get_station_operated_by(actor)

	if current_station != null and current_station != station:
		actor.ship.station_controller.clear_operator(current_station)

	actor.ship.station_controller.set_operator(station, actor)

	actor.ship.crew_task_controller.clear_requested_station(actor)
