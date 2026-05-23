class_name CannonStationPoint
extends StationPoint

@export var broadside: CannonSide.Value
@export var cannon_path: NodePath


func get_cannon(ship: Node) -> Cannon:

	if cannon_path.is_empty():
		return null

	var cannon = get_node_or_null(
		cannon_path
	) as Cannon

	if cannon != null:
		return cannon

	if ship == null:
		return null

	return ship.get_node_or_null(
		cannon_path
	) as Cannon


func get_cannon_for_operator(actor) -> Cannon:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.station_controller == null
	):
		return null

	if actor.ship.station_controller.get_operator(
		self
	) != actor:
		return null

	return get_cannon(
		actor.ship
	)
