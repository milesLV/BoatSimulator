extends ActionDefinition
class_name StationControlAction


var station: StationPoint


func _init(
	new_station: StationPoint
):

	station = new_station
	action_point = station

	if station == null:
		action_id = "control_missing_station"
		action_location = ""
		return

	action_id = (
		"control_%s"
		% station.name
	)

	action_location = String(station.name)
	base_duration = -1.0


func on_start(actor, _instance) -> void:

	if station == null:
		return

	actor.ship.set_operator(
		station,
		actor
	)
	actor.requested_station = null


func on_interrupt(actor, _instance) -> void:

	if station == null:
		return

	if (
		actor.ship.get_operator(
			station
		)
		== actor
	):

		actor.ship.clear_operator(
			station
		)
