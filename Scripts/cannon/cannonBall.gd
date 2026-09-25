class_name Cannonball
extends Area2D

const PEAK_SCALE := 1.5

static var shots_fired := 0
static var shots_hit := 0

# Height isn't simulated, so this is the share of misses that pass through the rigging.
static var mast_strike_chance := 0.25

## Rolled at fire time; a miss flies through everything to its range limit.
var will_hit := true
## Set for shots at a part: the ball passes over the hull and strikes the part itself.
var aimed_part: Node2D = null

var travelled_distance := 0.0
var max_range := 0.0
var arc_distance := 0.0
var owner_node: Node = null
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

	# something with reach catches the mast or wheel on any contact, so a bad roll at them still lands
	var lands = will_hit or (aimed_part is PartHole and ammo.reach > 0.0)

	if (lands and _strikes_part(from)) or travelled_distance >= max_range:
		queue_free()

	sprite.rotation += ammo.spin * delta

	if arc_distance > 0.0:
		sprite.scale = base_scale * (1.0 + (PEAK_SCALE - 1.0) * arc_height(travelled_distance / arc_distance))

## 0 at launch, 1 halfway, 0 on landing and beyond.
static func arc_height(s: float) -> float:
	return maxf(0.0, 4.0 * s * (1.0 - s))

func _on_body_entered(body):
	# a shot at a part is up in the air as it passes over the hull
	if body == owner_node or aimed_part != null:
		return

	if not will_hit:
		_try_part_strike(body)
		return

	if body.has_method("apply_cannonball_hit"):
		var struck = body.apply_cannonball_hit(global_position, ammo.hole_damage)
		_log_hit(struck.name if struck else "")

	queue_free()


func _log_hit(target: String) -> void:
	shots_hit += 1
	print("Cannonball accuracy: %d/%d (%s%%)%s" % [
		shots_hit, shots_fired, format_percent(100.0 * shots_hit / shots_fired),
		" -> %s" % target if target else ""
	])

## To 3 significant figures; Godot has no %g.
static func format_percent(pct: float) -> String:
	var decimals := 0 if pct == 0.0 else clampi(2 - floori(log(pct) / log(10.0)), 0, 12)
	return String.num(pct, decimals)


## A crewmate who moved off the line or went below lets the ball fly on.
func _strikes_part(from: Vector2) -> bool:

	if not is_instance_valid(aimed_part):
		return false

	var at := aimed_part.global_position
	var struck: bool = (
		_hits_part(aimed_part._get_ship(), aimed_part is WheelHole, from, global_position) if aimed_part is PartHole
		else not (aimed_part is Crewmate and (aimed_part as Crewmate).location not in DeckGraph.EXPOSED_DECKS)
			and Geometry2D.get_closest_point_to_segment(at, from, global_position).distance_to(at) <= ShipHealthSystem.PART_RADIUS
	)

	if struck:
		# all of a part's holes sit in one spot, so name the part rather than the hole
		_log_hit(("wheel" if aimed_part is WheelHole else "mast") if aimed_part is PartHole else String(aimed_part.name))

	return struck


func _hits_part(ship: Sloop, wheel: bool, from: Vector2, to: Vector2) -> bool:

	return (
		ship.apply_wheel_hit(from, to, ammo.wheel_holes_per_hit, ammo.reach) if wheel
		else ship.apply_mast_hit(from, to, ammo.mast_holes_per_hit, ammo.reach)
	)


## A miss passing over a ship can still strike its mast or wheel, and stops there.
func _try_part_strike(body) -> void:

	if not body is Sloop or randf() >= mast_strike_chance:
		return

	var to = global_position + Vector2.RIGHT.rotated(global_rotation) * (max_range - travelled_distance)

	if _hits_part(body, false, global_position, to) or _hits_part(body, true, global_position, to):
		queue_free()
