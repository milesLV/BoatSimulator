extends TimedInteractAction
class_name ReloadCannonAction

const RELOAD_DURATION := 2.0

var station: CannonStationPoint


func _init(new_station: CannonStationPoint) -> void:

	super(new_station, "reload_%s" % new_station.name, RELOAD_DURATION)
	station = new_station


func on_start(actor, _instance) -> void:
	_set_loaded(actor, false)


func on_complete(actor, _instance) -> void:
	_set_loaded(actor, true)


func _set_loaded(actor, loaded: bool) -> void:

	var cannon = station.get_cannon_for_operator(actor)

	if cannon != null:
		cannon.loaded = loaded
