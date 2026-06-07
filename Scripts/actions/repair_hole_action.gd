class_name RepairHoleAction
extends TimedInteractAction

const EXTRA_REPAIR_SECONDS := 1.0

var hole: ShipHolePoint


func _init(new_hole: ShipHolePoint) -> void:

	hole = new_hole

	super(
		new_hole,
		"repair_hole",
		0.0,
		ProgressPolicy.ONE_SHOT
	)


func get_duration(
	_actor,
	_context := {}
) -> float:

	if hole == null:
		return 0.0

	return float(
		hole.grade
	) + EXTRA_REPAIR_SECONDS


func on_complete(
	actor,
	instance
) -> void:

	if hole != null:
		hole.repair_fully()

		ShipDebugLog.repair(
			"%s repaired %s."
			% [
				_get_actor_name(
					actor
				),
				hole.name
			]
		)

	_release_reservation(
		actor,
		true
	)

	super.on_complete(
		actor,
		instance
	)


func on_interrupt(
	actor,
	_instance
) -> void:

	_release_reservation(
		actor,
		false
	)


func _get_actor_name(actor) -> String:

	if actor == null:
		return "Unknown actor"

	return String(
		actor.name
	)


func _release_reservation(
	actor,
	completed: bool
) -> void:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.repair_duty_controller == null
	):
		return

	if completed:
		actor.ship.repair_duty_controller.mark_repair_completed(actor)
	else:
		actor.ship.repair_duty_controller.release_hole_for(actor)
