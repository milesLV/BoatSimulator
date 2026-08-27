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

	if not crewmates.is_empty():
		selected_index = 0
		current_crewmate = crewmates[selected_index]
		_print_selected_crewmate()

	if ship.helmsman != null:
		ship.helmsman.set_location(DeckGraph.DECKS.UPPER)

	if ship.cannoneer != null:
		ship.cannoneer.set_location(DeckGraph.DECKS.MAIN)


func get_crewmates() -> Array[Crewmate]:

	return crewmates.duplicate()


func get_current_crewmate() -> Crewmate:

	return current_crewmate


func change_crewmate() -> Crewmate:

	if crewmates.is_empty():
		current_crewmate = null
		return null

	selected_index += 1
	selected_index %= crewmates.size()
	current_crewmate = crewmates[selected_index]

	_print_selected_crewmate()

	return current_crewmate


func _print_selected_crewmate() -> void:

	if current_crewmate == null:
		return

	ShipDebugLog.write(&"crew", "Selected: %s" % current_crewmate.name)
