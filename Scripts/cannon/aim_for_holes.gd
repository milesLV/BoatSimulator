class_name AimForHoles
extends RefCounted

## Picks which hole to shoot at, and whether firing now is the best use of the ball.

## Seconds past the earliest possible shot worth waiting for a better-scoring hole.
const DECK_HOLD_TOLERANCE := 0.25

## Seconds a hole must have been in view before the ball lands.
const EXPOSURE_INSURANCE := 0.3

const ANTICIPATION_HORIZON := 8.0
const ANTICIPATION_STEP := 0.2

## Copy of SloopCollision's outline in ship space; test_aim_for_holes checks it still matches.
const HULL := [
	Vector2(-150.8, 0.0), Vector2(-139.2, 29.0), Vector2(-104.4, 43.5), Vector2(-72.5, 43.5),
	Vector2(-34.8, 49.3), Vector2(0.0, 52.2), Vector2(31.9, 49.3), Vector2(89.9, 20.3),
	Vector2(120.64, 8.7), Vector2(149.06, 0.0), Vector2(120.64, -8.7), Vector2(89.9, -20.3),
	Vector2(31.9, -49.3), Vector2(0.0, -52.2), Vector2(-34.8, -49.3), Vector2(-72.5, -43.5),
	Vector2(-104.4, -43.5), Vector2(-139.2, -29.0),
]

const MIN_EXPOSURE := 0.35 # ~70 degrees off the hole's own normal

# Keyed on rounded positions: to_local returns slightly different floats every frame.
static var _normals := {}
static var _footprints := {}


static func _static_init() -> void:
	if OS.is_debug_build():
		_self_check()


## Returns {aim_point, hole (null = target centre), fire_now (false = hold and keep slewing)}.
static func pick_shot(cannon: Cannon, shooter: Node2D, target: Node2D) -> Dictionary:

	var target_now = {"position": target.global_position, "rotation": target.rotation}
	var cannon_now = cannon_state(cannon, shooter, {
		"position": shooter.global_position,
		"rotation": shooter.rotation,
	})

	var damageable: Array[Dictionary] = []
	var spent: Array[Dictionary] = []

	for hole in target.action_points.hull_holes:
		var candidate = {"hole": hole, "local": target.to_local(hole.global_position)}

		if not is_hittable(cannon_now, candidate["local"], target_now, cannon.ammo.max_range):
			continue

		candidate["point"] = _world_position(candidate["local"], target_now)

		if hole.grade >= hole.max_grade:
			spent.append(candidate)
		else:
			damageable.append(candidate)

	if not damageable.is_empty():
		return _pick_damageable(cannon, target, damageable)

	return _anticipate(cannon, shooter, target, spent)


static func _pick_damageable(
	cannon: Cannon,
	target: Node2D,
	damageable: Array[Dictionary]
) -> Dictionary:

	var cannon_position = cannon.global_position

	var score := func(candidate): return score_for(
		candidate["hole"].grade,
		target.health_system.get_deck_efficiency(candidate["hole"].deck),
		cannon.ammo.hole_damage
	)

	var best = damageable.reduce(func(a, b): return b if score.call(b) > score.call(a) else a)
	var nearest = _nearest(damageable, cannon_position)

	var ready_in = _ready_in(cannon)

	var wait_for_best = (
		maxf(ready_in, _slew_time(cannon, best["point"] - cannon_position))
		- maxf(ready_in, _slew_time(cannon, nearest["point"] - cannon_position))
	)

	var shot = best if wait_for_best <= DECK_HOLD_TOLERANCE else nearest
	return {"aim_point": shot["point"], "hole": shot["hole"], "fire_now": true}


## Everything in view is spent, so aim for a fresh hole about to come into view.
static func _anticipate(
	cannon: Cannon,
	shooter: Node2D,
	target: Node2D,
	spent: Array[Dictionary]
) -> Dictionary:

	var closest = _nearest(spent, cannon.global_position)
	var spent_shot = {"aim_point": target.global_position, "hole": null, "fire_now": true} if closest == null else {
		"aim_point": closest["point"], "hole": closest["hole"], "fire_now": true
	}

	var exposure = _first_exposure(cannon, shooter, target)

	if exposure.is_empty():
		return spent_shot

	var aim_point: Vector2 = exposure["aim_point"]

	var to_aim = aim_point - exposure["cannon_position"]
	var deadline = float(exposure["time"]) + EXPOSURE_INSURANCE
	var anticipated = {"aim_point": aim_point, "hole": exposure["hole"], "fire_now": false}

	if _arrival(cannon, _ready_in(cannon), to_aim) >= deadline:
		anticipated["fire_now"] = true
		return anticipated

	# Too early: spend the wait on a spent hole only if the reload still makes the deadline.
	var after_reload = _arrival(cannon, ReloadCannonAction.RELOAD_DURATION, to_aim)

	return spent_shot if after_reload >= deadline else anticipated


