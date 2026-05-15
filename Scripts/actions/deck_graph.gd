extends RefCounted
class_name DeckGraph

enum DECKS {UPPER, MAIN, MID, LOWER}

static func is_valid_deck(
	deck: int
) -> bool:

	return DECKS.values().has(
		deck
	)


static func get_deck_name(
	deck: int
) -> String:

	var deck_key = DECKS.find_key(
		deck
	)

	if deck_key == null:
		return "Unknown Deck"

	return "%s Deck" % String(deck_key).capitalize()


static func get_transition_path(
	connections: Dictionary,
	start_deck: int,
	target_deck: int
) -> Array[int]:

	if (
		not is_valid_deck(start_deck)
		or not is_valid_deck(target_deck)
	):
		return []

	if start_deck == target_deck:
		return [start_deck]


	# Godot doesn't support nested typed arrays.
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

			var result: Array[int] = []

			for deck in path:
				result.append(deck)

			return result


		var neighbors = connections.get(
			current,
			{}
		)


		for neighbor in neighbors.keys():

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
