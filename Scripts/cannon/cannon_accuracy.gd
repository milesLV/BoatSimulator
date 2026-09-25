class_name CannonAccuracy
extends RefCounted

## Chance that a shot connects, given how hard the shot is.
##
## Error is modelled as a Gaussian angular dispersion around the aim point, with the
## independent sources added in quadrature. Hit chance then falls out of how much of the
## target that dispersion covers, on two axes: cross-range (did it go wide) and down-range
## (did it go over or short).

const SIGMA_BASE := deg_to_rad(0.5) # irreducible gun/crew error
const K_RANGE := deg_to_rad(5.0) # elevation guesswork, at full range
const K_SLEW := 0.12 # rad of error per rad/sec the firing ship is turning
const K_LEAD := 0.20 # fraction of the lead angle left unresolved

# ponytail: one nominal silhouette for the only hull in the game, between the Sloop's
# ~300px length and ~104px beam. Measure the target's collision shape if a second hull ships.
const HULL_HALF_SIZE := 100.0


static func _static_init() -> void:
	if OS.is_debug_build():
		_self_check()


static func hit_chance(
	distance: float,
	max_range: float,
	own_turn_rate: float,
	relative_speed: float,
	ball_speed := 500.0 # a cannonball's
) -> float:

	if distance <= HULL_HALF_SIZE:
		return 1.0

	var range_fraction = distance / max_range

	var sigma_angle = sqrt(
		SIGMA_BASE * SIGMA_BASE
		+ pow(K_RANGE * range_fraction * range_fraction, 2.0)
		+ pow(K_SLEW * abs(own_turn_rate), 2.0)
		+ pow(K_LEAD * relative_speed / ball_speed, 2.0) # flight time over lead distance
	)

	var cross_chance = _gaussian_within(atan(HULL_HALF_SIZE / distance), sigma_angle)
	var down_chance = _gaussian_within(HULL_HALF_SIZE / distance, sigma_angle)

	return cross_chance * down_chance


## Same thing, reading the conditions off the ships involved.
static func for_shot(cannon: Node2D, shooter: Node2D, target: Node2D) -> float:

	if cannon == null or shooter == null or target == null:
		return 0.0

	return hit_chance(
		cannon.global_position.distance_to(target.global_position),
		cannon.max_range,
		shooter.movement_controller.current_angular_velocity,
		(target.velocity - shooter.velocity).length(),
		cannon.ammo.speed
	)


## Fraction of a zero-mean Gaussian falling within +/- half_width. erf(x) ~= tanh(1.2028x).
static func _gaussian_within(half_width: float, sigma: float) -> float:

	return tanh(1.2028 * half_width / (sigma * sqrt(2.0)))


static func _self_check() -> void:

	# point-blank at a sitting duck while under way: cannot realistically miss
	assert(hit_chance(150.0, 1200.0, 0.0, 300.0) > 0.98)

	# parallel run, matched speed: the lead term vanishes, so range barely matters
	assert(hit_chance(600.0, 1200.0, 0.0, 0.0) > 0.9)

	# max range at a target crossing at full speed: roughly the Trafalgar hit rate
	var long_shot = hit_chance(1200.0, 1200.0, 0.0, 300.0)
	assert(long_shot > 0.05 and long_shot < 0.30)

	# hauling the helm over throws the shot
	assert(hit_chance(400.0, 1200.0, 1.5, 0.0) < hit_chance(400.0, 1200.0, 0.0, 0.0))
