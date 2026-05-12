extends ActionDefinition
class_name GoToAction

const MOVE_SPEED := Crewmate.RUN_SPEED

var point_id: String
var _start_position: Vector2
var _target_position: Vector2

func _init(new_point_id: String):

	point_id = new_point_id
	action_id = "go_to_%s" % point_id
	action_location = point_id


func get_duration(actor, _context := {}) -> float:

	var point = actor.ship_action_points.get_point(point_id)

	if point == null:
		return 0.0

	var distance = actor.position.distance_to(
		point.position
	)

	return distance / MOVE_SPEED


func on_start(actor, _instance) -> void:

	var point = actor.ship_action_points.get_point(point_id)

	if point == null:
		push_error(
			"Action point not found: %s"
			% point_id
		)

		return

	_start_position = actor.position
	_target_position = point.position


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
func _update_actor_location(actor) -> void:

	if not point_id.contains("2"):
		print(point_id)
		return

	var parts = point_id.split("2")

	if parts.size() != 2:
		return

	var from_deck = parts[0]
	var to_deck = parts[1].trim_suffix("Bottom")

	if point_id.ends_with("Top"):

		actor.set_location(
			from_deck + " Deck"
		)


	elif point_id.ends_with("Bottom"):

		actor.set_location(
			to_deck + " Deck"
		)
