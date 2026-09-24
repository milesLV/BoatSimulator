extends ActionDefinition
class_name KnockMastLooseAction

## Lets a propped mast go, from the sail lines.


func _init() -> void:

	action_id = "knock_mast_loose"


func on_start(actor, _instance) -> void:

	actor.ship.mast_system.knock_loose()
