extends ActionDefinition
class_name RaiseMastAction

## The mast comes up in MastSystem.physics_process; this only holds the crewmate to it.


func _init() -> void:

	action_id = "raise_mast"
	progress_policy = ProgressPolicy.CONTINUOUS


func get_duration(actor) -> float:

	return actor.ship.mast_system.raise_time_left()


func on_start(actor, _instance) -> void:

	actor.ship.mast_system.begin_raising()


func on_interrupt(actor, _instance) -> void:

	actor.ship.mast_system.cancel_raising()
