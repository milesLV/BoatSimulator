extends ActionDefinition
class_name FireCannonAction

var station: CannonStationPoint


func _init(new_station: CannonStationPoint) -> void:

	station = new_station
	action_id = "fire_%s" % (String(station.name) if station != null else "")
	base_duration = 0.0
	progress_policy = ProgressPolicy.ONE_SHOT


func on_start(actor, _instance) -> void:

	var cannon = station.get_cannon_for_operator(actor) if station != null else null

	if cannon != null:
		cannon.fire()
