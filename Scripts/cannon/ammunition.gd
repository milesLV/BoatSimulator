class_name Ammunition
extends RefCounted

## One kind of shot a cannon can be loaded with. Every kind flies, arcs and holes the same way,
## so a kind is just its numbers, the aims that suit it, and whatever quirk sets it apart.

## Tap to load it, hold for its aims.
var key_action: StringName
var scene: PackedScene
## Grades a hit on the hull opens.
var hole_damage: int
var max_range: float
var speed: float
## What its ring offers; a crewmate who switches to it aims at the first.
var aim_options: Array[Cannon.AimTarget]
## Mast holes one strike on the mast opens.
var mast_holes_per_hit: int
## How far from its centre it can catch the mast. Anything with reach snags it on contact,
## whatever the accuracy roll said.
var mast_reach: float
## Radians per second the sprite tumbles in flight.
var spin: float


func _init(
	new_key_action: StringName,
	scene_path: String,
	new_hole_damage: int,
	new_max_range: float,
	new_speed: float,
	new_aim_options: Array[Cannon.AimTarget],
	new_mast_holes_per_hit := 1,
	new_mast_reach := 0.0,
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
	mast_reach = new_mast_reach
	spin = new_spin


func default_aim() -> Cannon.AimTarget:

	return aim_options[0]


static var CANNONBALL := Ammunition.new(
	&"loadCannonball", "res://Scenes/cannonball.tscn", 3, 1200.0, 500.0,
	[Cannon.AimTarget.HULL, Cannon.AimTarget.MAST, Cannon.AimTarget.CANNON, Cannon.AimTarget.WHEEL, Cannon.AimTarget.CREW]
)
## Two balls chained together: little use against planking, but it spins through the rigging
## and wraps the mast on any contact.
static var CHAINSHOT := Ammunition.new(
	&"loadChainshot", "res://Scenes/chainshot.tscn", 1, 800.0, 400.0,
	[Cannon.AimTarget.MAST, Cannon.AimTarget.WHEEL],
	# spinning, it sweeps a circle half the sprite's ~27px length across
	2, 13.5, TAU * 2.0
)
static var ALL: Array[Ammunition] = [CANNONBALL, CHAINSHOT]
