class_name Cannon
extends Node2D

@onready var sprite = $CannonSprite
@onready var cannon_mouth = $CannonSprite/CannonMouth
@onready var range_area = $CannonRange
@onready var range_detection = $CannonRange/CannonDetection

const MAX_ANGLE = deg_to_rad(45)
const ROTATION_SPEED = deg_to_rad(18) # 18 degrees/sec
const FIRE_ANGLE_TOLERANCE = deg_to_rad(2) # won't fire until cannon lined up with target with this error

@export var broadside: CannonSide.Value

enum AimTarget { HULL, MAST, CANNON, WHEEL, CREW }
## The smaller the part, the less often a shot that goes over the hull finds it.
const AIM_ACCURACY := {AimTarget.MAST: 0.8, AimTarget.CANNON: 0.7, AimTarget.WHEEL: 0.6, AimTarget.CREW: 0.5}

## What the next shot will be; switching needs no reload.
var ammo := Ammunition.CANNONBALL:
	set(value):
		ammo = value
		if is_node_ready():
			_show_range()
var max_range: float:
	get: return ammo.max_range

var loaded := true
var current_target = null
var last_direction_aimed: Vector2 = Vector2.ZERO
var last_aim_point: Vector2 = Vector2.ZERO

## Set by AimForHoles: the hole this shot is meant for, and whether it is worth firing
## at all right now. Holding still slews the barrel, it just does not pull the trigger.
var target_hole: ShipHolePoint = null
var hold_fire := false

## Set from whoever mans it: HULL goes hunting holes, the rest aim straight at that part.
var aim_target := AimTarget.HULL
## The part a non-hull aim is on this frame; null while it hunts holes instead.
var aimed_part: Node2D = null

var tracking_enabled := false
var tracking_target: Node = null

## The drawn cone at the detection circle's full size. That circle is shared by every cannon, so
## it stays at the longest range and only the drawing shrinks to what is loaded.
@onready var _full_range_scale: Vector2 = range_area.get_node(^"VisualRange").scale

func _ready():
	_show_range()

func _show_range() -> void:
	range_area.get_node(^"VisualRange").scale = _full_range_scale * ammo.max_range / range_detection.shape.radius

func _physics_process(delta):
	current_target = null
	target_hole = null
	hold_fire = false

	if not tracking_enabled or not is_instance_valid(tracking_target):
		return

	aimed_part = _aimed_part(tracking_target)

	var shot = (
		AimForHoles.pick_shot(self, get_parent(), tracking_target) if aimed_part == null
		else {"aim_point": aimed_part.global_position, "hole": null, "fire_now": true}
	)

	var aim_point: Vector2 = shot["aim_point"]
	target_hole = shot["hole"]
	hold_fire = not shot["fire_now"]

	if arc_contains(global_rotation, aim_point - global_position) and global_position.distance_to(aim_point) <= max_range:
		current_target = tracking_target
		aim_point = (
			calculate_intercept_position(aim_point, tracking_target.velocity) if aimed_part == null
			else _part_intercept(aimed_part)
		)

	last_aim_point = aim_point
	last_direction_aimed = (aim_point - global_position).normalized()

	var angle_to_aim = Vector2.RIGHT.rotated(global_rotation).angle_to(last_direction_aimed)
	sprite.rotation = move_toward(sprite.rotation, clamp(angle_to_aim, -MAX_ANGLE, MAX_ANGLE), ROTATION_SPEED * delta)

## What on [param ship] a non-hull aim is after: its mast, nearest cannon, wheel or nearest
## crewmate up top. Null for the hull, and while every crewmate is below decks.
func _aimed_part(ship: Node2D) -> Node2D:

	var nearest := func(nodes: Array) -> Node2D:
		return nodes.reduce(func(best, node): return (
			node if best == null or global_position.distance_to(node.global_position)
				< global_position.distance_to(best.global_position) else best
		), null)

	match aim_target:
		AimTarget.MAST:
			return nearest.call(ship.action_points.mast_holes)
		AimTarget.CANNON:
			return nearest.call(ship.cannons)
		AimTarget.WHEEL:
			return ship.action_points.get_station(&"Wheel")
		AimTarget.CREW:
			return nearest.call(ship.get_crewmates().filter(
				func(crewmate): return crewmate.location in DeckGraph.EXPOSED_DECKS
			))

	return null


## Where [param part] will be when a ball fired now gets there. A part is small enough that
## leading the ship's drift alone misses it once the ship is turning, so this rides the turn too.
func _part_intercept(part: Node2D) -> Vector2:

	var local = tracking_target.to_local(part.global_position)
	var at := part.global_position

	# the flight time depends on where it lands; twice round is plenty
	for i in 2:
		var flight = global_position.distance_to(at) / ammo.speed
		at = AimForHoles._world_position(local, tracking_target.motion_predictor.at(flight))

	return at


## The firing arc rule on its own, so the aim code can ask it of a mount bearing the ship
## has not swung round to yet.
static func arc_contains(mount_rotation: float, direction: Vector2) -> bool:
	return absf(Vector2.RIGHT.rotated(mount_rotation).angle_to(direction)) <= MAX_ANGLE

func calculate_intercept_position(target_position: Vector2, target_velocity: Vector2) -> Vector2:

	var projectile_speed := ammo.speed
	var dist_to_target = target_position - global_position

	# time when a ball and the target arrive at the same point
	var a = target_velocity.dot(target_velocity) - projectile_speed * projectile_speed
	var b = 2.0 * dist_to_target.dot(target_velocity)
	var c = dist_to_target.dot(dist_to_target)

	var discriminant = b*b - 4.0*a*c # quadratic eq. discriminant

	# soonest intercept that is actually in the future; a direct shot when there is none
	var intercept_time = dist_to_target.length() / projectile_speed

	if discriminant >= 0.0 and abs(a) >= 0.001:
		var sqrt_d = sqrt(discriminant)
		var roots = [(-b - sqrt_d) / (2.0 * a), (-b + sqrt_d) / (2.0 * a)].filter(
			func(root): return root > 0.0
		)

		if not roots.is_empty():
			intercept_time = roots.min()

	return target_position + target_velocity * intercept_time

func can_fire_now() -> bool:

	return (
		loaded
		and not hold_fire
		and is_instance_valid(current_target)
		# the barrel has come round to within tolerance of where it was last told to aim
		and last_direction_aimed != Vector2.ZERO
		and absf(Vector2.RIGHT.rotated(sprite.global_rotation).angle_to(last_direction_aimed)) <= FIRE_ANGLE_TOLERANCE
	)


func fire() -> bool:

	if not can_fire_now():
		return false

	loaded = false

	var new_cannonball = ammo.scene.instantiate()

	cannon_mouth.add_child(new_cannonball)
	new_cannonball.global_position = cannon_mouth.global_position
	new_cannonball.global_rotation = cannon_mouth.global_rotation

	new_cannonball.owner_node = get_parent()
	new_cannonball.ammo = ammo
	new_cannonball.max_range = max_range
	new_cannonball.arc_distance = minf(cannon_mouth.global_position.distance_to(last_aim_point), max_range)

	var hull_odds = CannonAccuracy.for_shot(self, get_parent(), current_target)

	if aimed_part == null:
		new_cannonball.will_hit = randf() < hull_odds
		return true

	# a shot at a part flips the hull roll: what would have struck the hull goes over it, the rest
	# is caught by it, and the part's size says whether one that goes over finds it
	var over = randf() < hull_odds
	new_cannonball.aimed_part = aimed_part if over else null
	new_cannonball.will_hit = not over or randf() < AIM_ACCURACY[aim_target]

	return true
