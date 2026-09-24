extends ActionDefinition
class_name ClaimStationAction

var station: StationPoint


func _init(new_station: StationPoint) -> void:

	station = new_station
	action_id = "claim_%s" % station.name


## set_operator also frees whatever station the actor held before.
func on_start(actor, _instance) -> void:
	actor.ship.station_controller.set_operator(station, actor)
