extends ActionDefinition
class_name StationControlAction


var station_id: String


func _init(
	new_station_id: String
):

	station_id = new_station_id

	action_id = (
		"control_%s"
		% station_id
	)

	base_duration = -1.0


func on_start(actor, _instance) -> void:

	actor.ship.set_operator(
		station_id,
		actor
	)
	actor.requested_station = ""


func on_interrupt(actor, _instance) -> void:

	if (
		actor.ship.get_operator(
			station_id
		)
		== actor
	):

		actor.ship.clear_operator(
			station_id
		)
