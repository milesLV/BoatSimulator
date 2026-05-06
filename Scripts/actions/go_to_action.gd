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

	var distance = actor.global_position.distance_to(
		point.global_position
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

	_start_position = actor.global_position
	_target_position = point.global_position


func on_tick(actor, instance, _delta: float) -> void:

	var progress = instance.get_progress()

	actor.global_position = _start_position.lerp(
		_target_position,
		progress
	)


func on_complete(actor, _instance) -> void:

	actor.global_position = _target_position
