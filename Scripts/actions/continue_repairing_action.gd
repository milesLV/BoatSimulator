class_name ContinueRepairingAction
extends ActionDefinition


func _init() -> void:

	action_id = "continue_repairing"
	base_duration = 0.0
	progress_policy = ProgressPolicy.ONE_SHOT


func on_complete(
	actor,
	instance
) -> void:

	if (
		actor == null
		or actor.ship == null
		or actor.action_executor == null
	):
		super.on_complete(
			actor,
			instance
		)
		return

	var repair_duty_controller = actor.ship.get("repair_duty_controller")

	if (
		repair_duty_controller != null
		and repair_duty_controller.is_repair_duty_crewmate(actor)
	):
		super.on_complete(
			actor,
			instance
		)
		return

	super.on_complete(
		actor,
		instance
	)
