extends ActionDefinition
class_name KnockMastLooseAction


func _init() -> void:

	action_id = "knock_mast_loose"


func on_start(actor, _instance) -> void:

	actor.ship.mast_system.knock_loose()
