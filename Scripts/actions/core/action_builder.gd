extends RefCounted
class_name ActionBuilder

static func build_go_to_wheel(
	actor
) -> Array[ActionDefinition]:

	var actions = DeckGraph.build_transition_actions(
		actor.location,
		DeckGraph.UPPER
	)

	actions.append(
		GoToAction.new(
			"Wheel"
		)
	)

	return actions
