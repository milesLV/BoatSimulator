extends Node2D

var ships: Array = []

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
