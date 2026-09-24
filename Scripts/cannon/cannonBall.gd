class_name Cannonball
extends Area2D

const SPEED := 500
const CANNONBALL_HOLE_DAMAGE := 3
## Sprite size at the top of the arc, relative to launch and landing size.
const PEAK_SCALE := 1.5

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
## A hit aimed at the mast: it flies on over the hull and always takes the mast if it crosses it.
var strikes_mast := false

var travelled_distance := 0.0
var max_range := 0.0
## How far the gunner lobbed it: the arc comes back down to deck height here.
var arc_distance := 0.0
var owner_node: Node = null

@onready var sprite: Sprite2D = $CannonballSprite
@onready var base_scale := sprite.scale

func _ready():
	shots_fired += 1

func _physics_process(delta):
	var direction = Vector2.RIGHT.rotated(global_rotation)

	global_position += SPEED * direction * delta
	travelled_distance += SPEED * delta

	if travelled_distance >= max_range:
		queue_free()

	if arc_distance > 0.0:
		sprite.scale = base_scale * (1.0 + (PEAK_SCALE - 1.0) * arc_height(travelled_distance / arc_distance))

## Height as a fraction of the peak at arc progress s: 0 at launch, 1 halfway, 0 on landing,
## and 0 past it, so a miss that flies on stays at deck size.
static func arc_height(s: float) -> float:
	return maxf(0.0, 4.0 * s * (1.0 - s))

func _on_body_entered(body):
	if body == owner_node:
		return

	if not will_hit:
		_try_mast_strike(body)
		return

	if body.has_method("apply_cannonball_hit"):
		var holed = body.apply_cannonball_hit(global_position, CANNONBALL_HOLE_DAMAGE)

		shots_hit += 1
		print("Cannonball accuracy: %d/%d (%s%%)%s" % [
			shots_hit, shots_fired, format_percent(100.0 * shots_hit / shots_fired),
			" -> %s" % holed.name if holed != null else ""
		])

	queue_free()

## A percentage to 3 significant figures: shift the decimals by the magnitude of the value.
static func format_percent(pct: float) -> String:
	var decimals := 0 if pct == 0.0 else clampi(2 - floori(log(pct) / log(10.0)), 0, 12)
	return String.num(pct, decimals)


## A miss goes on over the ship, so hand it the flight it has left and let the ship say
## whether that crossed its mast. A ball that finds the mast stops there, and still counts
## as the miss it was.
func _try_mast_strike(body) -> void:

	if not body.has_method("apply_mast_hit") or (not strikes_mast and randf() >= mast_strike_chance):
		return

	var remaining = Vector2.RIGHT.rotated(global_rotation) * (max_range - travelled_distance)

	if body.apply_mast_hit(global_position, global_position + remaining):
		queue_free()
