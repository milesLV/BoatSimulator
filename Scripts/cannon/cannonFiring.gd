extends Node2D

const MAX_ANGLE = deg_to_rad(45)
const ROTATION_SPEED = deg_to_rad(18) # 18 degrees/sec

@onready var pivot = $CannonPivot
@onready var sprite = $CannonPivot/CannonSprite
@onready var cannon_mouth = $CannonPivot/CannonSprite/CannonMouth

@onready var sectors = [
	$CannonRange/RangeSector1,
	$CannonRange/RangeSector2,
	$CannonRange/RangeSector3
]

@onready var range_manager = $CannonRange

var ready_to_fire = true
var current_target = null
var current_ring = -1

func _ready():
	await get_tree().process_frame
	for sector in sectors:
		sector.target_entered.connect(_on_target_entered)
		sector.target_exited.connect(_on_target_exited)

func _on_target_entered(body, ring_index):
	print("ENTER:", body.name, "ring:", ring_index)
	if body == get_parent().get_parent():
		print("IGNORED SELF")
		return
	current_target = body
	current_ring = ring_index
	if ready_to_fire:
		call_deferred(&"shoot")

func _on_target_exited(body):
	if body != current_target:
		return

	# Check if the body is STILL inside any sector
	for sector in sectors:
		if body in sector.get_overlapping_bodies():
			return  # Still in another ring → DO NOT clear

	# Only clear if fully out of all sectors
	current_target = null
	current_ring = -1

func _physics_process(_delta):
	if current_target == null or not is_instance_valid(current_target):
		current_target = null
		current_ring = -1
		return

	var target_pos = current_target.global_position
	var shooter_pos = pivot.global_position

	var target_velocity = Vector2.ZERO

	# Get velocity safely
	if current_target.has_method("get_velocity"):
		target_velocity = current_target.velocity
	elif "velocity" in current_target:
		target_velocity = current_target.velocity

	var projectile_speed = 500.0

	var r = target_pos - shooter_pos
	var v = target_velocity

	# Quadratic coefficients
	var a = v.dot(v) - projectile_speed * projectile_speed
	var b = 2.0 * r.dot(v)
	var c = r.dot(r)

	var t = 0.0

	# Solve quadratic
	var discriminant = b * b - 4.0 * a * c

	if discriminant < 0 or abs(a) < 0.001:
		# No valid solution → fallback to direct aim
		t = r.length() / projectile_speed
	else:
		var sqrt_d = sqrt(discriminant)

		var t1 = (-b - sqrt_d) / (2.0 * a)
		var t2 = (-b + sqrt_d) / (2.0 * a)

		# Pick smallest positive time
		t = min(t1, t2)
		if t < 0:
			t = max(t1, t2)

		if t < 0:
			# Both negative → fallback
			t = r.length() / projectile_speed

	# Predicted intercept point
	var predicted_pos = target_pos + v * t

	# Direction to aim
	var to_target = (predicted_pos - shooter_pos).normalized()
	var forward = Vector2.RIGHT.rotated(pivot.global_rotation)

	var angle_diff = forward.angle_to(to_target)
	var clamped_diff = clamp(angle_diff, -MAX_ANGLE, MAX_ANGLE)

	var target_rotation = pivot.rotation + clamped_diff
	sprite.rotation = move_toward(
		sprite.rotation,
		target_rotation,
		ROTATION_SPEED * _delta
	)

func shoot():
	if current_target == null or not is_instance_valid(current_target):
		return
	
	if not ready_to_fire:
		return
	
	ready_to_fire = false
	$Timer.start()
	
	const CANNONBALL = preload("res://Scenes/cannonball.tscn")
	var new_cannonball = CANNONBALL.instantiate()

	cannon_mouth.add_child(new_cannonball)
	new_cannonball.global_position = cannon_mouth.global_position
	new_cannonball.global_rotation = cannon_mouth.global_rotation

	new_cannonball.range_manager = range_manager
	new_cannonball.setup(get_parent())

func _on_timer_timeout():
	ready_to_fire = true
	if current_target == null or not is_instance_valid(current_target):
		return

	if current_ring == -1: # if enemy has not entered / has exited
		return

	shoot()
