extends Area2D

const SPEED := 500

var travelled_distance := 0.0
var range_manager = null
var owner_node: Node = null

func setup(owner: Node):
	owner_node = owner

func _physics_process(delta):
	if range_manager == null:
		return

	var direction = Vector2.RIGHT.rotated(global_rotation)
	var max_range = range_manager.MAX_RANGE

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
