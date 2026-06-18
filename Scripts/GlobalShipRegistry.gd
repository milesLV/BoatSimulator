extends Node2D
class_name GlobalShipRegistry

var ships: Array = []


static func get_player_ship_from_tree(tree: SceneTree) -> PlayerShip:

	if tree == null:
		return null

	var game_map = tree.current_scene

	if game_map == null or not game_map.has_method("get_player_ship"):
		return null

	return game_map.get_player_ship()

func register_ship(ship):
	if ship not in ships:
		ships.append(ship)

func unregister_ship(ship):
	ships.erase(ship)


func get_player_ship() -> PlayerShip:

	for ship in ships:

		if ship is PlayerShip:
			return ship

	return null


func get_other_ships(ship) -> Array:

	return ships.filter(
		func(candidate):
			return candidate != ship
	)
