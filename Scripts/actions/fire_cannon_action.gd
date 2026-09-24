extends ActionDefinition
class_name FireCannonAction

var station: CannonStationPoint


func _init(new_station: CannonStationPoint) -> void:

	station = new_station
	action_id = "fire_%s" % station.name


func on_start(actor, _instance) -> void:

	var cannon = station.get_cannon_for_operator(actor)

	if cannon != null:
		cannon.fire()
