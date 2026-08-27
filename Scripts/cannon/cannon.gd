class_name Cannon
extends Node2D

@onready var sprite = $CannonSprite
@onready var cannon_mouth = $CannonSprite/CannonMouth
@onready var range_area = $CannonRange
@onready var range_detection = $CannonRange/CannonDetection

const CANNONBALL = preload("res://Scenes/cannonball.tscn")
const MAX_ANGLE = deg_to_rad(45)
const ROTATION_SPEED = deg_to_rad(18) # 18 degrees/sec
const FIRE_ANGLE_TOLERANCE = deg_to_rad(2) # won't fire until cannon lined up with target with this error

@export var broadside: CannonSide.Value

var max_range := 0.0

var loaded := true
var current_target = null
var last_direction_aimed: Vector2 = Vector2.ZERO

var tracking_enabled := false
var tracking_target: Node = null

func _ready():
	await get_tree().process_frame
	max_range = range_detection.shape.radius

func _physics_process(delta):
	current_target = null

	if not tracking_enabled or tracking_target == null or not is_instance_valid(tracking_target):
		return

	var aim_point: Vector2 = tracking_target.global_position

	if is_in_arc(aim_point) and global_position.distance_to(aim_point) <= max_range:
		current_target = tracking_target
		aim_point = calculate_intercept_position(
			global_position,
			aim_point,
			tracking_target.velocity,
			500.0
		)

	aim_at_position(aim_point, delta)

func is_in_arc(target_pos: Vector2) -> bool:
	var to_target = (target_pos - global_position).normalized()
	return abs(Vector2.RIGHT.rotated(global_rotation).angle_to(to_target)) <= MAX_ANGLE

func aim_at_position(target_position: Vector2, delta: float):
	var shooter_position = global_position
	var aim_direction = (target_position - shooter_position).normalized()

	last_direction_aimed = aim_direction

	var current_forward = Vector2.RIGHT.rotated(global_rotation)
	var angle_to_target = current_forward.angle_to(aim_direction)
	var clamped_angle = clamp(angle_to_target, -MAX_ANGLE, MAX_ANGLE)

	sprite.rotation = move_toward(sprite.rotation, clamped_angle, ROTATION_SPEED * delta)

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

func can_fire_now() -> bool:

	return (
		loaded
		and current_target != null
		and is_instance_valid(current_target)
		and is_aligned()
	)


func fire() -> bool:

	if not can_fire_now():
		return false

	loaded = false

	var new_cannonball = CANNONBALL.instantiate()

	cannon_mouth.add_child(new_cannonball)
	new_cannonball.global_position = cannon_mouth.global_position
	new_cannonball.global_rotation = cannon_mouth.global_rotation

	new_cannonball.owner_node = get_parent()
	new_cannonball.max_range = max_range

	return true

func is_aligned() -> bool:
	if last_direction_aimed == Vector2.ZERO:
		return false

	var forward = Vector2.RIGHT.rotated(sprite.global_rotation)
	var angle = forward.angle_to(last_direction_aimed)

	return abs(angle) <= FIRE_ANGLE_TOLERANCE
