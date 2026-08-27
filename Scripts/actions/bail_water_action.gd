class_name BailWaterAction
extends TimedInteractAction

const DURATION := 1.0
const PICKUP_TOLERANCE := 1.0


func _init(new_point: ShipActionPoint) -> void:

	super(new_point, "bail_water", DURATION, ProgressPolicy.ONE_SHOT)
	fills_bucket = true


func on_start(actor, _instance) -> void:
	print_bail_started(actor, point)


func on_complete(actor, _instance) -> void:
	collect_water(actor, point)


static func print_bail_started(actor, bucket_point: ShipActionPoint) -> void:
	ShipDebugLog.write(&"bail",
		"%s started bailing at %s."
		% [
			String(actor.name) if actor != null else "Unknown actor",
			_get_bucket_name(bucket_point)
		]
	)


static func collect_water(actor, bucket_point: ShipActionPoint) -> bool:
	if (
		actor == null
		or actor.bucket_amount > 0.0
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return false

	if bucket_point == null or not bucket_point.contains_actor(actor, PICKUP_TOLERANCE):
		ShipDebugLog.write(&"bail",
			"Bail missed: %s was not at %s when the scoop finished."
			% [
				actor.name,
				_get_bucket_name(bucket_point)
			]
		)
		return false

	if (
		bucket_point.deck == DeckGraph.DECKS.MID
		and actor.ship.health_system.water_level
		< ShipHealthSystem.MID_DECK_WATER_LEVEL
	):
		return false

	actor.bucket_amount += actor.ship.health_system.remove_water(Crewmate.MAX_BUCKET_AMOUNT)

	ShipDebugLog.write(&"bail",
		"Ship water level after bail: %.1f/%.1f"
		% [
			actor.ship.health_system.water_level,
			actor.ship.health_system.MAX_WATER_LEVEL
		]
	)

	return true


static func _get_bucket_name(bucket_point: ShipActionPoint) -> String:

	return String(bucket_point.name) if bucket_point != null else "the bucket point"
