extends ClaimStationAction
class_name HoldStationAction

## Same claim as [ClaimStationAction], but held open until something interrupts it.
func _init(new_station: StationPoint) -> void:

	super(new_station)
	action_id = "control_%s" % (String(new_station.name) if new_station != null else "missing_station")
	base_duration = -1.0
	progress_policy = ProgressPolicy.CONTINUOUS


func on_interrupt(actor, _instance) -> void:

	if station == null:
		return

	if actor.ship.station_controller.get_operator(station) == actor:
		actor.ship.station_controller.clear_operator(station)
