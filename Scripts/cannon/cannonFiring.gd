extends Node2D

@onready var sprite = $CannonSprite
@onready var cannon_mouth = $CannonSprite/CannonMouth
@onready var range_area = $CannonRange
@onready var range_detection = $CannonRange/CannonDetection

const CANNONBALL = preload("res://Scenes/cannonball.tscn")
const MAX_ANGLE = deg_to_rad(45)
const ROTATION_SPEED = deg_to_rad(18) # 18 degrees/sec
const FIRE_ANGLE_TOLERANCE = deg_to_rad(2) # won't fire until cannon lined up with target with this error

var max_range := 0.0
var range_step := 0.0

var ready_to_fire = true
var current_target = null
var current_range = -1
var last_direction_aimed: Vector2 = Vector2.ZERO

var is_actively_tracking := false
var target_global: Node = null

func _ready():
	await get_tree().process_frame
	max_range = get_max_range()
	range_step = max_range / 3.0

func _physics_process(delta):
	var bodies = range_area.get_overlapping_bodies()

	current_target = null
	current_range = -1

	if bodies.size() > 0:
		# pick closest valid target
		var closest_dist = INF
		
		for body in bodies:
			if body == get_parent().get_parent():
				continue
			if not is_in_arc(body.global_position):
				continue

			var dist = global_position.distance_to(body.global_position)

			if dist < closest_dist:
				closest_dist = dist
				current_target = body

		if current_target != null:
			current_range = get_range(closest_dist)

	# fallback to external tracking (UNCHANGED)
	if current_target == null:
		if not is_actively_tracking or target_global == null or not is_instance_valid(target_global):
			return

		aim_at_position(target_global.global_position, delta)
		return

	# intercept + fire (UNCHANGED)
	var shooter_position = global_position
	var target_position = current_target.global_position
	var target_velocity = get_target_velocity(current_target)

	var intercept_position = calculate_intercept_position(
		shooter_position,
		target_position,
		target_velocity,
		500.0
	)

	aim_at_position(intercept_position, delta)

	if ready_to_fire and current_range != -1 and is_aligned():
		shoot()

func is_in_arc(target_pos: Vector2) -> bool:
	var forward = Vector2.RIGHT.rotated(global_rotation)
	var to_target = (target_pos - global_position).normalized()
	var angle = forward.angle_to(to_target)
	return abs(angle) <= MAX_ANGLE

func aim_at_position(target_position: Vector2, delta: float):
	var shooter_position = global_position
	var aim_direction = (target_position - shooter_position).normalized()

	last_direction_aimed = aim_direction

	var current_forward = Vector2.RIGHT.rotated(global_rotation)
	var angle_to_target = current_forward.angle_to(aim_direction)
	var clamped_angle = clamp(angle_to_target, -MAX_ANGLE, MAX_ANGLE)

	sprite.rotation = move_toward(
		sprite.rotation,
		clamped_angle,
		ROTATION_SPEED * delta
	)

func calculate_intercept_position(
	shooter_position: Vector2,
	target_position: Vector2,
	target_velocity: Vector2,
	projectile_speed: float
) -> Vector2:

	var dist_to_target = target_position - shooter_position
	
	# solving intercept equation
	# (target_velocity^2 - project_speed^2) * time^2 + 2*distance_between_ships*target_velocity)*time + distance_between_ships^2
	var a = target_velocity.dot(target_velocity) - projectile_speed * projectile_speed
	var b = 2.0 * dist_to_target.dot(target_velocity)
	var c = dist_to_target.dot(dist_to_target)

	var discriminant = b*b - 4.0*a*c # quadratic eq. discriminant

	var intercept_time: float

	if discriminant < 0.0 or abs(a) < 0.001:
		# fallback: direct shot
		intercept_time = dist_to_target.length() / projectile_speed
	else:
		var sqrt_d = sqrt(discriminant) # finding roots via quadratic equation
		var t1 = (-b - sqrt_d) / (2.0 * a)
		var t2 = (-b + sqrt_d) / (2.0 * a)

		intercept_time = min(t1, t2)
		if intercept_time < 0.0:
			intercept_time = max(t1, t2)
		if intercept_time < 0.0:
			intercept_time = dist_to_target.length() / projectile_speed

	return target_position + target_velocity * intercept_time

func get_target_velocity(target: Node) -> Vector2:
	if target.has_method("get_velocity"):
		return target.velocity
	elif "velocity" in target:
		return target.velocity
	
	print("Target doesnt have velocity!")
	return Vector2.ZERO

func shoot():
	if current_target == null or not is_instance_valid(current_target) or not ready_to_fire or not is_aligned():
		return
	
	ready_to_fire = false
	$Timer.start()
	
	var new_cannonball = CANNONBALL.instantiate()

	cannon_mouth.add_child(new_cannonball)
	new_cannonball.global_position = cannon_mouth.global_position
	new_cannonball.global_rotation = cannon_mouth.global_rotation

	new_cannonball.setup(get_parent(), get_max_range())

func _on_timer_timeout():
	ready_to_fire = true
	
func is_aligned() -> bool:
	if last_direction_aimed == Vector2.ZERO:
		return false
	
	var forward = Vector2.RIGHT.rotated(sprite.global_rotation)
	var angle = forward.angle_to(last_direction_aimed)
	
	return abs(angle) <= FIRE_ANGLE_TOLERANCE

func get_range(dist: float) -> int:
	if dist < range_step: # short
		return 0
	elif dist < range_step * 2.0: # medium
		return 1
	elif dist <= max_range: # long
		return 2
	
	return -1 # outside

func get_max_range() -> float:
	return range_detection.shape.radius
