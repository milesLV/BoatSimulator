class_name MoveAndThrowBucketWaterAction
extends MoveAndBailWaterAction

const THROW_DURATION := 1.0


func _init(new_point: ShipActionPoint, new_route_points: Array = []) -> void:
	super(new_point, new_route_points)
	action_id = "move_and_throw_bucket_water"
	fills_bucket = false


static func throw_water(actor, throw_point: ShipActionPoint) -> bool:
	if not throw_point.contains_actor(actor):
		return false

	actor.bucket_amount = 0.0
	return true