static func _first_exposure(cannon: Cannon, shooter: Node2D, target: Node2D) -> Dictionary:

	var shooter_states = shooter.motion_predictor.series(
		ANTICIPATION_HORIZON, ANTICIPATION_STEP, true
	)
	var target_states = target.motion_predictor.series(
		ANTICIPATION_HORIZON, ANTICIPATION_STEP, false
	)

	for index in mini(shooter_states.size(), target_states.size()):
		var future_cannon = cannon_state(cannon, shooter, shooter_states[index])

		for hole in target.action_points.hull_holes:

			if hole.grade >= hole.max_grade:
				continue

			var local = target.to_local(hole.global_position)

			if not is_hittable(future_cannon, local, target_states[index], cannon.ammo.max_range):
				continue

			return {
				"time": (index + 1) * ANTICIPATION_STEP,
				"hole": hole,
				"aim_point": _world_position(local, target_states[index]),
				"cannon_position": future_cannon["position"],
			}

	return {}


static func _nearest(candidates: Array, from: Vector2):

	return candidates.reduce(func(a, b): return b if b["point"].distance_to(from) < a["point"].distance_to(from) else a)


static func cannon_state(cannon: Cannon, shooter: Node2D, ship_state: Dictionary) -> Dictionary:

	var mount_offset = shooter.to_local(cannon.global_position)

	return {
		"position": ship_state["position"] + mount_offset.rotated(ship_state["rotation"]),
		"rotation": ship_state["rotation"] + cannon.rotation,
	}


static func is_hittable(
	cannon_now: Dictionary,
	hole_local: Vector2,
	target_state: Dictionary,
	max_range: float
) -> bool:

	var hole_position = _world_position(hole_local, target_state)
	var to_cannon = cannon_now["position"] - hole_position
	var distance = to_cannon.length()

	if distance <= 0.0 or distance > max_range:
		return false

	var facing = outward_normal(hole_local).rotated(target_state["rotation"])

	if (to_cannon / distance).dot(facing) < MIN_EXPOSURE:
		return false

	return Cannon.arc_contains(cannon_now["rotation"], -to_cannon)


## Hull normals blended by inverse square distance, so the bow hole faces forward.
static func outward_normal(hole_local: Vector2) -> Vector2:

	var key = hole_local.round()

	if not _normals.has(key):
		var blended := Vector2.ZERO

		for index in HULL.size():
			var from: Vector2 = HULL[index]
			var to: Vector2 = HULL[(index + 1) % HULL.size()]
			var nearest = Geometry2D.get_closest_point_to_segment(key, from, to)

			blended += (to - from).rotated(PI / 2.0).normalized() / maxf(
				nearest.distance_squared_to(key), 1.0
			)

		_normals[key] = blended.normalized()

	return _normals[key]


## Where a hole breaks the hull surface; the hole nodes sit 10-70px inside the plating.
static func hull_footprint(hole_local: Vector2) -> Vector2:

	var key = hole_local.round()

	if not _footprints.has(key):
		# 400 is longer than the ship, so the clipped ray ends where it exits the hull
		var ray = PackedVector2Array([key, key + outward_normal(key) * 400.0])
		var inside = Geometry2D.intersect_polyline_with_polygon(ray, PackedVector2Array(HULL))

		_footprints[key] = key if inside.is_empty() else inside[0][-1]

	return _footprints[key]


# Default is a cannonball's damage; Ammunition's statics don't exist yet when _self_check runs.
static func score_for(grade: int, deck_efficiency: float, damage := 3) -> float:

	return mini(damage, ShipHolePoint.MAX_GRADE - grade) * deck_efficiency


static func _world_position(hole_local: Vector2, ship_state: Dictionary) -> Vector2:

	return ship_state["position"] + hole_local.rotated(ship_state["rotation"])


static func _slew_time(cannon: Cannon, aim_direction: Vector2) -> float:

	var barrel = Vector2.RIGHT.rotated(cannon.sprite.global_rotation)

	return absf(barrel.angle_to(aim_direction)) / Cannon.ROTATION_SPEED


# Cannons only track a target while the duty controller exists.
static func _ready_in(cannon: Cannon) -> float:

	return cannon.get_parent().cannon_duty_controller.get_reload_remaining(cannon)


static func _arrival(cannon: Cannon, fire_delay: float, to_aim: Vector2) -> float:

	return (
		maxf(fire_delay, _slew_time(cannon, to_aim))
		+ to_aim.length() / cannon.ammo.speed
	)


static func _self_check() -> void:

	assert(outward_normal(Vector2(-63.0, -29.0)).dot(Vector2.UP) > 0.9)
	assert(outward_normal(Vector2(-63.0, 29.0)).dot(Vector2.DOWN) > 0.9)
	assert(outward_normal(Vector2(80.0, 0.0)).dot(Vector2.RIGHT) > 0.99)

	assert(outward_normal(Vector2(67.0, -20.0)).dot(Vector2.RIGHT) > MIN_EXPOSURE)

	assert(hull_footprint(Vector2(80.0, 0.0)).distance_to(Vector2(149.06, 0.0)) < 1.0)
	assert(hull_footprint(Vector2(67.0, 20.0)).distance_to(Vector2(72.1, 29.2)) < 1.0)

	var lower = ShipHealthSystem.STILL_LOWER_HOLE_EFFICIENCY
	var mid = ShipHealthSystem.STILL_MID_HOLE_EFFICIENCY

	assert(score_for(0, lower) > score_for(3, lower))
	assert(score_for(3, lower) > score_for(0, mid))

	assert(score_for(3, lower) > score_for(4, lower))

	assert(is_zero_approx(score_for(ShipHolePoint.MAX_GRADE, lower)))
