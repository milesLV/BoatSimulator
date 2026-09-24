class_name RepairHoleAction
extends TimedInteractAction

const EXTRA_REPAIR_SECONDS := 1.0


func _init(hole: ShipHolePoint) -> void:

	super(hole, "repair_hole", 0.0)


func get_duration(_actor, _context := {}) -> float:
	return point.repair_duration()


func on_complete(actor, _instance) -> void:
	point.set_grade(ShipHolePoint.MIN_GRADE)
	ShipDebugLog.write(&"repair", "%s repaired %s." % [actor.name, point.name])
	actor.ship.repair_duty_controller.release_hole_for(actor)


func on_interrupt(actor, _instance) -> void:
	actor.ship.repair_duty_controller.release_hole_for(actor)
