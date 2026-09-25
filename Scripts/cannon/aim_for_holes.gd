class_name AimForHoles
extends RefCounted

## Pick a specific hole worth damaging, aim at it, and decide whether firing
## right now is actually the best use of the ball.
##
## Value of a ball is the flood rate it buys: how many grade points it lands (the clamp at 5
## makes topping up a partly-open hole worth less than opening a fresh one) weighted by how
## fast that deck actually floods. A lower-deck hole is worth several times a mid-deck one
## while the target is dry, and that advantage fades on its own as its water rises.

## A better-scoring hole is worth waiting for, but only this long past when we could
## otherwise have fired.
const DECK_HOLD_TOLERANCE := 0.25

## A ball must land at least this long after a hole comes into view, so we are not betting
## on an exposure that lasts a single frame.
const EXPOSURE_INSURANCE := 0.3

# ponytail: the anticipation scan is a linear walk of horizon/step samples against every
# hole. It only runs when nothing is currently damageable, so it stays off the hot path.
const ANTICIPATION_HORIZON := 8.0
const ANTICIPATION_STEP := 0.2

## SloopCollision's outline in ship space, with the node's own rotation and 0.58 scale already
## applied, wound bow-ward down the starboard side. test_aim_for_holes checks it still matches
## the scene, a copy being a copy.
const HULL := [
	Vector2(-150.8, 0.0), Vector2(-139.2, 29.0), Vector2(-104.4, 43.5), Vector2(-72.5, 43.5),
	Vector2(-34.8, 49.3), Vector2(0.0, 52.2), Vector2(31.9, 49.3), Vector2(89.9, 20.3),
	Vector2(120.64, 8.7), Vector2(149.06, 0.0), Vector2(120.64, -8.7), Vector2(89.9, -20.3),
	Vector2(31.9, -49.3), Vector2(0.0, -52.2), Vector2(-34.8, -49.3), Vector2(-72.5, -43.5),
	Vector2(-104.4, -43.5), Vector2(-139.2, -29.0),
]

# ponytail: a hole seen edge-on is behind its own hull. The cosine against the hull's real
# normal stands in for a full occlusion test; trace the segment against HULL if it ever
# misjudges.
const MIN_EXPOSURE := 0.35 # ~70 degrees off the hole's own normal

# ponytail: keyed on the rounded local position - holes never move in ship space, but to_local
# hands back a slightly different float every frame, which would miss an exact key every time.
static var _normals := {}
static var _footprints := {}


static func _static_init() -> void:
	if OS.is_debug_build():
		_self_check()


## Returns {aim_point, hole, fire_now}. [code]hole[/code] is null when falling back to the
## target's centre; [code]fire_now[/code] false means hold a loaded gun and keep slewing.
static func pick_shot(cannon: Cannon, shooter: Node2D, target: Node2D) -> Dictionary:

	var centre_shot = {"aim_point": target.global_position, "hole": null, "fire_now": true}
	var target_now = {"position": target.global_position, "rotation": target.rotation}
	var cannon_now = cannon_state(cannon, shooter, {
		"position": shooter.global_position,
		"rotation": shooter.rotation,
	})

	var damageable: Array[Dictionary] = []
	var spent: Array[Dictionary] = []

	for hole in target.action_points.hull_holes:
		var candidate = {"hole": hole, "local": target.to_local(hole.global_position)}

		if not is_hittable(cannon_now, candidate["local"], target_now, cannon.max_range):
			continue

		candidate["point"] = _world_position(candidate["local"], target_now)

		if hole.grade >= hole.max_grade:
			spent.append(candidate)
		else:
			damageable.append(candidate)

	if not damageable.is_empty():
		return _pick_damageable(cannon, target, damageable)

	return _anticipate(cannon, shooter, target, spent, centre_shot)


## Take the best-scoring hole when the barrel can be on it soon enough, otherwise take
## whatever is nearest — a hole the gun cannot reach in time is worth nothing.
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
	var range_to := func(candidate): return candidate["point"].distance_to(cannon_position)

	var best = damageable.reduce(func(a, b): return b if score.call(b) > score.call(a) else a)
	var nearest = damageable.reduce(
		func(a, b): return b if range_to.call(b) < range_to.call(a) else a
	)

	var ready_in = _ready_in(cannon)

	var wait_for_best = (
		maxf(ready_in, _slew_time(cannon, best["point"] - cannon_position))
		- maxf(ready_in, _slew_time(cannon, nearest["point"] - cannon_position))
	)

	var shot = best if wait_for_best <= DECK_HOLD_TOLERANCE else nearest
	return {"aim_point": shot["point"], "hole": shot["hole"], "fire_now": true}


## Everything in view is spent. Work out whether the two ships are about to turn a fresh
## hole into the open, and whether a ball can be put on it late enough to count.
static func _anticipate(
	cannon: Cannon,
	shooter: Node2D,
	target: Node2D,
	spent: Array[Dictionary],
	centre_shot: Dictionary
) -> Dictionary:

	var cannon_position = cannon.global_position
	var closest = spent.reduce(func(a, b): return (
		b
		if b["point"].distance_to(cannon_position) < a["point"].distance_to(cannon_position)
		else a
	))
	var spent_shot = centre_shot if closest == null else {
		"aim_point": closest["point"], "hole": closest["hole"], "fire_now": true
	}

	var exposure = _first_exposure(cannon, shooter, target)

	if exposure.is_empty():
		return spent_shot

	var aim_point: Vector2 = exposure["aim_point"]

	# measured from where the gun will be by then, not where it stands now
	var to_aim = aim_point - exposure["cannon_position"]
	var deadline = float(exposure["time"]) + EXPOSURE_INSURANCE
	var anticipated = {"aim_point": aim_point, "hole": exposure["hole"], "fire_now": false}

	# firing at the first chance we get still lands late enough to count: take the shot
	if _arrival(cannon, _ready_in(cannon), to_aim) >= deadline:
		anticipated["fire_now"] = true
		return anticipated

	# too early. The slack is worth a shot at a spent hole only if the reload after it still
	# leaves the anticipated shot late enough; otherwise sit on the aim and wait.
	var after_reload = _arrival(cannon, ReloadCannonAction.RELOAD_DURATION, to_aim)

	return spent_shot if after_reload >= deadline else anticipated


