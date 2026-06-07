class_name ShipCrewController
extends RefCounted

var ship
var crewmates: Array[Crewmate] = []
var current_crewmate: Crewmate = null
var selected_index := 0


func _init(new_ship) -> void:

	ship = new_ship


func initialize() -> void:

	crewmates.clear()

	for child in ship.get_children():
		if child is Crewmate:
			crewmates.append(child)

	if not crewmates.is_empty():
		selected_index = 0
		current_crewmate = crewmates[selected_index]
		_print_selected_crewmate()

	_initialize_crewmate_decks()


func get_crewmates() -> Array[Crewmate]:

	var result: Array[Crewmate] = []

	for crewmate in crewmates:
		result.append(crewmate)

	return result


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


func is_selected(crewmate: Crewmate) -> bool:

	return (
		crewmate != null
		and current_crewmate == crewmate
	)


func _initialize_crewmate_decks() -> void:

	if ship.helmsman != null:
		ship.helmsman.set_location(DeckGraph.DECKS.UPPER)

	if ship.cannoneer != null:
		ship.cannoneer.set_location(DeckGraph.DECKS.MAIN)


func _print_selected_crewmate() -> void:

	if current_crewmate == null:
		return

	ShipDebugLog.crew(
		"Selected: %s"
		% current_crewmate.name
	)
