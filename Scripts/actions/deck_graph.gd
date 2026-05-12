extends RefCounted
class_name DeckGraph

const UPPER := "Upper Deck"
const MAIN := "Main Deck"
const MID := "Mid Deck"
const LOWER := "Lower Deck"

const CONNECTIONS := {

	UPPER: {
		MAIN: "Upper2Main"
	},

	MAIN: {
		UPPER: "Main2Upper",
		MID: "Main2Mid"
	},

	MID: {
		MAIN: "Main2Mid",
		LOWER: "Mid2Lower"
	},

	LOWER: {
		MID: "Mid2Lower"
	}
}

static func get_transition_path(
	start_deck: String,
	target_deck: String
) -> Array[String]:

	if start_deck == target_deck:
		return []


	# Godot doesn't support Array[Array[String]]
	var queue := []

	queue.append(
		[start_deck]
	)


	var visited := {}

	visited[start_deck] = true


	while not queue.is_empty():

		var path = queue.pop_front()

		var current = path.back()


		if current == target_deck:

			var result: Array[String] = []

			for deck in path:
				result.append(deck)

			return result


		var neighbors = CONNECTIONS.get(
			current,
			{}
		)


		for neighbor in neighbors:

			if visited.has(
				neighbor
			):
				continue


			visited[
				neighbor
			] = true


			var new_path = (
				path.duplicate()
			)

			new_path.append(
				neighbor
			)


			queue.append(
				new_path
			)

	return []

static func build_transition_actions(
	start_deck: String,
	target_deck: String
) -> Array[ActionDefinition]:

	var deck_path = get_transition_path(
		start_deck,
		target_deck
	)

	if deck_path.size() <= 1:
		return []


	var actions: Array[ActionDefinition] = []


	for i in range(
		deck_path.size() - 1
	):

		var from_deck = deck_path[i]

		var to_deck = deck_path[i + 1]


		var transition = CONNECTIONS[
			from_deck
		][
			to_deck
		]


		var going_up = (
			_get_level(
				to_deck
			)
			>
			_get_level(
				from_deck
			)
		)


		if going_up:

			actions.append(
				GoToAction.new(
					transition + "Bottom"
				)
			)

			actions.append(
				GoToAction.new(
					transition + "Top"
				)
			)

		else:

			actions.append(
				GoToAction.new(
					transition + "Top"
				)
			)

			actions.append(
				GoToAction.new(
					transition + "Bottom"
				)
			)


	return actions

static func _get_level(
	deck: String
) -> int:

	match deck:

		LOWER:
			return 0

		MID:
			return 1

		MAIN:
			return 2

		UPPER:
			return 3


	return -1