## First moment inside the horizon at which a hole worth damaging is in view, if any.
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

			if not is_hittable(future_cannon, local, target_states[index], cannon.max_range):
				continue

			return {
				"time": (index + 1) * ANTICIPATION_STEP,
				"hole": hole,
				"aim_point": _world_position(local, target_states[index]),
				"cannon_position": future_cannon["position"],
			}

	return {}


## Where the cannon's muzzle sits and which way its mount faces, for a given ship state.
static func cannon_state(cannon: Cannon, shooter: Node2D, ship_state: Dictionary) -> Dictionary:

	var mount_offset = shooter.to_local(cannon.global_position)

	return {
		"position": ship_state["position"] + mount_offset.rotated(ship_state["rotation"]),
		"rotation": ship_state["rotation"] + cannon.rotation,
	}


## A hole is worth shooting at only if it faces us squarely enough, sits inside the mount's
## arc, and is close enough to reach.
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


## Which way a hole faces, in ship space: the hull's outward normal where it is cut, blended
## from the panels around it by inverse square distance. The blend is what gives the bow hole a
## forward normal - both bow panels pull on it equally - and the shoulder holes one that is half
## forward, which is the difference between a shot and a graze on a bow-on target.
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


## Where a hole breaks the surface: out along its own normal to the hull outline. The nodes sit
## anywhere from 10 to 70px inside the plating, so this is the only point on a hole that a ball
## can actually strike, and the only one worth measuring an impact against.
static func hull_footprint(hole_local: Vector2) -> Vector2:

	var key = hole_local.round()

	if not _footprints.has(key):
		# 400 is longer than the ship, so the ray always clears the hull and the clip is the
		# stretch of it still inside - ending exactly where the hole breaks the surface
		var ray = PackedVector2Array([key, key + outward_normal(key) * 400.0])
		var inside = Geometry2D.intersect_polyline_with_polygon(ray, PackedVector2Array(HULL))

		_footprints[key] = key if inside.is_empty() else inside[0][-1]

	return _footprints[key]


# ponytail: defaults are a cannonball's, written out because the self-check runs before
# Ammunition's statics exist.
## Flood rate bought by one ball: grade points landed, weighted by how fast that deck floods.
static func score_for(grade: int, deck_efficiency: float, damage := 3) -> float:

	return mini(damage, ShipHolePoint.MAX_GRADE - grade) * deck_efficiency


static func _world_position(hole_local: Vector2, ship_state: Dictionary) -> Vector2:

	return ship_state["position"] + hole_local.rotated(ship_state["rotation"])


static func _slew_time(cannon: Cannon, aim_direction: Vector2) -> float:

	var barrel = Vector2.RIGHT.rotated(cannon.sprite.global_rotation)

	return absf(barrel.angle_to(aim_direction)) / Cannon.ROTATION_SPEED


## Seconds until the gun is loaded again, asked of the gunner working it. Cannons only track
## a target while the duty controller exists, so it is always there to ask.
static func _ready_in(cannon: Cannon) -> float:

	return cannon.get_parent().cannon_duty_controller.get_reload_remaining(cannon)


## When a ball would land, given the earliest the gun could go off.
static func _arrival(cannon: Cannon, fire_delay: float, to_aim: Vector2) -> float:

	return (
		maxf(fire_delay, _slew_time(cannon, to_aim))
		+ to_aim.length() / cannon.ammo.speed
	)


static func _self_check() -> void:

	# holes face out the side they are cut into; the bow hole faces forward
	assert(outward_normal(Vector2(-63.0, -29.0)).dot(Vector2.UP) > 0.9)
	assert(outward_normal(Vector2(-63.0, 29.0)).dot(Vector2.DOWN) > 0.9)
	assert(outward_normal(Vector2(80.0, 0.0)).dot(Vector2.RIGHT) > 0.99)

	# and the bow shoulder faces half forward, which is what makes it a shot when bow-on
	assert(outward_normal(Vector2(67.0, -20.0)).dot(Vector2.RIGHT) > MIN_EXPOSURE)

	# the bow hole surfaces at the stem, 69px ahead of its own node; the shoulder 10px out
	assert(hull_footprint(Vector2(80.0, 0.0)).distance_to(Vector2(149.06, 0.0)) < 1.0)
	assert(hull_footprint(Vector2(67.0, 20.0)).distance_to(Vector2(72.1, 29.2)) < 1.0)

	var lower = ShipHealthSystem.STILL_LOWER_HOLE_EFFICIENCY
	var mid = ShipHealthSystem.STILL_MID_HOLE_EFFICIENCY

	# while the target is dry: open a fresh lower hole, then finish it, before touching the mid deck
	assert(score_for(0, lower) > score_for(3, lower))
	assert(score_for(3, lower) > score_for(0, mid))

	# once its mid deck is under water both decks flood alike, so that last ordering flips
	# and a fresh mid hole outranks topping up a lower one
	var flooded_mid = lower

	assert(score_for(0, flooded_mid) > score_for(3, lower))

	# topping a hole up beats scraping the last point off it
	assert(score_for(3, lower) > score_for(4, lower))

	# a spent hole is worth nothing at all
	assert(is_zero_approx(score_for(ShipHolePoint.MAX_GRADE, lower)))
