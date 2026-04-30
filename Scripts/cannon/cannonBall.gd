extends Area2D

const SPEED := 500

var travelled_distance := 0.0
var max_range := 0.0
var owner_node: Node = null

func setup(cannon: Node, cannonball_range: float):
	owner_node = cannon
	max_range = cannonball_range

func _physics_process(delta):
	var direction = Vector2.RIGHT.rotated(global_rotation)

	global_position += SPEED * direction * delta
	travelled_distance += SPEED * delta

	if travelled_distance >= max_range:
		queue_free()

func _on_body_entered(body):
	if body == owner_node:
		return

	if body.has_method("updateHealth"):
		body.updateHealth(1)

	queue_free()
