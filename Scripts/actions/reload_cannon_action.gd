extends TimedInteractAction
class_name ReloadCannonAction

const RELOAD_DURATION := 2.0

var station: CannonStationPoint


func _init(
	new_station: CannonStationPoint
) -> void:

	var new_action_id := "reload_missing_cannon"
	var new_duration := 0.0

	if new_station != null:
		new_action_id = (
			"reload_%s"
			% String(new_station.name)
		)
		new_duration = RELOAD_DURATION

	super(
		new_station,
		new_action_id,
		new_duration
	)

	station = new_station


func on_start(actor, _instance) -> void:

	var cannon = _get_cannon(
		actor
	)

	if cannon == null:
		return

	cannon.begin_unloaded()


func on_complete(actor, instance) -> void:

	var cannon = _get_cannon(
		actor
	)

	if cannon != null:
		cannon.finish_reload()

	super.on_complete(
		actor,
		instance
	)


func _get_cannon(actor) -> Cannon:

	if station == null:
		return null

	return station.get_cannon_for_operator(
		actor
	)
