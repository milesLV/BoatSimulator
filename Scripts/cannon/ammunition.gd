class_name Ammunition
extends RefCounted

var key_action: StringName
var scene: PackedScene
var hole_damage: int
var max_range: float
var speed: float
## The first is the default aim.
var aim_options: Array[Cannon.AimTarget]
var mast_holes_per_hit: int
var wheel_holes_per_hit: int
## Anything with reach snags the mast or wheel on contact, whatever the accuracy roll said.
var reach: float
var spin: float


func _init(
	new_key_action: StringName,
	scene_path: String,
	new_hole_damage: int,
	new_max_range: float,
	new_speed: float,
	new_aim_options: Array[Cannon.AimTarget],
	new_mast_holes_per_hit := 1,
	new_wheel_holes_per_hit := 1,
	new_reach := 0.0,
	new_spin := 0.0
) -> void:

	key_action = new_key_action
	# load, not preload: the scene's script reads this class back
	scene = load(scene_path)
	hole_damage = new_hole_damage
	max_range = new_max_range
	speed = new_speed
	aim_options = new_aim_options
	mast_holes_per_hit = new_mast_holes_per_hit
	wheel_holes_per_hit = new_wheel_holes_per_hit
	reach = new_reach
	spin = new_spin


func default_aim() -> Cannon.AimTarget:

	return aim_options[0]


static var CANNONBALL := Ammunition.new(
	&"loadCannonball", "res://Scenes/cannonball.tscn", 3, 1200.0, 500.0,
	[Cannon.AimTarget.HULL, Cannon.AimTarget.MAST, Cannon.AimTarget.CANNON, Cannon.AimTarget.WHEEL, Cannon.AimTarget.CREW]
)
static var CHAINSHOT := Ammunition.new(
	&"loadChainshot", "res://Scenes/chainshot.tscn", 1, 800.0, 400.0,
	[Cannon.AimTarget.MAST, Cannon.AimTarget.WHEEL],
	# reach is half the sprite's ~27px length, swept as it spins
	2, 3, 13.5, TAU * 2.0
)
static var ALL: Array[Ammunition] = [CANNONBALL, CHAINSHOT]
