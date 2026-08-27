class_name RepairHoleAction
extends TimedInteractAction

const EXTRA_REPAIR_SECONDS := 1.0

var hole: ShipHolePoint


func _init(new_hole: ShipHolePoint) -> void:

	hole = new_hole

	super(new_hole, "repair_hole", 0.0, ProgressPolicy.ONE_SHOT)


func get_duration(_actor, _context := {}) -> float:
	return float(hole.grade) + EXTRA_REPAIR_SECONDS if hole != null else 0.0


func on_complete(actor, _instance) -> void:
	if hole != null:
		hole.set_grade(ShipHolePoint.MIN_GRADE)

		ShipDebugLog.write(&"repair",
			"%s repaired %s."
			% [
				String(actor.name) if actor != null else "Unknown actor",
				hole.name
			]
		)

	_release_reservation(actor)


func on_interrupt(actor, _instance) -> void:
	_release_reservation(actor)


func _release_reservation(actor) -> void:

	if actor == null or actor.ship == null or actor.ship.repair_duty_controller == null:
		return

	actor.ship.repair_duty_controller.release_hole_for(actor)
