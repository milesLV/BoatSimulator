class_name CannonStationPoint
extends StationPoint

@export var broadside: Cannon.Side
@export var cannon_path: NodePath

# or_null: the action-point scene is also loaded on its own, away from any cannons
@onready var cannon: Cannon = get_node_or_null(cannon_path)


func get_cannon_for_operator(actor) -> Cannon:

	return cannon if actor.ship.station_controller.get_operator(self) == actor else null
