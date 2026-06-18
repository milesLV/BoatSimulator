extends RefCounted
class_name ActionInstance


var definition: ActionDefinition

# Cached when the action starts.
# Prevents duration changing mid-action.
var duration := 0.0
var duration_initialized := false
var elapsed := 0.0
var saved_progress := 0.0
var started := false
var finished := false
var runtime_state: Dictionary = {}


func _init(
	action_definition: ActionDefinition,
	_actor
):

	definition = action_definition
	clear_runtime_state()


func begin(actor) -> void:

	definition.prepare_instance(
		actor,
		self
	)
	duration = definition.get_duration(actor)
	duration_initialized = true
	started = true


func get_progress() -> float:

	if not duration_initialized:
		return 0.0

	if duration <= 0.0:
		return 1.0

	return clamp(
		elapsed / duration,
		0.0,
		1.0
	)


func is_complete() -> bool:

	if not duration_initialized:
		return false

	if duration < 0.0:
		return false

	return elapsed >= duration


func get_remaining_time(actor) -> float:

	var remaining_duration := duration

	if not duration_initialized:
		remaining_duration = definition.get_duration(actor)

	if remaining_duration < 0.0:
		return 0.0

	return max(
		remaining_duration - elapsed,
		0.0
	)


func reset_to_zero() -> void:

	elapsed = 0.0


func save_progress(progress = null) -> void:

	if progress == null:
		progress = elapsed

	saved_progress = float(progress)


func restore_progress() -> void:

	elapsed = saved_progress


func set_runtime_value(key, value) -> void:

	runtime_state[key] = value


func get_runtime_value(
	key,
	default_value = null
):

	return runtime_state.get(
		key,
		default_value
	)


func has_runtime_value(key) -> bool:

	return runtime_state.has(key)


func clear_runtime_value(key) -> void:

	runtime_state.erase(key)


func clear_runtime_state() -> void:

	runtime_state.clear()
