extends Resource
class_name ActionDefinition


signal completed(context)


@export var action_id: String = ""

var action_point: ShipActionPoint = null
@export var action_location: String = ""

@export var base_duration: float = 0.0


func get_duration(actor, context := {}) -> float:
	return base_duration


func on_start(actor, instance) -> void:
	pass


func on_tick(actor, instance, delta: float) -> void:
	pass


func on_interrupt(actor, instance) -> void:
	pass


func on_complete(actor, instance) -> void:
	completed.emit(
		_build_context(actor, instance)
	)


func _build_context(actor, instance) -> Dictionary:

	return {
		"actor": actor,
		"instance": instance,
		"action_id": action_id
	}
