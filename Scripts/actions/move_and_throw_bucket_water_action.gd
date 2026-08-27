class_name MoveAndThrowBucketWaterAction
extends MoveAndBailWaterAction


func _init(new_point: ShipActionPoint, new_route_points: Array = []) -> void:
	super(new_point, new_route_points)
	action_id = "move_and_throw_bucket_water"
	fills_bucket = false


func on_complete(actor, instance) -> void:

	actor.position = instance.get_runtime_value(RUNTIME_TARGET_POSITION, actor.position)
	_update_actor_location(actor)
	ThrowBucketWaterAction.throw_water(actor, point)


func _on_windup_started(_actor) -> void:

	pass
