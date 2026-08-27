extends ActionDefinition
class_name RaiseAnchorAction

var anchor_point: ShipActionPoint


func _init(new_anchor_point: ShipActionPoint) -> void:

	anchor_point = new_anchor_point
	action_id = "raise_anchor"
	progress_policy = ProgressPolicy.CONTINUOUS

	if anchor_point == null:
		action_id = "raise_missing_anchor"


func get_duration(actor, _context := {}) -> float:

	var anchor_system = AnchorSystem.for_actor(actor)

	if anchor_system == null:
		return 0.0

	return anchor_system.drop_progress * AnchorSystem.RAISE_DURATION


func on_start(actor, _instance) -> void:

	AnchorSystem.call_for_actor(actor, &"begin_raising")


func on_tick(actor, _instance, delta: float) -> void:

	AnchorSystem.call_for_actor(actor, &"raise_by_delta", [delta])


func on_interrupt(actor, _instance) -> void:

	AnchorSystem.call_for_actor(actor, &"cancel_raising")


func on_complete(actor, _instance) -> void:

	AnchorSystem.call_for_actor(actor, &"finish_raising")
