extends Resource
class_name ActionDefinition


signal completed(context)

enum ProgressPolicy {
	ONE_SHOT,
	VARIABLE_TIME,
	CHECKPOINT,
	CONTINUOUS
}


@export var action_id: String = ""

var action_point: ShipActionPoint = null
@export var action_location: String = ""

@export var base_duration: float = 0.0
@export var progress_policy: ProgressPolicy = ProgressPolicy.ONE_SHOT
@export var checkpoint_times: Array[float] = []


func get_duration(_actor, _context := {}) -> float:
	return base_duration


func apply_interrupt_policy(_actor, instance) -> void:

	var interrupted_elapsed = _get_interrupted_elapsed(instance)

	instance.save_progress(interrupted_elapsed)

	instance.elapsed = interrupted_elapsed


func on_start(_actor, _instance) -> void:
	pass


func on_tick(_actor, _instance, _delta: float) -> void:
	pass


func on_interrupt(_actor, _instance) -> void:
	pass


func on_complete(actor, instance) -> void:
	completed.emit(_build_context(actor, instance))


func _get_interrupted_elapsed(instance) -> float:

	match progress_policy:
		ProgressPolicy.CHECKPOINT:
			return _get_completed_checkpoint_time(
				instance.elapsed
			)

		ProgressPolicy.CONTINUOUS:
			return instance.elapsed

		ProgressPolicy.ONE_SHOT, ProgressPolicy.VARIABLE_TIME:
			return 0.0

	return 0.0


func _get_completed_checkpoint_time(elapsed: float) -> float:

	var completed_checkpoint := 0.0

	for checkpoint_time in checkpoint_times:

		if (
			checkpoint_time <= elapsed
			and checkpoint_time > completed_checkpoint
		):
			completed_checkpoint = checkpoint_time

	return completed_checkpoint


func _build_context(actor, instance) -> Dictionary:

	return {
		"actor": actor,
		"instance": instance,
		"action_id": action_id,
		"progress_policy": progress_policy
	}
