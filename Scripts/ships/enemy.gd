extends "res://Scripts/ships/sloop.gd"

@onready var player = get_node("/root/GameMap/Player")

var target: Node2D

func _physics_process(delta):
	if target == null:
		return

	var to_target = (target.global_position - global_position).normalized()
	var forward = Vector2.RIGHT.rotated(rotation)

	var angle = forward.angle_to(to_target)

	turn_input = clamp(angle, -1.0, 1.0)

	# Example: always sails full speed
	sail_input = 1.0

	_process_movement(delta)
