extends Resource
class_name ActionDefinition


## ONE_SHOT starts over when interrupted; CONTINUOUS keeps its elapsed time.
enum ProgressPolicy {
	ONE_SHOT,
	CONTINUOUS
}


@export var action_id: String = ""
@export var base_duration: float = 0.0
@export var progress_policy: ProgressPolicy = ProgressPolicy.ONE_SHOT
## True while the action ends with the actor holding a filled bucket.
var fills_bucket := false


func get_duration(_actor, _context := {}) -> float:
	return base_duration


func apply_interrupt_policy(_actor, instance) -> void:

	if progress_policy == ProgressPolicy.ONE_SHOT:
		instance.elapsed = 0.0


func on_start(_actor, _instance) -> void:
	pass


func on_tick(_actor, _instance, _delta: float) -> void:
	pass


func on_interrupt(_actor, _instance) -> void:
	pass


func on_complete(_actor, _instance) -> void:
	pass
