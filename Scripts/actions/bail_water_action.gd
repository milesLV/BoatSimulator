class_name BailWaterAction
extends TimedInteractAction

const DURATION := 1.0
const PICKUP_TOLERANCE := 1.0


func _init(new_point: ShipActionPoint) -> void:

	super(
		new_point,
		"bail_water",
		DURATION,
		ProgressPolicy.ONE_SHOT
	)


func on_start(
	actor,
	_instance
) -> void:

	print_bail_started(
		actor,
		point
	)


func on_complete(
	actor,
	instance
) -> void:

	collect_water(
		actor,
		point
	)

	super.on_complete(
		actor,
		instance
	)


static func print_bail_started(
	actor,
	bucket_point: ShipActionPoint
) -> void:

	var actor_name := "Unknown actor"
	var bucket_name := "the bucket point"

	if actor != null:
		actor_name = String(actor.name)

	if bucket_point != null:
		bucket_name = String(bucket_point.name)

	ShipDebugLog.bail(
		"%s started bailing at %s."
		% [
			actor_name,
			bucket_name
		]
	)


static func collect_water(
	actor,
	bucket_point: ShipActionPoint
) -> bool:

	if (
		actor == null
		or actor.bucket_amount > 0.0
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return false

	if not _actor_is_at_bucket_point(
		actor,
		bucket_point
	):
		var bucket_name := "the bucket point"

		if bucket_point != null:
			bucket_name = String(bucket_point.name)

		ShipDebugLog.bail(
			"Bail missed: %s was not at %s when the scoop finished."
			% [
				actor.name,
				bucket_name
			]
		)
		return false

	var bucket_space = max(
		Crewmate.MAX_BUCKET_AMOUNT - actor.bucket_amount,
		0.0
	)

	actor.bucket_amount += actor.ship.health_system.remove_water(bucket_space)

	ShipDebugLog.bail(
		"Ship water level after bail: %.1f/%.1f"
		% [
			actor.ship.health_system.get_water_level(),
			actor.ship.health_system.MAX_WATER_LEVEL
		]
	)

	return true


static func _actor_is_at_bucket_point(
	actor,
	bucket_point: ShipActionPoint
) -> bool:

	if bucket_point == null:
		return false

	var bucket_position = bucket_point.get_position_for_actor(actor)

	return actor.position.distance_to(
		bucket_position
	) <= PICKUP_TOLERANCE
