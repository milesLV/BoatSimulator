extends RefCounted
class_name ShipActionPlanner

var action_points: ShipActionPointContainer


func _init(
	new_action_points: ShipActionPointContainer
) -> void:

	action_points = new_action_points


func build_go_to_point(
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
		MoveToPointAction.new(
			point
		)
	)

	return actions


func build_station_control(
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
		HoldStationAction.new(
			station
		)
	)

	return actions


func build_drop_anchor(
	actor
) -> Array[ActionDefinition]:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.anchor_system == null
		or not actor.ship.anchor_system.can_drop()
	):
		return []

	var anchor_point = action_points.get_point(
		&"Anchor"
	)

	if anchor_point == null:
		return []

	var actions = build_go_to_point(
		actor,
		anchor_point
	)

	if actions.is_empty():
		return []

	actions.append(
		RigAnchorAction.new(
			anchor_point
		)
	)

	actions.append(
		TriggerShipStateAction.new(
			"trigger_anchor_drop",
			actor.ship.anchor_system,
			&"start_dropping",
			[],
			anchor_point
		)
	)

	return actions


func build_raise_anchor(
	actor
) -> Array[ActionDefinition]:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.anchor_system == null
		or not actor.ship.anchor_system.can_raise()
	):
		return []

	var anchor_point = action_points.get_point(
		&"Anchor"
	)

	if anchor_point == null:
		return []

	var actions = build_go_to_point(
		actor,
		anchor_point
	)

	if actions.is_empty():
		return []

	actions.append(
		RaiseAnchorAction.new(
			anchor_point
		)
	)

	return actions


func build_transition_actions(
	actor,
	target_deck: int
) -> Array[ActionDefinition]:

	var deck_path = action_points.get_transition_path(
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

		var start_point = action_points.get_transition_point(
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
			MoveToPointAction.new(
				start_point
			)
		)

		actions.append(
			MoveToPointAction.new(
				destination_point
			)
		)

	return actions
