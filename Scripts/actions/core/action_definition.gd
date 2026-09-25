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
var fills_bucket := false


func get_duration(_actor) -> float:
	return base_duration


func on_start(_actor, _instance) -> void:
	pass


func on_tick(_actor, _instance, _delta: float) -> void:
	pass


func on_interrupt(_actor, _instance) -> void:
	pass


func on_complete(_actor, _instance) -> void:
	pass
