extends Node2D
class_name ActionManager

var action_points: Dictionary = {}

func _ready() -> void:
	_register_action_points()


func _register_action_points() -> void:
	action_points.clear()

	for child in get_children():
		if child is Node2D:
			if action_points.has(child.name):
				push_error("Duplicate action point: %s" % child.name)
				continue

			action_points[child.name] = child


func get_point(point_id: String) -> Node2D:
	if not action_points.has(point_id):
		push_error("Action point not found: %s" % point_id)
		return null

	return action_points[point_id]


func has_point(point_id: String) -> bool:
	return action_points.has(point_id)
