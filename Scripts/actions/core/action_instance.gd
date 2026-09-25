extends RefCounted
class_name ActionInstance


var definition: ActionDefinition

## Cached when the action starts, so it cannot change mid-action.
var duration := 0.0
var elapsed := 0.0
var started := false
var finished := false
var runtime_state: Dictionary = {}


func _init(action_definition: ActionDefinition):

	definition = action_definition


func begin(actor) -> void:

	duration = definition.get_duration(actor)
	started = true


func is_complete() -> bool:

	return started and duration >= 0.0 and elapsed >= duration


func get_remaining_time(actor) -> float:

	var total: float = duration if started else definition.get_duration(actor)

	# a held station runs open-ended, with nothing left to count down
	return 0.0 if total < 0.0 else maxf(total - elapsed, 0.0)
