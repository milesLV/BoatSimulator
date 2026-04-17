extends Node2D

var ships: Array = []

func register_ship(ship):
	if ship not in ships:
		ships.append(ship)

func unregister_ship(ship):
	ships.erase(ship)
