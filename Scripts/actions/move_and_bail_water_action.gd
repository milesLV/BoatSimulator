class_name MoveAndBailWaterAction
extends MoveToPointAction

## Scooping (or throwing) winds up this long before arrival.
const SCOOP_DURATION := 1.0
const PICKUP_TOLERANCE := 1.0


func _init(new_point: ShipActionPoint, new_route_points: Array = []) -> void:
	super(new_point, new_route_points)

	action_id = "move_and_bail_water"
	fills_bucket = true


func get_duration(actor) -> float:
	return max(super(actor), SCOOP_DURATION)


func on_tick(actor, instance, delta: float) -> void:
	# announced as the actor reaches the point; a throw does its work in on_complete
	if (
		fills_bucket
		and not instance.runtime_state.has(&"announced")
		and instance.elapsed >= instance.duration - SCOOP_DURATION
	):
		instance.runtime_state[&"announced"] = true
		ShipDebugLog.write(&"bail", "%s started bailing at %s." % [actor.name, point.name])

	super(actor, instance, delta)


func on_complete(actor, instance) -> void:
	super(actor, instance)

	if fills_bucket:
		_collect_water(actor)
	else:
		MoveAndThrowBucketWaterAction.throw_water(actor, point)


func _collect_water(actor) -> void:
	var health_system = actor.ship.health_system

	if actor.bucket_amount > 0.0:
		return

	if not point.contains_actor(actor, PICKUP_TOLERANCE):
		ShipDebugLog.write(&"bail",
			"Bail missed: %s was not at %s when the scoop finished." % [actor.name, point.name]
		)
		return

	if point.deck == DeckGraph.DECKS.MID and health_system.water_level < ShipHealthSystem.MID_DECK_WATER_LEVEL:
		return

	actor.bucket_amount += health_system.remove_water(Crewmate.MAX_BUCKET_AMOUNT)

	ShipDebugLog.write(&"bail",
		"Ship water level after bail: %.1f/%.1f"
		% [health_system.water_level, health_system.MAX_WATER_LEVEL]
	)
