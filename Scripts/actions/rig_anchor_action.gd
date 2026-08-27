extends TimedInteractAction
class_name RigAnchorAction


const RIG_DURATION := 0.5

var anchor_point: ShipActionPoint


func _init(new_anchor_point: ShipActionPoint) -> void:

	super(
		new_anchor_point,
		"rig_anchor_to_drop" if new_anchor_point != null else "rig_missing_anchor",
		RIG_DURATION if new_anchor_point != null else 0.0
	)

	anchor_point = new_anchor_point


func on_start(actor, _instance) -> void:

	AnchorSystem.call_for_actor(actor, &"begin_rigging")


func on_interrupt(actor, _instance) -> void:

	AnchorSystem.call_for_actor(actor, &"cancel_rigging")


func on_complete(_actor, _instance) -> void:

	ShipDebugLog.write(&"anchor", "Anchor has been rigged.")
