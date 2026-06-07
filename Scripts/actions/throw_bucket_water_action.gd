class_name ThrowBucketWaterAction
extends TimedInteractAction

const DURATION := 1.0


func _init(new_point: ShipActionPoint) -> void:

	super(
		new_point,
		"throw_bucket_water",
		DURATION,
		ProgressPolicy.ONE_SHOT
	)


func on_complete(
	actor,
	instance
) -> void:

	if actor != null:
		actor.bucket_amount = 0.0

	super.on_complete(
		actor,
		instance
	)
