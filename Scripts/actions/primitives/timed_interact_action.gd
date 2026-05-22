extends ActionDefinition
class_name TimedInteractAction

var point: ShipActionPoint


func _init(
	new_point: ShipActionPoint,
	new_action_id: String,
	new_duration: float,
	new_progress_policy := ProgressPolicy.ONE_SHOT
) -> void:

	point = new_point
	action_point = point
	action_id = new_action_id
	base_duration = new_duration
	progress_policy = new_progress_policy

	if point == null:
		action_location = ""
		return

	action_location = String(point.name)
