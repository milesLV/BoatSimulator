extends TimedInteractAction
class_name RigAnchorAction


const RIG_DURATION := 0.5


func _init(new_anchor_point: ShipActionPoint) -> void:

	super(new_anchor_point, "rig_anchor_to_drop", RIG_DURATION)


func on_start(actor, _instance) -> void:

	actor.ship.anchor_system.begin_rigging()


func on_interrupt(actor, _instance) -> void:

	actor.ship.anchor_system.cancel_rigging()


func on_complete(_actor, _instance) -> void:

	ShipDebugLog.write(&"anchor", "Anchor has been rigged.")
