class_name ThrowBucketWaterAction
extends TimedInteractAction

const DURATION := 1.0


func _init(new_point: ShipActionPoint) -> void:

	super(new_point, "throw_bucket_water", DURATION, ProgressPolicy.ONE_SHOT)


func on_complete(actor, _instance) -> void:
	throw_water(actor, point)


static func throw_water(actor, throw_point: ShipActionPoint) -> bool:
	if actor == null or throw_point == null or not throw_point.contains_actor(actor):
		return false

	actor.bucket_amount = 0.0
	return true
