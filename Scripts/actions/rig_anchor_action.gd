extends TimedInteractAction
class_name RigAnchorAction


const RIG_DURATION := 1.0

var anchor_point: ShipActionPoint


func _init(
	new_anchor_point: ShipActionPoint
) -> void:

	var new_action_id := "rig_missing_anchor"
	var new_duration := 0.0

	if new_anchor_point != null:
		new_action_id = "rig_anchor_to_drop"
		new_duration = RIG_DURATION

	super(new_anchor_point, new_action_id, new_duration)

	anchor_point = new_anchor_point


func on_start(actor, _instance) -> void:

	var anchor_system = _get_anchor_system(
		actor
	)

	if anchor_system == null:
		return

	anchor_system.begin_rigging()


func on_interrupt(actor, _instance) -> void:

	var anchor_system = _get_anchor_system(
		actor
	)

	if anchor_system == null:
		return

	anchor_system.cancel_rigging()


func on_complete(actor, instance) -> void:

	print(
		"Anchor has been rigged."
	)

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
