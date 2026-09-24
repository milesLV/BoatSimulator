extends ActionDefinition
class_name DropAnchorAction


func _init() -> void:

	action_id = "trigger_anchor_drop"


func on_start(actor, _instance) -> void:

	actor.ship.anchor_system.start_dropping()
