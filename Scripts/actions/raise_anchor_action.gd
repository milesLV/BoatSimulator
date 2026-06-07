extends ActionDefinition
class_name RaiseAnchorAction

var anchor_point: ShipActionPoint


func _init(new_anchor_point: ShipActionPoint) -> void:

	anchor_point = new_anchor_point
	action_point = anchor_point
	action_id = "raise_anchor"
	progress_policy = ProgressPolicy.CONTINUOUS

	if anchor_point == null:
		action_id = "raise_missing_anchor"
		action_location = ""
		return

	action_location = String(anchor_point.name)


func get_duration(actor, _context := {}) -> float:

	var anchor_system = _get_anchor_system(actor)

	if anchor_system == null:
		return 0.0

	return anchor_system.get_raise_remaining_duration()


func on_start(actor, _instance) -> void:

	var anchor_system = _get_anchor_system(actor)

	if anchor_system == null:
		return

	anchor_system.begin_raising()


func on_tick(actor, _instance, delta: float) -> void:

	var anchor_system = _get_anchor_system(actor)

	if anchor_system == null:
		return

	anchor_system.raise_by_delta(delta)


func on_interrupt(actor, _instance) -> void:

	var anchor_system = _get_anchor_system(actor)

	if anchor_system == null:
		return

	anchor_system.cancel_raising()


func on_complete(actor, instance) -> void:

	var anchor_system = _get_anchor_system(actor)

	if anchor_system != null:
		anchor_system.finish_raising()

	super.on_complete(
		actor,
		instance
	)


func _get_anchor_system(actor):

	if (
		actor == null
		or actor.ship == null
	):
		return null

	return actor.ship.anchor_system
