class_name Cannonball
extends Area2D

## Sprite size at the top of the arc, relative to launch and landing size.
const PEAK_SCALE := 1.5
## How close an aimed shot has to pass a part to take it, about a crewmate's width.
const PART_HIT_RADIUS := 8.0

# ponytail: whole-run totals for the session, printed as they change. A stats autoload if
# they ever need to outlive the run.
static var shots_fired := 0
static var shots_hit := 0

# ponytail: height is only drawn (arc_height), not simulated, so this chance stands in for how
# much of a miss goes through the rigging rather than over it. Tests set it to 0 or 1.
static var mast_strike_chance := 0.25

## False when the accuracy roll at fire time said this shot missed: it flies on through
## everything and expires at its range limit.
var will_hit := true
## Set on a shot at a part that went over the hull: it sails on over it, and a good one comes
## down on the part if it is still where it was aimed.
var aimed_part: Node2D = null

var travelled_distance := 0.0
var max_range := 0.0
## How far the gunner lobbed it: the arc comes back down to deck height here.
var arc_distance := 0.0
var owner_node: Node = null
## What was fired: how fast it flies and what it does to what it hits.
var ammo := Ammunition.CANNONBALL

@onready var sprite: Sprite2D = $CannonballSprite
@onready var base_scale := sprite.scale

func _ready():
	shots_fired += 1

func _physics_process(delta):
	var direction = Vector2.RIGHT.rotated(global_rotation)
	var from := global_position

	global_position += ammo.speed * direction * delta
	travelled_distance += ammo.speed * delta

	# something with reach catches the mast on any contact, so a bad roll at it still lands
	var lands = will_hit or (aimed_part is MastHole and ammo.mast_reach > 0.0)

	if (lands and _strikes_part(from)) or travelled_distance >= max_range:
		queue_free()

	sprite.rotation += ammo.spin * delta

	if arc_distance > 0.0:
		sprite.scale = base_scale * (1.0 + (PEAK_SCALE - 1.0) * arc_height(travelled_distance / arc_distance))

## Height as a fraction of the peak at arc progress s: 0 at launch, 1 halfway, 0 on landing,
## and 0 past it, so a miss that flies on stays at deck size.
static func arc_height(s: float) -> float:
	return maxf(0.0, 4.0 * s * (1.0 - s))

func _on_body_entered(body):
	# a shot at a part is up in the air as it passes over the hull
	if body == owner_node or aimed_part != null:
		return

	if not will_hit:
		_try_mast_strike(body)
		return

	if body.has_method("apply_cannonball_hit"):
		_log_hit(body.apply_cannonball_hit(global_position, ammo.hole_damage))

	queue_free()


func _log_hit(target: Node) -> void:
	shots_hit += 1
	print("Cannonball accuracy: %d/%d (%s%%)%s" % [
		shots_hit, shots_fired, format_percent(100.0 * shots_hit / shots_fired),
		" -> %s" % target.name if target != null else ""
	])

## A percentage to 3 significant figures: shift the decimals by the magnitude of the value.
static func format_percent(pct: float) -> String:
	var decimals := 0 if pct == 0.0 else clampi(2 - floori(log(pct) / log(10.0)), 0, 12)
	return String.num(pct, decimals)


## Whether the flight since [param from] came down on its part: the mast takes a mast strike,
## anything else just stops it for now. One that moved off the line, or a crewmate who went
## below, lets it fly on.
func _strikes_part(from: Vector2) -> bool:

	if not is_instance_valid(aimed_part):
		return false

	var at := aimed_part.global_position
	var struck: bool = (
		aimed_part._get_ship().apply_mast_hit(from, global_position, ammo.mast_holes_per_hit, ammo.mast_reach) if aimed_part is MastHole
		else not (aimed_part is Crewmate and (aimed_part as Crewmate).location not in DeckGraph.EXPOSED_DECKS)
			and Geometry2D.get_closest_point_to_segment(at, from, global_position).distance_to(at) <= PART_HIT_RADIUS
	)

	if struck:
		_log_hit(aimed_part)

	return struck


## A miss goes on over the ship, so hand it the flight it has left and let the ship say
## whether that crossed its mast. A ball that finds the mast stops there, and still counts
## as the miss it was.
func _try_mast_strike(body) -> void:

	if not body.has_method("apply_mast_hit") or randf() >= mast_strike_chance:
		return

	var remaining = Vector2.RIGHT.rotated(global_rotation) * (max_range - travelled_distance)

	if body.apply_mast_hit(global_position, global_position + remaining, ammo.mast_holes_per_hit, ammo.mast_reach):
		queue_free()
