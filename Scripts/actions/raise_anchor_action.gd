extends ActionDefinition
class_name RaiseAnchorAction

## The anchor comes up in AnchorSystem.physics_process; this only holds the crewmate to it.


func _init() -> void:

	action_id = "raise_anchor"
	progress_policy = ProgressPolicy.CONTINUOUS


func get_duration(actor, _context := {}) -> float:

	return actor.ship.anchor_system.drop_progress * AnchorSystem.RAISE_DURATION


func on_start(actor, _instance) -> void:

	actor.ship.anchor_system.begin_raising()


func on_interrupt(actor, _instance) -> void:

	actor.ship.anchor_system.cancel_raising()
