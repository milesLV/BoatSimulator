extends ActionDefinition
class_name ClaimStationAction

var station: StationPoint


func _init(new_station: StationPoint) -> void:

	station = new_station
	action_id = "claim_%s" % station.name


## set_operator also frees whatever station the actor held before.
func on_start(actor, _instance) -> void:
	actor.ship.station_controller.set_operator(station, actor)

	if station is CannonStationPoint and station.cannon != null:
		station.cannon.aim_target = actor.aim_target
