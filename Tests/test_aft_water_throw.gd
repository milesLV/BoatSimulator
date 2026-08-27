extends "res://Tests/harness.gd"


class TestActor:
	extends Node2D
	var location := DeckGraph.DECKS.MID
	var bucket_amount := Crewmate.MAX_BUCKET_AMOUNT
	var ship = null
	var action_executor = null

	func set_location(new_location: int) -> void:
		location = new_location


class TestShip:
	extends CharacterBody2D
	var health_system = null
	var crewmates: Array = []

	func get_crewmates() -> Array:
		return crewmates


func _run() -> void:

	var points = load("res://Scenes/shipActionPoints.tscn").instantiate()
	root.add_child(points)
	var actor_parent := Node2D.new()
	root.add_child(actor_parent)
	var actor := TestActor.new()
	actor_parent.add_child(actor)
	var zone: WaterThrowZone = points.get_node("AftBuckettingZone")

	actor.global_position = zone.to_global(Vector2(0.0, 20.0))
	assert(zone.contains_actor(actor))
	assert(zone.get_position_for_actor(actor).is_equal_approx(actor.position))

	actor.global_position = zone.to_global(Vector2(60.0, 20.0))
	var nearest = zone.get_position_for_actor(actor)
	actor.position = nearest
	assert(zone.contains_actor(actor))

	var target := ShipActionPoint.new()
	actor_parent.add_child(target)
	actor.position = Vector2.ZERO
	target.position = Vector2(300.0, 0.0)
	var long_throw := MoveAndThrowBucketWaterAction.new(target)
	assert(is_equal_approx(long_throw.get_duration(actor), 3.0))
	target.position = Vector2(40.0, 0.0)
	var short_throw := MoveAndThrowBucketWaterAction.new(target)
	assert(is_equal_approx(short_throw.get_duration(actor), 1.0))

	actor.bucket_amount = Crewmate.MAX_BUCKET_AMOUNT
	actor.global_position = zone.to_global(Vector2(60.0, 20.0))
	assert(not ThrowBucketWaterAction.throw_water(actor, zone))
	assert(actor.bucket_amount == Crewmate.MAX_BUCKET_AMOUNT)
	actor.global_position = zone.to_global(Vector2(0.0, 20.0))
	assert(ThrowBucketWaterAction.throw_water(actor, zone))
	assert(actor.bucket_amount == 0.0)

	var ship := TestShip.new()
	root.add_child(ship)
	var health := ShipHealthSystem.new(ship, points)
	ship.health_system = health
	health.water_level = 100.0
	health.lower_deck_flood_rate_cache = 10.0
	health.mid_deck_flood_rate_cache = 0.0
	assert(is_equal_approx(
		health.get_projected_water_level(
			2.0,
			[{"time": 1.0, "amount": 50.0}]
		),
		70.0
	))

	var planner := ShipActionPlanner.new(points)
	actor.ship = ship
	actor.bucket_amount = 0.0
	actor.location = DeckGraph.DECKS.MID
	actor.position = Vector2.ZERO
	ship.crewmates = [actor]
	health.water_level = 100.0
	health.lower_deck_flood_rate_cache = 0.0
	actor.global_position = zone.to_global(Vector2(-15.0, 20.0))
	var zone_exit = zone.get_position_for_actor(actor)
	var bucket_position = points.get_node("BucketLD").get_position_for_actor(actor)
	assert(
		zone_exit.distance_to(bucket_position)
		< actor.position.distance_to(bucket_position)
	)
	actor.position = Vector2.ZERO
	var low_water_actions = planner.build_bail_water(actor, true)
	assert(not low_water_actions.is_empty())
	assert(low_water_actions[0] is MoveAndBailWaterAction)
	assert(low_water_actions[0].point.name == &"BucketLD")
	assert(low_water_actions[low_water_actions.size() - 1] is MoveAndThrowBucketWaterAction)
	assert(low_water_actions[low_water_actions.size() - 1].point.name == &"WaterThrowSpot")

	var other := TestActor.new()
	actor_parent.add_child(other)
	other.ship = ship
	other.location = DeckGraph.DECKS.LOWER
	other.position = points.get_node("BucketLD").position
	other.bucket_amount = 0.0
	other.action_executor = ActionExecutor.new()
	other.add_child(other.action_executor)
	var pending_scoop := ActionInstance.new(
		MoveAndBailWaterAction.new(points.get_node("BucketLD"))
	)
	pending_scoop.begin(other)
	pending_scoop.elapsed = pending_scoop.duration - 0.1
	other.action_executor.current_action = pending_scoop
	ship.crewmates = [actor, other]
	health.water_level = 240.0
	var assisted_actions = planner.build_bail_water(actor, true)
	assert(not assisted_actions.is_empty())
	assert(assisted_actions[0].point.name == &"BucketLD")

	other.action_executor.current_action = null
	ship.crewmates = [actor]
	var flooded_actions = planner.build_bail_water(actor, true)
	assert(not flooded_actions.is_empty())
	assert(flooded_actions[0].point.deck == DeckGraph.DECKS.MID)

	actor.position = Vector2(-200.0, 0.0)
	var aft_actions = planner.build_bail_water(actor, true)
	assert(not aft_actions.is_empty())
	assert(aft_actions[aft_actions.size() - 1].point.name == &"AftBuckettingZone")

	print("aft water throw checks passed")
	points.queue_free()
	actor_parent.queue_free()
	ship.queue_free()
	await process_frame
	quit()
