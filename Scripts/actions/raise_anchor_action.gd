extends ActionDefinition
class_name RaiseAnchorAction


func _init() -> void:

	action_id = "raise_anchor"
	progress_policy = ProgressPolicy.CONTINUOUS


func get_duration(actor, _context := {}) -> float:

	return actor.ship.anchor_system.drop_progress * AnchorSystem.RAISE_DURATION


func on_start(actor, _instance) -> void:

	actor.ship.anchor_system.begin_raising()


func on_tick(actor, _instance, delta: float) -> void:

	actor.ship.anchor_system.raise_by_delta(delta)


func on_interrupt(actor, _instance) -> void:

	actor.ship.anchor_system.cancel_raising()


func on_complete(actor, _instance) -> void:

	actor.ship.anchor_system.finish_raising()
