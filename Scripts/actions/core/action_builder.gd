extends RefCounted
class_name ActionBuilder

static func build_station_control(
	actor,
	station_id: String,
	target_deck: String
) -> Array[ActionDefinition]:

	var actions = (
		DeckGraph.build_transition_actions(
			actor.location,
			target_deck
		)
	)

	actions.append(
		GoToAction.new(
			station_id
		)
	)

	actions.append(
		StationControlAction.new(
			station_id
		)
	)

	return actions
