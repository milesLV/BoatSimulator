class_name ShipCrewController
extends RefCounted

var ship
var crewmates: Array[Crewmate] = []
var current_crewmate: Crewmate = null
var selected_index := 0


func _init(new_ship) -> void:

	ship = new_ship


func initialize() -> void:

	crewmates.assign(ship.get_children().filter(func(child): return child is Crewmate))

	current_crewmate = crewmates[selected_index]
	_print_selected_crewmate()

	ship.helmsman.set_location(DeckGraph.DECKS.UPPER)
	ship.cannoneer.set_location(DeckGraph.DECKS.MAIN)


func get_crewmates() -> Array[Crewmate]:

	return crewmates


func get_current_crewmate() -> Crewmate:

	return current_crewmate


func change_crewmate() -> void:

	selected_index = (selected_index + 1) % crewmates.size()
	current_crewmate = crewmates[selected_index]

	_print_selected_crewmate()


func _print_selected_crewmate() -> void:

	ShipDebugLog.write(&"crew", "Selected: %s" % current_crewmate.name)
