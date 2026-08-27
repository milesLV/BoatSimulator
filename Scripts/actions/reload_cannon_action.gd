extends TimedInteractAction
class_name ReloadCannonAction

const RELOAD_DURATION := 2.0

var station: CannonStationPoint


func _init(new_station: CannonStationPoint) -> void:

	super(
		new_station,
		"reload_%s" % String(new_station.name) if new_station != null else "reload_missing_cannon",
		RELOAD_DURATION if new_station != null else 0.0
	)

	station = new_station


func on_start(actor, _instance) -> void:

	var cannon = _get_cannon(actor)

	if cannon == null:
		return

	cannon.loaded = false


func on_complete(actor, _instance) -> void:

	var cannon = _get_cannon(actor)

	if cannon != null:
		cannon.loaded = true


func _get_cannon(actor) -> Cannon:

	return station.get_cannon_for_operator(actor) if station != null else null
