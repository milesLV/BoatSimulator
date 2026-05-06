extends RefCounted
class_name ActionInstance


var definition: ActionDefinition


var elapsed := 0.0
var saved_progress := 0.0

# Cached at creation.
# Prevents duration changing mid-action.
var duration := 0.0


var started := false
var finished := false


func _init(
	action_definition: ActionDefinition,
	actor
):

	definition = action_definition

	duration = definition.get_duration(
		actor
	)


func get_progress() -> float:

	if duration <= 0.0:
		return 1.0

	return clamp(
		elapsed / duration,
		0.0,
		1.0
	)


func is_complete() -> bool:

	return elapsed >= duration


func reset_to_zero() -> void:

	elapsed = 0.0


func save_progress() -> void:

	saved_progress = elapsed


func restore_progress() -> void:

	elapsed = saved_progress
