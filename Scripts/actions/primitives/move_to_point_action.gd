extends ActionDefinition
class_name MoveToPointAction

const MOVE_SPEED := Crewmate.RUN_SPEED

var point: ShipActionPoint
var _start_position: Vector2
var _target_position: Vector2


func _init(
	new_point: ShipActionPoint
) -> void:

	point = new_point
	action_point = point
	progress_policy = ProgressPolicy.CONTINUOUS

	if point == null:
		action_id = "go_to_missing_point"
		action_location = ""
		return

	action_id = "go_to_%s" % point.name
	action_location = String(point.name)


func get_duration(actor, _context := {}) -> float:

	if point == null:
		return 0.0

	var distance = actor.position.distance_to(
		point.get_position_for_actor(
			actor
		)
	)

	return distance / MOVE_SPEED


func on_start(actor, _instance) -> void:

	if point == null:
		push_error(
			"MoveToPointAction has no action point."
		)

		return

	_start_position = actor.position
	_target_position = point.get_position_for_actor(
		actor
	)


func on_tick(actor, instance, _delta: float) -> void:

	var progress = instance.get_progress()

	actor.position = _start_position.lerp(
		_target_position,
		progress
	)

	_update_actor_location(
		actor
	)


func on_complete(actor, _instance) -> void:

	actor.position = _target_position

	_update_actor_location(
		actor
	)

	super.on_complete(
		actor,
		_instance
	)


func _update_actor_location(actor) -> void:

	if point == null:
		return

	actor.set_location(
		point.deck
	)
