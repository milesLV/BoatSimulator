extends Resource
class_name ActionDefinition


enum ProgressPolicy {
	ONE_SHOT,
	VARIABLE_TIME,
	CHECKPOINT,
	CONTINUOUS
}


@export var action_id: String = ""
@export var base_duration: float = 0.0
@export var progress_policy: ProgressPolicy = ProgressPolicy.ONE_SHOT
@export var checkpoint_times: Array[float] = []
## True while the action ends with the actor holding a filled bucket.
var fills_bucket := false


func get_duration(_actor, _context := {}) -> float:
	return base_duration


## ONE_SHOT and VARIABLE_TIME keep no partial progress; the other two do.
func apply_interrupt_policy(_actor, instance) -> void:

	match progress_policy:
		ProgressPolicy.CHECKPOINT:
			instance.elapsed = _get_completed_checkpoint_time(instance.elapsed)

		ProgressPolicy.CONTINUOUS:
			pass

		_:
			instance.elapsed = 0.0


func on_start(_actor, _instance) -> void:
	pass


func on_tick(_actor, _instance, _delta: float) -> void:
	pass


func on_interrupt(_actor, _instance) -> void:
	pass


func on_complete(_actor, _instance) -> void:
	pass


func _get_completed_checkpoint_time(elapsed: float) -> float:

	var completed = checkpoint_times.filter(
		func(checkpoint_time): return checkpoint_time <= elapsed
	)

	return completed.max() if not completed.is_empty() else 0.0
