extends RefCounted
class_name ActionBuilder

static func build_go_to_point(
	actor,
	point: ShipActionPoint
) -> Array[ActionDefinition]:

	if point == null:
		return []

	var actions = build_transition_actions(
		actor,
		point.deck
	)

	if (
		actor.location != point.deck
		and actions.is_empty()
	):
		return []

	actions.append(
		GoToAction.new(
			point
		)
	)

	return actions


static func build_station_control(
	actor,
	station: StationPoint
) -> Array[ActionDefinition]:

	if station == null:
		return []

	var actions = build_go_to_point(
		actor,
		station
	)

	actions.append(
		StationControlAction.new(
			station
		)
	)

	return actions


static func build_transition_actions(
	actor,
	target_deck: int
) -> Array[ActionDefinition]:

	var deck_path = actor.ship_action_points.get_transition_path(
		actor.location,
		target_deck
	)

	if deck_path.is_empty():
		push_error(
			"No deck path from %s to %s."
			% [
				DeckGraph.get_deck_name(actor.location),
				DeckGraph.get_deck_name(target_deck)
			]
		)
		return []

	if deck_path.size() <= 1:
		return []


	var actions: Array[ActionDefinition] = []

	for i in range(
		deck_path.size() - 1
	):

		var from_deck: int = deck_path[i]
		var to_deck: int = deck_path[i + 1]

		var start_point = actor.ship_action_points.get_transition_point(
			from_deck,
			to_deck
		)

		if start_point == null:
			return []

		var destination_point = start_point.deck_connection

		if destination_point == null:
			push_error(
				"Transition point %s has no connected destination."
				% start_point.name
			)
			return []

		actions.append(
			GoToAction.new(
				start_point
			)
		)

		actions.append(
			GoToAction.new(
				destination_point
			)
		)

	return actions
