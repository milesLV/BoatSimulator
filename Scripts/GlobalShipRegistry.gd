extends Node2D
class_name GlobalShipRegistry

var ships: Array = []


## The map root is the registry; off-map (tests, other scenes) this is null.
static func from_tree(tree: SceneTree) -> GlobalShipRegistry:

	return tree.current_scene as GlobalShipRegistry


static func get_player_ship_from_tree(tree: SceneTree) -> PlayerShip:

	var registry := from_tree(tree)

	return registry.get_player_ship() if registry != null else null


func get_player_ship() -> PlayerShip:

	for ship in ships:
		if ship is PlayerShip:
			return ship

	return null
