extends ActionDefinition
class_name DropAnchorAction


func _init(new_anchor_point: ShipActionPoint) -> void:

	action_id = "trigger_anchor_drop"
	base_duration = 0.0
	progress_policy = ProgressPolicy.ONE_SHOT


func on_start(actor, _instance) -> void:

	AnchorSystem.call_for_actor(actor, &"start_dropping")
